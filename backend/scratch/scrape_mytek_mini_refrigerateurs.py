import sys, io, requests, json, re, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE = "https://www.mytek.tn/rest/V1"
IMAGE_BASE = "https://www.mytek.tn/media/catalog/product"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json",
    "Accept-Language": "fr-FR,fr;q=0.9"
}

ATTR_CACHE = {}

def get_attribute_options(attr_code):
    if attr_code in ATTR_CACHE:
        return ATTR_CACHE[attr_code]
    try:
        r = requests.get(f"{BASE}/products/attributes/{attr_code}", headers=HEADERS, timeout=15)
        data = r.json()
        mapping = {str(opt["value"]): opt["label"] for opt in data.get("options", []) if opt.get("value") and opt.get("label")}
        ATTR_CACHE[attr_code] = mapping
        return mapping
    except Exception as e:
        print(f"  [WARN] Failed to resolve attr '{attr_code}': {e}")
        ATTR_CACHE[attr_code] = {}
        return {}

def resolve(attr_code, raw_value):
    if raw_value is None:
        return None
    val_str = str(raw_value).strip()
    if not val_str.isdigit():
        return val_str
    return get_attribute_options(attr_code).get(val_str, val_str)

def strip_html(html_str):
    if not html_str:
        return None
    text = re.sub(r"<[^>]+>", " ", html_str)
    text = re.sub(r"\s+", " ", text).strip()
    return text if text else None

def make_product_url(url_key):
    return f"https://www.mytek.tn/{url_key}.html" if url_key else None

def build_images(media_entries):
    images = []
    for entry in sorted(media_entries, key=lambda x: (x.get("disabled", True), x.get("position", 99))):
        if not entry.get("disabled", True) or entry.get("types"):
            file_path = entry.get("file", "")
            if file_path:
                images.append(IMAGE_BASE + file_path)
    return images

RESOLVE_CODES = [
    "couleur", "garantie", "type", "type_de_pose",
    "systeme_de_refroidissement", "inverter", "classe_energetique",
    "avec_distributeur", "afficheur", "volume_brut", "nombre_de_portes",
    "manufacturer",
]

def extract_attrs(custom_attributes):
    return {attr["attribute_code"]: attr["value"] for attr in custom_attributes if attr.get("attribute_code")}

def resolve_enums(attrs):
    return {code: resolve(code, attrs.get(code)) for code in RESOLVE_CODES}

def fetch_all_products(category_id, page_size=100):
    all_items = []
    page = 1
    while True:
        params = {
            "searchCriteria[filterGroups][0][filters][0][field]": "category_id",
            "searchCriteria[filterGroups][0][filters][0][value]": category_id,
            "searchCriteria[filterGroups][0][filters][0][conditionType]": "eq",
            "searchCriteria[pageSize]": str(page_size),
            "searchCriteria[currentPage]": str(page),
        }
        try:
            r = requests.get(f"{BASE}/products", headers=HEADERS, params=params, timeout=30)
            data = r.json()
        except Exception as e:
            print(f"[ERROR] Page {page}: {e}")
            break
        items = data.get("items", [])
        total = data.get("total_count", 0)
        all_items.extend(items)
        print(f"  Page {page}: got {len(items)} items | cumulative {len(all_items)}/{total}")
        if len(all_items) >= total or not items:
            break
        page += 1
        time.sleep(0.3)
    return all_items

def transform(item):
    attrs = extract_attrs(item.get("custom_attributes", []))
    enums = resolve_enums(attrs)
    status = item.get("status", 1)
    stock_status = "En stock" if status == 1 else "Epuisé"
    images = build_images(item.get("media_gallery_entries", []))
    if not images and attrs.get("image"):
        images = [IMAGE_BASE + attrs["image"]]
    return {
        "name": item.get("name"),
        "sku": item.get("sku"),
        "gtin": attrs.get("gtin"),
        "internal_id": item.get("id"),
        "brand": enums.get("manufacturer"),
        "category": "Mini-Réfrigérateur",
        "url": make_product_url(attrs.get("url_key")),
        "current_price": item.get("price"),
        "special_price": float(attrs["special_price"]) if attrs.get("special_price") else None,
        "special_price_from": attrs.get("special_from_date"),
        "special_price_to": attrs.get("special_to_date"),
        "short_description": strip_html(attrs.get("short_description")),
        "full_description": strip_html(attrs.get("description")),
        "meta_title": attrs.get("meta_title"),
        "meta_description": attrs.get("meta_description"),
        "meta_keywords": attrs.get("meta_keyword"),
        "availability": stock_status,
        "stock_status": stock_status,
        "erp_warehouse_id": attrs.get("erpstock"),
        "specifications": {
            "type": enums.get("type"),
            "type_de_pose": enums.get("type_de_pose"),
            "systeme_de_refroidissement": enums.get("systeme_de_refroidissement"),
            "inverter": enums.get("inverter"),
            "classe_energetique": enums.get("classe_energetique"),
            "avec_distributeur": enums.get("avec_distributeur"),
            "afficheur": enums.get("afficheur"),
            "volume_brut": enums.get("volume_brut"),
            "nombre_de_portes": enums.get("nombre_de_portes"),
            "couleur": enums.get("couleur"),
            "garantie": enums.get("garantie"),
            "dimensions": attrs.get("dimensions"),
            "consommation_d_energie": attrs.get("consommation_d_energie"),
            "nombre_d_etoiles": attrs.get("nombre_d_etoiles"),
            "type_gabarit": attrs.get("type_gabarit"),
        },
        "images": images,
        "primary_image": images[0] if images else None,
        "delivery_info": "Retrait en Magasin ou Livraison Gratuite* (*Livraison Gratuite Pour 1 seul colis <= 30 Kg)",
        "updated_at": item.get("updated_at"),
        "created_at": item.get("created_at"),
    }

# ── Run ──────────────────────────────────────────────────────────
print("=" * 60)
print("MyTek Mini-Réfrigérateur - REST API Scraper (category 228)")
print("=" * 60)

print("\nStep 1: Pre-loading attribute option mappings...")
for code in RESOLVE_CODES:
    opts = get_attribute_options(code)
    print(f"  {code}: {len(opts)} options")
    time.sleep(0.2)

print("\nStep 2: Fetching all products from category 228...")
raw_items = fetch_all_products(category_id="228", page_size=100)
print(f"  Total raw items: {len(raw_items)}")

print(f"\nStep 3: Transforming {len(raw_items)} products...")
results = [transform(item) for item in raw_items]

# Sort by brand then name
results.sort(key=lambda p: (p.get("brand") or "ZZZZ", p.get("name") or ""))

print("\nStep 4: Saving...")
output_path = "scrapers/mytek_mini_refrigerateurs_catalog.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

print(f"\nDone! {len(results)} products saved to: {output_path}")
brands = {}
for p in results:
    b = p.get("brand") or "Unknown"
    brands[b] = brands.get(b, 0) + 1
print("\nBrand breakdown:")
for b, count in sorted(brands.items(), key=lambda x: -x[1]):
    print(f"  {b}: {count}")
