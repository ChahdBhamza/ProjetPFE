import sys, io, requests, re, json, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from bs4 import BeautifulSoup
import concurrent.futures

BASE_URL = "https://www.tunisianet.com.tn"
OUTPUT_FILE = "scrapers/tunisianet_refrigerateurs_catalog.json"
MAX_WORKERS = 6

# Both categories to scrape
CATEGORIES = [
    {"url": f"{BASE_URL}/525-refrigerateur-tunisie",        "pages": 13, "label": "Réfrigérateur"},
    {"url": f"{BASE_URL}/735-mini-refrigerateur-mini-bar",  "pages": 1,  "label": "Mini-Réfrigérateur / Mini-Bar"},
]

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept-Language": "fr-FR,fr;q=0.9",
}

KNOWN_BRANDS = [
    "SAMSUNG", "LG", "BEKO", "BRANDT", "BOSCH", "WHIRLPOOL", "HISENSE",
    "MONTBLANC", "NEWSTAR", "CONDOR", "BIOLUX", "ACER", "FOCUS",
    "TELEFUNKEN", "MAXWELL", "ARISTON", "INDESIT", "CANDY", "HOOVER",
    "SHARP", "TCL", "TORNADO", "SABA", "UNIONAIRE", "SCHNEIDER",
    "IRIS", "JOKER", "AUXSTAR", "RANARO", "DAEWOO", "AZUR",
    "HYUNDAI", "STAR ONE", "STARIONE",
]

# ── Load existing MyTek SKUs ─────────────────────────────────────────────────
def load_existing_skus():
    skus = set()
    for fpath in ["scrapers/mytek_refrigerateurs_catalog.json",
                  "scrapers/mytek_mini_refrigerateurs_catalog.json"]:
        try:
            with open(fpath, encoding="utf-8") as f:
                data = json.load(f)
            for p in data:
                sku = (p.get("sku") or p.get("gtin") or "").strip().upper()
                if sku:
                    skus.add(sku)
            print(f"  Loaded {len(data)} entries from {fpath}")
        except FileNotFoundError:
            print(f"  [WARN] Not found: {fpath}")
    print(f"  Total existing MyTek SKUs: {len(skus)}")
    return skus

# ── Helpers ──────────────────────────────────────────────────────────────────
def get_soup(url):
    try:
        r = requests.get(url, headers=HEADERS, timeout=20)
        r.raise_for_status()
        return BeautifulSoup(r.text, "html.parser")
    except Exception as e:
        print(f"  [ERROR] {url}: {e}")
        return None

def clean(text):
    if not text:
        return None
    return re.sub(r"\s+", " ", str(text)).strip() or None

def parse_price(raw):
    if not raw:
        return None
    digits = re.sub(r"[^\d.,]", "", str(raw)).replace(",", ".")
    try:
        return float(digits)
    except ValueError:
        return None

def detect_brand(name):
    name_up = (name or "").upper()
    for b in KNOWN_BRANDS:
        if b in name_up:
            return b
    return None

# ── Collect links from a category ────────────────────────────────────────────
def collect_links_from_category(cat_url, total_pages, category_label):
    stubs = []
    seen = set()
    for page_num in range(1, total_pages + 1):
        url = cat_url if page_num == 1 else f"{cat_url}?page={page_num}"
        print(f"  [Page {page_num}/{total_pages}] {url}")
        soup = get_soup(url)
        if not soup:
            continue
        items = soup.select("article.product-miniature, .js-product-miniature")
        print(f"    -> {len(items)} items")
        for item in items:
            link = (item.select_one("a.product-thumbnail")
                    or item.select_one("h2 a, .product-title a"))
            if not link:
                continue
            prod_url = link.get("href", "").strip()
            if not prod_url or prod_url in seen:
                continue
            seen.add(prod_url)
            name_tag = item.select_one(".product-title a, h2 a, h3 a")
            name = clean(name_tag.get_text()) if name_tag else clean(link.get("title"))
            price_tag = item.select_one(".price")
            price = parse_price(clean(price_tag.get_text())) if price_tag else None
            img_tag = item.select_one("img")
            img = (img_tag.get("data-src") or img_tag.get("src")) if img_tag else None
            stubs.append({
                "name": name,
                "url": prod_url,
                "listing_price": price,
                "image_url": img,
                "category_label": category_label,
            })
        time.sleep(0.3)
    return stubs

