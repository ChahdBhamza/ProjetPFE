import requests
from bs4 import BeautifulSoup
import re

url = 'https://zoom.com.tn/climatiseur/17725-climatiseur-saba-12000-btu-chaudfroid-blanc.html'
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
r = requests.get(url, headers=headers, timeout=15)
soup = BeautifulSoup(r.text, 'html.parser')

print("=== Searching for spec text (Puissance, R410, CSH) ===")
for tag in soup.find_all(string=re.compile(r'Puissance|R410|refrigerant|Niveau Sonore|CSH-|BTU Froid', re.I)):
    parent = tag.parent
    grandparent = parent.parent if parent else None
    print(f"TAG: {parent.name} | CLASS: {parent.get('class')} | ID: {parent.get('id')}")
    if grandparent:
        print(f"  PARENT: {grandparent.name} | CLASS: {grandparent.get('class')} | ID: {grandparent.get('id')}")
    print(f"  TEXT: {str(tag)[:300]}")
    print("---")

print("\n=== All DL elements ===")
for dl in soup.find_all('dl'):
    print(f"DL CLASS: {dl.get('class')}, ID: {dl.get('id')}")
    print(dl.get_text()[:200])
    print("---")

print("\n=== #main-tabs content ===")
tabs = soup.select_one('#main-tabs, .tabs, .product-tabs')
if tabs:
    print(tabs.prettify()[:3000])

print("\n=== .rte or .rte-content divs ===")
for div in soup.select('.rte, .rte-content, .product_description'):
    print(f"DIV CLASS: {div.get('class')}")
    print(div.get_text()[:500])
    print("---")

print("\n=== Paragraphs containing 'Type:' ===")
for p in soup.find_all('p'):
    text = p.get_text()
    if 'Type:' in text or 'Puissance' in text or 'R410' in text:
        print(f"P PARENT: {p.parent.name} CLASS: {p.parent.get('class')}")
        print(text[:500])
        print("---")
