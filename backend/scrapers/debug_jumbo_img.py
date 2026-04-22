import requests
from bs4 import BeautifulSoup
import json

headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

url = "https://jumbo.tn/climatiseur/7454-climatiseur-brandt-inverter-tropicalise-12000-btu-chaud-froid-blanc.html"
r = requests.get(url, headers=headers, timeout=15)
soup = BeautifulSoup(r.text, "html.parser")

h1 = soup.find("h1")
print(f"Page title: {h1.get_text(strip=True) if h1 else 'Not found'}")
print()

# Check JSON-LD for image
print("--- Checking JSON-LD for image ---")
for script in soup.find_all("script", type="application/ld+json"):
    try:
        data = json.loads(script.string)
        images = data.get("image", [])
        if images:
            if isinstance(images, str): images = [images]
            for img in images:
                print(f"  JSON-LD image: {img}")
    except:
        pass

print()
print("--- Prestashop-style product images (large/medium) ---")
for img in soup.find_all("img"):
    src = img.get("src") or img.get("data-src") or ""
    if "large_default" in src or "medium_default" in src:
        parent = img.parent
        print(f"  src:   {src[:100]}")
        print(f"  class: {img.get('class')}, id: {img.get('id')}")
        print(f"  parent: <{parent.name} class='{parent.get('class')}' id='{parent.get('id')}'>")
        print()
