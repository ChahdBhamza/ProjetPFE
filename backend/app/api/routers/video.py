from fastapi import APIRouter, UploadFile, File, Form, Depends
from pydantic import BaseModel
from app.api.dependencies import verify_token
from app.database import mongo_db
from typing import Optional
from app.schemas import ExtractFramesResponse
from io import BytesIO
import os
import time
import shutil
import uuid
import base64
import asyncio


# ── Session housekeeping ──────────────────────────────────────────────────────

def _purge_old_sessions(max_age_hours: int = 24):
    """Delete session folders older than max_age_hours to stop disk from filling up."""
    sessions_root = "sessions"
    if not os.path.isdir(sessions_root):
        return
    cutoff = time.time() - max_age_hours * 3600
    for name in os.listdir(sessions_root):
        path = os.path.join(sessions_root, name)
        if not os.path.isdir(path):
            continue
        try:
            if os.path.getmtime(path) < cutoff:
                shutil.rmtree(path, ignore_errors=True)
                print(f"[Cleanup] Purged stale session: {name}")
        except Exception as _e:
            print(f"[Cleanup] Could not purge {name}: {_e}")


# ── Shared helper: build standardised equipment_result block ─────────────────

def build_equipment_result(forensic_data: dict, specs: dict | None = None, ai_image: str | None = None, raw_image: str | None = None) -> dict:
    """
    Converts raw forensic_data (from frame_detector) + optional specs (from
    spec_service) into the standardised equipment_result dict expected by Flutter.
    """
    from app.services.equipment_schemas import normalize_category

    candidates = forensic_data.get("model_candidates", [])
    top = candidates[0] if candidates else {}
    brand = ((specs or {}).get("brand") or forensic_data.get("brand") or "Unknown").strip()
    raw_category = (
        (specs or {}).get("equipment_category")
        or forensic_data.get("equipment_category")
        or forensic_data.get("equipment_type")
        or "unknown"
    )
    category = normalize_category(raw_category)

    final_model = (specs or {}).get("model") or top.get("model") or "Unknown Model"

    return {
        "identity": {
            "equipment_category": category,
            "brand": brand,
            "top_model": final_model.strip(),
            "confidence": top.get("confidence", 0),
            "all_candidates": candidates,
            "visual_cues": forensic_data.get("visual_cues", []),
            "pass1_type_confidence": forensic_data.get("pass1_type_confidence"),
        },
        "specs": (specs or {}).get("specs") or {},
        "meta": {
            "source_quality": (specs or {}).get("source_quality"),
            "fields_found": (specs or {}).get("fields_found"),
            "source_urls": (specs or {}).get("source_urls", []),
            "pipeline": (specs or {}).get("pipeline"),
            "summary": (specs or {}).get("summary"),
            "verified": (specs or {}).get("verified", False),
            "ai_image": ai_image or (specs or {}).get("ai_image") or forensic_data.get("ai_image") or raw_image,
        },
    }


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
                _equipment_result = build_equipment_result(_forensic, None, _wf_result.get("ai_image"))
                _top = _equipment_result["identity"]
                search_result = {
                    "success": True,
                    "equipment_result": _equipment_result,
                    # Legacy fields kept for backward compatibility
                    "vector_match": {
                        "item": {
                            "brand": _top["brand"],
                            "model_name": _top["top_model"],
                        },
                        "confidence": float(_top["confidence"]) / 100.0,
                    },
                    "verified_details": {
                        "equipment_type": _top["equipment_category"],
                        "model_candidates": _top["all_candidates"],
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
async def process_selected_frames_endpoint(req: SelectedFramesRequest, current_email: str = Depends(verify_token)):
    """Runs Roboflow + Brand ID per frame; Groq pacing handled by the rate limiter."""
    from app.services.workflow_service import WorkflowService
    from fastapi.concurrency import run_in_threadpool

    workflow_service = WorkflowService()
    base_dir_actual = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "sessions", req.session_id, "final_shots")

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

    # Pacing is handled by the shared Groq token-bucket limiter (rate_limiter.py).
    # Process frames in parallel (up to 4 concurrent) to max throughput while respecting rate cap.
    semaphore = asyncio.Semaphore(4)  # Limit concurrent Groq calls to 4
    
    async def process_with_semaphore(f):
        async with semaphore:
            return await process_single_frame(f)
    
    tasks = [process_with_semaphore(f) for f in req.filenames]
    final_results = [r for r in await asyncio.gather(*tasks) if r is not None]

    # Attach standardised equipment_result to each frame and log detection
    for frame in final_results:
        fd = frame.get("forensic_data") or {}
        frame["equipment_result"] = build_equipment_result(fd, None, frame.get("ai_image"), frame.get("raw_image"))
        
        # Log the raw AI detection to MongoDB
        mongo_db.log_detection(req.session_id, fd)

    return {"success": True, "frames": final_results}

@router.post("/get-specs")
async def get_specs_endpoint(req: dict):
    brand = req.get("brand", "").strip()
    model = req.get("model", "").strip()
    eq_type = req.get("equipment_type", "unknown").strip()
    forensic_data = req.get("forensic_data", {})   # optional: pass full forensic dict

    # Fallback: derive brand from model string if not supplied
    if (not brand or brand.lower() == "unknown") and model:
        brand = model.split()[0]

    try:
        from app.services.spec_service import SpecService
        from fastapi.concurrency import run_in_threadpool

        spec_service = SpecService()
        specs = await run_in_threadpool(
            spec_service.get_full_identity,
            brand=brand, model=model, equipment_type=eq_type
        )
        equipment_result = build_equipment_result(
            forensic_data or {"brand": brand}, 
            specs, 
            (forensic_data or {}).get("ai_image") or (specs or {}).get("ai_image")
        )
        return {"success": True, "equipment_result": equipment_result, **specs}
    except Exception as e:
        import traceback; traceback.print_exc()
        return {"success": False, "status": "error", "message": str(e)}

@router.post("/script-process")
async def video_script_process_endpoint(
    file: Optional[UploadFile] = File(None),
    video: Optional[UploadFile] = File(None),
    current_email: str = Depends(verify_token)
):
    import subprocess
    import imageio_ffmpeg
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    from fastapi.concurrency import run_in_threadpool
    from app.scripts.smart_extract import smart_extract
    
    actual_file = file or video
    if not actual_file:
        return {"success": False, "error": "No file or video field provided."}

    # Housekeeping: purge stale session folders before creating a new one
    _purge_old_sessions(max_age_hours=24)

    session_id = f"lab_{uuid.uuid4().hex[:8]}"

    # Start the scan session in the database
    mongo_db.start_scan_session(current_email, session_id, device_info="Video Upload")

    base_dir = os.path.join("sessions", session_id)
    raw_dir = os.path.join(base_dir, "raw")
    os.makedirs(raw_dir, exist_ok=True)
    video_path = os.path.join(base_dir, "video.mp4")

    contents = await actual_file.read()
    with open(video_path, "wb") as buffer:
        buffer.write(contents)

    def _run_ffmpeg():
        fixed_path = video_path + "_fixed.mp4"
        # Pass 1: remux with corrected color space metadata (no re-encode, fast)
        subprocess.run([ffmpeg_exe, "-y", "-i", video_path,
                        "-c", "copy",
                        "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
                        fixed_path], check=True, capture_output=True, text=True)
        # Pass 2: extract 1 frame/sec from the fixed video
        result = subprocess.run([ffmpeg_exe, "-y", "-i", fixed_path,
                                 "-r", "1", "-pix_fmt", "yuvj420p",
                                 os.path.join(raw_dir, "frame_%04d.jpg")],
                                check=True, capture_output=True, text=True)
        try:
            os.remove(fixed_path)
        except Exception:
            pass
        return result

    try:
        await run_in_threadpool(_run_ffmpeg)
    except subprocess.CalledProcessError as e:
        print(f"[FFMPEG ERROR] returncode={e.returncode}")
        print(f"[FFMPEG STDERR] {e.stderr}")
        print(f"[FFMPEG STDOUT] {e.stdout}")
        return {"success": False, "error": f"FFmpeg failed: {e.stderr}"}

    # video.mp4 is the largest file and is not needed after frame extraction
    # (smart_extract works only off the raw/ frames). Delete it immediately.
    try:
        if os.path.exists(video_path):
            os.remove(video_path)
    except Exception as _e:
        print(f"[Cleanup] Could not remove video.mp4: {_e}")

    global _yolov5_service, _roboflow_service
    if _yolov5_service is None:
        from app.services.yolov5_service import YOLOv5Service
        _yolov5_service = YOLOv5Service()
    if _roboflow_service is None:
        from app.services.roboflow_service import RoboflowService
        _roboflow_service = RoboflowService()
    
    def _run_smart_extract():
        smart_extract(video_path=video_path, output_dir=base_dir, interval=1, strict=True, max_frames=60, yolo=_yolov5_service, roboflow=_roboflow_service)
    
    try:
        await run_in_threadpool(_run_smart_extract)
    except Exception as e:
        return {"success": False, "error": str(e)}

    final_dir = os.path.join(base_dir, "final_shots")
    if not os.path.exists(final_dir):
        mongo_db.end_scan_session(session_id, status="failed")
        return {"success": False, "error": "Final shots directory not created."}
        
    final_frames = []
    for f in sorted([f for f in os.listdir(final_dir) if f.endswith((".jpg", ".png"))]):
        with open(os.path.join(final_dir, f), "rb") as img_file:
            import re
            m = re.match(r"hero_\d+_(.+?)_f\d+\.(png|jpg)", f)
            if m:
                detected_class = m.group(1).replace("_", " ").title()
            else:
                detected_class = f.replace("hero_", "").replace(".png", "").replace(".jpg", "").replace("_", " ").title()

            final_frames.append({
                "filename": f,
                "image": base64.b64encode(img_file.read()).decode('utf-8'),
                "has_ai": True,
                "is_hero": True,
                "detected_class": detected_class
            })

    hero_base64 = None
    if final_frames:
        hero_base64 = final_frames[0]["image"]
        
    mongo_db.end_scan_session(session_id, status="completed", hero_frame_base64=hero_base64)

    return {"success": True, "session_id": session_id, "frames": final_frames, "heros": final_frames}
