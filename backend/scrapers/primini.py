from base_scraper import BaseScraper
import json
import re

class PriminiScraper(BaseScraper):
    def __init__(self):
        super().__init__("primini", "https://primini.tn/liste-produit/climatiseurs")
        self.standard_keys = [
            "Reference", "Model", "Capacity", "Technology", "Mode", 
            "Energy_Class", "Gas_Type", "Dimensions", "Weight", 
            "Noise_Level", "Warranty", "Air_Flow", "Dehumidification", 
            "Voltage", "Color", "Features"
        ]

    def get_all_product_links(self):
        links = []
        soup = self.get_soup(self.base_url)
        if not soup: return []
        
        potential_links = soup.find_all('a', href=True)
        for a in potential_links:
            href = a['href']
            if "/produit/" in href:
                full_url = href
                if not full_url.startswith("http"):
                    full_url = "https://primini.tn" + full_url
                if full_url not in links:
                    links.append(full_url)
        return links

    def fetch_product_details(self, url):
        soup = self.get_soup(url)
        if not soup: return None
        
        product = {
            "title": "Not found",
            "price": "Not found",
            "brand": "Other",
            "description": "Not found",
            "image_url": "Not found",
            "product_url": url,
            "specs": {key: "Not found" for key in self.standard_keys}
        }

        try:
            # 1. Identity
            title_tag = soup.find('h1')
            if title_tag:
                product["title"] = title_tag.get_text(strip=True).upper()
                product["brand"] = self.detect_brand(product["title"])

            # Advanced Price Scraping for Primini
            price_match = re.search(r"(\d+[\s,.]\d+\s*DT)", soup.get_text())
            if price_match:
                product["price"] = price_match.group(1).strip()

            img_tag = soup.find("img", src=re.compile(r"/products/"))
            if img_tag:
                image_url = img_tag.get('src')
                if image_url and not image_url.startswith("http"):
                    image_url = "https://primini.tn" + image_url
                product["image_url"] = image_url

            # 2. Tech Specs Mapping
            mapping = {
                "r[ée]f[ée]rence": "Reference", "mod[èe]le": "Model",
                "btu": "Capacity", "capacit": "Capacity", "puissance": "Capacity",
                "techno": "Technology", "système": "Technology", "inverter": "Technology",
                "mode": "Mode", "froid": "Mode", "chaud": "Mode",
                "energ": "Energy_Class", "classe": "Energy_Class",
                "gaz": "Gas_Type", "refrige": "Gas_Type", "r410": "Gas_Type", "r32": "Gas_Type",
                "dimen": "Dimensions", "poids": "Weight", "kg": "Weight",
                "sonore": "Noise_Level", "bruit": "Noise_Level", "db": "Noise_Level",
                "garan": "Warranty", "ans": "Warranty",
                "volt": "Voltage", "tens": "Voltage", "coul": "Color"
            }

            spec_containers = soup.find_all("div", class_=re.compile(r"productInfoItem")) or soup.find_all("tr")
            for container in spec_containers:
                text = container.get_text(separator="|").split("|")
                if len(text) >= 2:
                    k, v = text[0].strip().lower(), text[1].strip()
                    for pattern, target_key in mapping.items():
                        if re.search(pattern, k):
                            product["specs"][target_key] = v
                            break

            # 3. Reference Fallbacks
            if product["specs"]["Reference"] == "Not found":
                # Try URL slug
                url_slug = url.split('/')[-1]
                slug_parts = url_slug.split('-')
                for part in reversed(slug_parts):
                    if any(c.isdigit() for c in part) and any(c.isalpha() for c in part) and len(part) >= 4:
                        if not any(x in part.upper() for x in ["BTU", "CLIMATISEUR", "PROMO", "TUNISIE"]):
                            product["specs"]["Reference"] = part.upper()
                            product["specs"]["Model"] = part.upper()
                            break

            if product["specs"]["Reference"] == "Not found":
                title_ref = re.search(r'\b([A-Z0-9]+-[A-Z0-9]+)\b', product["title"])
                if not title_ref:
                    title_ref = re.search(r'([A-Z]{2,5}[0-9]{2,}[A-Z0-9\-]*)', product["title"])
                if title_ref:
                    candidate = title_ref.group(1).strip("-").upper()
                    if not any(x in candidate for x in ["VENTILATEUR", "CLIMATISEUR", "ORIENT", "GREE", "TCL", "SAMSUNG", "MIDEA", "CONDOR"]):
                        product["specs"]["Reference"] = candidate
                        product["specs"]["Model"] = candidate

            if product["specs"]["Model"] == "Not found" and product["specs"]["Reference"] != "Not found":
                product["specs"]["Model"] = product["specs"]["Reference"]

            if "INVERTER" in product["title"]:
                product["specs"]["Technology"] = "Inverter"

            return product
        except Exception as e:
            print(f"Error parsing Primini product: {e}")
            return None

if __name__ == "__main__":
    PriminiScraper().run()
