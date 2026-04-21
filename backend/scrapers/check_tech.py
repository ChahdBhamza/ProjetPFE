import json

with open("scraper_jumbo_results.json", "r", encoding="utf-8") as f:
    data = json.load(f)

techs = set()
for brand, b in data.items():
    for p in b["products"]:
        techs.add(p["specs"].get("Technology"))

print(f"Unique Technology values: {techs}")
