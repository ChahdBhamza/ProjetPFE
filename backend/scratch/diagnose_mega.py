import sys, io, requests
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from bs4 import BeautifulSoup

headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"}

url = "https://www.mega.tn/electromenager/froid/refrigerateur"
r = requests.get(url, headers=headers, timeout=20)
soup = BeautifulSoup(r.text, "html.parser")

items = soup.select(".product-item")
print(f"Total .product-item: {len(items)}")

# Let's see if there is any text like "Affichage 1-34 sur 500"
all_text = soup.get_text()
import re
match = re.search(r'(\d+)\s*sur\s*(\d+)', all_text)
if match:
    print(f"Found display range: {match.group(0)}")
else:
    print("No 'X sur Y' pattern found.")

# Try looking for a load more script
if "loadMore" in r.text or "append" in r.text:
    print("Found potential AJAX load more code.")
