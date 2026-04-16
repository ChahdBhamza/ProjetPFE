from base_scraper import BaseScraper
import re
import urllib.parse
import time

class MegaScraper(BaseScraper):
    def __init__(self):
        super().__init__("mega", "https://www.mega.tn/electromenager/climatisations/climatiseurs")
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
        
        brand_pages = [self.base_url]
        brand_links = soup.find_all('a', href=re.compile(r'/electromenager/climatisations/climatiseurs/'))
        for a in brand_links:
            href = a.get('href', '')
            if href and href.startswith('http') and href.count('/') == 6:
                if href not in brand_pages: brand_pages.append(href)
        
        print(f"Scanning {len(brand_pages)} brand categories...")

        for brand_url in brand_pages:
            brand_soup = self.get_soup(brand_url)
            if not brand_soup: continue
            items = brand_soup.select(".product-item-holder .title a") or brand_soup.select(".product-item .title a")
            for a in items:
                href = a.get('href', '').strip()
                if not href: continue
                if not href.startswith("http"): href = "https://www.mega.tn" + href
                href = href.replace(" ", "-")
                href = urllib.parse.quote(href, safe=':/?#[]@!$&\'()*+,;=')
                if href not in links: links.append(href)
            time.sleep(0.05)
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
            # 1. Identity & Visuals
            title_tag = soup.find('h1')
            if title_tag: 
                product["title"] = title_tag.get_text(strip=True).upper()
                product["brand"] = self.detect_brand(product["title"])

            # Advanced Price Scraping
            price_elem = soup.select_one(".price") or soup.select_one(".total-price") or \
                         soup.select_one(".new-price") or soup.select_one(".price-off") or \
                         soup.select_one("span.value") or soup.select_one(".offer-price")
            
            if price_elem:
                product["price"] = re.sub(r'\s+', ' ', price_elem.get_text(strip=True)).strip()
            else:
                # Meta description fallback (often contains price on Mega)
                meta_desc = soup.find("meta", {"name": "description"})
                if meta_desc and " DT" in meta_desc.get("content", ""):
                    price_match = re.search(r'à partir de\s*([\d\.\s]+DT)', meta_desc["content"])
                    if price_match: product["price"] = price_match.group(1).strip()

            img_tag = soup.select_one(".product-carousel img") or soup.select_one(".product-image img") or \
                      soup.select_one("#main-img") or soup.select_one(".main-image img")
            if img_tag:
                src = img_tag.get('src') or img_tag.get('data-src') or img_tag.get('srcset')
                if src: product["image_url"] = src.split(' ')[0] if src.startswith("http") else "https://www.mega.tn" + src.split(' ')[0]

            desc_div = soup.select_one(".product-description") or soup.select_one("#description") or \
                       soup.select_one(".product-short-description")
            if desc_div: product["description"] = desc_div.get_text(separator="\n", strip=True)

            # 2. Aggressive Reference Logic
            ref = "Not found"
            all_text = soup.get_text(separator=" ", strip=True)
            
            # Check for label-value pairs with word boundaries
            # Tightened: Short prefixes (Ref, Réf) now require a colon or at least a space to avoid matching 'Réfrigérateur'
            ref_match = re.search(r'\b(?:R[ée]f[ée]rence|Mod[èe]le|Mod[ée]le|Code|Item|R[ée]f\s*[:\-]|R[ée]f\s+)\s*([A-Z0-9\.\-_]{4,})', all_text, re.I)
            if ref_match: 
                ref_candidate = ref_match.group(1).upper().strip(": ")
                if ref_candidate not in ["RIGERATEUR", "FRIGERATEUR", "CLIMATISEUR"]:
                    ref = ref_candidate
            
            if ref == "Not found":
                # Fallback: Extract model code from title (e.g. OV-1812P, CL12GR, etc.)
                title_ref = re.search(r'\b([A-Z0-9]+-[A-Z0-9]+)\b', product["title"])
                if not title_ref:
                    title_ref = re.search(r'([A-Z]{2,4}[0-9/]{3,}[A-Z0-9\-]*)', product["title"])
                
                if title_ref:
                    candidate = title_ref.group(1).strip("-").upper()
                    # Exclude generic words that might match the pattern
                    if not any(x in candidate for x in ["VENTILATEUR", "CLIMATISEUR", "REFRIGERATEUR", "ORIENT", "GREE", "TCL", "SAMSUNG", "MIDEA", "CONDOR"]):
                        ref = candidate

            product["specs"]["Reference"] = ref
            product["specs"]["Model"] = ref

            # 3. Unified Technical Extraction
            mapping = {
                "btu": "Capacity", "capacit": "Capacity", "puissance": "Capacity",
                "techno": "Technology", "système": "Technology", "inverter": "Technology",
                "mode": "Mode", "froid": "Mode", "chaud": "Mode",
                "energ": "Energy_Class", "classe": "Energy_Class",
                "gaz": "Gas_Type", "refrige": "Gas_Type", "r410": "Gas_Type", "r32": "Gas_Type",
                "dimen": "Dimensions", "poids": "Weight", "kg": "Weight",
                "sonore": "Noise_Level", "bruit": "Noise_Level", "db": "Noise_Level",
                "garan": "Warranty", "ans": "Warranty",
                "flux": "Air_Flow", "m3": "Air_Flow",
                "humid": "Dehumidification",
                "volt": "Voltage", "tens": "Voltage", "coul": "Color"
            }

            def try_extract(text):
                # Split by newline or list dash explicitly
                lines = re.split(r'[\n•]', text)
                for line in lines:
                    line = line.strip()
                    if not line: continue
                    
                    # Split only on FIRST colon to avoid value bleed
                    if ":" in line:
                        k, v = line.split(":", 1)
                        k, v = k.lower().strip(), v.strip()
                        for pattern, target_key in mapping.items():
                            if pattern in k and product["specs"][target_key] == "Not found":
                                # Clean value of redundant info
                                v_clean = re.split(r'  | - ', v)[0].strip()
                                product["specs"][target_key] = v_clean
                                break
                    
                    # BTU standalone detection
                    btu_match = re.search(r'(\d{4,5})\s*BTU', line, re.I)
                    if btu_match and product["specs"]["Capacity"] == "Not found":
                        product["specs"]["Capacity"] = btu_match.group(0)

                    # Case 3: Inverter Detection
                    if "INVERTER" in line.upper() and product["specs"]["Technology"] == "Not found":
                        product["specs"]["Technology"] = "Inverter"

            # Parse Description + Fiche Technique
            source_text = (product["description"] or "") + " " + (product["title"] or "")
            tech_div = soup.select_one("#additional-info") or soup.select_one(".table-specs")
            if tech_div: source_text += "\n" + tech_div.get_text(separator="\n")
            
            try_extract(source_text)

            return product
        except Exception as e:
            print(f"Error parsing product: {e}")
            return None

if __name__ == "__main__":
    MegaScraper().run()
