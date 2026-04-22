import json
with open('backend/scrapers/master_catalog.json', 'r', encoding='utf-8') as f:
    catalog = json.load(f)
print("Catalog Keys:", list(catalog.keys()))
