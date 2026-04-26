from base_scraper import BaseScraper
import re
import json

class ZoomScraper(BaseScraper):
    def __init__(self):
        super().__init__("zoom", "https://zoom.com.tn/1110-climatiseur")

    def get_all_product_links(self):
        links = []
        page = 1
        while page <= 8:
            url = f"{self.base_url}?page={page}"
            soup = self.get_soup(url)
            if not soup: break
            
            found = 0
            items = soup.select(".product-title a")
            for a in items:
                href = a.get('href')
                if href:
                    if href not in links:
                        links.append(href)
                        found += 1
            if found == 0: break
            page += 1
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

            # 2. Price
            price_tag = soup.select_one(".current-price, .product-price, .price")
            if price_tag:
                product["price"] = self.clean_text(price_tag.get_text()).replace('DT', 'TND')

            # 3. Image
            img_tag = soup.select_one(".js-qv-product-cover, .product-cover img")
            if img_tag:
                img_url = img_tag.get('src') or img_tag.get('data-src')
                if img_url: product["image_url"] = img_url

            # 4. Description
            desc_div = soup.select_one(".product-description, #description")
            if desc_div: product["description"] = desc_div.get_text(separator="\n", strip=True)

            # 5. Extraction
            self.extract_specs_from_html(soup, product, "dl.data-sheet, .product-features, table")
            
            # 6. Reference (Zoom specific)
            ref_tag = soup.select_one(".product-reference span, [itemprop='sku']")
            if ref_tag:
                product["specs"]["Reference"] = ref_tag.get_text(strip=True).upper()
            
            product["specs"]["Model"] = product["specs"]["Reference"]

            # 7. Text Enrichment
            self.extract_specs_from_text(product["description"] + " " + product["title"], product)

            return product
        except Exception as e:
            print(f"Error parsing {url}: {e}")
            return None

if __name__ == "__main__":
    ZoomScraper().run()
