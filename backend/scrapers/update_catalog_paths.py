import json

catalog_path = 'backend/scrapers/master_catalog.json'
with open(catalog_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('"brand": "Aux"', '"brand": "Aux_Brand"')
content = content.replace('"Aux": [', '"Aux_Brand": [')
content = content.replace('/climatiseurs/Aux/', '/climatiseurs/Aux_Brand/')

with open(catalog_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Master catalog updated successfully.")
