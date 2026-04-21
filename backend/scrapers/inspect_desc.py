import requests
from bs4 import BeautifulSoup

url = "https://jumbo.tn/climatiseur/7010-climatiseur-tcl-12000-btu-onoff-chaud-froid-inverter.html"
response = requests.get(url)
soup = BeautifulSoup(response.text, 'html.parser')

print("--- Classes with description ---")
for el in soup.find_all(lambda tag: 'description' in str(tag.get('class', [])) or 'description' in str(tag.get('id', '')) or 'description' in str(tag.get('itemprop', ''))):
    print(f"Tag: {el.name}, id: {el.get('id')}, class: {el.get('class')}")
