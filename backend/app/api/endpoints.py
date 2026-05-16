from fastapi import APIRouter, UploadFile, File, Form, Response, BackgroundTasks
from typing import Optional
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image
from io import BytesIO
import json
import os
import sys
import uuid
import shutil
import asyncio
import base64
import cv2
import numpy as np
from collections import deque
from app.database import mongo_db

router = APIRouter()

# Global service holders
_embedder = None
_vector_store = None
_vision_service = None # Gemini
_web_service = None
_local_vlm = None # Qwen/Moondream
_openai_service = None
_video_service = None
_yolov5_service = None
_roboflow_service = None
_orchestrator_service = None
_ocr_service = None # Added for consistency, even if unused currently

def init_services(embedder, vector_store, vision_service, web_service, local_vlm=None, openai_service=None, yolov5_service=None, roboflow_service=None, orchestrator_service=None, ocr_service=None):
    global _embedder, _vector_store, _vision_service, _web_service, _local_vlm, _openai_service, _yolov5_service, _roboflow_service, _orchestrator_service, _ocr_service
    _embedder = embedder
    _vector_store = vector_store
    _vision_service = vision_service
    _web_service = web_service
    _local_vlm = local_vlm
    _ocr_service = ocr_service
    _openai_service = openai_service
    _yolov5_service = yolov5_service
    _roboflow_service = roboflow_service
    _orchestrator_service = orchestrator_service

def normalize_btu(btu_str):
    """Normalize '12' or '12k' to '12000' for reliable DB filtering"""
    if not btu_str or btu_str == "null" or btu_str == "None": 
        return None
    import re
    # Extract numbers
    nums = re.findall(r'\d+', str(btu_str))
    if not nums: return None
    
    val = int(nums[0])
    if val < 100: # It's in kBTU (e.g. 12 or 18)
        return val * 1000
    return val

# --- FORENSIC HELPERS FOR HERO SELECTION ---
ALLOWED_KEYWORDS = ["air", "ac", "conditioner", "microwave", "refrigerator", "fridge", "laptop", "computer", "tv", "monitor"]

def is_allowed(cls_name):
    """Checks if the detected class is actually forensic equipment"""
    name = cls_name.lower()
    if any(kw in name for kw in ["microwave", "refrigerator", "fridge", "laptop", "computer", "tv", "monitor"]):
        return True
    if "conditioner" in name or "ac" == name or "ac " in name or " ac" in name or "air cond" in name:
        return True
    return False

def calculate_center_score(bbox, img_w, img_h):
    """Scores how centered an object is in the frame"""
    x1, y1, x2, y2 = bbox
    obj_center_x = (x1 + x2) / 2
    obj_center_y = (y1 + y2) / 2
    img_center_x = img_w / 2
    img_center_y = img_h / 2
    dist_x = abs(obj_center_x - img_center_x) / img_center_x
    dist_y = abs(obj_center_y - img_center_y) / img_center_y
    centering = 1.0 - (dist_x + dist_y) / 2
    return max(0, centering)

@router.post("/search")
async def search_endpoint(
    file: UploadFile = File(...),
    use_vlm: bool = Form(False),
    use_openai: bool = Form(False) 
):
    contents = await file.read()
    image = Image.open(BytesIO(contents))
    return await _perform_search(image, contents, use_vlm, use_openai)

async def _perform_search(image, contents, use_vlm=False, use_openai=False):
    global _embedder, _vector_store, _vision_service
    
    # --- LAZY INITIALIZATION ---
    if _embedder is None:
        print("[LazyLoad] Initializing AI Services on demand...")
        from app.services.clip_embedder import CLIPEmbedder
        from app.services.vector_store import VectorStore
        from app.services.vision_rag_service import VisionRAGService
        
        try:
            _embedder = CLIPEmbedder()
            _vector_store = VectorStore()
            _vision_service = VisionRAGService()
            print("[LazyLoad] Neural Link Established!")
        except Exception as e:
            print(f"[LazyLoad] CRITICAL FAILURE: {e}")
            return {"success": False, "error": "AI Services failed to wake up."}

    try:
        # Update contents for the models that read raw bytes
        img_byte_arr = BytesIO()
        image.save(img_byte_arr, format='JPEG')
        contents = img_byte_arr.getvalue()
        
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
        
        # Normalize filters to match uppercase DB entries
        if v_brand: v_brand = v_brand.upper()
        
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





