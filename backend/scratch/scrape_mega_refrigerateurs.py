import sys, io, requests, json, time
from bs4 import BeautifulSoup

# Set encoding for console output
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE_URL = "https://www.mega.tn/electromenager/froid/refrigerateur"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    "Accept-Language": "fr-FR,fr;q=0.9"
}

def scrape_mega_refrigerateurs():
    print("Scraping Mega.tn Refrigerator Catalog...")
    
    # Brands identified from previous analysis
    brands = [
        "samsung", "mont-blanc", "newstar", "beko", "condor", "brandt", "whirlpool",
        "telefunken", "hoover", "candy", "premium", "biolux", "acer", "saba", "bosch",
        "lg", "hisense", "tornado", "sharp", "daewoo", "focus", "orient", "arcelik"
    ]
    
    all_products = []
    seen_urls = set()

    for brand in brands:
        url = f"{BASE_URL}/{brand}"
        print(f"Fetching {brand.upper()}...")
        
        try:
            response = requests.get(url, headers=HEADERS, timeout=20)
            if response.status_code != 200:
                print(f"  Failed: {response.status_code}")
                continue
                
            soup = BeautifulSoup(response.content, "html.parser")
            
            # The actual product titles are in <div class="title">
            title_divs = soup.find_all("div", class_="title")
            
            count = 0
            for title_div in title_divs:
                link_tag = title_div.find("a")
                if not link_tag: continue
                
                href = link_tag.get("href", "")
                if brand not in href.lower() and "/refrigerateur/" not in href.lower():
                    continue
                
                name = link_tag.get_text(strip=True)
                # Fix spacing issue where brand and name are glued
                name = name.replace(" -", " - ")
                name = " ".join(name.split())
                
                link = href
                if not link.startswith("http"):
                    link = "https://www.mega.tn" + link
                
                if link in seen_urls:
                    continue
                seen_urls.add(link)
                
                # Navigate up to the product wrapper
                # title -> body -> body-holder -> wrapper
                wrapper = title_div.parent.parent.parent
                if not wrapper: continue
                
                # Extract Image
                image_url = None
                img_div = wrapper.find("div", class_="image")
                if img_div:
                    img_tag = img_div.find("img")
                    if img_tag:
                        image_url = img_tag.get("data-src") or img_tag.get("src")
                        if image_url and not image_url.startswith("http"):
                            image_url = "https://www.mega.tn" + image_url
                
                # Extract Specs
                specs = ""
                desc_span = wrapper.find("span", class_="cl_desc")
                if desc_span:
                    specs = desc_span.get_text(strip=True)
                
                # Extract Price
                price = None
                price_span = wrapper.find("span", class_="value")
                if price_span:
                    try:
                        price = float(price_span.get_text(strip=True))
                    except ValueError:
                        pass
                
                all_products.append({
                    "nom": name,
                    "prix": price,
                    "url": link,
                    "image": image_url,
                    "description": specs,
                    "brand": brand.upper(),
                    "source": "mega.tn"
                })
                count += 1
            
            print(f"  Captured {count} items")
            time.sleep(1) # Be polite
            
        except Exception as e:
            print(f"  Error fetching {brand}: {e}")

    # Save results
    output_file = "mega_refrigerateurs_catalog.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(all_products, f, indent=4, ensure_ascii=False)
    
    print(f"\nDone! Scraped {len(all_products)} products.")

if __name__ == "__main__":
    scrape_mega_refrigerateurs()
