"""
SFM Equipment Identifier — FastAPI Backend
Run: uvicorn main:app --reload --port 8000
"""
import os
import tempfile
import shutil
import uuid
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from dotenv import load_dotenv
import cv2
import numpy as np

load_dotenv()

from frame_detector import process_frame
from spec_retriever import get_equipment_specs
from chat_assistant import chat

app = FastAPI(title="SFM Equipment Identifier", version="2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "uploads"
RAW_FRAMES_DIR = "raw_frames"
PROCESSED_FRAMES_DIR = "processed_frames"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(RAW_FRAMES_DIR, exist_ok=True)
os.makedirs(PROCESSED_FRAMES_DIR, exist_ok=True)

# Mount static files to serve images
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
app.mount("/frames_static", StaticFiles(directory=PROCESSED_FRAMES_DIR), name="frames_static")
app.mount("/raw_static", StaticFiles(directory=RAW_FRAMES_DIR), name="raw_static")

GEMINI_KEY = os.getenv("GEMINI_API_KEY", "").strip()
SERPER_KEY  = os.getenv("SERPER_API_KEY", "").strip()


@app.get("/health")
def health():
    return {"status": "ok", "gemini_key_set": bool(GEMINI_KEY), "search": "duckduckgo (no key needed)"}


@app.get("/frames")
def list_frames(session_id: Optional[str] = None):
    """List all frames in a specific session's processed_frames directory."""
    path = PROCESSED_FRAMES_DIR
    if session_id:
        path = os.path.join(PROCESSED_FRAMES_DIR, session_id)
        
    if not os.path.exists(path):
        return []
    files = sorted([f for f in os.listdir(path) if f.lower().endswith(('.jpg', '.jpeg', '.png'))])
    url_prefix = f"/frames_static/{session_id}/" if session_id else "/frames_static/"
    return [{"filename": f, "url": f"{url_prefix}{f}"} for f in files]

def get_frame_score(file_path):
    """Calculate a 'quality score' for a frame based on sharpness and object visibility."""
    img = cv2.imread(file_path)
    if img is None: return 0
    
    # 1. Sharpness (Laplacian variance)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    sharpness = cv2.Laplacian(gray, cv2.CV_64F).var()
    
    # 2. Objectness (use existing detector logic)
    from frame_detector import detect_dominant_object
    bbox = detect_dominant_object(img)
    if not bbox: return sharpness * 0.1 # Low score if no object
    
    x, y, w, h = bbox
    area_pct = (w * h) / (img.shape[0] * img.shape[1])
    
    # We want objects that take up 15-70% of the frame (not too small, not too huge)
    object_score = 100 if (0.15 < area_pct < 0.70) else 10
    
    return sharpness * object_score

@app.get("/auto-select")
def auto_select_best_frame(session_id: Optional[str] = None):
    """Find the best frame in a session using purely standard CV."""
    path = PROCESSED_FRAMES_DIR
    if session_id:
        path = os.path.join(PROCESSED_FRAMES_DIR, session_id)

    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="No frames folder found")
        
    files = sorted([f for f in os.listdir(path) if f.lower().endswith(('.jpg', '.jpeg', '.png'))])
    if not files:
        raise HTTPException(status_code=404, detail="No frames found")
        
    # Standard CV Scoring Logic
    candidates = []
    for f in files:
        file_path = os.path.join(path, f)
        img = cv2.imread(file_path)
        if img is None: continue
        
        # 1. Standard Sharpness (Laplacian)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        sharpness = cv2.Laplacian(gray, cv2.CV_64F).var()
        
        # 2. Standard Detection (Contours)
        from frame_detector import detect_dominant_object
        bbox = detect_dominant_object(img)
        has_object = 1.5 if bbox else 1.0 # 50% bonus if an object is found
        
        score = sharpness * has_object
        candidates.append({"file": f, "score": score, "img": img})

    if not candidates:
        return {"filename": files[0], "url": f"/frames_static/{files[0]}", "score": 0}

    # 3. Standard Deduplication (Pixel Difference)
    # We sort by score and pick the top one that is unique
    candidates.sort(key=lambda x: x["score"], reverse=True)
    
    # Just return the top one for now - it's the "best" standard CV result
    best = candidates[0]
    url_prefix = f"/frames_static/{session_id}/" if session_id else "/frames_static/"
            
    return {"filename": best["file"], "url": f"{url_prefix}{best['file']}", "score": best["score"]}
