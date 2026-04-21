from base_scraper import BaseScraper
import re
import urllib.parse
import json

class MegaScraper(BaseScraper):
    def __init__(self):
        super().__init__("mega", "https://www.mega.tn/electromenager/climatisations/climatiseurs")

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
        return links

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

            # 2. Price Discovery
            price_elem = soup.select_one(".price, .total-price, .new-price, .price-off, .offer-price, span.value")
            if price_elem:
                product["price"] = self.clean_text(price_elem.get_text()).replace('DT', 'TND')
            else:
                meta_desc = soup.find("meta", {"name": "description"})
                if meta_desc and " DT" in meta_desc.get("content", ""):
                    price_match = re.search(r'à partir de\s*([\d\.\s]+DT)', meta_desc["content"])
                    if price_match: product["price"] = price_match.group(1).replace('DT', 'TND').strip()

            # 3. Image
            img_tag = soup.select_one(".product-carousel img, .product-image img, #main-img, .main-image img")
            if img_tag:
                src = img_tag.get('src') or img_tag.get('data-src') or img_tag.get('srcset')
                if src: 
                    src = src.split(' ')[0]
                    product["image_url"] = src if src.startswith("http") else "https://www.mega.tn" + src

            # 4. Description
            desc_div = soup.select_one(".product-description, #description, .product-short-description")
            if desc_div: product["description"] = desc_div.get_text(separator="\n", strip=True)

            # 5. Specifications Extraction
            self.extract_specs_from_html(soup, product, "#additional-info, .table-specs, table, .fiche-technique")
            
            # 6. Reference Strategy
            all_text = soup.get_text(separator=" ", strip=True)
            ref_match = re.search(r'\b(?:R[ée]f[ée]rence|Mod[èe]le|Code|Item|R[ée]f\s*[:\-]|R[ée]f\s+)\s*([A-Z0-9\.\-_]{4,})', all_text, re.I)
            if ref_match: 
                ref = ref_match.group(1).upper().strip(": ")
                if ref not in ["RIGERATEUR", "FRIGERATEUR", "CLIMATISEUR"]:
                    product["specs"]["Reference"] = ref

            if product["specs"]["Reference"] == "Not found":
                title_ref = re.search(r'\b([A-Z0-9]+-[A-Z0-9]+)\b', product["title"]) or re.search(r'([A-Z]{2,4}[0-9/]{3,}[A-Z0-9\-]*)', product["title"])
                if title_ref:
                    candidate = title_ref.group(1).upper()
                    if not any(x in candidate for x in ["VENTILATEUR", "CLIMATISEUR", "REFRIGERATEUR", "ORIENT", "GREE", "TCL", "SAMSUNG", "MIDEA", "CONDOR"]):
                        product["specs"]["Reference"] = candidate
            
            product["specs"]["Model"] = product["specs"]["Reference"]

            # 7. Text Fallback
            self.extract_specs_from_text(product["description"] + " " + product["title"], product)

            return product
        except Exception as e:
            print(f"Error parsing {url}: {e}")
            return None

if __name__ == "__main__":
    MegaScraper().run()
