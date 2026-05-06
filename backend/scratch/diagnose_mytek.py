import json

with open("scrapers/tunisianet_refrigerateurs_catalog.json", encoding="utf-8") as f:
    tun = json.load(f)
with open("scrapers/mytek_refrigerateurs_catalog.json", encoding="utf-8") as f:
    myt = json.load(f)

# Build MyTek lookup by SKU
myt_by_sku = {p["sku"].upper(): p for p in myt if p.get("sku")}

# Find duplicates
dups = [p for p in tun if p.get("duplicate_of_mytek_sku")]

print(f"Comparing {len(dups)} duplicates...\n")

for p in dups[:4]:  # sample 4
    sku = p["duplicate_of_mytek_sku"]
    m = myt_by_sku.get(sku)
    if not m:
        continue

    print(f"{'='*60}")
    print(f"SKU: {sku}")
    print(f"\n  [MYTEK]")
    print(f"    Name       : {m.get('name')}")
    print(f"    Price      : {m.get('current_price')} DT")
    print(f"    Short desc : {(m.get('short_description') or '')[:120]}")
    print(f"    Specs keys : {list(m.get('specifications', {}).keys())}")
    print(f"    Images     : {len(m.get('images', []))}")
    print(f"    Full desc  : {'YES' if m.get('full_description') else 'NO'}")

    print(f"\n  [TUNISIANET]")
    print(f"    Name       : {p.get('name')}")
    print(f"    Price      : {p.get('current_price')} DT")
    print(f"    Short desc : {(p.get('short_description') or '')[:120]}")
    print(f"    Specs keys : {list(p.get('specifications', {}).keys())}")
    print(f"    Images     : {len(p.get('images', []))}")
    print(f"    Full desc  : {'YES' if p.get('full_description') else 'NO'}")
    print()
