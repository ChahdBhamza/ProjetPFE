import sys, io, requests, json, re, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE = "https://www.mytek.tn/rest/V1"
IMAGE_BASE = "https://www.mytek.tn/media/catalog/product"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json",
    "Accept-Language": "fr-FR,fr;q=0.9"
}

# ────────────────────────────────────────────────
# Attribute option resolver (maps int IDs → labels)
# ────────────────────────────────────────────────
ATTR_CACHE = {}  # {attribute_code: {option_id: label}}

def get_attribute_options(attr_code: str) -> dict:
    if attr_code in ATTR_CACHE:
        return ATTR_CACHE[attr_code]
    try:
        url = f"{BASE}/products/attributes/{attr_code}"
        r = requests.get(url, headers=HEADERS, timeout=15)
        data = r.json()
        mapping = {}
        for opt in data.get("options", []):
            if opt.get("value") and opt.get("label"):
                mapping[str(opt["value"])] = opt["label"]
        ATTR_CACHE[attr_code] = mapping
        return mapping
    except Exception as e:
        print(f"  [WARN] Failed to resolve attr '{attr_code}': {e}")
        ATTR_CACHE[attr_code] = {}
        return {}

def resolve(attr_code: str, raw_value) -> str:
    """Try to resolve a numeric option ID to its label text."""
    if raw_value is None:
        return None
    val_str = str(raw_value).strip()
    if not val_str.isdigit():
        return val_str  # Already a label / text value
    options = get_attribute_options(attr_code)
    return options.get(val_str, val_str)

# ────────────────────────────────────────────────
# HTML → plain text helper
# ────────────────────────────────────────────────
def strip_html(html_str: str | None) -> str | None:
    if not html_str:
        return None
    text = re.sub(r"<[^>]+>", " ", html_str)
    text = re.sub(r"\s+", " ", text).strip()
    return text if text else None

# ────────────────────────────────────────────────
# Build product URL from url_key
# ────────────────────────────────────────────────
def make_product_url(url_key: str | None) -> str | None:
    if not url_key:
        return None
    return f"https://www.mytek.tn/{url_key}.html"

# ────────────────────────────────────────────────
# Build image URLs from media gallery entries
# ────────────────────────────────────────────────
def build_images(media_entries: list) -> list[str]:
    images = []
    for entry in sorted(media_entries, key=lambda x: (x.get("disabled", True), x.get("position", 99))):
        if not entry.get("disabled", True) or entry.get("types"):
            file_path = entry.get("file", "")
            if file_path:
                images.append(IMAGE_BASE + file_path)
    return images

# ────────────────────────────────────────────────
# Main custom_attributes extractor
# ────────────────────────────────────────────────
KNOWN_ATTR_CODES = [
    "short_description", "description", "meta_description", "meta_title", "meta_keyword",
    "url_key", "image", "small_image", "thumbnail",
    "manufacturer", "couleur", "garantie",
    "type", "type_de_pose", "systeme_de_refroidissement",
    "inverter", "classe_energetique", "avec_distributeur", "afficheur",
    "volume_brut", "nombre_de_portes", "dimensions", "consommation_d_energie",
    "nombre_d_etoiles", "gtin", "erpstock", "type_gabarit",
    "garanties", "garanties_delais",
    "special_price", "special_from_date", "special_to_date",
]

RESOLVE_CODES = [
    "couleur", "garantie", "type", "type_de_pose",
    "systeme_de_refroidissement", "inverter", "classe_energetique",
    "avec_distributeur", "afficheur", "volume_brut", "nombre_de_portes",
    "manufacturer",
]

def extract_attrs(custom_attributes: list) -> dict:
    result = {}
    for attr in custom_attributes:
        code = attr.get("attribute_code")
        val = attr.get("value")
        if code:
            result[code] = val
    return result

# ────────────────────────────────────────────────
# Resolve all known enum attributes (batch)
# ────────────────────────────────────────────────
def resolve_enums(attrs: dict) -> dict:
    resolved = {}
    for code in RESOLVE_CODES:
        raw = attrs.get(code)
        if raw is not None:
            resolved[code] = resolve(code, raw)
    return resolved

