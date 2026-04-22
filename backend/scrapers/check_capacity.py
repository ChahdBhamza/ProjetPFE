import json

with open("master_catalog.json", "r", encoding="utf-8") as f:
    data = json.load(f)

missing = []
total = 0

for brand, items in data.items():
    for p in items:
        total += 1
        cap = p.get("capacity_btu")
        if not cap or cap == "Not found":
            missing.append(f"[{brand}] {p['clean_title']} (Ref: {p.get('normalized_reference')})")

print(f"Total Products: {total}")
print(f"Products with Missing Capacity: {len(missing)} ({(len(missing)/total)*100:.1f}%)")
print("\n--- SAMPLE OF PRODUCTS WITHOUT CAPACITY ---")
for m in missing[:20]:
    print(f"  - {m}")