@router.post("/video/extract-frames")
async def extract_frames_endpoint(
    file: UploadFile = File(...),
    auto_search: bool = Form(False)
):
    """Extract key frames and optionally run search on the best one"""
    global _video_service
    if _video_service is None:
        from app.services.video_service import VideoService
        _video_service = VideoService()
        
    try:
        contents = await file.read()
        
        frames = _video_service.process_video_bytes(contents)
        
        if not frames:
            return {"success": False, "error": "No clear key frames detected."}
            
        processed_frames = []
        for f in frames:
            processed_frames.append({
                "raw": _video_service.pil_to_base64(f["raw"]),
                "frame_idx": f["frame_idx"]
            })

        search_result = None
        if auto_search and len(frames) > 0:
            best_frame_data = frames[0]
            best_frame = best_frame_data["raw"]
            
            print("[Video] Auto-searching on best frame...")
            img_byte_arr = BytesIO()
            best_frame.save(img_byte_arr, format='JPEG')
            best_frame_bytes = img_byte_arr.getvalue()
            
            search_result = await _perform_search(best_frame, best_frame_bytes)
            
        return {
            "success": True, 
            "frame_count": len(frames),
            "frames": processed_frames,
            "auto_search_result": search_result,
            "message": f"Extracted {len(frames)} key frames with full AI pipeline."
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

@router.post("/forensic/search")
async def forensic_search_endpoint(file: UploadFile = File(...)):
    """Advanced Forensic Pipeline: Crop -> Enhance -> Gemini ID -> V2 Vector Search -> Gemini Verify"""
    global _vision_service, _embedder
    
    # 1. Lazy Initialization
    if _vision_service is None:
        from app.services.vision_rag_service import VisionRAGService
        _vision_service = VisionRAGService()
    if _embedder is None:
        from app.services.clip_embedder import CLIPEmbedder
        _embedder = CLIPEmbedder()
        
    # We use a dedicated VectorStore for V2 Forensic DB
    from app.services.vector_store import VectorStore
    v2_store = VectorStore(collection_name="climatiseurs_forensic", path="qdrant_db_v2")

    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents)).convert("RGB")
        
        # 2. Forensic Pre-processing (Enhance only)
        # In forensic mode, we keep the original aspect but ensure high quality
        enhanced_image = image
        
        # Convert to bytes
        color_buf = BytesIO()
        enhanced_image.save(color_buf, format='JPEG', quality=95)
        color_bytes = color_buf.getvalue()
        
        # For UI display (COLOR VERSION)
        import base64
        enhanced_b64 = base64.b64encode(color_bytes).decode('utf-8')

        # 3. AI Perception (Gemini Identification)
        print("[ForensicAPI] Requesting Gemini Identification...")
        ai_perception = _vision_service.identify_from_raw_image(color_bytes)
        
        # 4. Vector Search (V2 DB)
        print("[ForensicAPI] Searching V2 Forensic Database...")
        query_vector = _embedder.embed_image(image) # Use color for visual search
        
        results = v2_store.hybrid_search(
            query_vector=query_vector,
            text_query=ai_perception.get('analysis', ""),
            limit=3,
            brand_filter=ai_perception.get('brand'),
            btu_filter=ai_perception.get('btu')
        )

        if not results:
            return {"success": False, "error": "No matches found in Forensic V2 DB."}

        best_match = results[0].payload
        similarity_score = results[0].score

        # 5. Final Verification (Gemini)
        print("[ForensicAPI] Requesting Final Verification...")
        verification = _vision_service.verify_equipment(color_bytes, best_match, similarity_score)

        return {
            "success": True,
            "enhanced_image": enhanced_b64,
            "ai_perception": ai_perception,
            "best_match": {
                "item": best_match,
                "score": float(similarity_score)
            },
            "verification": verification,
            "all_matches": [
                {"brand": r.payload.get("brand"), "model": r.payload.get("model_name"), "score": float(r.score)} 
                for r in results
            ]
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}

