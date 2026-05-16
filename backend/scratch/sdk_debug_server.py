from fastapi import FastAPI, UploadFile, File
from inference_sdk import InferenceHTTPClient
import tempfile, shutil, json, base64
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

# Initialize SDK Client
client = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key=os.getenv("ROBOFLOW_API_KEY", "oesPLELo2uEPnMKXp8dM")
)

WORKSPACE = "devileyess-workspace"
WORKFLOW = "custom-workflow-2"
OUTPUT_IMG_PATH = r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\scratch\latest_detection.jpg"

@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    suffix = Path(file.filename).suffix or ".jpg"
    tmp = Path(tempfile.gettempdir()) / f"rf_{file.filename}_{suffix}"
    
    with tmp.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    print(f"DEBUG: Running workflow '{WORKFLOW}' using SDK...")
    
    try:
        # Use the SDK client
        result = client.run_workflow(
            workspace_name=WORKSPACE,
            workflow_id=WORKFLOW,
            images={"image": str(tmp)},
            use_cache=False
        )

        # The SDK returns a list
        item = result[0] if result and isinstance(result, list) else {}
        
        # --- NEW: Auto-save the annotated image ---
        annotated_b64 = item.get("annotated_image")
        if annotated_b64:
            # Clean base64 string if necessary
            if "," in annotated_b64:
                annotated_b64 = annotated_b64.split(",")[1]
            
            with open(OUTPUT_IMG_PATH, "wb") as f:
                f.write(base64.b64decode(annotated_b64))
            print(f"✅ Saved annotated image to: {OUTPUT_IMG_PATH}")
        else:
            print("⚠️ No annotated_image found in the response.")

        return {
            "success": True,
            "predictions": item.get("predictions", []),
            "count": item.get("count", 0),
            "annotated_saved_to": OUTPUT_IMG_PATH if annotated_b64 else None
        }
    except Exception as e:
        print(f"SDK ERROR: {e}")
        return {"success": False, "error": str(e)}
    finally:
        if tmp.exists():
            os.remove(tmp)

if __name__ == "__main__":
    import uvicorn
    print(f"🚀 Starting SDK-Powered Debug Server on port 8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
