import json

with open("scraper_jumbo_results.json", "r", encoding="utf-8") as f:
    data = json.load(f)

total = 0
found_dimensions = 0
found_noise = 0
found_airflow = 0
found_warranty = 0

for brand, b_data in data.items():
    for p in b_data["products"]:
        total += 1
        specs = p.get("specs", {})
        if specs.get("Dimensions", "Not found") != "Not found": found_dimensions += 1
        if specs.get("Noise_Level", "Not found") != "Not found": found_noise += 1
        if specs.get("Air_Flow", "Not found") != "Not found": found_airflow += 1
        if specs.get("Warranty", "Not found") != "Not found": found_warranty += 1

print(f"Metrics across {total} products:")
print(f"- Warranty found: {found_warranty}")
print(f"- Dimensions found: {found_dimensions}")
print(f"- Noise Levels found: {found_noise}")
print(f"- Air Flow found: {found_airflow}")