@router.post("/forensic/search_rag_only")
async def forensic_search_rag_only(file: UploadFile = File(...)):
    """Dual-RAG Comparison: Original Image vs Enhanced (No Gemini)"""
    global _embedder
    
    if _embedder is None:
        from app.services.clip_embedder import CLIPEmbedder
        _embedder = CLIPEmbedder()
        
    # 1. Setup ONE Vector Store connection
    from app.services.vector_store import VectorStore
    v_store = VectorStore(collection_name="climatiseurs_forensic", path="qdrant_db_v2")

    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents)).convert("RGB")

        # A. Search in RAW Collection (Original vs Original)
        print("[RAG-Only] Searching in RAW Collection...")
        raw_vector = _embedder.embed_image(image)
        
        # Temporarily swap collection to 'raw' for this search
        v_store.collection_name = "climatiseurs_raw"
        raw_results = v_store.search(raw_vector, limit=3)
        
        # B. Search in FORENSIC Collection (Enhanced vs Enhanced)
        print("[RAG-Only] Searching in FORENSIC Collection...")
        v_store.collection_name = "climatiseurs_forensic" # Swap back
        
        forensic_vector = _embedder.embed_image(image)
        forensic_results = v_store.search(forensic_vector, limit=3)

        # Base64 for display
        import base64
        img_byte_arr = BytesIO()
        image.save(img_byte_arr, format='JPEG')
        enhanced_b64 = base64.b64encode(img_byte_arr.getvalue()).decode('utf-8')

        return {
            "success": True,
            "enhanced_image": enhanced_b64,
            "raw_matches": [
                {"brand": r.payload.get("brand"), "model": r.payload.get("model_name"), "score": float(r.score)} 
                for r in raw_results
            ],
            "forensic_matches": [
                {"brand": r.payload.get("brand"), "model": r.payload.get("model_name"), "score": float(r.score)} 
                for r in forensic_results
            ]
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}

@router.post("/yolov5/detect")
async def yolov5_detect_endpoint(file: UploadFile = File(...)):
    """Standalone YOLOv5 Laptop Detection (Implemented from YOLO_APP_FINAL)"""
    global _yolov5_service
    
    if _yolov5_service is None:
        print("[LazyLoad] Initializing YOLOv5 Service...")
        from app.services.yolov5_service import YOLOv5Service
        _yolov5_service = YOLOv5Service()
        
    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents)).convert("RGB")
        
        # 1. Run detection
        detections = _yolov5_service.detect(image)
        
        # 2. Draw for visualization
        boxed_image = _yolov5_service.draw_detections(image, detections)
        
        # 3. Convert to Base64 for UI
        img_byte_arr = BytesIO()
        boxed_image.save(img_byte_arr, format='JPEG')
        import base64
        img_b64 = base64.b64encode(img_byte_arr.getvalue()).decode('utf-8')
        
        # 4. Message logic
        if len(detections) == 0:
            message = "No laptops detected! That's not a laptop."
        else:
            message = f"Found {len(detections)} laptop(s)!"
            
        return {
            "success": True,
            "message": message,
            "detections": detections,
            "image": img_b64,
            "total": len(detections)
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=500, content={"error": f"YOLOv5 Failed: {str(e)}"})

