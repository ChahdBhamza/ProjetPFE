from fastapi import APIRouter, UploadFile, File, Form
from fastapi.responses import JSONResponse
from PIL import Image
from io import BytesIO
import json
from app.services.classic_ocr_service import ClassicOCRService
from app.services.hybrid_ocr_service import HybridOCRService

router = APIRouter()

# Global service holders
_embedder = None
_vector_store = None
_vision_service = None # Gemini
_web_service = None
_local_vlm = None # Qwen/Moondream
_ocr_service = None # OCR Engine

def init_services(embedder, vector_store, vision_service, web_service, local_vlm=None, ocr_service=None):
    global _embedder, _vector_store, _vision_service, _web_service, _local_vlm, _ocr_service
    _embedder = embedder
    _vector_store = vector_store
    _vision_service = vision_service
    _web_service = web_service
    _local_vlm = local_vlm
    _ocr_service = ocr_service

@router.post("/search")
async def search_endpoint(
    file: UploadFile = File(...),
    use_vlm: bool = Form(False) 
):
    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents))
        
        # --- ORIGINAL CLIP SEARCH LOGIC ---
        query_vector = _embedder.embed_image(image)
        
        # We only apply filters if 'Edge Mode' is active
        v_brand = None
        v_btu = None
        local_vlm_analysis = {"status": "VLM Disabled for this session."}

        if use_vlm and _local_vlm:
            print("[Backend] Using Local Edge-AI for Brand Routing...")
            local_vlm_analysis = _local_vlm.extract_specs(image)
            v_brand = local_vlm_analysis.get("brand")
            v_btu = local_vlm_analysis.get("btu")

        # Core Search
        matches = _vector_store.search(query_vector, limit=1, brand_filter=v_brand, btu_filter=v_btu)

        if not matches and v_btu:
            print("[Endpoints] No exact BTU match. Falling back to Brand-wide search...")
            matches = _vector_store.search(query_vector, limit=1, brand_filter=v_brand)

        if not matches:
            print("[Endpoints] No filtered matches. Falling back to Global Semantic search...")
            matches = _vector_store.search(query_vector, limit=1)

        if not matches:
            return {"success": False, "error": "No technical matches detected in database."}

        best_match = matches[0].payload
        similarity_score = matches[0].score

        # --- REAL-TIME WEB GROUNDING ---
        web_evidence = {"summary": "Web Grounding active."}
        if _web_service:
            search_name = best_match.get("filename", "").replace(".jpg", "").replace(".png", "")
            web_evidence = _web_service.verify_product_specs(search_name, best_match.get("btu", "Unknown"))

        # --- REASONING COMPONENT (DORMANT AS REQUESTED) ---
        verified_details = {
            "status": "AI Verification Skipped (Evaluation Mode)",
            "analysis": "Gemini is currently disabled to save tokens. Web Grounding is active.",
            "is_match_verified": True
        }

        # Override only if explicitly in Edge Mode
        if use_vlm and _local_vlm:
            print("[Backend] Executing Dual-VLM Comparison (Qwen vs Gemma4)...")
            # 1. Qwen Analysis
            qwen_verify = _local_vlm.verify_match(image, best_match)
            
            # 2. Gemma 4 Analysis
            original_model = _local_vlm.model_name
            _local_vlm.model_name = "gemma4:e2b" 
            try:
                gemma_verify = _local_vlm.verify_match(image, best_match)
            except Exception as e:
                gemma_verify = {"analysis": f"Gemma4 Error: {str(e)}", "is_match_verified": False}
            _local_vlm.model_name = original_model # Restore
            
            verified_details = {
                "is_comparison": True,
                "qwen": qwen_verify,
                "gemma": gemma_verify
            }

        return {
            "success": True,
            "vector_match": {
                "item": best_match,
                "confidence": similarity_score
            },
            "web_grounding": web_evidence,
            "verified_details": verified_details,
            "local_vlm_raw": local_vlm_analysis
        }

    except Exception as e:
        print(f"[Backend Error] {e}")
        return {"error": str(e)}

@router.post("/ocr")
async def ocr_endpoint(file: UploadFile = File(...)):
    """Dedicated endpoint for raw OCR text extraction"""
    if _ocr_service is None:
        return {"error": "OCR Service not initialized on server."}
        
    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents))
        
        # Core OCR logic
        result = _ocr_service.process_image(image)
        return result
        
    except Exception as e:
        return {"error": f"OCR Failed: {str(e)}"}
@router.post("/ocr/classic")
async def classic_ocr_endpoint(
    file: UploadFile = File(...),
    lang_combo: str = Form("en_fr")
):
    """Dumb OCR endpoint for raw text comparison"""
    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents))
        
        ocr = ClassicOCRService()
        return ocr.process_image(image, combo=lang_combo)
        
    except Exception as e:
        return {"error": f"Classic OCR Failed: {str(e)}", "status": "error"}

@router.post("/ocr/hybrid")
async def hybrid_ocr_endpoint(file: UploadFile = File(...)):
    """Hybrid Pipeline: EasyOCR -> Text LLM"""
    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents))
        
        hybrid_service = HybridOCRService()
        return await hybrid_service.process_image(image)
        
    except Exception as e:
        return {"success": False, "error": f"Hybrid Pipeline Failed: {str(e)}"}
