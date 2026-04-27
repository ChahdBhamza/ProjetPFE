import os
import uvicorn
from fastapi import FastAPI
from fastapi.responses import FileResponse
from pathlib import Path

# Import services
from app.api.endpoints import router as api_router, init_services
from app.api.auth_endpoints import router as auth_router

# 1. Initialize FastAPI
app = FastAPI(title="DetectionAppPFE - Stable Mode")

# Register API endpoints
app.include_router(api_router, prefix="/api")
app.include_router(auth_router, prefix="/api/auth")

# 4. Startup Logic (ULTRA STABLE MODE)
@app.on_event("startup")
async def startup_event():
    print("[Main] Starting in ULTRA-STABLE MODE...")
    
    # We initialize with None. Services will load lazily when needed.
    # This PREVENTS the startup crash and allows Login to work instantly.
    init_services(None, None, None, None, None, None, None)
    
    print("[Main] --- AUTHENTICATION ENGINE READY ---")
    print("[Main] (AI Services will load on-demand during scan)")

# 5. Dashboard / Demo Route
@app.get("/")
async def read_root():
    return FileResponse("demo_frontend.html")

if __name__ == "__main__":
    # Use Port 5000 as agreed
    uvicorn.run("main:app", host="0.0.0.0", port=5000, reload=False)
