import json

with open("master_catalog.json", "r", encoding="utf-8") as f:
    data = json.load(f)

web_prods = []
local_prods = []

for brand, items in data.items():
    for p in items:
        stores = [av["store"] for av in p.get("availability", [])]
        if "local_dataset" in stores:
            local_prods.append(p)
        else:
            web_prods.append(p)

print("=== POTENTIAL DUPLICATES (Same Brand + Same BTU) ===")
duplicates_found = 0
for lp in local_prods:
    brand = lp["brand"]
    btu = lp.get("capacity_btu")
    if not btu: continue
    
    for wp in web_prods:
        if wp["brand"] == brand and wp.get("capacity_btu") == btu:
            print(f"  Match Found: {brand} {btu} BTU")
            print(f"    Web  : {wp['clean_title']} (Ref: {wp['normalized_reference']})")
            print(f"    Local: {lp['clean_title']} (Ref: {lp['normalized_reference']})")
            print("-" * 50)
            duplicates_found += 1
            break

print(f"\nTotal potential duplicates found: {duplicates_found}")
