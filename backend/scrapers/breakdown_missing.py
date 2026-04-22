import json

with open("master_catalog.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print("=== PRODUCTS MISSING CAPACITY BREAKDOWN ===")

for brand, items in data.items():
    for p in items:
        if not p.get("capacity_btu"):
            title = p.get("clean_title", "").upper()
            ref = p.get("normalized_reference", "")
            
            # Simple Categorization
            category = "Likely AC (Missing Info)"
            if any(x in title for x in ["VENTILATEUR", "FAN", "VP140", "V45IND", "V45IN", "V40M"]):
                category = "VENTILATEUR (FAN)"
            elif any(x in title or x in ref for x in ["CLIMEUR", "COOLER", "RAD-SB", "RA100", "TRF-9022"]):
                category = "CLIMEUR (AIR COOLER)"
            
            print(f"  [{brand}] {category.ljust(20)} | {p['clean_title']} (Ref: {ref})")
