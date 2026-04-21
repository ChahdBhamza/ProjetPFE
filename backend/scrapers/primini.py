from base_scraper import BaseScraper
import re

class PriminiScraper(BaseScraper):
    def __init__(self):
        super().__init__("primini", "https://primini.tn/categorie/climatiseurs")

    def get_all_product_links(self):
        links = []
        page = 1
        while page <= 10:
            url = self.base_url if page == 1 else f"{self.base_url}/page/{page}/"
            soup = self.get_soup(url)
            if not soup: break
            
            items = soup.select(".product-title a")
            if not items: break
            for a in items:
                href = a.get('href')
                if href and href not in links: links.append(href)
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
            title_tag = soup.select_one(".product_title")
            if title_tag:
                product["title"] = title_tag.get_text(strip=True).upper()
                product["brand"] = self.detect_brand(product["title"])

            price_tag = soup.select_one(".price")
            if price_tag:
                product["price"] = self.clean_text(price_tag.get_text()).replace('DT', 'TND')

            img_tag = soup.select_one(".woocommerce-product-gallery__image img")
            if img_tag: product["image_url"] = img_tag.get('src') or img_tag.get('data-src')

            desc_div = soup.select_one(".woocommerce-product-details__short-description, #tab-description")
            if desc_div: product["description"] = desc_div.get_text(separator="\n", strip=True)

            self.extract_specs_from_html(soup, product, ".woocommerce-product-attributes, table")
            
            sku_tag = soup.select_one(".sku")
            if sku_tag: product["specs"]["Reference"] = sku_tag.get_text(strip=True).upper()
            product["specs"]["Model"] = product["specs"]["Reference"]

            self.extract_specs_from_text(product["description"] + " " + product["title"], product)
            return product
        except: return None

if __name__ == "__main__":
    PriminiScraper().run()
