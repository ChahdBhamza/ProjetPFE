import os
import uvicorn
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from pathlib import Path

# Import services
from app.services.clip_embedder import CLIPEmbedder
from app.services.vector_store import VectorStore
from app.services.vision_rag_service import VisionRAGService
from app.api.endpoints import router as api_router, init_services

# 1. Initialize FastAPI
app = FastAPI(title="DetectionAppPFE - Visual RAG API")

# Define global services placeholders
embedder = None
vector_store = None
vision_service = None

# 3. Include API routes
app.include_router(api_router)

# 4. Startup Logic
@app.on_event("startup")
async def startup_event():
    global embedder, vector_store, vision_service
    
    print("[Main] Starting services...")
    embedder = CLIPEmbedder()
    vector_store = VectorStore(path="qdrant_db")
    vision_service = VisionRAGService()
    
    # Inject into the router
    init_services(embedder, vector_store, vision_service)
    
    # Build the database if empty
    base_dir = Path("../dataequipment/climatiseurs")
    
    # Check if we already have records (to avoid redundant indexing)
    existing_points = vector_store.client.count(collection_name=vector_store.collection_name).count
    if existing_points > 0:
        print(f"[Startup] DB already contains {existing_points} records. Skipping re-indexing.")
        return

    if not base_dir.exists():
        print(f"[Startup] Warning: Data folder '{base_dir}' not found.")
        return

    print("[Startup] --- BUILDING LOCAL VECTOR DATABASE ---")
    image_paths = list(base_dir.rglob("images/*.jpg")) + list(base_dir.rglob("images/*.png"))
    
    indexed_count = 0
    for img_path in image_paths:
        try:
            # Generate embedding
            embedding = embedder.embed_image(img_path)
            if embedding is None: continue
            
            # Load metadata (Prioritize JSON if available)
            json_path = img_path.parent.parent / "text" / (img_path.stem + ".json")
            txt_path = img_path.parent.parent / "text" / (img_path.stem + ".txt")
            
            payload = {
                "filename": img_path.name,
                "brand": img_path.parent.parent.name
            }

            if json_path.exists():
                with open(json_path, "r", encoding="utf-8") as f:
                    enriched_data = json.load(f)
                    payload.update(enriched_data)
            
            if txt_path.exists() and "specs" not in payload:
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
        except Exception as e:
            pass

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
