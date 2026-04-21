from base_scraper import BaseScraper
import bs4
import requests

def inspect():
    url = "https://jumbo.tn/climatiseur/1578-climatiseur-hyundai-24000-btu-onoff-chaud-froid-hy2-24t1.html"
    headers = {'User-Agent': 'Mozilla/5.0'}
    resp = requests.get(url, headers=headers)
    soup = bs4.BeautifulSoup(resp.text, 'html.parser')
    
    print("--- Searching for technical table rows ---")
    tables = soup.select('table, dl.data-sheet, .product-features')
    for table in tables:
        print(f"Table found: {table.get('class')}")
        for row in table.find_all('tr'):
            tds = row.find_all(['td', 'th'])
            if len(tds) >= 2:
                k = tds[0].get_text(strip=True)
                v = tds[1].get_text(strip=True)
                print(f"  Row: '{k}' -> '{v}'")

if __name__ == "__main__":
    inspect()
