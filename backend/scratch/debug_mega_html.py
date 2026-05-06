import requests
from bs4 import BeautifulSoup

url = "https://www.mega.tn/electromenager/froid/refrigerateur/samsung"
headers = {"User-Agent": "Mozilla/5.0"}

r = requests.get(url, headers=headers)
soup = BeautifulSoup(r.content, "html.parser")

print("--- ALL LINKS (First 50) ---")
links = soup.find_all("a")
for i, link in enumerate(links[:50]):
    print(f"{i}: text='{link.get_text(strip=True)[:50]}' href='{link.get('href')}'")

print("\n--- ALL H3/H2 TAGS ---")
for h in soup.find_all(["h1", "h2", "h3", "h4"]):
    print(f"{h.name}: {h.get_text(strip=True)[:100]}")
