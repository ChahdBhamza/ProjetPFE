import requests
import base64
import json
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("ROBOFLOW_API_KEY", "oesPLELo2uEPnMKXp8dM")
WORKSPACE = "devileyess-workspace"
WORKFLOW = "custom-workflow-2"
IMAGE_PATH = r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\pro_test_result.jpg"

def try_user_logic():
    print(f"--- Running User Logic (via Requests) ---")
    
    # 1. Prepare Image
    with open(IMAGE_PATH, "rb") as f:
        img_b64 = base64.b64encode(f.read()).decode("utf-8")

    # 2. Call Workflow (use_cache=False)
    url = f"https://serverless.roboflow.com/{WORKSPACE}/workflows/{WORKFLOW}"
    payload = {
        "api_key": API_KEY,
        "inputs": {"image": {"type": "base64", "value": img_b64}}
    }

    print(f"Calling {WORKFLOW}...")
    response = requests.post(url, json=payload)
    result = response.json()

    # 3. Print RAW like in user code
    print("RAW:", json.dumps(result, indent=2, default=str))

    # 4. Extract logic from user's code
    if "outputs" in result:
        item = result["outputs"][0]
    else:
        item = result[0] if isinstance(result, list) else {}

    final_output = {
        "predictions": item.get("predictions", []),
        "count": item.get("count", 0),
    }

    print("\nFINAL RETURN:")
    print(json.dumps(final_output, indent=2))

if __name__ == "__main__":
    try_user_logic()
