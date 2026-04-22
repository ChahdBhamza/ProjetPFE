import json

with open("master_catalog.json", "r", encoding="utf-8") as f:
    data = json.load(f)

total = 0
linked = 0
null_count = 0

for brand, items in data.items():
    for p in items:
        total += 1
        path = p.get("local_image_path")
        if path:
            linked += 1
            print(f"  LINKED: [{brand}] {p['clean_title']}")
            print(f"          -> {path}")
        else:
            null_count += 1

print()
print(f"Total products:     {total}")
print(f"Linked to dataset:  {linked}")
print(f"No local image:     {null_count}")
