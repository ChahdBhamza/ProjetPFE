import json

with open("master_catalog.json", "r", encoding="utf-8") as f:
    data = json.load(f)

non_ac_keywords = ["ventilateur", "climeur", "rafraichisseur", "fan", "cooler", "humidificateur", "mist", "brumisateur"]

print("=== NON-AC PRODUCTS (FANS / AIR COOLERS) ===")

brand_summary = {}
non_ac_list = []

for brand, items in data.items():
    for p in items:
        title = p.get("clean_title", "").lower()
        
        # Identify non-AC products by keywords
        is_non_ac = any(key in title for key in non_ac_keywords)
        
        if is_non_ac:
            non_ac_list.append(f"[{brand}] {p['clean_title']}")
            brand_summary[brand] = brand_summary.get(brand, 0) + 1

for item in sorted(non_ac_list):
    print(f"  {item}")

print("\n=== BRAND SUMMARY (NON-AC UNITS) ===")
for brand, count in sorted(brand_summary.items(), key=lambda x: x[1], reverse=True):
    print(f"{brand}: {count} units")
