import json
import os
import shutil
from pathlib import Path
import re

# Paths
BASE_DIR = Path(__file__).parent
PROJECT_ROOT = BASE_DIR.parent.parent
DATA_EQUIPMENT_DIR = PROJECT_ROOT / "dataequipment" / "climatiseurs"
MASTER_EQUIPMENT_DIR = PROJECT_ROOT / "Equipment" / "climatiseurs"
CATALOG_FILE = BASE_DIR / "master_catalog.json"

def clean_ref(text):
    return re.sub(r'[^A-Z0-9]', '', text.upper())

def sanitize_brand(brand):
    # Windows reserved names
    reserved = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
    if brand.upper() in reserved:
        return f"{brand}_Brand"
    return brand

def main():
    if not CATALOG_FILE.exists():
        print("Master catalog not found!")
        return

    with open(CATALOG_FILE, "r", encoding="utf-8") as f:
        master_catalog = json.load(f)

    # Collect existing references
    existing_refs = set()
    for brand in master_catalog:
        for p in master_catalog[brand]:
            existing_refs.add(p.get("normalized_reference"))

    print("Starting migration from dataequipment to Equipment...")
    
    added_count = 0

    for brand_folder in DATA_EQUIPMENT_DIR.iterdir():
        if not brand_folder.is_dir(): continue
        brand_name = sanitize_brand(brand_folder.name)
        
        json_dir = brand_folder / "text"
        img_src_dir = brand_folder / "images"
        if not json_dir.exists(): continue
        
        for json_file in json_dir.glob("*.json"):
            # Detect reference from filename
            match = re.search(r'\b([A-Z0-9-]{4,})\b', json_file.stem)
            ref = clean_ref(match.group(1)) if match else f"LOCAL_{json_file.stem[:10].upper()}"
            
            if ref in existing_refs:
                continue

            # Load local data
            try:
                with open(json_file, "r", encoding="utf-8") as f_in:
                    local_data = json.load(f_in)
            except:
                continue

            # Map to our standard format
            capacity = local_data.get("btu")
            tech = "Inverter" if local_data.get("inverter") else "Non Inverter"
            
            product_obj = {
                "clean_title": json_file.stem,
                "brand": brand_name,
                "normalized_reference": ref,
                "capacity_btu": int(capacity) if str(capacity).isdigit() else None,
                "primary_image": "Not found",
                "description": f"Local dataset product: {local_data.get('type', 'Climatiseur')} {local_data.get('color', '')}",
                "availability": [
                    {
                        "store": "local_dataset",
                        "price_tnd": local_data.get("price", "N/A"),
                        "raw_title": json_file.stem,
                        "url": "local",
                        "image_url": "local"
                    }
                ],
                "specs": {
                    "Technology": tech,
                    "Mode": local_data.get("mode", "Not found"),
                    "Energy_Class": local_data.get("energy_class", "Not found"),
                    "Gas_Type": local_data.get("gas", "Not found"),
                    "Dimensions": "Not found",
                    "Weight": "Not found",
                    "Noise_Level": "Not found",
                    "Warranty": f"{local_data.get('warranty')} ans" if local_data.get('warranty') else "Not found",
                }
            }

            # Prepare directories in Equipment
            dest_img_dir = MASTER_EQUIPMENT_DIR / brand_name / "images"
            dest_txt_dir = MASTER_EQUIPMENT_DIR / brand_name / "text"
            dest_json_dir = MASTER_EQUIPMENT_DIR / brand_name / "json"
            
            for d in [dest_img_dir, dest_txt_dir, dest_json_dir]:
                d.mkdir(parents=True, exist_ok=True)

            # Copy Image
            # Try to find a matching image in img_src_dir
            found_img = False
            if img_src_dir.exists():
                # Filenames in dataequipment often match exactly between text and images folder
                potential_img = img_src_dir / f"{json_file.stem}.jpg"
                if potential_img.exists():
                    dest_path = dest_img_dir / f"{brand_name}_{ref}.jpg"
                    shutil.copy(potential_img, dest_path)
                    product_obj["primary_image"] = str(dest_path).replace("\\", "/")
                    product_obj["local_image_path"] = str(dest_path).replace("\\", "/")
                    found_img = True

            # Generate TXT and JSON in Equipment
            txt_path = dest_txt_dir / f"{brand_name}_{ref}.txt"
            with open(txt_path, "w", encoding="utf-8") as f_txt:
                f_txt.write(f"PRODUCT NAME: {product_obj['clean_title']}\nBRAND: {brand_name}\nREFERENCE: {ref}\n")
                for k, v in product_obj["specs"].items():
                    f_txt.write(f"{k}: {v}\n")

            json_path = dest_json_dir / f"{brand_name}_{ref}.json"
            with open(json_path, "w", encoding="utf-8") as f_json:
                json.dump(product_obj, f_json, ensure_ascii=False, indent=4)

            product_obj["local_text_path"] = str(txt_path).replace("\\", "/")
            product_obj["local_json_path"] = str(json_path).replace("\\", "/")

            # Add to master catalog
            if brand_name not in master_catalog:
                master_catalog[brand_name] = []
            master_catalog[brand_name].append(product_obj)
            existing_refs.add(ref)
            added_count += 1

    # Save final catalog
    with open(CATALOG_FILE, "w", encoding="utf-8") as f:
        json.dump(master_catalog, f, ensure_ascii=False, indent=4)

    print(f"\nMigration Complete! Added {added_count} unique products from dataequipment to the Equipment folder.")

if __name__ == "__main__":
    main()
