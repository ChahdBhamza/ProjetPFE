from qdrant_client import QdrantClient
from qdrant_client.models import VectorParams, Distance, PointStruct
import os
from pathlib import Path

class VectorStore:
    def __init__(self, collection_name="climatiseurs", path="qdrant_db"):
        """Initialize Qdrant Vector Store"""
        self.collection_name = collection_name
        # Use a local path for persistence instead of just :memory:
        self.client = QdrantClient(path=path)
        
        # Create collection if it doesn't exist
        try:
            self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(size=512, distance=Distance.COSINE),
            )
            print(f"✓ Collection '{collection_name}' created")
        except Exception:
            # Collection likely already exists
            print(f"✓ Using existing collection '{collection_name}'")

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

    def search(self, query_vector, limit=3):
        """Search for similar products"""
        return self.client.query_points(
            collection_name=self.collection_name,
            query=query_vector.tolist() if hasattr(query_vector, 'tolist') else query_vector,
            limit=limit
        ).points

    def persist(self):
        """Qdrant local storage persists automatically on every upsert, but we can keep this for compatibility"""
        pass

# Factory function
def get_vector_store():
    return VectorStore()
