import json
import os
import re
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent
DATA_EQUIPMENT_DIR = BASE_DIR.parent.parent / "dataequipment" / "climatiseurs"
OUTPUT_FILE = BASE_DIR / "master_catalog.json"

# Trust hierarchy: Jumbo is our gold standard for specs
SITES_IN_ORDER = ["jumbo", "zoom", "mega", "tunisianet"]

BRAND_CASING = {
    "tcl": "TCL", "lg": "LG", "hge": "HGE", "bosch": "BOSCH", 
    "newstar": "NewStar", "delonghi": "DeLonghi", "westpoint": "Westpoint",
    "chaffoteaux": "Chaffoteaux",
}

# Mapping for Tunisianet French keys to Master Keys
TUNISIANET_MAP = {
    "Type": "Mode",
    "Garantie": "Warranty",
    "Puissance": "Capacity",
    "Inverter": "Technology",
    "Smart": "Smart",
    "Couleur": "Color"
}

def clean_brand(brand):
    """Normalize brand name."""
    if not brand or brand == "Not found": return "Other"
    key = brand.strip().lower()
    if key in BRAND_CASING:
        return BRAND_CASING[key]
    
    # Windows reserved names sanitization
    reserved = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
    final_brand = brand.strip().title()
    if final_brand.upper() in reserved:
        return f"{final_brand}_Brand"
    return final_brand

def clean_reference(ref):
    """Ruthless normalization to create a solid deduplication key."""
    if not ref or ref == "Not found": return "UNKNOWN"
    # Upper case, remove all non-alphanumeric characters (hyphens, spaces, slashes)
    return re.sub(r'[^A-Z0-9]', '', ref.upper())

def clean_capacity(cap, title="", ref=""):
    """Extract integer BTU with fallback to title and reference string."""
    # 1. Check direct capacity data
    if cap and cap != "Not found":
        match = re.search(r'([0-9]{4,5})', str(cap))
        if match: return int(match.group(1))
    
    # 2. Fallback to Title search
    if title:
        match = re.search(r'(\d{4,5})\s*BTU', str(title), re.I)
        if match: return int(match.group(1))
        # Handle cases like "12k" or "9k"
        match_k = re.search(r'(\d{1,2})k\b', str(title), re.I)
        if match_k: return int(match_k.group(1)) * 1000
    
    # 3. Fallback to Reference Code (e.g., FC12CH -> 12000)
    if ref:
        # Common patterns: -12-, 12000, 12, etc. after a brand prefix
        match_ref = re.search(r'(\d{2})[A-Z0-9]*$', str(ref))
        if match_ref:
            code = int(match_ref.group(1))
            if code in [9, 12, 18, 24, 30, 36, 48, 60]: return code * 1000
            
    return None

def clean_price(price_str):
    """Attempt to parse the price to a float."""
    if not price_str or price_str == "Not found": return None
    price_str = price_str.upper().replace('TND', '').replace('DT', '').replace(' ', '').replace(',', '.')
    try:
        return float(price_str)
    except:
        return None

def check_local_dataset(brand, norm_ref, raw_title):
    """Check if images exist for this product in dataequipment/climatiseurs/{Brand}/images/"""
    brand_images_folder = DATA_EQUIPMENT_DIR / brand / "images"
    if not brand_images_folder.exists():
        return None

    try:
        all_images = list(brand_images_folder.iterdir())
        if not all_images:
            return None

        # Strategy 1: Match by normalized reference inside filename
        if norm_ref and norm_ref != "UNKNOWN":
            for f in all_images:
                clean_fname = re.sub(r'[^A-Z0-9]', '', f.stem.upper())
                if norm_ref in clean_fname:
                    return str(f).replace("\\", "/")

        # Strategy 2: Fuzzy match by BTU capacity from the title
        if raw_title:
            btu_match = re.search(r'(\d{4,5})\s*btu', raw_title, re.I)
            if btu_match:
                btu = btu_match.group(1)
                for f in all_images:
                    if btu in f.name:
                        return str(f).replace("\\", "/")

        # Strategy 3: Return first image in the folder as a brand-level fallback
        first_img = next((f for f in all_images if f.suffix.lower() in ['.jpg', '.jpeg', '.png', '.webp']), None)
        if first_img:
            return str(first_img).replace("\\", "/")

    except Exception:
        pass
    return None

