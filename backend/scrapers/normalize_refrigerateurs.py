import json
import os
import re
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent
OUTPUT_FILE = BASE_DIR / "master_refrigerateurs_catalog.json"

FILES_TO_PROCESS = [
    {"path": BASE_DIR / "mytek_refrigerateurs_catalog.json", "store": "mytek", "type": "refrigerateur"},
    {"path": BASE_DIR / "mytek_mini_refrigerateurs_catalog.json", "store": "mytek", "type": "mini-bar"},
    {"path": BASE_DIR / "tunisianet_refrigerateurs_catalog.json", "store": "tunisianet", "type": "mixed"},
    {"path": BASE_DIR / "mega_refrigerateurs_catalog.json", "store": "mega.tn", "type": "refrigerateur"}
]

BRAND_CASING = {
    "samsung": "SAMSUNG", "lg": "LG", "beko": "BEKO", "whirlpool": "WHIRLPOOL",
    "mont-blanc": "MONTBLANC", "mont blanc": "MONTBLANC", "montblanc": "MONTBLANC",
    "brandt": "BRANDT", "telefunken": "TELEFUNKEN", "condor": "CONDOR",
    "newstar": "NEWSTAR", "acer": "ACER", "hoover": "HOOVER", "candy": "CANDY",
    "biolux": "BIOLUX", "bosch": "BOSCH", "saba": "SABA"
}

def clean_brand(brand):
    if not brand: return "UNKNOWN"
    b = str(brand).strip().lower()
    return BRAND_CASING.get(b, b.upper())

def extract_reference(title, sku=None):
    # If we have a clean SKU from MyTek/Tunisianet, use it
    if sku and str(sku).strip() and str(sku).lower() not in ["null", "none"]:
        return re.sub(r'[^A-Z0-9]', '', str(sku).upper())
    
    # For Mega.tn and others without clean SKU, extract from title
    # Sometimes it's in brackets [RB34T673EBN]
    match = re.search(r'\[([A-Za-z0-9-]+)\]', title)
    if match:
        return re.sub(r'[^A-Z0-9]', '', match.group(1).upper())
    
    # Otherwise, look for the first word with both letters and numbers
    words = str(title).replace('-', ' ').replace('_', ' ').split()
    for w in words:
        w_clean = re.sub(r'[^A-Z0-9]', '', w.upper())
        if len(w_clean) >= 4 and any(c.isdigit() for c in w_clean) and any(c.isalpha() for c in w_clean):
            return w_clean
            
    return "UNKNOWN"

def extract_capacity(text):
    if not text: return None
    # Look for patterns like 340L, 340 L, 340Litres, 340 Litres
    match = re.search(r'(\d{2,4})\s*(?:L|Litres|litres)\b', str(text), re.I)
    if match:
        return int(match.group(1))
    return None

def extract_cooling_system(text):
    if not text: return "Inconnu"
    text_lower = str(text).lower()
    if "no frost" in text_lower or "nofrost" in text_lower:
        return "No Frost"
    if "de frost" in text_lower or "defrost" in text_lower:
        return "DeFrost"
    if "statique" in text_lower:
        return "Statique"
    if "brassé" in text_lower or "brasse" in text_lower:
        return "Froid Brassé"
    return "Inconnu"

def extract_doors(text):
    if not text: return "Inconnu"
    text_lower = str(text).lower()
    if "1 porte" in text_lower or "une porte" in text_lower or "mini" in text_lower:
        return "1 Porte"
    if "2 portes" in text_lower or "double porte" in text_lower or "combiné" in text_lower:
        return "2 Portes"
    if "multi" in text_lower or "4 portes" in text_lower or "side by side" in text_lower:
        return "Multi-Portes"
    return "Inconnu"

def main():
    print("Starting Refrigerator Normalization & Fusion Pipeline...")
    master_catalog = {}

    for file_info in FILES_TO_PROCESS:
        file_path = file_info["path"]
        store = file_info["store"]
        
        if not file_path.exists():
            print(f"Skipping {store}, file not found: {file_path}")
            continue
            
        print(f"Processing {store} data...")
        with open(file_path, "r", encoding="utf-8") as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                print(f"Error parsing JSON from {file_path}")
                continue
                
        # Handle dict format (Tunisianet might have different structure or just list)
        if isinstance(data, dict):
            # If grouped by brand or something
            flat_data = []
            for k, v in data.items():
                if isinstance(v, list):
                    flat_data.extend(v)
                elif isinstance(v, dict) and "products" in v:
                    flat_data.extend(v["products"])
            data = flat_data
            
        for product in data:
            # Extract basic info
            raw_title = product.get("name") or product.get("nom") or ""
            if not raw_title: continue
            
            raw_brand = product.get("brand", "")
            brand = clean_brand(raw_brand)
            if brand == "UNKNOWN":
                # Try to extract from title
                for k, v in BRAND_CASING.items():
                    if k in raw_title.lower():
                        brand = v
                        break
                        
            sku = product.get("sku") or product.get("reference")
            ref = extract_reference(raw_title, sku)
            
            # Combine all text for feature extraction
            raw_desc = product.get("description") or product.get("short_description") or ""
            specs = product.get("specifications", {})
            full_text = f"{raw_title} {raw_desc} {json.dumps(specs)}"
            
            capacity = extract_capacity(full_text)
            cooling = extract_cooling_system(full_text)
            doors = extract_doors(full_text)
            
            price = product.get("current_price") or product.get("prix")
            try:
                if isinstance(price, str):
                    price = float(price.replace("DT", "").replace(",", ".").replace(" ", ""))
                else:
                    price = float(price)
            except:
                price = None
                
            img_url = product.get("primary_image") or product.get("image")
            url = product.get("url", "")
            
            # The Master Key!
            if ref != "UNKNOWN":
                master_key = f"{brand}_{ref}"
            else:
                # If no clear reference, use a hash or cleaned title
                clean_t = re.sub(r'[^A-Z0-9]', '', raw_title.upper())
                master_key = f"{brand}_{clean_t[:20]}"
            
            if master_key not in master_catalog:
                master_catalog[master_key] = {
                    "clean_title": f"Réfrigérateur {brand} {capacity}L" if capacity else f"Réfrigérateur {brand} {ref}",
                    "brand": brand,
                    "reference": ref if ref != "UNKNOWN" else "",
                    "capacity_litres": capacity,
                    "cooling_system": cooling,
                    "door_type": doors,
                    "primary_image": img_url,
                    "description": raw_desc if len(raw_desc) > 10 else raw_title,
                    "availability": []
                }
            
            # Update missing top-level info
            if not master_catalog[master_key]["primary_image"] and img_url:
                master_catalog[master_key]["primary_image"] = img_url
            if not master_catalog[master_key]["capacity_litres"] and capacity:
                master_catalog[master_key]["capacity_litres"] = capacity
                
            # Add availability
            master_catalog[master_key]["availability"].append({
                "store": store,
                "price_tnd": price,
                "url": url,
                "raw_title": raw_title
            })

    # Save final unified catalog
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(master_catalog, f, ensure_ascii=False, indent=4)
        
    print(f"\nFusion Complete! Merged records into {len(master_catalog)} unique, clean refrigerators.")
    print(f"Data saved to: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
