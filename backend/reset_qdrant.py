from qdrant_client import QdrantClient
import os

def reset_database():
    # Use the same path as your main app
    qdrant_path = "qdrant_db"
    collection_name = "climatiseurs"
    
    print(f"Connecting to Qdrant at: {qdrant_path}...")
    client = QdrantClient(path=qdrant_path)
    
    try:
        print(f"Deleting collection '{collection_name}'...")
        client.delete_collection(collection_name=collection_name)
        print("Success! Database has been cleared.")
    except Exception as e:
        print(f"Note: Could not delete collection (it might not exist yet): {e}")

if __name__ == "__main__":
    reset_database()