@router.post("/roboflow/detect")
async def roboflow_detect_endpoint(
    file: UploadFile = File(...), 
    workflow_id: str = "detect-count-and-visualize"
):
    """Roboflow Workflow Detection (Implemented from directory 'a')"""
    global _roboflow_service
    
    if _roboflow_service is None:
        print("[LazyLoad] Initializing Roboflow Service...")
        from app.services.roboflow_service import RoboflowService
        _roboflow_service = RoboflowService()
        
    try:
        contents = await file.read()
        image = Image.open(BytesIO(contents)).convert("RGB")
        
        # 1. Run detection
        result = _roboflow_service.detect(image, workflow_id=workflow_id)
        
        if "error" in result:
            return JSONResponse(status_code=500, content=result)
            
        detections = result["detections"]
        
        # 2. Draw for visualization
        boxed_image = _roboflow_service.draw_detections(image.copy(), detections)
        
        # 3. Convert to Base64 for UI
        img_byte_arr = BytesIO()
        boxed_image.save(img_byte_arr, format='JPEG')
        import base64
        img_b64 = base64.b64encode(img_byte_arr.getvalue()).decode('utf-8')
        
        return {
            "success": True,
            "message": f"Roboflow found {len(detections)} object(s) using workflow '{workflow_id}'",
            "detections": detections,
            "image": img_b64,
            "total": len(detections),
            "workflow": workflow_id
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": f"Roboflow Integration Failed: {str(e)}"})

@router.post("/detect/unified")
async def unified_detect(file: UploadFile = File(...)):
    """Automatic routing: Laptop (YOLOv5) -> Refrigerator (Roboflow) -> AC (Roboflow)"""
    global _orchestrator_service, _yolov5_service, _roboflow_service
    
    if _orchestrator_service is None:
        print("[LazyLoad] Initializing Orchestrator Service...")
        from app.services.yolov5_service import YOLOv5Service
        from app.services.roboflow_service import RoboflowService
        from app.services.orchestrator_service import OrchestratorService
        
        if _yolov5_service is None:
            _yolov5_service = YOLOv5Service()
        if _roboflow_service is None:
            _roboflow_service = RoboflowService()
            
        _orchestrator_service = OrchestratorService(_yolov5_service, _roboflow_service)
    
    try:
        contents = await file.read()
        results = _orchestrator_service.auto_detect(contents)
        
        # Add visual bounding boxes to the result image
        try:
            from io import BytesIO
            import base64
            image = Image.open(BytesIO(contents)).convert("RGB")
            
            if results["source"] == "yolov5":
                detections = results["detections"]
                boxed_image = _yolov5_service.draw_detections(image, detections)
            elif results["source"] == "roboflow":
                # If roboflow already provided an annotated image, use it!
                if results.get("image"):
                    results["image"] = results["image"] # Already base64
                    boxed_image = None # Skip local drawing
                else:
                    detections = results.get("detections", [])
                    boxed_image = _roboflow_service.draw_detections(image, detections)
            else:
                boxed_image = None
                
            if boxed_image:
                img_byte_arr = BytesIO()
                boxed_image.save(img_byte_arr, format='JPEG')
                results["image"] = base64.b64encode(img_byte_arr.getvalue()).decode('utf-8')
        except Exception as draw_error:
            print(f"⚠️ Visualization failed: {draw_error}")
            
        return results
    except Exception as e:
        import traceback
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": f"Unified Detection Failed: {str(e)}"})
@router.post("/video/unified-stream")
async def unified_video_stream(file: UploadFile = File(...)):
    """
    Intelligent Video Stream Analysis:
    1. Extracts high-quality key frames (VideoService)
    2. Filters and routes each frame (OrchestratorService)
    3. Returns results for each frame found
    """
    global _video_service, _orchestrator_service, _yolov5_service, _roboflow_service
    
    # 1. Lazy load all necessary services
    if _video_service is None:
        from app.services.video_service import VideoService
        _video_service = VideoService()
    
    if _orchestrator_service is None:
        from app.services.yolov5_service import YOLOv5Service
        from app.services.roboflow_service import RoboflowService
        from app.services.orchestrator_service import OrchestratorService
        
        if _yolov5_service is None:
            _yolov5_service = YOLOv5Service()
        if _roboflow_service is None:
            _roboflow_service = RoboflowService()
            
        _orchestrator_service = OrchestratorService(_yolov5_service, _roboflow_service)

    try:
        contents = await file.read()
        
        # 2. Extract sharpest frames (Scene Detection)
        # Increased to 10 frames for better coverage
        frames = _video_service.process_video_bytes(contents, max_frames=10)
        
        if not frames:
            return {"success": False, "error": "No clear key frames found in video."}
            
        # 3. Process each frame through the Unified Orchestrator
        raw_stream_results = []
        for f_data in frames:
            pil_img = f_data["raw"]
            
            # Convert PIL to bytes for the orchestrator
            img_byte_arr = BytesIO()
            pil_img.save(img_byte_arr, format='JPEG')
            frame_bytes = img_byte_arr.getvalue()
            
            # Run unified detection (YOLO -> Roboflow routing)
            res = _orchestrator_service.auto_detect(frame_bytes)
            
            # Add visualization
            try:
                import base64
                res_b64 = None
                if res["source"] == "yolov5":
                    boxed_img = _yolov5_service.draw_detections(pil_img, res["detections"])
                else:
                    # For Roboflow, if we have a base64 image from the cloud, use it, 
                    # otherwise draw locally
                    if res.get("image"):
                        res_b64 = res["image"]
                        boxed_img = None
                    else:
                        boxed_img = _roboflow_service.draw_detections(pil_img, res["detections"])
                
                if boxed_img:
                    out_buf = BytesIO()
                    boxed_img.save(out_buf, format='JPEG')
                    res_b64 = base64.b64encode(out_buf.getvalue()).decode('utf-8')
                
                if res_b64:
                    res["image"] = res_b64
            except:
                pass
                
            raw_stream_results.append({
                "frame_idx": f_data["frame_idx"],
                "analysis": res
            })

        # 4. INTELLIGENT DEDUPLICATION
        # We only want the "Best" frame for each unique equipment type
        best_results_by_category = {}
        
        for item in raw_stream_results:
            category = item["analysis"]["category"]
            
            # Skip unrecognized frames for the "Best Of" selection
            if not item["analysis"]["is_known_equipment"]:
                continue
                
            # Get the confidence of the best detection in this frame
            detections = item["analysis"].get("detections", [])
            max_conf = max([d.get("confidence", 0) for d in detections]) if detections else 0
            
            # If this is the first time we see this category, or if it's better than the previous one
            if category not in best_results_by_category or max_conf > best_results_by_category[category]["conf"]:
                best_results_by_category[category] = {
                    "data": item,
                    "conf": max_conf
                }
        
        # Final list contains only the "Hero Shots"
        deduplicated_results = [val["data"] for val in best_results_by_category.values()]
        
        # If no known equipment was found at all, show the unrecognized frames as a fallback
        if not deduplicated_results:
            deduplicated_results = raw_stream_results[:3]

        return {
            "success": True,
            "results": deduplicated_results,
            "total_raw_processed": len(raw_stream_results),
            "total_deduplicated": len(deduplicated_results),
            "message": f"Detected {len(best_results_by_category.keys())} unique equipment types."
        }
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


class SelectedFramesRequest(BaseModel):
    session_id: str
    filenames: list[str]

@router.post("/video/process-selected-frames")
async def process_selected_frames_endpoint(req: SelectedFramesRequest):
    """
    Runs Roboflow + Brand ID in PARALLEL for all selected frames.
    """
    from app.services.workflow_service import WorkflowService
    from fastapi.concurrency import run_in_threadpool
    import asyncio
    
    workflow_service = WorkflowService()
    base_dir = os.path.join("sessions", req.session_id, "processed")
    
    async def process_single_frame(f):
        img_path = os.path.join(base_dir, f)
        if not os.path.exists(img_path): return None
        
        # Run the heavy AI work in a thread pool so it doesn't block
        res = await run_in_threadpool(workflow_service.run_specialized_workflow, img_path)
        
        return {
            "filename": f,
            "raw_image": res.get("raw_image"),
            "ai_image": res.get("ai_image"),
            "raw_output": res.get("raw_output"),
            "has_ai": res.get("has_ai", False),
            "forensic_data": res.get("forensic_data"),
            "specs_status": "none"
        }

    # Launch all AI tasks at once!
    tasks = [process_single_frame(f) for f in req.filenames]
    results = await asyncio.gather(*tasks)
    
    # Filter out None results
    final_results = [r for r in results if r is not None]
        
    return {"success": True, "frames": final_results}

@router.post("/video/get-specs")
async def get_specs_endpoint(req: dict):
    print("🔔 [DEBUG] get_specs_endpoint CALLED!")
    print(f"📦 [DEBUG] Request Data: {req}")
    brand = req.get("brand")
    model = req.get("model", "standard")
    eq_type = req.get("equipment_type", "equipment")
    
    # Smart brand recovery: if brand is unknown but model has it
    if (not brand or brand.lower() == "unknown") and model != "standard":
        brand = model.split()[0] # Try the first word of the model (e.g. "Lenovo")
        print(f"💡 [Smart Recovery] Brand was Unknown, extracted '{brand}' from model.")

    import sys
    sfm_path = r"c:\Users\chahd\Desktop\DetectionAppPFE\sfm_project\backend"
    if sfm_path not in sys.path:
        sys.path.insert(0, sfm_path) # Force priority
    
    try:
        from spec_retriever import get_equipment_specs
        print(f"🌐 [On-Demand] START: {brand} | {model} | {eq_type}")
        specs = get_equipment_specs(
            brand=brand,
            model=model,
            equipment_type=eq_type,
            gemini_key=os.getenv("OPENROUTER_API_KEY")
        )
        print(f"✅ [On-Demand] COMPLETE: Found {len(specs.get('specs', {}) or {})} spec keys")
        return specs
    except Exception as e:
        print(f"❌ On-Demand Spec Error: {e}")
        import traceback
        traceback.print_exc()
        return {"status": "error", "message": str(e)}

@router.post("/video/script-process")
async def video_script_process_endpoint(
    file: Optional[UploadFile] = File(None),
    video: Optional[UploadFile] = File(None)
):
    """
    SMART AUTO-SELECT PIPELINE (V3 - FFmpeg Hybrid):
    1. FFmpeg High-Speed Extraction
    2. Dual-AI Scan (YOLOv5 + Roboflow)
    3. Spatial & Temporal Hero Selection
    """
    import subprocess
    import shutil
    import base64
    import os
    import sys
    import uuid
    import asyncio
    from fastapi.concurrency import run_in_threadpool
    from PIL import Image
    
    # Handle both 'file' and 'video' field names
    actual_file = file or video
    if not actual_file:
        return {"success": False, "error": "No file or video field provided in multipart form data."}
    
    session_id = f"lab_{uuid.uuid4().hex[:8]}"
    base_dir = os.path.join("sessions", session_id)
    raw_dir = os.path.join(base_dir, "raw")
    os.makedirs(raw_dir, exist_ok=True)

    video_path = os.path.join(base_dir, "video.mp4")
    # Read the entire file content asynchronously
    contents = await actual_file.read()
    with open(video_path, "wb") as buffer:
        buffer.write(contents)

    # 1. FFmpeg Extraction (3 frames per second for high detail)
    print(f"🎬 [FFmpeg] Extracting frames for session {session_id} from {video_path}...")
    try:
        result = subprocess.run([
            "ffmpeg", "-y", "-i", video_path, 
            "-vf", "fps=3", 
            os.path.join(raw_dir, "frame_%04d.png")
        ], check=True, capture_output=True, text=True)
        print(f"✅ [FFmpeg] Success: {result.stdout}")
    except subprocess.CalledProcessError as e:
        print(f"❌ [FFmpeg] Failed with code {e.returncode}")
        print(f"❌ [FFmpeg] Stderr: {e.stderr}")
        return {"success": False, "error": f"FFmpeg failed: {e.stderr}"}

    # 2. Path Setup
    sfm_path = r"c:\Users\chahd\Desktop\DetectionAppPFE\sfm_project\backend"
    if sfm_path not in sys.path: sys.path.insert(0, sfm_path)
    
    global _yolov5_service, _roboflow_service
    if _yolov5_service is None:
        from app.services.yolov5_service import YOLOv5Service
        _yolov5_service = YOLOv5Service()
    if _roboflow_service is None:
        from app.services.roboflow_service import RoboflowService
        _roboflow_service = RoboflowService()
    
    # 3. Execute the "Perfect" Smart Extract Script
    print(f"🚀 [Backend] Running smart_extract.py for session {session_id}...")
    
    # Define ROOT_DIR relative to this file (backend/app/api/endpoints.py)
    # Move up 3 levels to reach the project root
    ROOT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    script_path = os.path.join(ROOT_DIR, "sfm_project", "backend", "scripts", "smart_extract.py")
    
    try:
        # We run the script to process the video and extract forensic heroes
        result = subprocess.run([
            sys.executable, script_path,
            "--input", video_path,
            "--output", base_dir,
            "--interval", "8", # Every 8 frames for a good balance of speed/detail
            "--strict", "1"    # Forensic whitelist active
        ], capture_output=True, text=True, check=True, encoding='utf-8', errors='replace')
        print(f"✅ Script Success: {result.stdout}")
    except subprocess.CalledProcessError as e:
        print(f"❌ Script Error (Code {e.returncode}):")
        print(f"❌ Stderr: {e.stderr}")
        return {"success": False, "error": f"Script failed: {e.stderr}"}
    except Exception as e:
        print(f"❌ Execution Error: {e}")
        return {"success": False, "error": str(e)}

    # 4. Collect the resulting Hero Shots from the output folder
    final_dir = os.path.join(base_dir, "final_shots")
    if not os.path.exists(final_dir):
        return {"success": False, "error": "Final shots directory not created."}
        
    hero_files = sorted([f for f in os.listdir(final_dir) if f.endswith((".jpg", ".png"))])
    final_frames = []
    
    for f in hero_files:
        path = os.path.join(final_dir, f)
        with open(path, "rb") as img_file:
            b64 = base64.b64encode(img_file.read()).decode('utf-8')
            final_frames.append({
                "filename": f,
                "image": b64,
                "has_ai": True,
                "is_hero": True,
                "detected_class": f.replace("hero_", "").replace(".jpg", "").replace("_", " ")
            })

    print(f"✅ Smart Extraction Complete. Found {len(final_frames)} Hero Shots.")
    return {
        "success": True,
        "session_id": session_id,
        "frames": final_frames,
        "heros": final_frames
    }

@router.get("/api/sfm/sessions")
async def list_sfm_sessions():
    """List subfolders in the SFM project's processed_frames directory."""
    import os
    sfm_path = r"c:\Users\chahd\Desktop\DetectionAppPFE\sfm_project\backend\processed_frames"
    if not os.path.exists(sfm_path):
        return []
    sessions = [{"name": d} for d in os.listdir(sfm_path) if os.path.isdir(os.path.join(sfm_path, d))]
    return sessions

@router.get("/api/sfm/frames")
async def get_sfm_frames(session_id: str):
    """Retrieve frames from a specific SFM session folder."""
    import os
    import base64
    sfm_path = r"c:\Users\chahd\Desktop\DetectionAppPFE\sfm_project\backend\processed_frames"
    session_path = os.path.join(sfm_path, session_id)
    
    if not os.path.exists(session_path):
        return []
        
    frames = []
    files = sorted([f for f in os.listdir(session_path) if f.lower().endswith(('.jpg', '.jpeg', '.png'))])
    
    for f in files:
        with open(os.path.join(session_path, f), "rb") as img_f:
            b64 = base64.b64encode(img_f.read()).decode('utf-8')
            frames.append({"filename": f, "image": b64})
    
    return frames


@router.post("/spec-lookup")
async def spec_lookup_endpoint(req: dict):
    """
    Agentic Spec Retrieval Pipeline:
    DuckDuckGo (Search) -> BeautifulSoup (Scrape) -> Gemini (Verify & Extract)
    """
    from app.services.spec_service import SpecService

    brand = req.get("brand", "")
    model = req.get("model", "")
    equipment_type = req.get("equipment_type", "equipment")

    if not brand:
        return JSONResponse(status_code=400, content={"error": "Brand is required"})

    try:
        spec_service = SpecService()
        result = spec_service.get_full_identity(brand, model, equipment_type)
        return {"success": True, "data": result}
    except Exception as e:
        import traceback
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})




