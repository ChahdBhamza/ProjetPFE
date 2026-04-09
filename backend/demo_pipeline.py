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
    print(f"Failed to load CLIP: {type(e).__name__}: {str(e)}")
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
    qdrant = None

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
    
    # Improved Prompt for better JSON stability
    prompt = f"""
    Extract technical AC specifications. Return ONLY a JSON object. 
    NO preamble. NO conversational text.

    Input Context (Retrieved Match):
    {json.dumps(best_match, indent=2, ensure_ascii=False)}
    (Visual similarity score: {similarity_score})

    Required JSON structure:
    {{
      "brand": "string",
      "model_identifier": "string",
      "btu_rating": "string",
      "energy_class": "string",
      "analysis": "2-3 sentences of visual reasoning",
      "is_match_verified": boolean
    }}
    """
    
    try:
        max_retries = 5
        retry_delay = 10 
        model_name = 'gemini-2.5-flash'
        
        config = types.GenerateContentConfig(
            tools=[{"google_search": {}}],
            max_output_tokens=1024,
            temperature=0.7
        )
        
        print(f"--- Using model: {model_name} ---")
        last_error = ""
        for attempt in range(max_retries):
            try:
                response = gemini_client.models.generate_content(
                    model=model_name,
                    contents=[prompt, image],
                    config=config
                )
                if not response or not response.text:
                    raise ValueError("Gemini returned an empty response.")

                # Robust JSON Extraction
                text = response.text
                if "```json" in text:
                    text = text.split("```json")[1].split("```")[0]
                elif "```" in text:
                    text = text.split("```")[1].split("```")[0]
                
                text = text.strip()
                final_json = json.loads(text)
                
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
                return {
                    "step_3": "Search embedding completed.",
                    "step_4": "Cosine Similarity Search and LLM RAG JSON generation completed.",
                    "retrieved_item": best_match,
                    "cosine_similarity": similarity_score,
                    "gemini_json_response": final_json
                }
            except Exception as e:
                error_msg = str(e).lower()
                last_error = str(e)
                if ("503" in error_msg or "unavailable" in error_msg or "429" in error_msg) and attempt < max_retries - 1:
                    wait_time = retry_delay + random.uniform(0, 1)
                    print(f"Retrying {model_name}... attempt {attempt+1}")
                    time.sleep(wait_time)
                    retry_delay *= 2
                else:
                    print(f"Model {model_name} failed: {e}")
        
        # If all models/retries failed
        final_json = {"error": "All models failed", "last_error": last_error}
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
