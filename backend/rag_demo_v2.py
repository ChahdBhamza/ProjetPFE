import os
import sys
from pathlib import Path
from PIL import Image

# Ensure we are in the backend directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Add the current directory to sys.path for app imports
sys.path.append(os.getcwd())

from app.services.data_loader import DataLoader
from app.services.vector_store import VectorStore
from app.services.vision_rag_service import VisionRAGService

def main():
    print("="*60)
    print("FORENSIC RAG DEMO - V2 (ENHANCED INDEXING)")
    print("="*60)

    # 1. Setup a NEW Database folder as requested
    db_path_v2 = "qdrant_db_v2"
    collection_name = "climatiseurs_forensic"
    
    print(f"[SETUP] Initializing New Database at: {db_path_v2}")
    
    # Custom VectorStore instance pointing to the new DB
    v_store_v2 = VectorStore(collection_name=collection_name, path=db_path_v2)
    
    # 2. Initialize DataLoader with the new VectorStore
    loader = DataLoader(data_root="../dataequipment")
    loader.vector_store = v_store_v2 # Inject the new store
    
    # 3. Start Forensic Indexing (Crop + Enhance)
    print("\n[PHASE 1] STARTING FORENSIC INDEXING...")
    print("Note: This will CROP and ENHANCE every database image to match user camera conditions.")
    
    # We index the dataset (you can limit this if you want it faster, but let's go!)
    count = loader.index_dataset(use_yolo_crop=True)
    
    print(f"\n[OK] Indexing Complete! {count} items moved to the forensic knowledge base.")

    # 4. Simulation of a Search
    print("\n[PHASE 2] RUNNING SEARCH SIMULATION...")
    
    vision_service = VisionRAGService()
    
    # Find a sample image to "search" for
    sample_img_path = Path("../dataequipment/climatiseurs/Gree/images/Climatiseur Gree CL12AQCXB-CF Tropicalisé 12000 BTU Chaud Froid - Blanc.jpg")
    
    if not sample_img_path.exists():
        print("[WARNING] Sample image not found for simulation. Skipping search test.")
        return

    print(f"[STATUS] Testing with sample: {sample_img_path.name}")
    
    # A. Process the "Query" image (Crop + Enhance)
    raw_query_img = Image.open(sample_img_path).convert("RGB")
    cropped_query = loader.yolo_service.detect_and_crop(raw_query_img)
    enhanced_query = loader.yolo_service.enhance_for_ocr(cropped_query)
    
    # B. Generate Query Vector
    query_vector = loader.embedder.embed_image(enhanced_query)
    
    # C. Search in the NEW Forensic Collection
    results = v_store_v2.search(query_vector, limit=3)
    
    print("\n[RESULTS] SEARCH RESULTS (Forensic vs Forensic):")
    for i, res in enumerate(results):
        payload = res.payload
        print(f"{i+1}. {payload.get('brand')} - {payload.get('model_name')} (Score: {res.score:.4f})")
        print(f"   BTU: {payload.get('btu')} | Ref: {payload.get('reference')}")

    print("\n" + "="*60)
    print("Demo logic complete. You now have a high-accuracy forensic database in 'qdrant_db_v2'.")
    print("="*60)

if __name__ == "__main__":
    main()
