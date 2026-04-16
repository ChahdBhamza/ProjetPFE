from base_scraper import BaseScraper
import re

class TunisianetScraper(BaseScraper):
    def __init__(self):
        super().__init__("tunisianet", "https://www.tunisianet.com.tn/457-climatiseur-tunisie-chaud-froid")
        self.standard_keys = [
            "Reference", "Model", "Capacity", "Technology", "Mode", 
            "Energy_Class", "Gas_Type", "Dimensions", "Weight", 
            "Noise_Level", "Warranty", "Air_Flow", "Dehumidification", 
            "Voltage", "Color", "Features"
        ]

    def get_all_product_links(self):
        links = []
        page = 1
        while page <= 10:
            url = f"{self.base_url}?page={page}"
            soup = self.get_soup(url)
            if not soup: break
            
            product_miniatures = soup.select(".product-miniature")
            if not product_miniatures: break
            
            found_on_page = 0
            for item in product_miniatures:
                link_tag = item.select_one("h2.product-title a")
                if link_tag and link_tag.has_attr('href'):
                    if link_tag['href'] not in links:
                        links.append(link_tag['href'])
                        found_on_page += 1
            
            if found_on_page == 0: break
            page += 1
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

            price_tag = soup.select_one(".current-price span")
            if price_tag:
                product["price"] = price_tag.get_text(strip=True)

            img_tag = soup.select_one("img.js-qv-product-cover")
            if img_tag:
                product["image_url"] = img_tag.get('src') or img_tag.get('data-src')

            desc_div = soup.select_one(".product-description")
            if desc_div:
                product["description"] = desc_div.get_text(separator="\n", strip=True)

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

            data_sheet = soup.select_one("dl.data-sheet")
            if data_sheet:
                dts = data_sheet.find_all("dt")
                dds = data_sheet.find_all("dd")
                for dt, dd in zip(dts, dds):
                    k, v = dt.get_text(strip=True).lower(), dd.get_text(strip=True)
                    for pattern, target_key in mapping.items():
                        if re.search(pattern, k):
                            product["specs"][target_key] = v
                            break

            # 3. Fallback / Refinement
            # If Reference is missing, try title parts (often after the last /)
            if product["specs"]["Reference"] == "Not found":
                parts = [p.strip() for p in product["title"].split('/')]
                # Look at the last 2 parts specifically as they usually contain the model
                for part in reversed(parts[-2:]):
                    # Likely a model if it has both letters and numbers and is short
                    if any(c.isdigit() for c in part) and any(c.isalpha() for c in part) and len(part) < 20:
                        if not any(x in part for x in ["BTU", "CHAUD", "FROID", "ANS", "GARANTIE", "MOIS"]):
                            product["specs"]["Reference"] = part
                            product["specs"]["Model"] = part
                            break
            
            # Additional regex fallback if still not found
            if product["specs"]["Reference"] == "Not found":
                # Try to extract from URL slug (e.g., ...-sabw12c-iw.html)
                url_slug = url.split('/')[-1].replace('.html', '')
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
                    # Flexible pattern: 2-5 letters followed by 2+ digits
                    title_ref = re.search(r'([A-Z]{2,5}[0-9]{2,}[A-Z0-9\-]*)', product["title"])
                
                if title_ref:
                    candidate = title_ref.group(1).strip("-").upper()
                    if not any(x in candidate for x in ["VENTILATEUR", "CLIMATISEUR", "REFRIGERATEUR", "ORIENT", "GREE", "TCL", "SAMSUNG", "MIDEA", "CONDOR"]):
                        product["specs"]["Reference"] = candidate
                        product["specs"]["Model"] = candidate

            # Ensure Model follows Reference if Model is still missing
            if product["specs"]["Model"] == "Not found" and product["specs"]["Reference"] != "Not found":
                product["specs"]["Model"] = product["specs"]["Reference"]

            # Inverter text detection
            if "INVERTER" in product["title"] or "INVERTER" in product["description"].upper():
                product["specs"]["Technology"] = "Inverter"

            return product
        except Exception as e:
            print(f"Error parsing Tunisianet product: {e}")
            return None

if __name__ == "__main__":
    TunisianetScraper().run()
