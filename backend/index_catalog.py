import json
import os
import uuid
from pathlib import Path
from app.services.clip_embedder import CLIPEmbedder
from app.services.vector_store import VectorStore

# Paths
BASE_DIR = Path(__file__).parent
CATALOG_FILE = BASE_DIR / "scrapers" / "master_catalog.json"

def main():
    if not CATALOG_FILE.exists():
        print(f"Master catalog not found at {CATALOG_FILE}")
        return

    print("--- STARTING CATALOG INDEXING ---")
    
    # 1. Initialize Services
    embedder = CLIPEmbedder()
    vstore = VectorStore(collection_name="climatiseurs_v2", path="qdrant_db")
    
    # FORCE CLEAR (Delete and Recreate)
    print("Clearing collection 'climatiseurs_v2'...")
    try:
        vstore.client.delete_collection("climatiseurs_v2")
    except: pass

    from qdrant_client.models import VectorParams, Distance
    try:
        vstore.client.create_collection(
            collection_name="climatiseurs_v2",
            vectors_config=VectorParams(size=512, distance=Distance.COSINE),
        )
    except: pass

    print("Database ready for fresh indexing in 'climatiseurs_v2'.")
    with open(CATALOG_FILE, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    total_indexed = 0
    
    # 3. Iterate and Index
    for brand_name, products in catalog.items():
        print(f"\nIndexing Brand: {brand_name}")
        for product in products:
            try:
                title = product.get("clean_title")
                img_path = product.get("local_image_path")
                
                if not img_path or not os.path.exists(img_path):
                    print(f"  [SKIP] {title} - No local image found")
                    continue

                # Generate Vector from the Image
                # CLIP allows us to search these images using both images and text!
                embedding = embedder.embed_image(img_path)
                
                if embedding is None:
                    print(f"  [ERROR] {title} - Failed to generate embedding")
                    continue

                # Prepare Metadata for Qdrant Payload
                metadata = {
                    "brand": brand_name,
                    "normalized_reference": product.get("normalized_reference"),
                    "btu": str(product.get("capacity_btu")),
                    "clean_title": title,
                    "primary_image": product.get("primary_image"),
                    "local_image_path": product.get("local_image_path"),
                    "local_json_path": product.get("local_json_path"),
                    "tech": product.get("specs", {}).get("Technology"),
                    "mode": product.get("specs", {}).get("Mode"),
                    "smart": product.get("specs", {}).get("Smart"),
                    "color": product.get("specs", {}).get("Color"),
                    "energy_class": product.get("specs", {}).get("Energy_Class"),
                    "gas_type": product.get("specs", {}).get("Gas_Type"),
                    "dimensions": product.get("specs", {}).get("Dimensions"),
                    "weight": product.get("specs", {}).get("Weight"),
                    "noise_level": product.get("specs", {}).get("Noise_Level"),
                    "warranty": product.get("specs", {}).get("Warranty"),
                    "description": product.get("description")
                }

                # Generate a unique ID for this point
                point_id = str(uuid.uuid4())

                # Upsert to Qdrant
                vstore.add_climatiseur(
                    product_id=point_id,
                    brand=brand_name,
                    model_name=title,
                    embedding=embedding,
                    metadata=metadata
                )
                
                total_indexed += 1
                if total_indexed % 10 == 0:
                    print(f"  Progress: {total_indexed} products indexed...")

            except Exception as e:
                print(f"  [CRITICAL ERROR] Failed to index {product.get('clean_title')}: {e}")

    print(f"\n--- INDEXING COMPLETE ---")
    print(f"Successfully indexed {total_indexed} products into Qdrant collection 'climatiseurs'.")

if __name__ == "__main__":
    main()
