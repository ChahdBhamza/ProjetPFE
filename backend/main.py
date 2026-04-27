import os
import uvicorn
import time
from fastapi import FastAPI
from fastapi.responses import FileResponse
from contextlib import asynccontextmanager

# Import services
from app.api.endpoints import router as api_router, init_services
from app.api.auth_endpoints import router as auth_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("="*40)
    print("[USB] SHIELDED BACKEND ONLINE (PORT 8000)")
    print("[USB] ADB REVERSE LINK READY")
    print("="*40)
    init_services(None, None, None, None, None, None, None)
    yield

app = FastAPI(title="DetectionAppPFE - USB Mode", lifespan=lifespan)
app.include_router(api_router, prefix="/api")
app.include_router(auth_router, prefix="/api/auth")

@app.get("/")
async def read_root():
    return FileResponse("demo_frontend.html")

if __name__ == "__main__":
    try:
        print("[USB] Launching Backend...")
        # Back to standard Port 8000 for ADB Reverse
        uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info")
    except Exception as e:
        print(f"[USB] FATAL ERROR: {e}")
        input("Press Enter...")
