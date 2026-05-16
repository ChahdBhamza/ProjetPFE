from fastapi import FastAPI, UploadFile, File
from inference_sdk import InferenceHTTPClient
import tempfile, shutil, json
from pathlib import Path
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()
client = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key=os.getenv("ROBOFLOW_API_KEY", "oesPLELo2uEPnMKXp8dM")
)

@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    suffix = Path(file.filename).suffix or ".jpg"
    tmp = Path(tempfile.gettempdir()) / f"rf_{file.filename}_{suffix}"
    with tmp.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    print(f"DEBUG: Running workflow 'custom-workflow-2' on {tmp}")
    
    try:
        result = client.run_workflow(
            workspace_name="devileyess-workspace",
            workflow_id="custom-workflow-2",
            images={"image": str(tmp)},
            use_cache=False
        )

        print("RAW RESULT:", json.dumps(result, indent=2, default=str))
        
        item = result[0] if result and isinstance(result, list) else {}
        
        return {
            "predictions": item.get("predictions", []),
            "count": item.get("count", 0),
            "raw": item
        }
    except Exception as e:
        print(f"EXCEPTION: {e}")
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
