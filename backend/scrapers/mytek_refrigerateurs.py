import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

"""
MyTek Refrigerator Scraper
==========================
Scrapes all refrigerators from https://www.mytek.tn/electromenager/froid/refrigerateur.html
across all 6 pages, then visits each product page for full details.

Output: scrapers/mytek_refrigerateurs_catalog.json
"""

import requests
import re
import json
import time
import concurrent.futures
from bs4 import BeautifulSoup
from pathlib import Path


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
BASE_URL = "https://www.mytek.tn"
CATEGORY_URL = f"{BASE_URL}/electromenager/froid/refrigerateur.html"
TOTAL_PAGES = 6
OUTPUT_FILE = Path(__file__).parent / "mytek_refrigerateurs_catalog.json"
MAX_WORKERS = 6          # parallel product-page fetchers
REQUEST_DELAY = 0.3      # seconds between page-list requests

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "fr-FR,fr;q=0.9,en;q=0.8",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def get_soup(url: str) -> BeautifulSoup | None:
    """Fetch a URL and return a BeautifulSoup object, or None on failure."""
    try:
        resp = requests.get(url, headers=HEADERS, timeout=20)
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "html.parser")
    except Exception as exc:
        print(f"  [ERROR] fetching {url}: {exc}")
        return None


def clean(text: str | None) -> str | None:
    """Strip extra whitespace from a string."""
    if text is None:
        return None
    cleaned = re.sub(r"\s+", " ", text).strip()
    return cleaned if cleaned else None


def parse_price(raw: str | None) -> float | None:
    """Convert '1 499.000 DT' → 1499.0, or None if not parseable."""
    if not raw:
        return None
    digits = re.sub(r"[^\d.]", "", raw.replace(",", "."))
    try:
        return float(digits)
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Step 1 – Collect all product links from category pages
# ---------------------------------------------------------------------------
def collect_product_links() -> list[dict]:
    """
    Iterate all 6 listing pages and collect product stubs:
    { name, url, sku, listing_price, listing_price_original, availability, brand, image_url }
    """
    stubs = []
    seen_urls = set()

    for page_num in range(1, TOTAL_PAGES + 1):
        url = CATEGORY_URL if page_num == 1 else f"{CATEGORY_URL}?p={page_num}"
        print(f"[Page {page_num}/{TOTAL_PAGES}] Fetching listing: {url}")
        soup = get_soup(url)
        if not soup:
            continue

        items = soup.select("li.product-item")
        if not items:
            # Fallback – some themes wrap products differently
            items = soup.select(".product-item")
        print(f"  -> Found {len(items)} items on page {page_num}")

        for item in items:
            # --- Product URL ---
            link_tag = item.select_one("a.product-item-link")
            if not link_tag:
                link_tag = item.select_one("a[href]")
            if not link_tag:
                continue
            prod_url = link_tag.get("href", "").strip()
            if not prod_url.startswith("http"):
                prod_url = BASE_URL + prod_url
            if prod_url in seen_urls:
                continue
            seen_urls.add(prod_url)

            # --- Name ---
            name = clean(link_tag.get_text())

            # --- SKU (shown in brackets on listing cards) ---
            sku_tag = item.select_one(".product-item-sku") or item.select_one("[data-sku]")
            sku = None
            if sku_tag:
                sku = clean(sku_tag.get_text())
            else:
                # Try scraping from the text blob that wraps the SKU in [brackets]
                card_text = item.get_text()
                m = re.search(r"\[([A-Z0-9\-]+)\]", card_text)
                if m:
                    sku = m.group(1)

            # --- Image ---
            img_tag = item.select_one("img.product-image-photo") or item.select_one("img")
            image_url = None
            if img_tag:
                image_url = img_tag.get("data-src") or img_tag.get("src")
                if image_url and not image_url.startswith("http"):
                    image_url = BASE_URL + image_url

            # --- Listing price ---
            price_tag = item.select_one(".price-wrapper .price") or item.select_one(".price")
            listing_price_raw = clean(price_tag.get_text()) if price_tag else None
            listing_price = parse_price(listing_price_raw)

            # --- Old/original price (strikethrough) ---
            old_price_tag = item.select_one(".old-price .price") or item.select_one("del .price")
            listing_price_original_raw = clean(old_price_tag.get_text()) if old_price_tag else None
            listing_price_original = parse_price(listing_price_original_raw)

            # --- Availability on listing card ---
            avail_tag = item.select_one(".stock-status") or item.select_one(".availability")
            availability_listing = clean(avail_tag.get_text()) if avail_tag else None

            # --- Brand (from logo title attribute) ---
            brand_tag = item.select_one("a[title]")
            brand = None
            if brand_tag and brand_tag.get("title", "").isupper():
                brand = brand_tag.get("title")

            stubs.append({
                "name": name,
                "url": prod_url,
                "sku": sku,
                "listing_price": listing_price,
                "listing_price_original": listing_price_original,
                "availability_listing": availability_listing,
                "brand": brand,
                "image_url": image_url,
            })

        time.sleep(REQUEST_DELAY)

    print(f"\nTotal product links collected: {len(stubs)}")
    return stubs


