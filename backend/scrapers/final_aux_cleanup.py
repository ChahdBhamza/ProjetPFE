import json
import os

catalog_path = 'backend/scrapers/master_catalog.json'
if os.path.exists(catalog_path):
    with open(catalog_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace the path segments
    new_content = content.replace('/Aux/images/', '/Aux_Brand/images/')
    new_content = new_content.replace('/Aux/json/', '/Aux_Brand/json/')
    new_content = new_content.replace('/climatiseurs/Aux\"', '/climatiseurs/Aux_Brand\"')
    
    with open(catalog_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Cleaned paths in master_catalog.json")

# Also clean any JSON files that might have been generated in the wrong folder
aux_json_dir = 'Equipment/climatiseurs/Aux/json'
if os.path.exists(aux_json_dir):
    print("Found JSONs in wrong Aux folder, deleting...")
    # (The powershell command should have handled this, but just in case)