@app.post("/upload-video")
async def upload_video(file: UploadFile = File(...)):
    """Upload a video and automatically extract frames into a unique folder."""
    video_id = str(uuid.uuid4())[:8]
    video_name = os.path.splitext(file.filename)[0]
    session_id = f"{video_name}_{video_id}"
    
    video_path = os.path.join(UPLOAD_DIR, file.filename)
    with open(video_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # Create session-specific folders
    raw_path = os.path.join(RAW_FRAMES_DIR, session_id)
    proc_path = os.path.join(PROCESSED_FRAMES_DIR, session_id)
    os.makedirs(raw_path, exist_ok=True)
    os.makedirs(proc_path, exist_ok=True)
    
    import subprocess
    import sys
    try:
        # 1. Extract ALL frames to session raw folder
        subprocess.run([sys.executable, "scripts/extract_frames.py", "--input", video_path, "--output", raw_path, "--interval", "15"], check=True)
        
        # 2. Copy all frames to session processed folder
        shutil.copytree(raw_path, proc_path, dirs_exist_ok=True)
        
        # 3. Deduplicate the session processed folder
        subprocess.run([sys.executable, "scripts/deduplicate_frames.py", "--dir", proc_path, "--window", "10", "--threshold", "50.0"], check=True)
        
        return {
            "status": "success", 
            "message": f"Video '{file.filename}' processed.",
            "session_id": session_id
        }
    except Exception as e:
        print(f"Upload-video error: {e}")
        raise HTTPException(status_code=500, detail=f"Script error: {str(e)}")
    except Exception as e:
        print(f"Upload-video error: {e}")
        raise HTTPException(status_code=500, detail=f"Script error: {str(e)}")


@app.post("/identify")
async def identify_equipment(frame: UploadFile = File(...)):
    key = os.getenv("GEMINI_API_KEY", "").strip()
    if not key:
        raise HTTPException(500, "GEMINI_API_KEY not set in .env")
    
    suffix = ".jpg" if "jpeg" in (frame.content_type or "") else ".png"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await frame.read())
        tmp_path = tmp.name
    
    try:
        result = process_frame(image_path=tmp_path, api_key=key)
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        return result
    except Exception as e:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        msg = str(e)
        print(f"Error in identify_equipment: {msg}")
        raise HTTPException(status_code=500, detail=msg)


class SpecRequest(BaseModel):
    brand: str
    model: str
    equipment_type: str

@app.post("/specs")
async def fetch_specs(req: SpecRequest):
    g_key = os.getenv("GEMINI_API_KEY", "").strip()
    s_key = os.getenv("SERPER_API_KEY", "").strip()
    if not g_key or not s_key:
        raise HTTPException(500, "API keys not set in .env")
    return get_equipment_specs(
        brand=req.brand, model=req.model,
        equipment_type=req.equipment_type,
        serper_key=s_key, gemini_key=g_key,
    )


class ChatRequest(BaseModel):
    user_message: str
    specs: dict
    history: list[dict]

@app.post("/chat")
async def maintenance_chat(req: ChatRequest):
    key = os.getenv("GEMINI_API_KEY", "").strip()
    if not key:
        raise HTTPException(500, "GEMINI_API_KEY not set in .env")
    return chat(
        user_message=req.user_message,
        specs=req.specs,
        history=req.history,
        api_key=key,
    )
