import os
import uvicorn
from fastapi import FastAPI
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from app.api.router import api_router

# Load Env
load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("="*60)
    print("CYBERSIGHT FORENSIC API ONLINE")
    print("[STATUS] API Layer Activated | Initializing AI Models...")
    from app.api.routers.video import _yolov5_service
    from app.services.yolov5_service import YOLOv5Service
    import app.api.routers.video as video_router
    video_router._yolov5_service = YOLOv5Service()
    print("[STATUS] YOLOv5 Model Loaded into memory.")
    print("[STATUS] Waiting for first mobile request...")
    print("="*60)
    yield
    print("="*60)
    print("TERMINATING CYBERSIGHT SERVICES CLEANLY...")
    print("="*60)

# Initialize FastAPI
app = FastAPI(
    title="Cybersight Forensic API", 
    description="Backend Neural Engine orchestrating video stabilization, localized object detection, and multimodal spec retrieval.",
    version="2.0.0",
    lifespan=lifespan
)

# Add CORS Middleware to enable communication with Android/iOS ADB reverse USB link
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allows all origins
    allow_credentials=True,
    allow_methods=["*"], # Allows all methods
    allow_headers=["*"], # Allows all headers
)

app.include_router(api_router, prefix="/api")

@app.get("/")
async def read_root():
    return {
        "status": "online",
        "service": "Cybersight Neural Link Active",
        "endpoints": {
            "api_gateway": "/api"
        }
    }

if __name__ == "__main__":
    # Standard Port 8000 for ADB Reverse USB Link in local mobile development
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info", reload=True)
