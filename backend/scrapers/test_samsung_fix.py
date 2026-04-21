import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from jumbo import JumboScraper
import json

def test_product():
    scraper = JumboScraper()
    url = "https://jumbo.tn/climatiseur/3441-climatiseur-samsung-12000-btu-inverter-chaud-froid-wifi-technologie-windfree.html"
    details = scraper.fetch_product_details(url)
    if details:
        dim = details["specs"].get("Dimensions", "Not found")
        print(f"DIMENSIONS_FOUND: {dim}")
    else:
        print("FAILED")

if __name__ == "__main__":
    test_product()
