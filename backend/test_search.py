from app.services.clip_embedder import CLIPEmbedder
from app.services.vector_store import VectorStore
import json

def test_search():
    # 1. Setup
    embedder = CLIPEmbedder()
    vstore = VectorStore(collection_name="climatiseurs", path="qdrant_db")
    
    # 2. Search query (TEXT ONLY)
    query_text = "Climatiseur Gree Inverter 12000 BTU"
    print(f"\n--- Testing Search for: '{query_text}' ---")
    
    # Convert text to the SAME vector space as the images
    query_vector = embedder.embed_text(query_text)
    
    # 3. Ask Qdrant to find the closest IMAGE vectors
    results = vstore.search(query_vector, limit=3)
    
    # 4. Show results
    print("\nTop 3 Matches found in Qdrant:")
    for i, res in enumerate(results):
        payload = res.payload
        print(f"{i+1}. {payload['clean_title']} (Score: {res.score:.4f})")
        print(f"   Brand: {payload['brand']} | BTU: {payload.get('btu')}")
        print(f"   Image Path: {payload.get('local_image_path')}")
        print("-" * 30)

if __name__ == "__main__":
    test_search()
