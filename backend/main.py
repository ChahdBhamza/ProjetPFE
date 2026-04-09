import os
import json
import uvicorn
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from pathlib import Path

# Import services
from app.services.clip_embedder import CLIPEmbedder
from app.services.vector_store import VectorStore
from app.services.vision_rag_service import VisionRAGService
from app.services.web_search_service import WebSearchService
from app.api.endpoints import router as api_router, init_services

# 1. Initialize FastAPI
app = FastAPI(title="DetectionAppPFE - Visual RAG API")

# Register API endpoints
app.include_router(api_router, prefix="/api")

# Define global services placeholders
embedder = None
vector_store = None
vision_service = None
web_service = None

# ... logic ...

# 4. Startup Logic
@app.on_event("startup")
async def startup_event():
    global embedder, vector_store, vision_service, web_service
    
    print("[Main] Starting services...")
    embedder = CLIPEmbedder()
    vector_store = VectorStore(path="qdrant_db")
    vision_service = VisionRAGService()
    web_service = WebSearchService()
    
    # Inject into the router
    init_services(embedder, vector_store, vision_service, web_service)
    
    # Build the database if empty
    base_dir = Path("../dataequipment/climatiseurs").resolve()
    print(f"[Startup] Looking for data in: {base_dir}")
    
    if not base_dir.exists():
        print(f"[Startup] ERROR: Data folder '{base_dir}' NOT FOUND.")
        return

    # Check if we already have records
    try:
        existing_points = vector_store.client.count(collection_name=vector_store.collection_name).count
        if existing_points > 0:
            print(f"[Startup] DB already contains {existing_points} records. Skipping re-indexing.")
            return
    except Exception as e:
        print(f"[Startup] Collection doesn't exist yet or error: {e}")

    print("[Startup] --- BUILDING LOCAL VECTOR DATABASE ---")
    image_paths = list(base_dir.rglob("*.jpg")) + list(base_dir.rglob("*.png"))
    print(f"[Startup] Found {len(image_paths)} image files to index.")
    
    indexed_count = 0
    for img_path in image_paths:
        try:
            # Generate embedding
            embedding = embedder.embed_image(img_path)
            if embedding is None:
                print(f"  [Skip] CLIP failed for: {img_path.name}")
                continue
            
            # Load metadata (Prioritize JSON if available)
            json_path = img_path.parent.parent / "text" / (img_path.stem + ".json")
            txt_path = img_path.parent.parent / "text" / (img_path.stem + ".txt")
            
            payload = {
                "filename": img_path.name,
                "brand": img_path.parent.parent.name
            }

            if json_path.exists():
                with open(json_path, "r", encoding="utf-8") as f:
                    payload.update(json.load(f))
            elif txt_path.exists():
                with open(txt_path, "r", encoding="utf-8") as f:
                    payload["specs"] = f.read()

            # Add to store
            vector_store.add_climatiseur(
                product_id=indexed_count + 1,
                brand=payload["brand"],
                model_name=img_path.name,
                embedding=embedding,
                metadata=payload
            )
            indexed_count += 1
            if indexed_count % 10 == 0:
                print(f"  [Progress] Indexed {indexed_count}/133...")
                
        except Exception as e:
            print(f"  [Error] Failed to index {img_path.name}: {e}")

    print(f"[Startup] --- SUCCESS: {indexed_count} items indexed ---")

# 5. Dashboard / Demo Route
@app.get("/", response_class=HTMLResponse)
async def serve_dashboard():
    dashboard_path = Path("demo_frontend.html")
    if dashboard_path.exists():
        with open(dashboard_path, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>demo_frontend.html not found</h1>"

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=False)
