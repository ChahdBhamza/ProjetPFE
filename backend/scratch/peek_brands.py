from qdrant_client import QdrantClient
from pathlib import Path

def peek():
    db_path = str(Path("qdrant_db").absolute())
    print(f"Connecting to: {db_path}")
    client = QdrantClient(path=db_path)
    
    try:
        # Check climatiseurs collection
        results = client.scroll(
            collection_name="climatiseurs",
            limit=20,
            with_payload=True
        )[0]
        
        print("\n--- DATABASE ENTRIES ---")
        for p in results:
            brand = p.payload.get("brand")
            model = p.payload.get("model_name") or p.payload.get("model")
            print(f"| BRAND: '{brand}' | MODEL: {model}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    peek()
