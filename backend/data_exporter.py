import json
import os
import requests
import re
from pathlib import Path

def sanitize_filename(name):
    # Remove invalid filename characters
    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def extract_and_organize_data():
    # Folder Structure: dataequipment / climatiseurs / [Brand] / text , images
    base_dir = Path("../dataequipment/climatiseurs")

    
    # Load the JSON data
    try:
        # Looking for the file we created earlier
        with open("scraper_results.json", "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        print("Error: scraper_results.json not found! Please run the scraper first.")
        return

    total_products = 0
    total_images_downloaded = 0
    
    print(" Starting data export process...")
    
    for brand, info in data.items():
        products = info.get("products", [])
        print(f" Processing brand: {brand} ({len(products)} products)")
        
        # Create brand directories
        brand_dir = base_dir / brand
        brand_img_dir = brand_dir / "images"
        brand_text_dir = brand_dir / "text"
        brand_img_dir.mkdir(parents=True, exist_ok=True)
        brand_text_dir.mkdir(parents=True, exist_ok=True)
        
        for product in products:
            title = product.get("title", "Unknown Title")
            safe_title = sanitize_filename(title)
            
            # --- 1. Export Specs to Text ---
            text_filename = brand_text_dir / f"{safe_title}.txt"
            with open(text_filename, "w", encoding="utf-8") as text_file:
                text_file.write(f"Product: {title}\n")
                text_file.write(f"Price: {product.get('price', 'N/A')}\n")
                text_file.write(f"URL: {product.get('product_url', 'N/A')}\n")
                text_file.write(f"\n--- Technical Specifications ---\n")
                
                specs = product.get("specs", {})
                for spec_name, spec_value in specs.items():
                    text_file.write(f"{spec_name}: {spec_value}\n")
                    
            # --- 2. Download Image ---
            image_url = product.get("image_url")
            if image_url:
                if image_url.startswith("//"):
                    image_url = "https:" + image_url
                    
                img_ext = image_url.split('.')[-1].split('?')[0] if '.' in image_url else "jpg"
                if len(img_ext) > 4:  
                    img_ext = "jpg"
                    
                img_filename = brand_img_dir / f"{safe_title}.{img_ext}"
                
                # Check if image already exists to avoid re-downloading
                if not img_filename.exists():
                    try:
                        response = requests.get(image_url, stream=True, timeout=10)
                        if response.status_code == 200:
                            with open(img_filename, 'wb') as img_file:
                                for chunk in response.iter_content(1024):
                                    img_file.write(chunk)
                            total_images_downloaded += 1
                    except Exception as e:
                        print(f"    Failed to download image for '{title}': {e}")
            total_products += 1

    print(f"\n Export complete!")
    print(f" Total products processed: {total_products}")
    print(f" New images downloaded: {total_images_downloaded}")
    print(f" Folders created in: {base_dir}")

if __name__ == "__main__":
    extract_and_organize_data()
