from qdrant_client import QdrantClient, models
from qdrant_client.models import VectorParams, Distance, PointStruct
import os
from pathlib import Path

class VectorStore:
    def __init__(self, collection_name="climatiseurs_v2", path="qdrant_db"):
        """Initialize Qdrant Vector Store"""
        self.collection_name = collection_name
        # Ensure we always use the same database folder in backend/qdrant_db
        base_dir = Path(__file__).parent.parent.parent
        db_path = str(base_dir / "backend" / "qdrant_db")
        self.client = QdrantClient(path=db_path)
        
        # Create collection if it doesn't exist
        try:
            self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(size=512, distance=Distance.COSINE),
            )
            print(f"Collection '{collection_name}' created")
        except Exception:
            # Collection likely already exists
            print(f"Using existing collection '{collection_name}'")

    def add_climatiseur(self, product_id, brand, model_name, embedding, metadata):
        """Add a single product to the vector database"""
        self.client.upsert(
            collection_name=self.collection_name,
            points=[
                PointStruct(
                    id=product_id,
                    vector=embedding.tolist() if hasattr(embedding, 'tolist') else embedding,
                    payload={
                        "brand": brand,
                        "model_name": model_name,
                        **metadata
                    }
                )
            ]
        )

    def search(self, query_vector, limit=3, brand_filter=None, btu_filter=None):
        """Search for similar products with optional technical filtering"""
        query_filter = None
        conditions = []
        
        if brand_filter and brand_filter != "Unknown":
            conditions.append(models.FieldCondition(
                key="brand",
                match=models.MatchValue(value=brand_filter)
            ))
            
        if btu_filter and btu_filter != "Unknown":
            conditions.append(models.FieldCondition(
                key="btu",
                match=models.MatchValue(value=btu_filter)
            ))
            
        if conditions:
            query_filter = models.Filter(must=conditions)
            print(f"[VectorStore] Searching with filters: {brand_filter} | {btu_filter}")

        return self.client.query_points(
            collection_name=self.collection_name,
            query=query_vector.tolist() if hasattr(query_vector, 'tolist') else query_vector,
            query_filter=query_filter,
            limit=limit
        ).points

    def persist(self):
        """Qdrant local storage persists automatically on every upsert, but we can keep this for compatibility"""
        pass

# Factory function
def get_vector_store():
    return VectorStore()