KNOWN_BRANDS = [
    "Gree", "Samsung", "Midea", "Condor", "TCL", "Whirlpool", "LG", "Beko", "Unionaire",
    "Saba", "Montblanc", "Biolux", "BOSCH", "Maxwell", "Westpoint", "Hisense", "Haier",
    "Sharp", "Panasonic", "Toshiba", "Carrier", "Daikin", "Trane", "York", "Aux", "Iris",
    "Brandt", "NewStar", "Vega", "Fresh", "Tornado", "Focus", "Coala", "Hyundai",
    "Comfee", "Orient", "General Gold", "Servicom", "Airwell", "Manta", "Sabra", "Galanz", "Indesit",
    "Falcon", "HGE", "Techwood", "Tristar", "Luxell", "Delonghi", "Chaffoteaux"
]

def detect_brand_from_title(title):
    """Re-detect brand from raw product title using the known brands list."""
    if not title: return "Other"
    t = title.upper()
    for brand in KNOWN_BRANDS:
        if brand.upper() in t:
            key = brand.lower()
            return BRAND_CASING.get(key, brand)
    # Hyundai model-code only titles
    import re
    if re.search(r'\bHY2[-\s]', title, re.I):
        return "Hyundai"
    return "Other"

def deep_extraction(product_specs, text):
    """Fallback: Search for missing specs inside raw text descriptions."""
    if not text or text == "Not found": return
    
    patterns = {
        "Energy_Class": r'(?:classe|energetique|nergtique|classe \wnerg\w|energy class)\s*:?\s*([A-G]\s*\+*)',
        "Warranty": r'(\d+)\s*(?:ans|mois|years|months)\s*(?:de\s*)?garantie',
        "Gas_Type": r'\b(R410A|R32|R22|R410)\b',
        "Noise_Level": r'(\d+)\s*(?:dB|dbA|dba)',
        "Smart": r'\b(Smart|WiFi|Wi-Fi|Wifi|Connect.\s*Wi-Fi)\b',
        "Color": r'(?:Couleur|Color)\s*:?\s*(\w+)',
        "Mode": r'\b(Chaud\s*[&/]\s*Froid|Froid\s*[&/]\s*Chaud|Chaud\s*Froid|Froid|Chaud)\b',
        "Dimensions": r'(?:Dimensions?|Dim|Taille)\s*(?:unit.\s*int.rieure)?\s*:?\s*([\d\s*[xX×*]\s*[\d\s*[xX×*]\s*[\d,.]+\s*(?:mm|cm|m))',
        "Weight": r'(?:Poids|Weight)\s*(?:unit.\s*int.rieure)?\s*:?\s*([\d,.]+\s*kg)',
    }
    
    for key, pattern in patterns.items():
        if product_specs.get(key) == "Not found" or (key == "Smart" and product_specs.get(key) == "No"):
            match = re.search(pattern, text, re.I)
            if match:
                val = match.group(1) if len(match.groups()) > 0 else match.group(0)
                if key == "Smart":
                    product_specs[key] = "Yes"
                elif key == "Mode":
                    # Normalize mode
                    v = val.lower()
                    if "chaud" in v and "froid" in v: product_specs[key] = "Chaud & Froid"
                    elif "froid" in v: product_specs[key] = "Froid"
                    elif "chaud" in v: product_specs[key] = "Chaud"
                elif key == "Gas_Type":
                    product_specs[key] = val.upper().replace("GAZ ", "")
                else:
                    product_specs[key] = val.strip()

def final_cleanup(catalog):
    """Ensure zero 'Not found' fields and link to local equipment files."""
    EQUIPMENT_ROOT = Path(r"c:\Users\chahd\Desktop\DetectionAppPFE\Equipment\climatiseurs")
    
    for master_key, p in catalog.items():
        specs = p.get("specs", {})
        brand = p["brand"]
        ref = p["normalized_reference"]
        
        # Smart Defaults
        if specs.get("Color") == "Not found":
            specs["Color"] = "Blanc"
        if specs.get("Mode") == "Not found":
            specs["Mode"] = "Chaud & Froid"
        if specs.get("Warranty") == "Not found":
            specs["Warranty"] = "3 Ans"
        if specs.get("Energy_Class") == "Not found":
            specs["Energy_Class"] = "Standard"
        if specs.get("Gas_Type") == "Not found":
            specs["Gas_Type"] = "R410A"
        
        # Associate with local files if they exist in Equipment folder
        local_img = EQUIPMENT_ROOT / brand / "images" / f"{brand}_{ref}.jpg"
        local_json = EQUIPMENT_ROOT / brand / "json" / f"{brand}_{ref}.json"
        
        if local_img.exists():
            p["local_image_path"] = str(local_img).replace("\\", "/")
        if local_json.exists():
            p["local_json_path"] = str(local_json).replace("\\", "/")
        
        # Catch-all for remaining 'Not found'
        for k, v in specs.items():
            if v == "Not found" or v is None:
                specs[k] = "N/A"
        
        # Also clean top-level fields
        if p.get("description") == "Not found":
            p["description"] = f"Climatiseur {p['brand']} {p['capacity_btu']} BTU {specs['Technology']}"

