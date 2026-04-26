import os
import json
import re
from pathlib import Path

# Configuration
DATA_DIR = Path("../dataequipment/climatiseurs")

def extract_with_regex(text: str, brand_name: str):
    """Zero-token extraction using pattern matching"""
    # Initialize default structure
    data = {
        "brand": brand_name,
        "btu": "Unknown",
        "inverter": False,
        "mode": "Unknown",
        "gas": "Unknown",
        "energy_class": "Unknown",
        "warranty": "Unknown"
    }

    # 1. Extract BTU
    btu_match = re.search(r"(\d{4,5})\s*BTU", text, re.IGNORECASE)
    if btu_match:
        data["btu"] = btu_match.group(1)

    # 2. Extract Inverter
    data["inverter"] = True if re.search(r"inverter", text, re.IGNORECASE) else False

    # 3. Extract Type (Split vs Armoire)
    if re.search(r"armoir", text, re.IGNORECASE):
        data["type"] = "Armoire"
    else:
        data["type"] = "Split"

    # 4. Extract Tropicalized
    trop_match = re.search(r"tropicalis[ée]\s*:\s*(oui|non|yes|no)", text, re.IGNORECASE)
    if trop_match:
        data["tropicalized"] = True if trop_match.group(1).lower() in ["oui", "yes"] else False
    else:
        # Fallback search
        data["tropicalized"] = True if re.search(r"tropicalis[ée]", text, re.IGNORECASE) else False

    # 5. Extract Smart
    smart_match = re.search(r"smart\s*:\s*(oui|non|yes|no)", text, re.IGNORECASE)
    if smart_match:
        data["smart"] = True if smart_match.group(1).lower() in ["oui", "yes"] else False
    else:
        data["smart"] = True if re.search(r"smart", text, re.IGNORECASE) and not re.search(r"smart\s*:\s*non", text, re.IGNORECASE) else False

    # 6. Extract Gas
    gas_match = re.search(r"(R410A|R32|R22|R407C)", text, re.IGNORECASE)
    if gas_match:
        data["gas"] = gas_match.group(1).upper()

    # 7. Extract Price (e.g. 5 449,000 DT)
    price_match = re.search(r"Price:\s*([\d\s\u202f,]+)\s*DT", text, re.IGNORECASE)
    if price_match:
        data["price"] = price_match.group(1).replace("\u202f", " ").strip() + " DT"

    # 8. Extract Color
    color_match = re.search(r"Couleur:\s*(.*?)(?:\n|$)", text, re.IGNORECASE)
    if color_match:
        data["color"] = color_match.group(1).strip()

    # 9. Extract Surface
    surface_match = re.search(r"Surface couverte clim:\s*(.*?)(?:\n|$)", text, re.IGNORECASE)
    if surface_match:
        # Just grab the first part (e.g. "entre 100 m² et 120 m²")
        data["surface"] = surface_match.group(1).split("👉")[0].strip()

    # 4. Extract Energy Class
    energy_match = re.search(r"classe\s*energetic\s*:\s*([A-C]\+*)", text, re.IGNORECASE) or \
                   re.search(r"classe\s*:\s*([A-C]\+*)", text, re.IGNORECASE) or \
                   re.search(r"\b([A-C]\+{1,3})\b", text)
    if energy_match:
        data["energy_class"] = energy_match.group(1).upper()

    # 5. Extract Mode
    if "chaud" in text.lower() and "froid" in text.lower():
        data["mode"] = "Chaud-Froid"
    elif "froid" in text.lower():
        data["mode"] = "Froid"

    # 6. Extract Warranty
    warranty_match = re.search(r"(\d+)\s*ans", text, re.IGNORECASE)
    if warranty_match:
        data["warranty"] = warranty_match.group(1)

    return data

def main():
    print("--- 🛡️ STARTING ZERO-TOKEN REGEX ENRICHMENT ---")
    
    if not DATA_DIR.exists():
        print(f"Error: {DATA_DIR} not found.")
        return

    brands = [d for d in DATA_DIR.iterdir() if d.is_dir()]
    total_files = 0
    enriched_count = 0

    for brand_folder in brands:
        print(f"Processing: {brand_folder.name}")
        text_dir = brand_folder / "text"
        if not text_dir.exists(): continue
            
        txt_files = list(text_dir.glob("*.txt"))
        for txt_file in txt_files:
            json_file = text_dir / (txt_file.stem + ".json")
            
            with open(txt_file, "r", encoding="utf-8") as f:
                raw_text = f.read()
                
            # Always run regex (it's fast and free)
            enriched_data = extract_with_regex(raw_text, brand_folder.name)
            
            with open(json_file, "w", encoding="utf-8") as f:
                json.dump(enriched_data, f, indent=4)
            
            enriched_count += 1
            total_files += 1

    print(f"--- ✅ SUCCESS ---")
    print(f"Files Processed: {total_files}")
    print(f"Metadata JSONs created: {enriched_count}")

if __name__ == "__main__":
    main()