# ────────────────────────────────────────────────
# Fetch all products via paginated REST API
# ────────────────────────────────────────────────
def fetch_all_products(category_id: str = "364", page_size: int = 50) -> list[dict]:
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

# ────────────────────────────────────────────────
# Transform raw API item → clean product dict
# ────────────────────────────────────────────────
def transform(item: dict) -> dict:
    attrs = extract_attrs(item.get("custom_attributes", []))
    enums = resolve_enums(attrs)
    
    # Special / sale price comes from extension or custom_attributes
    special_price = attrs.get("special_price")
    special_from = attrs.get("special_from_date")
    special_to   = attrs.get("special_to_date")
    
    # Stock: erpstock attribute is a warehouse ID, availability comes from status
    # status: 1=enabled (In Stock), 2=disabled (Out of Stock)
    status = item.get("status", 1)
    stock_status = "En stock" if status == 1 else "Epuisé"
    
    # Build image list
    images = build_images(item.get("media_gallery_entries", []))
    if not images and attrs.get("image"):
        images = [IMAGE_BASE + attrs["image"]]
    
    # Short description plain text
    short_desc_html = attrs.get("short_description", "")
    short_desc = strip_html(short_desc_html)
    
    # Full description plain text
    full_desc_html = attrs.get("description", "")
    full_desc = strip_html(full_desc_html)
    
    product_url = make_product_url(attrs.get("url_key"))
    
    return {
        # ── Identification ──────────────────────────────
        "name": item.get("name"),
        "sku": item.get("sku"),
        "gtin": attrs.get("gtin"),
        "internal_id": item.get("id"),
        "brand": enums.get("manufacturer"),
        "category": "Réfrigérateur",
        "url": product_url,
        
        # ── Pricing ─────────────────────────────────────
        "current_price": item.get("price"),
        "special_price": float(special_price) if special_price else None,
        "special_price_from": special_from,
        "special_price_to": special_to,
        
        # ── Descriptions ────────────────────────────────
        "short_description": short_desc,
        "full_description": full_desc,
        "meta_title": attrs.get("meta_title"),
        "meta_description": attrs.get("meta_description"),
        "meta_keywords": attrs.get("meta_keyword"),
        
        # ── Availability ────────────────────────────────
        "availability": stock_status,
        "stock_status": stock_status,
        "erp_warehouse_id": attrs.get("erpstock"),
        
        # ── Technical Specs ─────────────────────────────
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
        
        # ── Media ────────────────────────────────────────
        "images": images,
        "primary_image": images[0] if images else None,
        
        # ── Delivery ────────────────────────────────────
        "delivery_info": "Retrait en Magasin ou Livraison Gratuite* (*Livraison Gratuite Pour 1 seul colis <= 30 Kg)",
        
        # ── Dates ────────────────────────────────────────
        "updated_at": item.get("updated_at"),
        "created_at": item.get("created_at"),
    }

# ────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────
print("=" * 60)
print("MyTek Refrigerateur - REST API Scraper")
print("=" * 60)

print("\nStep 1: Pre-loading attribute option mappings...")
for code in RESOLVE_CODES:
    opts = get_attribute_options(code)
    print(f"  {code}: {len(opts)} options")
    time.sleep(0.2)

print(f"\nStep 2: Fetching all products from category 364...")
raw_items = fetch_all_products(category_id="364", page_size=100)
print(f"  Total raw items fetched: {len(raw_items)}")

print(f"\nStep 3: Transforming {len(raw_items)} products...")
results = []
for i, item in enumerate(raw_items):
    prod = transform(item)
    results.append(prod)
    if (i + 1) % 50 == 0:
        print(f"  Processed {i+1}/{len(raw_items)}...")

print(f"\nStep 4: Saving...")
output_path = "scrapers/mytek_refrigerateurs_catalog.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

print(f"\nDone! {len(results)} products saved to: {output_path}")

# Quick summary
brands = {}
for p in results:
    b = p.get("brand") or "Unknown"
    brands[b] = brands.get(b, 0) + 1
print("\nBrand breakdown:")
for b, count in sorted(brands.items(), key=lambda x: -x[1]):
    print(f"  {b}: {count}")
