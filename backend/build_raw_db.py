import os
import sys
import json
from pathlib import Path
from PIL import Image

# Setup paths
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(os.getcwd())

from app.services.clip_embedder import CLIPEmbedder
from app.services.vector_store import VectorStore

def build_raw_db():
    print("="*60)
    print("BUILDING RAW DATABASE WITH METADATA (JSON LINKED)")
    print("="*60)

    # 1. Setup RAW Vector Store in EXISTING DB FOLDER
    db_path = "qdrant_db_v2"
    collection_name = "climatiseurs_raw"
    v_store = VectorStore(collection_name=collection_name, path=db_path)
    embedder = CLIPEmbedder()

    # 2. Get Data Folders
    data_root = Path("../equipment/climatiseurs")
    if not data_root.exists():
        print(f"[ERROR] Data folder not found at {data_root}")
        return

    # 3. Index Images with JSON data
    image_files = list(data_root.glob("**/images/*.jpg")) + list(data_root.glob("**/images/*.png"))
    print(f"Found {len(image_files)} images to index with Metadata...")

    for i, img_path in enumerate(image_files):
        try:
            # A. Find corresponding JSON
            # Structure: .../Brand/images/Filename.jpg -> .../Brand/json/Filename.json
            json_dir = img_path.parent.parent / "json"
            json_path = json_dir / (img_path.stem + ".json")
            
            brand = "Unknown"
            model = img_path.stem
            btu = "Unknown"
            
            if json_path.exists():
                with open(json_path, 'r', encoding='utf-8') as f:
                    meta = json.load(f)
                    brand = meta.get("brand", brand)
                    model = meta.get("clean_title", model)
                    btu = meta.get("capacity_btu", btu)
            
            # B. Process Image
            image = Image.open(img_path).convert("RGB")
            vector = embedder.embed_image(image)
            
            payload = {
                "brand": brand,
                "model_name": model,
                "btu": str(btu),
                "original_path": str(img_path),
                "is_raw": True
            }
            
            v_store.add_climatiseur(
                product_id=i,
                brand=brand,
                model_name=model,
                embedding=vector,
                metadata=payload
            )
            
            if (i+1) % 20 == 0:
                print(f"Indexed {i+1}/{len(image_files)} with Metadata...")
                
        except Exception as e:
            print(f"Error indexing {img_path}: {e}")

    print("="*60)
    print(f"RAW DATABASE WITH METADATA BUILT at {db_path}")
    print("="*60)

if __name__ == "__main__":
    build_raw_db()