# ---------------------------------------------------------------------------
# Step 2 – Scrape each product's detail page
# ---------------------------------------------------------------------------
def scrape_product_page(stub: dict) -> dict:
    """Visit a product URL and enrich the stub with full details."""
    url = stub["url"]
    soup = get_soup(url)

    product = {
        # Carry over listing-level data
        "name": stub.get("name"),
        "url": url,
        "sku": stub.get("sku"),
        "brand": stub.get("brand"),
        "image_url": stub.get("image_url"),
        "listing_price": stub.get("listing_price"),
        "listing_price_original": stub.get("listing_price_original"),
        "availability_listing": stub.get("availability_listing"),
        # Detail-level fields (filled below)
        "category": "Réfrigérateur",
        "subcategory": None,
        "reference": None,
        "current_price": None,
        "original_price": None,
        "promo_label": None,
        "short_description": None,
        "full_description": None,
        "specifications": {},
        "features": [],
        "availability": None,
        "stock_status": None,
        "delivery_info": None,
        "in_store_pickup": None,
        "images": [],
        "videos": [],
        "rating": None,
        "review_count": None,
        "reviews": [],
        "warranty": None,
        "color": None,
        "badges": [],
        "tags": [],
        "certifications": [],
        "variants": [],
    }

    if not soup:
        return product

    # ---- Page title / full name ----
    h1 = soup.select_one("h1.page-title span, h1.product-name, h1")
    if h1:
        product["name"] = clean(h1.get_text()) or product["name"]

    # ---- SKU / Reference ----
    sku_tag = (
        soup.select_one(".product.attribute.sku .value")
        or soup.select_one("[itemprop='sku']")
        or soup.select_one(".sku .value")
    )
    if sku_tag:
        product["reference"] = clean(sku_tag.get_text())
    if not product["sku"] and product["reference"]:
        product["sku"] = product["reference"]

    # ---- Prices ----
    price_box = soup.select_one(".product-info-price")
    if price_box:
        # Current price
        cur = price_box.select_one(".price-wrapper[data-price-type='finalPrice'] .price")
        if cur:
            product["current_price"] = parse_price(cur.get_text())
        # Original / was price
        old = price_box.select_one(".price-wrapper[data-price-type='oldPrice'] .price")
        if old:
            product["original_price"] = parse_price(old.get_text())
        # Promo label
        promo = price_box.select_one(".badge-promo, .special-price .label, .percent-discount")
        if promo:
            product["promo_label"] = clean(promo.get_text())

    # Fallback price
    if not product["current_price"]:
        p = soup.select_one(".price")
        if p:
            product["current_price"] = parse_price(p.get_text())

    # ---- Short description ----
    short_desc = soup.select_one(".product.attribute.overview .value, .short-description, [itemprop='description']")
    if short_desc:
        product["short_description"] = clean(short_desc.get_text())

    # ---- Full / long description ----
    full_desc = soup.select_one("#description .value, .product.attribute.description .value, [data-role='content']")
    if full_desc:
        product["full_description"] = clean(full_desc.get_text())

    # ---- Availability / Stock ----
    avail = soup.select_one(".stock span, .availability .value, [itemprop='availability']")
    if avail:
        product["availability"] = clean(avail.get_text())
        product["stock_status"] = product["availability"]

    # ---- Delivery / Shipping info ----
    delivery_blocks = soup.select(".delivery-info, .shipping-info, .livraison")
    if delivery_blocks:
        product["delivery_info"] = " | ".join(clean(b.get_text()) for b in delivery_blocks if clean(b.get_text()))

    # Fallback – look for delivery in the page text
    if not product["delivery_info"]:
        for txt_node in soup.find_all(string=re.compile(r"livraison|retrait|magasin", re.I)):
            txt = clean(txt_node)
            if txt and len(txt) > 10:
                product["delivery_info"] = txt
                break

    # ---- In-store pickup ----
    pickup = soup.select_one(".store-pickup, .retrait-magasin, .click-collect")
    if pickup:
        product["in_store_pickup"] = clean(pickup.get_text())

    # ---- Specifications table ----
    spec_table = soup.select_one("#product-attribute-specs-table, .product-attributes table, .data.table.additional-attributes")
    if spec_table:
        for row in spec_table.select("tr"):
            cells = row.select("th, td")
            if len(cells) >= 2:
                key = clean(cells[0].get_text())
                val = clean(cells[1].get_text())
                if key and val:
                    product["specifications"][key] = val
    else:
        # Try definition list format
        for dl in soup.select("dl.product-attributes, .attribute-list"):
            dts = dl.select("dt")
            dds = dl.select("dd")
            for dt, dd in zip(dts, dds):
                key = clean(dt.get_text())
                val = clean(dd.get_text())
                if key and val:
                    product["specifications"][key] = val

    # ---- Features / bullet list ----
    feature_list = soup.select(".product-features li, .product-details ul li, .description ul li")
    for li in feature_list:
        feat = clean(li.get_text())
        if feat and feat not in product["features"]:
            product["features"].append(feat)

    # ---- Images (all product images) ----
    gallery = soup.select(".fotorama__stage img, .gallery-placeholder img, .product.media img")
    if not gallery:
        gallery = soup.select("img[itemprop='image'], .product-image-photo")
    seen_imgs = set()
    for img in gallery:
        src = img.get("data-src") or img.get("data-zoom-image") or img.get("src")
        if src and src not in seen_imgs and "placeholder" not in src:
            if not src.startswith("http"):
                src = BASE_URL + src
            seen_imgs.add(src)
            product["images"].append(src)

    # Ensure listing thumbnail is included
    if stub.get("image_url") and stub["image_url"] not in seen_imgs:
        product["images"].insert(0, stub["image_url"])

    # ---- Videos ----
    for video in soup.select("video source, iframe[src*='youtube'], iframe[src*='youtu.be']"):
        src = video.get("src") or video.get("data-src")
        if src:
            product["videos"].append(src)

    # ---- Brand (more reliable from product page) ----
    brand_el = soup.select_one(".product-brand img, .brand-logo img, a[title][href*='/brand/']")
    if brand_el:
        product["brand"] = brand_el.get("title") or brand_el.get("alt") or product["brand"]

    # ---- Warranty ----
    for key, val in product["specifications"].items():
        if re.search(r"garant", key, re.I):
            product["warranty"] = val
            break

    # ---- Color ----
    for key, val in product["specifications"].items():
        if re.search(r"coul", key, re.I):
            product["color"] = val
            break
    # Fallback: parse from name
    if not product["color"]:
        color_m = re.search(r"-\s*(blanc|noir|silver|gris|inox|rouge|bleu|rose|platine|dark\s+\w+)$", product["name"] or "", re.I)
        if color_m:
            product["color"] = color_m.group(1).strip().capitalize()

    # ---- Ratings & Reviews ----
    rating_el = soup.select_one("[itemprop='ratingValue'], .rating-result span, .rating-summary .rating-result")
    if rating_el:
        product["rating"] = clean(rating_el.get("content") or rating_el.get_text())
    review_count_el = soup.select_one("[itemprop='reviewCount'], .reviews-actions a")
    if review_count_el:
        text = clean(review_count_el.get_text())
        m = re.search(r"\d+", text or "")
        product["review_count"] = int(m.group()) if m else None
    for review in soup.select(".review-item"):
        title = clean(review.select_one(".review-title"))
        body = clean(review.select_one(".review-content, .review-text"))
        rating = clean(review.select_one(".rating-result span"))
        author = clean(review.select_one(".review-author .value"))
        date = clean(review.select_one(".review-date .value"))
        if body:
            product["reviews"].append({
                "title": title,
                "body": body,
                "rating": rating,
                "author": author,
                "date": date,
            })

    # ---- Badges / labels (e.g. "Nouveau", "Promo", "Top Vente") ----
    for badge in soup.select(".product-label, .badge, .product-label-text, .amribbon-label"):
        txt = clean(badge.get_text())
        if txt and txt not in product["badges"]:
            product["badges"].append(txt)

    # ---- Variants (if multi-color or multi-config on same page) ----
    for opt in soup.select(".swatch-attribute-options .swatch-option, .product-options-wrapper .swatch-option"):
        product["variants"].append(clean(opt.get("aria-label") or opt.get_text()))

    return product


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print("=" * 60)
    print("MyTek Réfrigérateurs – Full Catalog Scraper")
    print("=" * 60)

    # --- Phase 1: Collect all product links from the 6 listing pages ---
    stubs = collect_product_links()

    if not stubs:
        print("[FATAL] No products found. Aborting.")
        return

    # --- Phase 2: Visit each product page concurrently ---
    print(f"\nScraping {len(stubs)} product pages (max {MAX_WORKERS} parallel)…")
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(scrape_product_page, stub): stub for stub in stubs}
        for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
            prod = future.result()
            results.append(prod)
            print(f"  [{i}/{len(stubs)}] ✓ {prod.get('name', '?')} — {prod.get('current_price')} DT")

    # --- Phase 3: Sort by price and save ---
    results.sort(key=lambda p: (p.get("current_price") or 0))

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n{'=' * 60}")
    print(f"Done! {len(results)} products saved to:")
    print(f"  {OUTPUT_FILE}")
    print("=" * 60)


if __name__ == "__main__":
    main()
