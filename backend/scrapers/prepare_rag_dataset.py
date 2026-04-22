import json
import os
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent
PROJECT_ROOT = BASE_DIR.parent.parent
MASTER_EQUIPMENT_DIR = PROJECT_ROOT / "Equipment" / "climatiseurs"
CATALOG_FILE = BASE_DIR / "master_catalog.json"

def main():
    if not CATALOG_FILE.exists():
        print("Master catalog not found!")
        return

    with open(CATALOG_FILE, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    print("Generating structured text specs for RAG...")
    
    processed_count = 0

    for brand_name, products in catalog.items():
        # Create brand subdirectories
        brand_text_dir = MASTER_EQUIPMENT_DIR / brand_name / "text"
        brand_json_dir = MASTER_EQUIPMENT_DIR / brand_name / "json"
        
        brand_text_dir.mkdir(parents=True, exist_ok=True)
        brand_json_dir.mkdir(parents=True, exist_ok=True)

        for product in products:
            ref = product.get("normalized_reference", "Unknown")
            
            # 1. Generate TXT specs
            text_content = []
            text_content.append(f"PRODUCT NAME: {product.get('clean_title')}")
            text_content.append(f"BRAND: {product.get('brand')}")
            text_content.append(f"REFERENCE: {product.get('normalized_reference')}")
            text_content.append(f"CAPACITY: {product.get('capacity_btu')} BTU")
            
            text_content.append("\n=== TECHNICAL SPECIFICATIONS ===")
            specs = product.get("specs", {})
            for key, val in specs.items():
                text_content.append(f"{key}: {val}")
            
            text_content.append("\n=== AVAILABILITY & PRICING ===")
            for av in product.get("availability", []):
                price = av.get("price_tnd", "N/A")
                text_content.append(f"- {av['store'].capitalize()}: {price} TND ({av['url']})")
            
            txt_path = brand_text_dir / f"{brand_name}_{ref}.txt"
            with open(txt_path, "w", encoding="utf-8") as f_out:
                f_out.write("\n".join(text_content))
            
            # 2. Generate JSON metadata
            json_path = brand_json_dir / f"{brand_name}_{ref}.json"
            with open(json_path, "w", encoding="utf-8") as f_out:
                json.dump(product, f_out, ensure_ascii=False, indent=4)
            
            # Link it in the master catalog
            product["local_text_path"] = str(txt_path).replace("\\", "/")
            product["local_json_path"] = str(json_path).replace("\\", "/")
            processed_count += 1

    # Save the updated catalog
    with open(CATALOG_FILE, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=4)

    print(f"\nFinished! Generated {processed_count} text spec files.")
    print(f"Dataset structure is now complete in {MASTER_EQUIPMENT_DIR}")

if __name__ == "__main__":
    main()