# ── Scrape one product page ───────────────────────────────────────────────────
def scrape_product(stub, existing_skus):
    url = stub["url"]
    soup = get_soup(url)
    product = {
        "name": stub.get("name"),
        "url": url,
        "sku": None,
        "brand": detect_brand(stub.get("name")),
        "category": stub.get("category_label", "Réfrigérateur"),
        "source": "tunisianet",
        "current_price": stub.get("listing_price"),
        "original_price": None,
        "discount_percent": None,
        "short_description": None,
        "full_description": None,
        "availability": None,
        "specifications": {},
        "images": [stub["image_url"]] if stub.get("image_url") else [],
        "primary_image": stub.get("image_url"),
        "duplicate_of_mytek_sku": None,
    }
    if not soup:
        return product

    h1 = soup.select_one("h1[itemprop='name'], h1")
    if h1:
        product["name"] = clean(h1.get_text())
        if not product["brand"]:
            product["brand"] = detect_brand(product["name"])

    ref = soup.select_one(".product-reference span, [itemprop='sku']")
    if ref:
        product["sku"] = clean(ref.get_text()).upper()
    if product["sku"] and product["sku"] in existing_skus:
        product["duplicate_of_mytek_sku"] = product["sku"]

    brand_el = soup.select_one(".manufacturer a, [itemprop='brand'] span, .product-brand")
    if brand_el:
        product["brand"] = clean(brand_el.get_text()).upper()

    cur = soup.select_one(".current-price [itemprop='price'], .current-price .price, span.price")
    if cur:
        product["current_price"] = parse_price(cur.get("content") or cur.get_text())
    old = soup.select_one(".regular-price, .price.old-price, s .price")
    if old:
        product["original_price"] = parse_price(clean(old.get_text()))
    disc = soup.select_one(".discount-percentage, .reduction-amount")
    if disc:
        product["discount_percent"] = clean(disc.get_text())

    avail = soup.select_one(".availability span, [itemprop='availability']")
    if avail:
        product["availability"] = clean(avail.get_text())
    elif soup.select_one(".in-stock, .label-success"):
        product["availability"] = "En stock"
    elif soup.select_one(".out-of-stock, .label-danger"):
        product["availability"] = "Epuisé"

    short = soup.select_one(".product-short-description, [itemprop='description']")
    if short:
        product["short_description"] = clean(short.get_text())
    full = soup.select_one("#description, .product-description")
    if full:
        product["full_description"] = clean(full.get_text())

    for dl in soup.select("dl.data-sheet"):
        for dt, dd in zip(dl.select("dt"), dl.select("dd")):
            k, v = clean(dt.get_text()), clean(dd.get_text())
            if k and v:
                product["specifications"][k] = v
    if not product["specifications"]:
        for row in soup.select("table.table tr, .product-features tr"):
            cells = row.select("td, th")
            if len(cells) >= 2:
                k, v = clean(cells[0].get_text()), clean(cells[1].get_text())
                if k and v:
                    product["specifications"][k] = v

    seen_imgs = set(product["images"])
    for img in soup.select(".product-cover img, .images-container img, [itemprop='image']"):
        src = img.get("data-src") or img.get("src")
        if src and src not in seen_imgs and "placeholder" not in src:
            seen_imgs.add(src)
            product["images"].append(src)
    return product

# ── Main ─────────────────────────────────────────────────────────────────────
print("=" * 60)
print("Tunisianet Full Scraper — Fridges + Mini-Fridges")
print("=" * 60)

print("\nLoading existing MyTek SKUs for deduplication...")
existing_skus = load_existing_skus()

# Collect all stubs from both categories
all_stubs = []
seen_urls = set()
for cat in CATEGORIES:
    print(f"\n[Category] {cat['label']} ({cat['pages']} pages)")
    stubs = collect_links_from_category(cat["url"], cat["pages"], cat["label"])
    # Deduplicate across categories (mini-fridges already in /525 may appear in /735 too)
    for s in stubs:
        if s["url"] not in seen_urls:
            seen_urls.add(s["url"])
            all_stubs.append(s)

print(f"\nTotal unique product URLs collected: {len(all_stubs)}")

print(f"\nScraping {len(all_stubs)} product pages (parallel)...")
results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
    futures = {executor.submit(scrape_product, s, existing_skus): s for s in all_stubs}
    for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
        prod = future.result()
        results.append(prod)
        dup = f" [DUP MyTek: {prod['duplicate_of_mytek_sku']}]" if prod.get("duplicate_of_mytek_sku") else ""
        brand_str = prod.get("brand") or "?"
        print(f"  [{i:>3}/{len(all_stubs)}] {brand_str:<12} | {(prod.get('name') or '')[:55]}{dup}")

# Sort by brand then name
results.sort(key=lambda p: (p.get("brand") or "ZZZZ", p.get("name") or ""))

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

dups    = [p for p in results if p.get("duplicate_of_mytek_sku")]
unique  = [p for p in results if not p.get("duplicate_of_mytek_sku")]
mini    = [p for p in results if "mini" in (p.get("category") or "").lower()]
brands  = {}
for p in results:
    b = p.get("brand") or "Unknown"
    brands[b] = brands.get(b, 0) + 1

print(f"\n{'=' * 60}")
print(f"Done! {len(results)} products saved to: {OUTPUT_FILE}")
print(f"  -> {len(unique)} unique (not in MyTek)")
print(f"  -> {len(dups)} duplicates of MyTek")
print(f"  -> {len(mini)} mini-fridges / mini-bars")
print(f"\nBrand breakdown:")
for b, count in sorted(brands.items(), key=lambda x: -x[1]):
    print(f"  {b}: {count}")
