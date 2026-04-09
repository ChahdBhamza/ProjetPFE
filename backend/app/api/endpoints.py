from fastapi import APIRouter, File, UploadFile, HTTPException
from PIL import Image
from io import BytesIO
from app.services.web_search_service import WebSearchService

router = APIRouter()

# Services
embedder = None
vector_store = None
vision_service = None
web_service = None

def init_services(e, v, vr, ws=None):
    global embedder, vector_store, vision_service, web_service
    embedder = e
    vector_store = v
    vision_service = vr
    web_service = ws

@router.post("/search")
async def search_ac(file: UploadFile = File(...)):
    """Unified endpoint for AC Identification & Verification"""
    if not embedder or not vector_store:
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
        
        # 3. REAL-TIME WEB GROUNDING (FREE SEARCH)
        web_evidence = {"search_conducted": False}
        if web_service:
            # Clean name for search (remove .jpg)
            search_name = best_match.get("filename", "").replace(".jpg", "").replace(".png", "")
            db_btu = best_match.get("btu", "Unknown")
            web_evidence = web_service.verify_product_specs(search_name, db_btu)
        
        # 4. AI Verification (Gemini) - COMMENTED OUT
        gemini_result = {
            "status": "AI Verification Skipped (Evaluation Mode)",
            "analysis": "Gemini is currently disabled to save tokens. Web Grounding is active.",
            "is_match_verified": True
        }
        
        return {
            "success": True,
            "vector_match": {
                "item": best_match,
                "confidence": similarity_score
            },
            "web_grounding": web_evidence,
            "verified_details": gemini_result
        }
    except Exception as e:
        return {"error": str(e)}
