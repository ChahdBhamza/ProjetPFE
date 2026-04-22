from base_scraper import BaseScraper
import json
import re

class JumboScraper(BaseScraper):
    def __init__(self):
        super().__init__("jumbo", "https://jumbo.tn/498-climatiseur")

    def get_all_product_links(self):
        links = []
        page = 1
        while page <= 10:
            url = f"{self.base_url}?page={page}"
            soup = self.get_soup(url)
            if not soup: break
            
            found_on_page = 0
            for a in soup.find_all('a', href=True):
                href = a['href']
                if ".html" in href and any(c.isdigit() for c in href.split('/')[-1]):
                    if any(x in href for x in ["/content/", "/nous-contacter", "mon-compte", "panier", "connexion"]): continue
                    full_url = href
                    if not full_url.startswith("http"): full_url = "https://jumbo.tn" + full_url
                    if full_url not in links:
                        links.append(full_url)
                        found_on_page += 1
            if found_on_page == 0: break
            print(f"    Found {found_on_page} links on page {page}.")
            page += 1
        return list(set(links))

    def fetch_product_details(self, url):
        soup = self.get_soup(url)
        if not soup: return None
        
        product = {
            "title": "Not found", "price": "Not found", "brand": "Other", 
            "description": "Not found", "image_url": "Not found", "product_url": url,
            "specs": {key: "Not found" for key in self.standard_keys}
        }

        try:
            # 1. Identity
            title_tag = soup.find('h1')
            if title_tag:
                product["title"] = title_tag.get_text(strip=True).upper()
                product["brand"] = self.detect_brand(product["title"])

            # 2. Price & Image Discovery (JSON-LD + Meta + Scripts)
            scripts = soup.find_all('script', type='application/ld+json')
            for script in scripts:
                try:
                    data = json.loads(script.string)
                    items = data.get('@graph', [data]) if isinstance(data, dict) else []
                    for item in items:
                        offers = item.get('offers')
                        if offers:
                            if isinstance(offers, list): offers = offers[0]
                            p = offers.get('price')
                            if p: product["price"] = f"{p} TND"
                        sku = item.get('sku') or item.get('mpn')
                        if sku: product["specs"]["Reference"] = str(sku).upper()
                        # Extract image from JSON-LD
                        img_ld = item.get('image')
                        if img_ld and product["image_url"] == "Not found":
                            if isinstance(img_ld, list): img_ld = img_ld[0]
                            if isinstance(img_ld, str) and img_ld.startswith("http"):
                                product["image_url"] = img_ld
                        if product["price"] != "Not found": break
                except: continue

            if product["price"] == "Not found":
                price_meta = soup.find('meta', itemprop='price') or soup.find('meta', property='product:price:amount')
                if price_meta:
                    val = price_meta.get('content', '0').replace(',', '.')
                    if float(val) > 0: product["price"] = f"{val} TND"

            # 3. Image (fallback if JSON-LD didn't provide it)
            if product["image_url"] == "Not found":
                img_tag = soup.select_one('.elementor-carousel-image, .product-cover img, [itemprop="image"]')
                if img_tag:
                    img_url = img_tag.get('src') or img_tag.get('data-src') or img_tag.get('srcset', '').split(' ')[0]
                    if img_url:
                        if not img_url.startswith("http"): img_url = "https://jumbo.tn" + img_url
                        product["image_url"] = img_url

            # 4. Description
            # Scope to main product block to avoid extracting text from 'related products' miniatures
            desc_div = soup.select_one('.ce-product-description, .ce-product-description-short, #description, [itemprop="description"]')
            if desc_div: product["description"] = desc_div.get_text(separator="\n", strip=True)
            # 5. Automated Specifications Extraction
            self.extract_specs_from_html(soup, product, 'dl.data-sheet, .product-features, table, #description table')
            
            # 6. Reference Refinement
            best_ref = product["specs"]["Reference"]
            blacklist = ["BTU", "GARANTIE", "LIVRAISON", "TND", "CHAUD", "FROID", "INVERTER", "CLIMATISEUR", "SYSTEME", "MULTISPLIT", "MULTI-SPLIT"]
            
            def is_valid_ref(code):
                if not code or len(code) < 4: return False
                u_code = code.upper()
                if any(x in u_code for x in blacklist): return False
                if re.match(r'^\d+$', code): return False 
                if re.search(r'\d+BTU', code, re.I): return False
                return True

            if not is_valid_ref(best_ref):
                best_ref = "Not found"
                m_title = re.findall(r'\(([^)]+)\)|/\s*([A-Z0-9\-/ ]{5,})', product["title"])
                for match in m_title:
                    code = next(m for m in match if m).strip()
                    if is_valid_ref(code):
                        best_ref = code.upper()
                        break
            
            if best_ref == "Not found":
                parts = url.split('/')[-1].replace('.html', '').split('-')
                for part in reversed(parts):
                    if is_valid_ref(part):
                        best_ref = part.upper()
                        break

            product["specs"]["Reference"] = best_ref
            product["specs"]["Model"] = best_ref if best_ref != "Not found" else product["specs"]["Model"]

            # 7. Final Text-based enrichment
            if "INVERTER" in product["title"]: product["specs"]["Technology"] = "Inverter"
            if product["specs"]["Capacity"] == "Not found":
                m_btu = re.search(r'(\d+)\s*BTU', product["title"])
                if m_btu: product["specs"]["Capacity"] = m_btu.group(1) + " BTU"

            # Maximize extraction by grabbing all text within the main product body
            product_body = soup.select_one('#main, .product-information')
            full_text = product_body.get_text(separator=" ", strip=True) if product_body else product["description"]
            self.extract_specs_from_text(full_text + " " + product["title"], product)

            return product
        except Exception as e:
            print(f"Error parsing {url}: {e}")
            return None

if __name__ == "__main__":
    JumboScraper().run()
