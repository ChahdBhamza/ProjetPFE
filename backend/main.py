import os
import uvicorn
from fastapi import FastAPI
from fastapi.responses import FileResponse
from contextlib import asynccontextmanager
from dotenv import load_dotenv

# Import services
from app.api.endpoints import router as api_router

# Load Env
load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("="*50)
    print("!!! CYBERSIGHT BACKEND ONLINE (LAZY MODE) !!!")
    print("[STATUS] Waiting for first request to load AI...")
    print("="*50)
    
    # In Lazy Mode, we don't load models here. 
    # We let the API layer handle it on demand.
    yield
    print("[SHIELD] TERMINATING CLEANLY...")

# Initialize FastAPI
app = FastAPI(title="DetectionAppPFE - Lazy RAG", lifespan=lifespan)

# Add CORS Middleware
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allows all origins
    allow_credentials=True,
    allow_methods=["*"], # Allows all methods
    allow_headers=["*"], # Allows all headers
)

# Register API endpoints
app.include_router(api_router, prefix="/api")
# Import auth router here to avoid circular dependencies if any
from app.api.auth_endpoints import router as auth_router
app.include_router(auth_router, prefix="/api/auth")

@app.get("/")
async def read_root():
    return {"message": "Cybersight Neural Link Active"}

@app.get("/yolov5")
async def serve_yolov5_ui():
    html_path = os.path.join(os.path.dirname(__file__), "yolov5_test_ui.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "UI file not found"}

@app.get("/video")
async def serve_video_ui():
    html_path = os.path.join(os.path.dirname(__file__), "video_test_ui.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "UI file not found"}

@app.get("/roboflow")
async def serve_roboflow_ui():
    html_path = os.path.join(os.path.dirname(__file__), "roboflow_test_ui.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "UI file not found"}

@app.get("/detect")
async def serve_unified_ui():
    html_path = os.path.join(os.path.dirname(__file__), "unified_test_lab.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "UI file not found"}

@app.get("/forensic")
async def serve_forensic_ui():
    html_path = os.path.join(os.path.dirname(__file__), "forensic_test_ui.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "UI file not found"}

@app.get("/script-lab")
async def serve_script_lab_ui():
    html_path = os.path.join(os.path.dirname(__file__), "script_lab.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "Script Lab UI file not found"}

@app.get("/legacy-gallery")
async def serve_legacy_gallery_ui():
    html_path = os.path.join(os.path.dirname(__file__), "legacy_gallery.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "Legacy Gallery UI file not found"}



@app.get("/spec-lookup")
async def serve_spec_lookup_ui():
    html_path = os.path.join(os.path.dirname(__file__), "spec_lookup_ui.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "Spec Lookup UI file not found"}

if __name__ == "__main__":

    # Standard Port 8000 for ADB Reverse USB Link
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info")
