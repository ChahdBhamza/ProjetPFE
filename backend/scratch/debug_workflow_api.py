import os
import base64
import requests
import json
import shutil
import tempfile
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse

# Load environment variables (.env)
load_dotenv()

app = FastAPI()

# Configuration
API_KEY = os.getenv("ROBOFLOW_API_KEY", "oesPLELo2uEPnMKXp8dM")
WORKSPACE = os.getenv("ROBOFLOW_WORKSPACE", "devileyess-workspace")
WORKFLOW_ID = "custom-workflow-2"

@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    # 1. Prepare temporary file safely
    suffix = Path(file.filename).suffix or ".jpg"
    tmp_path = Path(tempfile.gettempdir()) / f"debug_process_{file.filename}{suffix}"
    
    with tmp_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    try:
        # 2. Encode Image to Base64
        with open(tmp_path, "rb") as f:
            img_b64 = base64.b64encode(f.read()).decode("utf-8")

        # 3. Call Roboflow Workflow API
        url = f"https://serverless.roboflow.com/{WORKSPACE}/workflows/{WORKFLOW_ID}"
        payload = {
            "api_key": API_KEY,
            "inputs": {
                "image": {"type": "base64", "value": img_b64}
            }
        }

        print(f"\n📡 Sending frame to workflow: {WORKFLOW_ID}...")
        response = requests.post(url, json=payload)
        
        if response.status_code != 200:
            print(f"❌ Roboflow API Error: {response.status_code}")
            print(response.text)
            return JSONResponse(status_code=response.status_code, content={"error": "Roboflow API Error", "details": response.text})

        result = response.json()
        
        # 4. Debug: See exactly what the Workflow is returning
        print("--- RAW WORKFLOW OUTPUT ---")
        print(json.dumps(result, indent=2))
        print("---------------------------")

        # 5. Extract results from the 'outputs' list
        if "outputs" not in result or not result["outputs"]:
            return {"error": "Workflow returned no outputs.", "raw": result}

        item = result["outputs"][0]

        return {
            "success": True,
            "predictions": item.get("predictions", []),
            "count": item.get("count", 0),
            "ac_detections": item.get("ac_detections", []),
            "ac_count": item.get("ac_count", 0),
            "raw_debug": item
        }

    except Exception as e:
        print(f"❌ CRITICAL ERROR: {e}")
        return {"success": False, "error": str(e)}
    finally:
        # Cleanup
        if tmp_path.exists():
            os.remove(tmp_path)

if __name__ == "__main__":
    import uvicorn
    print(f"\n🚀 Starting Debug Server for Workflow: {WORKFLOW_ID}")
    print(f"📍 Endpoint: http://127.0.0.1:8000/detect")
    uvicorn.run(app, host="0.0.0.0", port=8000)
