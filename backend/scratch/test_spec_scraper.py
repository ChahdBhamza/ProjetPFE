# -*- coding: utf-8 -*-
"""Quick test: See what DuckDuckGo + BeautifulSoup actually scrape"""
import sys
import os
os.environ["PYTHONIOENCODING"] = "utf-8"
sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, ".")

from app.services.spec_service import SpecService

svc = SpecService()

brand = "Samsung"
model = "RT38"
eq_type = "refrigerator"

# Step 1: DuckDuckGo URLs
print("=" * 60)
print(f"STEP 1: DuckDuckGo Search for '{brand} {model} {eq_type}'")
print("=" * 60)
urls = svc.search_product_urls(brand, model, eq_type)
for i, u in enumerate(urls):
    print(f"\n  [{i+1}] {u['title']}")
    print(f"      URL: {u['url']}")
    print(f"      Snippet: {u['snippet'][:120]}...")

# Step 2: Scrape the best one
print("\n" + "=" * 60)
print("STEP 2: BeautifulSoup Scraping")
print("=" * 60)
for u in urls:
    url = u.get("url", "")
    if not url:
        continue
    print(f"\n  Scraping: {url[:80]}...")
    content = svc.scrape_page_content(url)
    print(f"  Content length: {len(content)} chars")
    print(f"\n--- RAW SCRAPED CONTENT (first 2000 chars) ---")
    print(content[:2000])
    print("--- END ---")
    if len(content) > 500:
        break
