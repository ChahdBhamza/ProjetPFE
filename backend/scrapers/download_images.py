import json
import os
import requests
import concurrent.futures
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent
PROJECT_ROOT = BASE_DIR.parent.parent
MASTER_EQUIPMENT_DIR = PROJECT_ROOT / "Equipment" / "climatiseurs"
CATALOG_FILE = BASE_DIR / "master_catalog.json"

def download_image(product):
    brand = product.get("brand", "Unknown")
    ref = product.get("normalized_reference", "Unknown")
    url = product.get("primary_image")
    
    if not url or url == "Not found" or not url.startswith("http"):
        return None

    # Create the specific brand images folder
    brand_images_dir = MASTER_EQUIPMENT_DIR / brand / "images"
    brand_images_dir.mkdir(parents=True, exist_ok=True)

    # Determine file extension
    ext = ".jpg"
    if ".png" in url.lower(): ext = ".png"
    if ".webp" in url.lower(): ext = ".webp"
    
    filename = f"{brand}_{ref}{ext}"
    save_path = brand_images_dir / filename
    
    # Skip if already downloaded
    if save_path.exists():
        return str(save_path).replace("\\", "/")

    try:
        response = requests.get(url, timeout=10, headers={"User-Agent": "Mozilla/5.0"})
        if response.status_code == 200:
            with open(save_path, "wb") as f:
                f.write(response.content)
            return str(save_path).replace("\\", "/")
    except Exception as e:
        print(f"Error downloading {url}: {e}")
    
    return None

def main():
    if not CATALOG_FILE.exists():
        print("Master catalog not found!")
        return

    with open(CATALOG_FILE, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    print("Starting image download pipeline...")
    
    all_products = []
    for brand in catalog:
        for product in catalog[brand]:
            all_products.append(product)

    total = len(all_products)
    downloaded_count = 0

    # Use ThreadPoolExecutor for faster downloads
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        future_to_prod = {executor.submit(download_image, p): p for p in all_products}
        for future in concurrent.futures.as_completed(future_to_prod):
            prod = future_to_prod[future]
            local_path = future.result()
            if local_path:
                prod["local_image_path"] = local_path
                downloaded_count += 1
            
            if downloaded_count % 10 == 0:
                print(f"Progress: {downloaded_count}/{total} images handled.")

    # Save the updated catalog
    with open(CATALOG_FILE, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=4)

    print(f"\nFinished! Downloaded {downloaded_count} images to {MASTER_EQUIPMENT_DIR}")
    print("Master catalog updated with 'local_image_path'.")

if __name__ == "__main__":
    main()
