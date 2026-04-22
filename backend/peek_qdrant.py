from qdrant_client import QdrantClient

def peek():
    qdrant_path = "qdrant_db"
    collection_name = "climatiseurs"
    
    client = QdrantClient(path=qdrant_path)
    
    # Scroll through the points to see what's inside
    print(f"--- PEEKING INTO QDRANT ('{collection_name}') ---")
    
    points, next_page = client.scroll(
        collection_name=collection_name,
        limit=10,
        with_payload=True,
        with_vectors=False # Don't show the huge list of numbers
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
