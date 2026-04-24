from qdrant_client import QdrantClient
from pathlib import Path

def reset_database():
    # Base directory for the database
    base_dir = Path(r"c:\Users\chahd\Desktop\DetectionAppPFE\backend")
    db_path = str(base_dir / "backend" / "qdrant_db")
    collection_name = "climatiseurs_v2"
    
    print(f"Connecting to Qdrant at: {db_path}...")
    client = QdrantClient(path=db_path)
    
    try:
        print(f"Deleting collection '{collection_name}'...")
        client.delete_collection(collection_name=collection_name)
        print("Success! Collection 'climatiseurs_v2' has been cleared.")
    except Exception as e:
        print(f"Note: Could not delete collection: {e}")

if __name__ == "__main__":
    reset_database()
