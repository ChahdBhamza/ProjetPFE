from fastapi import APIRouter, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional
from app.schemas import ExtractFramesResponse
from io import BytesIO
import os
import uuid
import base64


router = APIRouter(prefix="/video", tags=["Video Processing"])

_video_service = None
_yolov5_service = None
_roboflow_service = None

@router.post("/extract-frames", response_model=ExtractFramesResponse)
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
            best_frame = frames[0]["raw"]
            print("[Video] Auto-searching on best frame using Roboflow pipeline...")
            import tempfile as _tmp
            from fastapi.concurrency import run_in_threadpool
            img_byte_arr = BytesIO()
            best_frame.save(img_byte_arr, format='JPEG')
            img_bytes = img_byte_arr.getvalue()
            with _tmp.NamedTemporaryFile(delete=False, suffix=".jpg") as _f:
                _f.write(img_bytes)
                _tmp_path = _f.name
            try:
                from app.services.workflow_service import WorkflowService
                _wf_result = await run_in_threadpool(WorkflowService().run_specialized_workflow, _tmp_path)
                _forensic = _wf_result.get("forensic_data", {})
                _candidates = _forensic.get("model_candidates", [])
                _top = _candidates[0] if _candidates else {}
                search_result = {
                    "success": True,
                    "vector_match": {
                        "item": {
                            "brand": _forensic.get("brand", "Unknown"),
                            "model_name": _top.get("model", "Unknown Model"),
                            "btu": None,
                        },
                        "confidence": float(_top.get("confidence", 0)) / 100.0 if _top else 0.5,
                    },
                    "verified_details": {
                        "equipment_type": _forensic.get("equipment_type"),
                        "model_candidates": _candidates,
                        "annotated_image": _wf_result.get("ai_image"),
                    },
                }
            except Exception as _e:
                search_result = {"success": False, "error": str(_e)}
            finally:
                try:
                    os.unlink(_tmp_path)
                except Exception:
                    pass
            
        return {
            "success": True, 
            "frame_count": len(frames),
            "frames": processed_frames,
            "auto_search_result": search_result,
            "message": f"Extracted {len(frames)} key frames with full AI pipeline."
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

class SelectedFramesRequest(BaseModel):
    session_id: str
    filenames: list[str]

@router.post("/process-selected-frames")
async def process_selected_frames_endpoint(req: SelectedFramesRequest):
    """Runs Roboflow + Brand ID in PARALLEL for all selected frames."""
    from app.services.workflow_service import WorkflowService
    from fastapi.concurrency import run_in_threadpool
    import asyncio
    
    workflow_service = WorkflowService()
    base_dir_actual = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "processed_frames", req.session_id, "final_shots")
    
    async def process_single_frame(f):
        img_path = os.path.join(base_dir_actual, f)
        if not os.path.exists(img_path): return None
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

    tasks = [process_single_frame(f) for f in req.filenames]
    results = await asyncio.gather(*tasks)
    final_results = [r for r in results if r is not None]
    return {"success": True, "frames": final_results}

@router.post("/get-specs")
async def get_specs_endpoint(req: dict):
    brand = req.get("brand")
    model = req.get("model", "standard")
    eq_type = req.get("equipment_type", "equipment")
    
    if (not brand or brand.lower() == "unknown") and model != "standard":
        brand = model.split()[0]

    try:
        from app.services.spec_service import SpecService
        spec_service = SpecService()
        specs = spec_service.get_full_identity(brand=brand, model=model, equipment_type=eq_type)
        return specs
    except Exception as e:
        return {"status": "error", "message": str(e)}

@router.post("/script-process")
async def video_script_process_endpoint(
    file: Optional[UploadFile] = File(None),
    video: Optional[UploadFile] = File(None)
):
    import subprocess
    from fastapi.concurrency import run_in_threadpool
    from app.scripts.smart_extract import smart_extract
    
    actual_file = file or video
    if not actual_file:
        return {"success": False, "error": "No file or video field provided."}
    
    session_id = f"lab_{uuid.uuid4().hex[:8]}"
    base_dir = os.path.join("sessions", session_id)
    raw_dir = os.path.join(base_dir, "raw")
    os.makedirs(raw_dir, exist_ok=True)
    video_path = os.path.join(base_dir, "video.mp4")
    
    contents = await actual_file.read()
    with open(video_path, "wb") as buffer:
        buffer.write(contents)

    def _run_ffmpeg():
        return subprocess.run(["ffmpeg", "-y", "-i", video_path, "-vf", "fps=1", os.path.join(raw_dir, "frame_%04d.jpg")], check=True, capture_output=True, text=True)

    try:
        await run_in_threadpool(_run_ffmpeg)
    except subprocess.CalledProcessError as e:
        return {"success": False, "error": f"FFmpeg failed: {e.stderr}"}

    global _yolov5_service, _roboflow_service
    if _yolov5_service is None:
        from app.services.yolov5_service import YOLOv5Service
        _yolov5_service = YOLOv5Service()
    if _roboflow_service is None:
        from app.services.roboflow_service import RoboflowService
        _roboflow_service = RoboflowService()
    
    def _run_smart_extract():
        smart_extract(video_path=video_path, output_dir=base_dir, interval=1, strict=True, max_frames=28, yolo=_yolov5_service, roboflow=_roboflow_service)
    
    try:
        await run_in_threadpool(_run_smart_extract)
    except Exception as e:
        return {"success": False, "error": str(e)}

    final_dir = os.path.join(base_dir, "final_shots")
    if not os.path.exists(final_dir):
        return {"success": False, "error": "Final shots directory not created."}
        
    final_frames = []
    for f in sorted([f for f in os.listdir(final_dir) if f.endswith((".jpg", ".png"))]):
        with open(os.path.join(final_dir, f), "rb") as img_file:
            final_frames.append({
                "filename": f,
                "image": base64.b64encode(img_file.read()).decode('utf-8'),
                "has_ai": True,
                "is_hero": True,
                "detected_class": f.replace("hero_", "").replace(".jpg", "").replace("_", " ")
            })

    return {"success": True, "session_id": session_id, "frames": final_frames, "heros": final_frames}
