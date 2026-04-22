import json
import os
from pathlib import Path
import re

# Paths
BASE_DIR = Path(__file__).parent
DATA_EQUIPMENT_DIR = BASE_DIR.parent.parent / "dataequipment" / "climatiseurs"
MASTER_CATALOG_FILE = BASE_DIR / "master_catalog.json"

def clean_ref(text):
    return re.sub(r'[^A-Z0-9]', '', text.upper())

def main():
    if not MASTER_CATALOG_FILE.exists():
        print("Master catalog not found!")
        return

    with open(MASTER_CATALOG_FILE, "r", encoding="utf-8") as f:
        master_catalog = json.load(f)

    # Collect all references currently in the master catalog
    existing_refs = set()
    for brand in master_catalog:
        for p in master_catalog[brand]:
            existing_refs.add(p.get("normalized_reference"))

    print("Checking for unique products in dataequipment...")
    
    missing_from_catalog = []
    
    if not DATA_EQUIPMENT_DIR.exists():
        print(f"Data equipment directory not found at {DATA_EQUIPMENT_DIR}")
        return

    for brand_folder in DATA_EQUIPMENT_DIR.iterdir():
        if not brand_folder.is_dir(): continue
        
        json_dir = brand_folder / "text"
        if not json_dir.exists(): continue
        
        for json_file in json_dir.glob("*.json"):
            # Try to extract reference from filename
            # Filename example: "Climatiseur Armoire Biolux ECO36CF..."
            # We look for a code-like string (letters + numbers)
            match = re.search(r'\b([A-Z0-9-]{4,})\b', json_file.stem)
            if match:
                ref = clean_ref(match.group(1))
                if ref not in existing_refs:
                    missing_from_catalog.append({
                        "brand": brand_folder.name,
                        "file": json_file.name,
                        "detected_ref": ref
                    })

    print(f"Found {len(missing_from_catalog)} products in dataequipment that are NOT in the master catalog.")
    if missing_from_catalog:
        print("\n--- SAMPLE OF MISSING PRODUCTS ---")
        for item in missing_from_catalog[:15]:
            print(f"  - [{item['brand']}] {item['file']} (Ref: {item['detected_ref']})")
            
if __name__ == "__main__":
    main()
