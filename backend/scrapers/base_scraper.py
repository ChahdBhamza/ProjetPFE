import requests
import re
from bs4 import BeautifulSoup
import json
import concurrent.futures
from pathlib import Path

class BaseScraper:
    def __init__(self, name, base_url):
        self.name = name
        self.base_url = base_url
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        }
        self.known_brands = [
            "Gree", "Samsung", "Midea", "Condor", "TCL", "Whirlpool", "LG", "Beko", "Unionaire", 
            "Saba", "Montblanc", "Biolux", "BOSCH", "Maxwell", "Westpoint", "Hisense", "Haier", 
            "Sharp", "Panasonic", "Toshiba", "Carrier", "Daikin", "Trane", "York", "Aux", "Iris", 
            "Brandt", "NewStar", "Vega", "Fresh", "Tornado", "Focus", "Coala", "Hyundai", 
            "Comfee", "Orient", "General Gold", "Servicom", "Airwell", "Manta", "Sabra", "Galanz"
        ]

    def get_soup(self, url):
        try:
            response = requests.get(url, headers=self.headers, timeout=15)
            response.raise_for_status()
            return BeautifulSoup(response.text, "html.parser")
        except Exception as e:
            print(f"Error fetching {url}: {e}")
            return None

    def detect_brand(self, title):
        if not title: return "Other"
        for brand in self.known_brands:
            if re.search(rf'\b{re.escape(brand)}\b', title, re.I):
                return brand
        return "Other"

    def save_results(self, results):
        # Save to the same folder as the scraper
        output_file = Path(__file__).parent / f"scraper_{self.name}_results.json"
        
        standardized_data = {}
        for product in results:
            brand = self.detect_brand(product['title'])
            if brand not in standardized_data:
                standardized_data[brand] = {"count": 0, "products": []}
            standardized_data[brand]["products"].append(product)
            standardized_data[brand]["count"] += 1

        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(standardized_data, f, ensure_ascii=False, indent=4)
        print(f"[{self.name}] Finalized {len(results)} products across {len(standardized_data)} brands.")

    def run(self):
        print(f"Starting optimized scraper for {self.name}...")
        links = self.get_all_product_links()
        print(f"Found {len(links)} products to scrape.")
        
        results = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(self.fetch_product_details, link) for link in links]
            for future in concurrent.futures.as_completed(futures):
                res = future.result()
                if res: results.append(res)
        
        self.save_results(results)

    def get_all_product_links(self):
        raise NotImplementedError

    def fetch_product_details(self, url):
        raise NotImplementedError
