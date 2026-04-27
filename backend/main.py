import os
import uvicorn
import time
from fastapi import FastAPI
from fastapi.responses import FileResponse
from pathlib import Path
import signal
import sys

# Import services
from app.api.endpoints import router as api_router, init_services
from app.api.auth_endpoints import router as auth_router

# 1. Initialize FastAPI
app = FastAPI(title="DetectionAppPFE - Shielded Mode")

# Register API endpoints
app.include_router(api_router, prefix="/api")
app.include_router(auth_router, prefix="/api/auth")

# 4. Startup Logic (SHIELDED MODE)
@app.on_event("startup")
async def startup_event():
    print("="*40)
    print("[SHIELD] STARTING BACKEND IN PROTECTED MODE")
    print("[SHIELD] PORT: 8000 | HOST: 0.0.0.0")
    print("="*40)
    
    # Initialize with None to prevent AI-related crashes on startup
    init_services(None, None, None, None, None, None, None)
    
    print("[SHIELD] --- AUTHENTICATION ENGINE ONLINE ---")

# 5. Dashboard / Demo Route
@app.get("/")
async def read_root():
    return FileResponse("demo_frontend.html")

if __name__ == "__main__":
    try:
        # We use Port 8000 but we run it with 'app' object directly for better stability on Windows
        print("[SHIELD] Launching Uvicorn...")
        uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info", access_log=True)
    except Exception as e:
        print(f"[SHIELD] FATAL CRASH: {e}")
        input("Press Enter to close...") # Keep window open to see error
