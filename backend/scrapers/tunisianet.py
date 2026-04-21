from base_scraper import BaseScraper
import re

class TunisianetScraper(BaseScraper):
    def __init__(self):
        super().__init__("tunisianet", "https://www.tunisianet.com.tn/501-climatiseur")

    def get_all_product_links(self):
        links = []
        page = 1
        while page <= 6:
            url = f"{self.base_url}?page={page}"
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
            title_tag = soup.find('h1', itemprop='name')
            if title_tag:
                product["title"] = title_tag.get_text(strip=True).upper()
                product["brand"] = self.detect_brand(product["title"])

            price_tag = soup.select_one(".current-price span, [itemprop='price']")
            if price_tag:
                product["price"] = price_tag.get('content') or price_tag.get_text(strip=True)
                if "DT" in str(product["price"]): product["price"] = product["price"].replace("DT", "TND")
                if not "TND" in str(product["price"]): product["price"] = f"{product['price']} TND"

            img_tag = soup.select_one(".item-inner img")
            if img_tag: product["image_url"] = img_tag.get('src') or img_tag.get('data-src')

            desc_div = soup.select_one(".product-description, #description")
            if desc_div: product["description"] = desc_div.get_text(separator="\n", strip=True)

            self.extract_specs_from_html(soup, product, "dl.data-sheet, .product-features, table")
            
            ref_tag = soup.select_one(".product-reference span, [itemprop='sku']")
            if ref_tag: product["specs"]["Reference"] = ref_tag.get_text(strip=True).upper()
            product["specs"]["Model"] = product["specs"]["Reference"]

            self.extract_specs_from_text(product["description"] + " " + product["title"], product)
            return product
        except: return None

if __name__ == "__main__":
    TunisianetScraper().run()
