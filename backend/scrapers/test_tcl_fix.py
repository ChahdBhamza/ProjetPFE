import sys
import os
# Add parent directory to path so we can import base_scraper
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from jumbo import JumboScraper
import json

def test_product():
    scraper = JumboScraper()
    url = "https://jumbo.tn/climatiseur/8813-climatiseur-tcl-9000-btu-chaud-froid-inverter-tac-09-chsaxa51.html"
    print(f"Testing TCL URL: {url}")
    details = scraper.fetch_product_details(url)
    if details:
        print(json.dumps(details, indent=4, ensure_ascii=False))
    else:
        print("Failed to fetch details.")

if __name__ == "__main__":
    test_product()
