import os
import json
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import HTMLResponse
from google import genai
from google.genai import types
from qdrant_client import QdrantClient
from qdrant_client.models import VectorParams, Distance, PointStruct
from PIL import Image
from io import BytesIO
import uvicorn
import time
import random
from dotenv import load_dotenv

from app.services.clip_embedder import CLIPEmbedder

load_dotenv()

app = FastAPI(title="Image RAG Pipeline Demo")

# Initialize CLIP via the modular Embedder
print("Initializing CLIP Embedder...")
try:
    embedder = CLIPEmbedder()
except Exception as e:
    print(f"Failed to load CLIP: {e}")
    embedder = None


# Step 2: Initialize Vector DB (Qdrant in-memory for demo)
print("Initializing Qdrant...")
try:
    qdrant = QdrantClient(":memory:")
    qdrant.create_collection(
        collection_name="images",
        vectors_config=VectorParams(size=512, distance=Distance.COSINE),
    )
except Exception as e:
    print(f"Failed to init Qdrant: {e}")
    qant = None

# Gemini setup
try:
    gemini_client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY", "YOUR_API_KEY_HERE"))
except Exception as e:
    print(f"Failed to init GenAI client: {e}")
    gemini_client = None

SAMPLE_DB = []

@app.get("/", response_class=HTMLResponse)
async def serve_frontend():
    # Note: Ensure demo_frontend.html exists in the same directory
    try:
        with open("demo_frontend.html", "r", encoding="utf-8") as f:
            html_content = f.read()
    except FileNotFoundError:
        return HTMLResponse(content="<h1>demo_frontend.html not found</h1>", status_code=404)
        
    return HTMLResponse(
        content=html_content, 
        status_code=200,
        headers={"Cache-Control": "no-cache, no-store, must-revalidate", "Pragma": "no-cache", "Expires": "0"}
    )

from pathlib import Path

@app.on_event("startup")
async def startup_event():
    """Automatically build the Qdrant database using local equipment folder on server startup"""
    if embedder is None:
        print("Warning: Embedder not loaded. DB indexing skipped.")
        return

    # Updated to point to dataequipment in the root
    base_dir = Path("../dataequipment/climatiseurs")
    if not base_dir.exists():
        print(f"Warning: Directory '{base_dir}' not found. DB indexing skipped.")
        return

    print("--- BUILDING LOCAL VECTOR DATABASE ---")
    image_paths = list(base_dir.rglob("images/*.jpg")) + list(base_dir.rglob("images/*.png"))
    
    points = []
    
    for img_path in image_paths:
        try:
            embedding = embedder.embed_image(img_path)
            if embedding is None:
                continue
            
            # Match the text details from the processor structure
            txt_path = img_path.parent.parent / "text" / (img_path.stem + ".txt")
            specs = "No specifications available."
            if txt_path.exists():
                with open(txt_path, "r", encoding="utf-8") as f:
                    specs = f.read()

            point_id = len(SAMPLE_DB) + 1
            metadata = {
                "id": point_id,
                "name": img_path.name,
                "specs": specs,
                "brand": img_path.parent.parent.name
            }
            
            points.append(PointStruct(id=point_id, vector=embedding.tolist(), payload=metadata))
            SAMPLE_DB.append(metadata)
        except Exception as e:
            # print(f"Error indexing {img_path}: {e}")
            pass

    if points and qdrant:
        qdrant.upsert(collection_name="images", points=points)
    
    print(f"--- SUCCESS: {len(SAMPLE_DB)} items indexed into Qdrant Vector DB ---")
    print("Ready to accept queries from the UI!")


@app.post("/api/step3_search")
async def step3_search(file: UploadFile = File(...)):
    """Step 3 & 4: Embed query image via explicit CLIP, cosine search, RAG"""
    if embedder is None:
        return {"error": "CLIP Embedder failed to load during startup."}

    contents = await file.read()
    image = Image.open(BytesIO(contents))
    
    search_embedding = embedder.embed_image(image)
    if search_embedding is None:
        return {"error": "Failed to generate embedding for the uploaded image."}
    
    response_qdrant = qdrant.query_points(
        collection_name="images",
        query=search_embedding.tolist(),
        limit=1
    )
    search_result = response_qdrant.points
    
    if not search_result:
         return {"error": "No matches found in DB."}
         
    best_match = search_result[0].payload
    similarity_score = search_result[0].score
    
    prompt = f"""
    You are an expert AC visual inspector with access to Google Search.
    A user has uploaded a photo of an AC equipment unit (attached).
    
    Part 1: Pure Visual Extraction
    Look closely at the pixels of the image. Extract brand logo, numbers, energy labels, etc.
    
    Part 2: Database Cross-Reference
    {json.dumps(best_match, indent=2, ensure_ascii=False)}
    (Cosine similarity score: {similarity_score})
    
    Part 3: Search Grounding
    Use Google Search to look up official specs for this unit.
    
    Return ONLY valid JSON.
    """
    
    try:
        config = types.GenerateContentConfig(
            tools=[{"google_search": {}}]
        )
        
        max_retries = 3
        retry_delay = 5
        
        for attempt in range(max_retries):
            try:
                # Use gemini-2.0-flash (most stable for grounding)
                response = gemini_client.models.generate_content(
                    model='gemini-2.0-flash',
                    contents=[prompt, image],
                    config=config
                )
                break
            except Exception as e:
                error_msg = str(e).lower()
                if ("503" in error_msg or "unavailable" in error_msg or "429" in error_msg) and attempt < max_retries - 1:
                    wait_time = retry_delay + random.uniform(0, 1)
                    print(f"Retrying... {attempt+1}")
                    time.sleep(wait_time)
                    retry_delay *= 2
                else:
                    raise e
        
        json_text = response.text.replace('```json', '').replace('```', '').strip()
        final_json = json.loads(json_text)
        
        sources = []
        try:
            if response.candidates and response.candidates[0].grounding_metadata:
                metadata = response.candidates[0].grounding_metadata
                if metadata.grounding_chunks:
                    for chunk in metadata.grounding_chunks:
                        if chunk.web:
                            sources.append({"title": chunk.web.title, "url": chunk.web.uri})
        except:
             pass
             
        final_json["verification_sources"] = sources
    except Exception as e:
        final_json = {"error": "Failed to parse JSON", "raw_error": str(e), "raw_text": response.text if 'response' in locals() else "None"}
    
    return {
        "step_3": "Search embedding completed.",
        "step_4": "Cosine Similarity Search and LLM RAG JSON generation completed.",
        "retrieved_item": best_match,
        "cosine_similarity": similarity_score,
        "gemini_json_response": final_json
    }

if __name__ == "__main__":
    print("Starting visual RAG demo server...")
    uvicorn.run(app, host="127.0.0.1", port=8000)
