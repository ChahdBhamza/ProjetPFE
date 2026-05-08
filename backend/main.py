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

# Register API endpoints
app.include_router(api_router, prefix="/api")
# Import auth router here to avoid circular dependencies if any
from app.api.auth_endpoints import router as auth_router
app.include_router(auth_router, prefix="/api/auth")

@app.get("/")
async def read_root():
    return {"message": "Cybersight Neural Link Active"}

@app.get("/yolo")
async def serve_yolo_ui():
    html_path = os.path.join(os.path.dirname(__file__), "yolo_test_ui.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "UI file not found"}

@app.get("/video")
async def serve_video_ui():
    html_path = os.path.join(os.path.dirname(__file__), "video_test_ui.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "UI file not found"}

@app.get("/forensic")
async def serve_forensic_ui():
    html_path = os.path.join(os.path.dirname(__file__), "forensic_test_ui.html")
    if os.path.exists(html_path):
        return FileResponse(html_path)
    return {"error": "UI file not found"}


if __name__ == "__main__":

    # Standard Port 8000 for ADB Reverse USB Link
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info")