def main():
    print("Starting Normalization & Data Fusion Pipeline...")
    master_catalog = {}

    for site in SITES_IN_ORDER:
        file_path = BASE_DIR / f"scraper_{site}_results.json"
        if not file_path.exists():
            print(f"Skipping {site}, file not found.")
            continue
        
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        print(f"Processing {site} data...")
        
        for raw_brand, brand_data in data.items():
            for product in brand_data.get("products", []):
                specs = product.get("specs", {})
                
                raw_ref = specs.get("Reference", "Not found")
                raw_title = product.get("title", "")
                raw_desc = product.get("description", "")
                
                # Re-detect brand from the raw title (more reliable than stored brand)
                brand = clean_brand(detect_brand_from_title(raw_title)) if raw_title else clean_brand(raw_brand)
                norm_ref = clean_reference(raw_ref)
                
                # If the scraper failed to find a reference, it's impossible to deduplicate accurately.
                if norm_ref == "UNKNOWN":
                    continue
                
                # The Master Key!
                master_key = f"{brand}_{norm_ref}"
                
                # Initialize item if we haven't seen it before
                if master_key not in master_catalog:
                    capacity = clean_capacity(specs.get("Capacity"), raw_title, norm_ref)
                    tech = specs.get("Technology", "Not found")
                    
                    # Generate a clean, unified title
                    synth_title = f"{brand} {tech} {capacity} BTU ({raw_ref})" if capacity else f"{brand} {tech} ({raw_ref})"
                    
                    master_catalog[master_key] = {
                        "clean_title": synth_title.replace("Not found", "").strip(),
                        "brand": brand,
                        "normalized_reference": norm_ref,
                        "capacity_btu": capacity,
                        "primary_image": "Not found",
                        "description": "Not found",
                        "availability": [],
                        "specs": {
                            "Technology": tech,
                            "Mode": "Not found",
                            "Energy_Class": "Not found",
                            "Gas_Type": "Not found",
                            "Dimensions": "Not found",
                            "Weight": "Not found",
                            "Noise_Level": "Not found",
                            "Warranty": "Not found",
                            "Smart": "No",
                            "Color": "Not found",
                        }
                    }
                
                # Update Description if this one is better (longer)
                if raw_desc and raw_desc != "Not found" and len(raw_desc) > len(master_catalog[master_key]["description"]):
                    master_catalog[master_key]["description"] = raw_desc

                # Data Fusion: Update Specs ONLY if they are currently missing
                for spec_key in master_catalog[master_key]["specs"].keys():
                    if master_catalog[master_key]["specs"][spec_key] == "Not found":
                        # Direct check
                        val = specs.get(spec_key, "Not found")
                        
                        # Tunisianet Mapping check
                        if site == "tunisianet":
                            for fr_key, en_key in TUNISIANET_MAP.items():
                                if en_key == spec_key:
                                    val = specs.get(fr_key, val)
                        
                        if val != "Not found" and str(val).strip() != "":
                            # Clean "Oui/Non" for Technology/Smart
                            if spec_key in ["Technology", "Smart"]:
                                if str(val).lower() in ["oui", "yes", "true"]: val = "Yes" if spec_key == "Smart" else "Inverter"
                                elif str(val).lower() in ["non", "no", "false"]: val = "No" if spec_key == "Smart" else "Non Inverter"

                            master_catalog[master_key]["specs"][spec_key] = val
                            
                # Deep Extraction: Try to recover missing specs from title + description
                deep_extraction(master_catalog[master_key]["specs"], f"{raw_title} {raw_desc}")

                # Append Pricing & Availability Data
                price = clean_price(product.get("price"))
                img_url = product.get("image_url", "Not found")
                
                # Set primary image if not set yet (Trust order: Jumbo -> Zoom -> Mega)
                if master_catalog[master_key]["primary_image"] == "Not found" and img_url != "Not found":
                    master_catalog[master_key]["primary_image"] = img_url

                master_catalog[master_key]["availability"].append({
                    "store": site,
                    "price_tnd": price,
                    "raw_title": raw_title,
                    "url": product.get("product_url", ""),
                    "image_url": img_url
                })

    # --- NEW STEP: Import unique products from dataequipment ---
    print("Checking for unique products in dataequipment...")
    if DATA_EQUIPMENT_DIR.exists():
        import shutil
        for brand_folder in DATA_EQUIPMENT_DIR.iterdir():
            if not brand_folder.is_dir(): continue
            brand_name = clean_brand(brand_folder.name)
            json_dir = brand_folder / "text"
            if not json_dir.exists(): continue
            
            for json_file in json_dir.glob("*.json"):
                match = re.search(r'\b([A-Z0-9-]{4,})\b', json_file.stem)
                ref = clean_reference(match.group(1)) if match else f"LOCAL_{json_file.stem[:10].upper()}"
                
                # Check for exact reference match
                master_key = f"{brand_name}_{ref}"
                
                # Check for Fuzzy match (Same Brand + Same BTU)
                fuzzy_match_key = None
                capacity = None
                try:
                    with open(json_file, "r", encoding="utf-8") as f_in:
                        local_data = json.load(f_in)
                        capacity = int(local_data.get("btu")) if str(local_data.get("btu")).isdigit() else None
                except: continue

                if master_key not in master_catalog and capacity:
                    for k, v in master_catalog.items():
                        if v["brand"] == brand_name and v.get("capacity_btu") == capacity:
                            fuzzy_match_key = k
                            break

                target_key = fuzzy_match_key if fuzzy_match_key else master_key
                
                if target_key in master_catalog:
                    # MERGE into existing
                    p = master_catalog[target_key]
                    if p["specs"]["Energy_Class"] == "Not found":
                        p["specs"]["Energy_Class"] = local_data.get("energy_class", "Not found")
                    if p["specs"]["Warranty"] == "Not found" and local_data.get("warranty"):
                        p["specs"]["Warranty"] = f"{local_data.get('warranty')} ans"
                    
                    # Add to availability if not already there
                    if not any(av["store"] == "local_dataset" for av in p["availability"]):
                        p["availability"].append({
                            "store": "local_dataset", 
                            "price_tnd": local_data.get("price"),
                            "raw_title": json_file.stem,
                            "url": "local", "image_url": "local"
                        })
                else:
                    # ADD as NEW
                    tech = "Inverter" if local_data.get("inverter") else "Non Inverter"
                    master_catalog[master_key] = {
                        "clean_title": json_file.stem,
                        "brand": brand_name,
                        "normalized_reference": ref,
                        "capacity_btu": capacity,
                        "primary_image": "Not found",
                        "description": f"Local product: {local_data.get('type', 'Climatiseur')}",
                        "availability": [
                            {
                                "store": "local_dataset", 
                                "price_tnd": local_data.get("price"),
                                "raw_title": json_file.stem,
                                "url": "local", "image_url": "local"
                            }
                        ],
                        "specs": {
                            "Technology": tech, "Mode": local_data.get("mode", "Not found"),
                            "Energy_Class": local_data.get("energy_class", "Not found"),
                            "Gas_Type": local_data.get("gas", "Not found"),
                            "Dimensions": "Not found", "Weight": "Not found",
                            "Noise_Level": "Not found", 
                            "Warranty": f"{local_data.get('warranty')} ans" if local_data.get('warranty') else "Not found",
                            "Smart": "Yes" if local_data.get("smart") or local_data.get("wifi") or local_data.get("wifi_connect") else "No",
                            "Color": local_data.get("color", "Not found")
                        }
                    }
                    # Copy image
                    img_src = brand_folder / "images" / f"{json_file.stem}.jpg"
                    if img_src.exists():
                        dest_img = BASE_DIR.parent.parent / "Equipment" / "climatiseurs" / brand_name / "images" / f"{brand_name}_{ref}.jpg"
                        dest_img.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy(img_src, dest_img)
                        master_catalog[master_key]["primary_image"] = str(dest_img).replace("\\", "/")

    # --- NEW STEP: Final Cleanup Pass ---
    print("Performing final data cleaning and normalization...")
    final_cleanup(master_catalog)

    # Prepare for saving (group by brand)
    grouped_by_brand = {}
    for item in master_catalog.values():
        brand = item["brand"]
        if brand not in grouped_by_brand:
            grouped_by_brand[brand] = []
        grouped_by_brand[brand].append(item)
    
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(grouped_by_brand, f, ensure_ascii=False, indent=4)
        
    print(f"\nFusion Complete! Merged records into {len(master_catalog)} unique, clean products.")
    print(f"Data saved to: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
