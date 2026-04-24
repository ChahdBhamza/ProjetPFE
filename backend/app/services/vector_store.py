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
            
            # Configure Full-Text Search Indexes for better RAG accuracy
            self.client.create_payload_index(
                collection_name=self.collection_name,
                field_name="clean_title",
                field_schema=models.TextIndexParams(
                    type="text",
                    tokenizer=models.TokenizerType.WORD,
                    min_token_len=2,
                    max_token_len=15,
                    lowercase=True,
                )
            )
            self.client.create_payload_index(
                collection_name=self.collection_name,
                field_name="normalized_reference",
                field_schema=models.TextIndexParams(
                    type="text",
                    tokenizer=models.TokenizerType.WORD,
                    min_token_len=2,
                    max_token_len=15,
                    lowercase=True,
                )
            )
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

    def keyword_search(self, text_query, limit=3):
        """Perform exact keyword matching on titles and references"""
        return self.client.query_points(
            collection_name=self.collection_name,
            query=None, # No vector search, just filtering
            query_filter=models.Filter(
                should=[
                    models.FieldCondition(
                        key="clean_title",
                        match=models.MatchText(text=text_query)
                    ),
                    models.FieldCondition(
                        key="normalized_reference",
                        match=models.MatchText(text=text_query)
                    )
                ]
            ),
            limit=limit
        ).points

    def hybrid_search(self, query_vector, text_query, limit=3, brand_filter=None, btu_filter=None):
        """Combine Vector Search and Manual Keyword Reranking for maximum RAG accuracy"""
        # 1. Get a larger pool of vector results (e.g., top 20)
        vector_results = self.search(query_vector, limit=20, brand_filter=brand_filter, btu_filter=btu_filter)
        
        if not text_query:
            return vector_results[:limit]
            
        # 2. Manual Reranking based on text_query (OCR extracted text)
        # We split the OCR text into keywords to find matches
        keywords = [k.lower() for k in text_query.replace("\n", " ").split() if len(k) > 2]
        
        scored_results = []
        for res in vector_results:
            payload = res.payload
            title = payload.get("clean_title", "").lower()
            ref = payload.get("normalized_reference", "").lower()
            desc = payload.get("description", "").lower()
            
            # Count how many keywords match
            match_count = 0
            for kw in keywords:
                if kw in title or kw in ref or kw in desc:
                    match_count += 1
            
            # Boost score based on matches
            # A single keyword match is a strong signal for AC models
            boost = match_count * 0.5
            res.score = res.score + boost
            scored_results.append(res)
            
        # 3. Sort and return top N
        scored_results.sort(key=lambda x: x.score, reverse=True)
        return scored_results[:limit]

    def persist(self):
        """Qdrant local storage persists automatically on every upsert, but we can keep this for compatibility"""
        pass

# Factory function
def get_vector_store():
    return VectorStore()
