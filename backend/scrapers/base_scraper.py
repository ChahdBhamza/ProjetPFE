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
            "Comfee", "Orient", "General Gold", "Servicom", "Airwell", "Manta", "Sabra", "Galanz", "Indesit"
        ]
        self.standard_keys = [
            "Reference", "Model", "Capacity", "Technology", "Mode", 
            "Energy_Class", "Gas_Type", "Dimensions", "Weight", 
            "Noise_Level", "Warranty", "Air_Flow", "Dehumidification", 
            "Voltage", "Color", "Features", "Type", "Control", "Display",
            "Max_Temp_Cold", "Max_Temp_Hot"
        ]
        self.spec_mapping = {
            "r[ée]f[ée]rence": "Reference", "mod[èe]le": "Model", "BTU": "Capacity", "capacit": "Capacity", "puissance": "Capacity",
            "techno": "Technology", "système": "Technology", "inverter": "Technology", "mode": "Mode", "froid": "Mode", "chaud": "Mode",
            "energ": "Energy_Class", "classe": "Energy_Class", "climatique": "Energy_Class", "gaz": "Gas_Type", "refrige": "Gas_Type", "r410": "Gas_Type", "r32": "Gas_Type",
            "dimen": "Dimensions", "poids": "Weight", "kg": "Weight", "sonore": "Noise_Level", "bruit": "Noise_Level", "db": "Noise_Level",
            "garan": "Warranty", "ans": "Warranty", "volt": "Voltage", "tens": "Voltage", "coul": "Color",
            "type": "Type", "split": "Type", "contrô": "Control", "comma": "Control", "affich": "Display", "écran": "Display",
            "opera": "Max_Temp_Cold", "ambian": "Max_Temp_Hot"
        }

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

    def clean_text(self, text):
        if not text: return ""
        # Remove hidden Unicode characters that break regex
        text = re.sub(r'[^\x00-\x7f\x80-\xff\u0100-\u017f]', ' ', text)
        return re.sub(r'\s+', ' ', text).strip()

    def extract_specs_from_html(self, soup, product, containers_selector):
        """Standard extraction from tables/definition lists"""
        containers = soup.select(containers_selector)
        for container in containers:
            for row in container.find_all(['tr', 'dt', 'li']):
                k, v = "", ""
                if row.name == 'tr':
                    tds = row.find_all(['td', 'th'])
                    if len(tds) >= 2:
                        k, v = tds[0].get_text(strip=True).lower(), tds[1].get_text(strip=True)
                elif row.name == 'dt':
                    k = row.get_text(strip=True).lower()
                    v = row.find_next_sibling('dd').get_text(strip=True) if row.find_next_sibling('dd') else ""
                elif row.name == 'li' and ':' in row.get_text():
                    parts = row.get_text(strip=True).split(':', 1)
                    k, v = parts[0].lower(), parts[1]

                if not k or not v: continue

                for pattern, target in self.spec_mapping.items():
                    if re.search(pattern, k):
                        if product["specs"][target] == "Not found":
                            product["specs"][target] = v
                        elif v not in product["specs"][target]:
                            if target in ["Dimensions", "Noise_Level"]:
                                product["specs"][target] += " | " + v
                        break

    def extract_specs_from_text(self, text, product):
        """Regex-based fallback for unstructured descriptions"""
        if not text: return
        t = self.clean_text(text).lower()
        
        desc_patterns = {
            "Gas_Type": [r"(r410a|r32|r22|gaz\s*r\d+)"],
            "Mode": [r"mode\s*(?::|->)?\s*(chaud\s*(?:&|/|et)\s*froid|froid|chaud)", r"(chaud\s*(?:&|/|et)\s*froid)"],
            "Voltage": [r"([0-9]{3}\s*(?:v|volt|hz)[a-z0-9\-/ \~]*?)"],
            "Dimensions": [r"([0-9.]+\s*[x×]\s*[0-9.]+\s*[x×]\s*[0-9.]+\s*mm)"],
            "Weight": [r"poids\s*(?:net)?\s*(?:unité)?\s*(?:extérieure|intérieure)?\s*(?::|->)?\s*([0-9,.]+\s*kg)"],
            "Noise_Level": [r"([0-9]+\s*db[a]?)"],
            "Warranty": [r"garantie\s*(?::|->)?\s*([0-9]+\s*ans?)"],
            "Color": [r"couleur\s*(?::|->)?\s*([^/,\-\.\n]{3,20})", r"\b(blanc|noir|silver|gris)\b"],
            "Energy_Class": [r"classe\s*énergétique\s*(?::|->)?\s*([a-z0-9+]+)"],
            "Air_Flow": [r"débit\s*d.air\s*(?:intérieur)?\s*(?::|->)?\s*([0-9,.]+\s*m.?.h)"],
            "Dehumidification": [r"élimination\s*de\s*l.humidité\s*(?::|->)?\s*([0-9.]+\s*litres?/h)"],
            "Max_Temp_Hot": [r"température\s*ambiante\s*(?::|->)?\s*([^.\n]+)"]
        }

        for key, patterns in desc_patterns.items():
            if product["specs"][key] == "Not found" or not product["specs"][key]:
                for pattern in patterns:
                    if key in ["Dimensions", "Noise_Level"]:
                        matches = re.findall(pattern, t)
                        if matches:
                            clean_matches = []
                            for m in matches:
                                m_val = m[0] if isinstance(m, tuple) and m[0] else (m if isinstance(m, str) else "")
                                if m_val: clean_matches.append(m_val.strip().capitalize())
                            if clean_matches:
                                product["specs"][key] = " | ".join(clean_matches)
                                break
                    else:
                        match = re.search(pattern, t)
                        if match:
                            val = match.group(1) if match.groups() else match.group(0)
                            product["specs"][key] = val.strip().upper() if key in ["Gas_Type", "Energy_Class"] else val.strip().capitalize()
                            break
        # Enforce Non Inverter classification and normalize
        tech = str(product["specs"].get("Technology", "Not found")).strip().lower()
        if tech in ["not found", "non"]:
            if "inverter" in product["title"].lower() or "inverter" in t:
                product["specs"]["Technology"] = "Inverter"
            else:
                product["specs"]["Technology"] = "Non Inverter"
        elif tech == "oui":
            product["specs"]["Technology"] = "Inverter"
        elif "inverter" in tech:
            product["specs"]["Technology"] = "Inverter"
        else:
            product["specs"]["Technology"] = "Non Inverter"

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
