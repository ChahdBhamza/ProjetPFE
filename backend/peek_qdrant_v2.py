from qdrant_client import QdrantClient

def peek():
    qdrant_path = "qdrant_db"
    collection_name = "climatiseurs_v2" # WE ARE LOOKING AT V2 NOW
    
    client = QdrantClient(path=qdrant_path)
    
    print(f"--- PEEKING INTO QDRANT ('{collection_name}') ---")
    
    points, next_page = client.scroll(
        collection_name=collection_name,
        limit=5,
        with_payload=True,
        with_vectors=False
    )
    
    if not points:
        print("The database is empty!")
        return

    for p in points:
        payload = p.payload
        print(f"ID: {p.id}")
        print(f"  Product: {payload.get('clean_title')}")
        print(f"  Brand  : {payload.get('brand')}")
        print(f"  Ref    : {payload.get('normalized_reference')}")
        print(f"  BTU    : {payload.get('btu')}")
        print("-" * 30)

    total_count = client.get_collection(collection_name).points_count
    print(f"\nTotal Points in Database: {total_count}")

if __name__ == "__main__":
    peek()
