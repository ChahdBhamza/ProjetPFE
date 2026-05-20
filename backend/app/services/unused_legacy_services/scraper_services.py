# app/services/scraper_service.py
import requests
import re
from bs4 import BeautifulSoup
import concurrent.futures

def fetch_product_details(url, headers):
    try:
        response = requests.get(url, headers=headers, timeout=10)
        soup = BeautifulSoup(response.text, "html.parser")
        
        # Extract Title
        title_tag = soup.find('h1')
        title = title_tag.text.strip() if title_tag else "Unknown Title"
        
        # Extract Price (combining integer and fraction if needed)
        price = "Unknown Price"
        price_tag = soup.select_one(".current-price span")
        if price_tag:
            price = price_tag.text.strip()
             
        # Extract Detailed or Short Description
        desc_tag = soup.find("div", itemprop="description") or soup.find("div", class_="product-description-short")
        description = desc_tag.text.strip() if desc_tag else "No detailed description found"
        
        # Extract Main Image URL
        img_tag = soup.find("img", class_="js-qv-product-cover")
        image_url = img_tag['src'] if img_tag and img_tag.has_attr('src') else None

        # Extract Specifications (Fiche technique)
        specs = {}
        data_sheet = soup.find("dl", class_="data-sheet")
        if data_sheet:
            names = data_sheet.find_all("dt", class_="name")
            values = data_sheet.find_all("dd", class_="value")
            for name, value in zip(names, values):
                specs[name.text.strip()] = value.text.strip()
        
        return {
            "title": title,
            "price": price,
            "description": description,
            "image_url": image_url,
            "specs": specs,
            "product_url": url
        }
    except Exception as e:
        return {"error": str(e), "product_url": url}

def scrape_quotes():
    # The main AC category page containing all brands
    base_url = "https://spacenet.tn/160-climatiseur-tunisie-chaud-froid"

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    
    # 1. & 2. Fetch pages and extract individual product URLs from thumbnails
    links = []
    page = 1
    
    while True:
        url = f"{base_url}?page={page}"
        response = requests.get(url, headers=headers)
        soup = BeautifulSoup(response.text, "html.parser")
        
        page_links = []
        for a in soup.find_all('a', class_='product-thumbnail', href=True):
            if a['href'] not in links:
                links.append(a['href'])
                page_links.append(a['href'])
                
        # If no new links were found on this page, we've reached the end
        if not page_links:
            break
            
        page += 1
        
        # Safeguard to prevent infinite loops just in case
        if page > 10:
            break
            
    # We will use this list to intelligently detect the brand from the title
    known_brands = ["Gree", "Samsung", "Midea", "Condor", "TCL", "Whirlpool", "LG", "Beko", "Unionaire", "Saba", "Montblanc", "Biolux", "BOSCH", "Maxwell", "Westpoint", "Hisense", "Haier", "Sharp", "Panasonic", "Toshiba", "Carrier", "Daikin", "Trane", "York", "Aux"]
            
    # 3. Visit each product page concurrently to scrape deep data
    grouped_quotes = {}
    
    # Using ThreadPoolExecutor to make multiple concurrent requests
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(fetch_product_details, link, headers) for link in links]
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            if result:
                title = result.get("title", "")
                
                # Determine brand from title
                detected_brand = "Other"
                for brand in known_brands:
                    if brand.lower() in title.lower():
                        detected_brand = brand
                        break
                        
                # Add product to its brand category and increment count
                if detected_brand not in grouped_quotes:
                    grouped_quotes[detected_brand] = {
                        "count": 0,
                        "products": []
                    }
                grouped_quotes[detected_brand]["products"].append(result)
                grouped_quotes[detected_brand]["count"] += 1
                
    return grouped_quotes

if __name__ == "__main__":
    import json
    print("🚀 Starting scraper test...")
    results = scrape_quotes()
    
    # Save the results to a JSON file
    with open("scraper_results.json", "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=4)
        
    print(f"✅ Scraping complete! Found {len(results)} brands.")
    print("📂 Results saved to 'scraper_results.json'")
