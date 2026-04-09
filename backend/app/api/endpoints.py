from fastapi import APIRouter, File, UploadFile, HTTPException
from PIL import Image
from io import BytesIO
from app.services.clip_embedder import CLIPEmbedder
from app.services.vector_store import VectorStore
from app.services.vision_rag_service import VisionRAGService

router = APIRouter(prefix="/api")

# Services (initialized in main.py or a dependency injection system)
# For simplicity in this refactor, we can assume they are accessible
# or pass them as app state.
embedder = None
vector_store = None
vision_service = None

def init_services(e, v, vr):
    global embedder, vector_store, vision_service
    embedder = e
    vector_store = v
    vision_service = vr

@router.post("/search")
async def search_ac(file: UploadFile = File(...)):
    """Unified endpoint for AC Identification & Verification"""
    if not embedder or not vector_store or not vision_service:
        raise HTTPException(status_code=503, detail="Services not initialized")

    try:
        # Load and process image
        contents = await file.read()
        image = Image.open(BytesIO(contents))
        
        # 1. Generate Query Embedding
        query_vector = embedder.embed_image(image)
        if query_vector is None:
            return {"error": "Failed to generate visual features for the image."}
        
        # 2. Search Vector Database
        matches = vector_store.search(query_vector, limit=1)
        if not matches:
             return {"error": "No matching equipment found in the database."}
             
        best_match = matches[0].payload
        similarity_score = matches[0].score
        
        # 3. Perform AI Verification (Gemini)
        # Rewind image stream for Gemini if needed (using the PIL object)
        gemini_result = vision_service.verify_ac_unit(image, best_match, similarity_score)
        
        return {
            "success": True,
            "vector_match": {
                "item": best_match,
                "confidence": similarity_score
            },
            "verified_details": gemini_result
        }
    except Exception as e:
        return {"error": str(e)}
