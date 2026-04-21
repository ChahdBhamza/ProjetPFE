import json
import os

sites = ["jumbo", "mega", "zoom", "tunisianet", "primini"]
fields_to_check = ["Reference", "Capacity", "Technology", "Dimensions", "Noise_Level", "Gas_Type", "Warranty", "Mode"]

report = {}

for site in sites:
    filepath = f"scraper_{site}_results.json"
    if not os.path.exists(filepath):
        print(f"File missing: {filepath}")
        continue
    
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    total_products = 0
    counts = {field: 0 for field in fields_to_check}
    
    for brand, bdata in data.items():
        for product in bdata["products"]:
            total_products += 1
            specs = product.get("specs", {})
            for field in fields_to_check:
                val = str(specs.get(field, "Not found")).strip()
                if val != "Not found" and val != "":
                    counts[field] += 1
                    
    report[site] = {
        "Total": total_products,
        "Fields": counts
    }

for site, metrics in report.items():
    print(f"\n--- {site.upper()} ({metrics['Total']} products) ---")
    for field, count in metrics["Fields"].items():
        pct = (count / metrics["Total"] * 100) if metrics["Total"] > 0 else 0
        print(f"{field}: {count} ({pct:.1f}%)")

