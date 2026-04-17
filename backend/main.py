import os
import json
import uvicorn
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, FileResponse
from pathlib import Path

# Import services
from app.services.clip_embedder import CLIPEmbedder
from app.services.vector_store import VectorStore
from app.services.vision_rag_service import VisionRAGService
from app.services.web_search_service import WebSearchService
from app.services.local_vlm_service import LocalVLMService
from app.services.ocr_service import OCRService
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
local_vlm = None
ocr_service = None

# ... logic ...

# 4. Startup Logic
@app.on_event("startup")
async def startup_event():
    global embedder, vector_store, vision_service, web_service, local_vlm, ocr_service
    
    print("[Main] Starting services...")
    embedder = CLIPEmbedder()
    vector_store = VectorStore(path="qdrant_db")
    vision_service = VisionRAGService()
    web_service = WebSearchService()
    
    # Optional Local VLM
    try:
        local_vlm = LocalVLMService(model_name="qwen2.5vl:3b")
        print("[Main] Local VLM (Qwen2.5-VL) initialized.")
    except Exception as e:
        print(f"[Main] Local VLM skip: {e}")
        local_vlm = None

    # Dedicated OCR Service
    try:
        ocr_service = OCRService(model_name="qwen2.5vl:3b")
        print("[Main] OCR Service (Direct Alphanumeric) initialized.")
    except Exception as e:
        print(f"[Main] OCR Init failed: {e}")
        ocr_service = None
    
    # Inject into the router
    init_services(embedder, vector_store, vision_service, web_service, local_vlm, ocr_service)
    
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
@app.get("/")
async def read_root():
    return FileResponse("demo_frontend.html")

@app.get("/edge")
async def read_edge():
    return FileResponse("edge_ai_demo.html")

@app.get("/ocr")
async def read_ocr():
    return FileResponse("ocr_test_ui.html")

@app.get("/classic-ocr")
async def read_classic_ocr():
    return FileResponse("classic_ocr_test_ui.html")

@app.get("/hybrid-ocr")
async def read_hybrid_ocr():
    return FileResponse("hybrid_ocr_test_ui.html")

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=False)
