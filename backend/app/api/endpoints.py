from fastapi import APIRouter, UploadFile, File, Form
from fastapi.responses import JSONResponse
from PIL import Image
from io import BytesIO
import json
from app.services.classic_ocr_service import ClassicOCRService
from app.services.hybrid_ocr_service import HybridOCRService
from app.database import mongo_db

router = APIRouter()

# Global service holders
_embedder = None
_vector_store = None
_vision_service = None # Gemini
_web_service = None
_local_vlm = None # Qwen/Moondream
_ocr_service = None # OCR Engine
_openai_service = None

def init_services(embedder, vector_store, vision_service, web_service, local_vlm=None, ocr_service=None, openai_service=None):
    global _embedder, _vector_store, _vision_service, _web_service, _local_vlm, _ocr_service, _openai_service
    _embedder = embedder
    _vector_store = vector_store
    _vision_service = vision_service
    _web_service = web_service
    _local_vlm = local_vlm
    _ocr_service = ocr_service
    _openai_service = openai_service

def normalize_btu(btu_str):
    """Normalize '12' or '12k' to '12000' for reliable DB filtering"""
    if not btu_str or btu_str == "null" or btu_str == "None": 
        return None
    import re
    # Extract numbers
    nums = re.findall(r'\d+', str(btu_str))
    if not nums: return None
    val = int(nums[0])
    # If they said '12' or '18', convert to '12000'
    if val in [9, 12, 18, 24, 30, 36, 48, 60]:
        return str(val * 1000)
    # If they said '12000', return as is
    if val >= 7000:
        return str(val)
    return str(val)

@router.post("/search")
async def search_endpoint(
    file: UploadFile = File(...),
    use_vlm: bool = Form(False),
    use_openai: bool = Form(False) 
):
    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents))
        
        # 2. Embed the image
        query_vector = _embedder.embed_image(image)
        
        # 3. Apply AI Routing / Pre-filtering (Pure VLM Mode)
        v_brand = None
        v_btu = None
        local_vlm_analysis = {"status": "AI Pre-filtering Disabled"}
        ocr_text = "N/A (VLM-Only Mode)"

        # OPTION A: Enhanced GPT-4o Pre-filtering (High Accuracy)
        if use_openai and _openai_service:
            print("[Endpoints] Using GPT-4o for Pre-Search routing (Pure VLM)...")
            openai_prediction = _openai_service.identify_from_raw_image(contents)
            v_brand = openai_prediction.get("brand")
            v_btu = normalize_btu(openai_prediction.get("btu"))
            local_vlm_analysis = openai_prediction 
            print(f"[Endpoints] GPT-4o Predicted: Brand={v_brand}, BTU={v_btu}")
            print(f"[DEBUG] Raw OpenAI Perception: {json.dumps(openai_prediction, indent=2)}")

        # OPTION B: Gemini Pre-filtering (Google AI)
        elif not use_openai and not use_vlm and _vision_service:
            print("[Endpoints] Using Gemini for Pre-Search routing...")
            gemini_prediction = _vision_service.identify_from_raw_image(contents)
            v_brand = gemini_prediction.get("brand")
            v_btu = normalize_btu(gemini_prediction.get("btu"))
            local_vlm_analysis = gemini_prediction
            print(f"[Endpoints] Gemini Predicted: Brand={v_brand}, BTU={v_btu}")
            print(f"[DEBUG] Raw Gemini Perception: {json.dumps(gemini_prediction, indent=2)}")

        # OPTION C: Local VLM Pre-filtering (Edge Mode)
        elif use_vlm and _local_vlm:
            print("[Backend] Using Local Edge-AI for Brand Routing...")
            local_vlm_analysis = _local_vlm.extract_specs(image)
            v_brand = local_vlm_analysis.get("brand")
            v_btu = normalize_btu(local_vlm_analysis.get("btu"))

        # 4. Core Hybrid Search (Semantic + Keywords + AI Filters)
        matches = _vector_store.hybrid_search(
            query_vector=query_vector, 
            text_query=ocr_text, 
            limit=1, 
            brand_filter=v_brand,
            btu_filter=v_btu
        )

        if not matches:
            print("[Endpoints] No matches found. Falling back to Global Semantic search...")
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

        # --- REASONING COMPONENT ---
        verified_details = {
            "status": "AI Verification Skipped",
            "analysis": "Verification model not selected.",
            "is_match_verified": True
        }

        # 1. Option: OpenAI Verification (High Accuracy)
        if use_openai and _openai_service:
            print("[Endpoints] Using OpenAI GPT-4o for verification...")
            verified_details = _openai_service.verify_ac_unit(contents, best_match, similarity_score)
        
        # 2. Option: Gemini Verification (Legacy/Alternative)
        elif not use_vlm and _vision_service:
            print("[Endpoints] Using Gemini for verification...")
            verified_details = _vision_service.verify_ac_unit(contents, best_match, similarity_score)

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
            "raw_ai_perception": local_vlm_analysis, # <-- WHAT GEMINI SEES RAW
            "vector_match": {
                "item": best_match,
                "confidence": similarity_score
            },
            "ocr_text": ocr_text,
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

@router.post("/inventory/save")
async def save_to_inventory(data: dict):
    """Save a detected item to the user's MongoDB inventory"""
    try:
        brand = data.get("brand", "Unknown")
        model = data.get("model", "Unknown")
        btu = data.get("btu")
        metadata = data.get("metadata", {})
        
        # Call the MongoDB service from app/database.py
        success = mongo_db.save_detection(
            brand=brand,
            raw_text=f"Model: {model}",
            btu=int(btu) if btu and str(btu).isdigit() else None,
            details=metadata
        )
        
        if success:
            return {"success": True, "message": "Item secured in cloud database."}
        else:
            return {"success": False, "message": "Database connection error."}
            
    except Exception as e:
        return {"success": False, "error": str(e)}
