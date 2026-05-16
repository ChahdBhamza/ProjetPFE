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

def run_latest_user_logic():
    print(f"--- Running Latest User Snippet ---")
    
    # Read and encode image
    with open(IMAGE_PATH, "rb") as f:
        img_b64 = base64.b64encode(f.read()).decode()

    # Call the serverless API
    url = f"https://serverless.roboflow.com/infer/workflows/{WORKSPACE}/{WORKFLOW}"
    payload = {
        "api_key": API_KEY,
        "inputs": {
            "image": {"type": "base64", "value": img_b64}
        }
    }

    print(f"Calling: {url}")
    response = requests.post(url, json=payload, timeout=60)
    print("Status:", response.status_code)
    data = response.json()

    # Inspect the result
    print("Full response:", json.dumps(data, indent=2))

    # Extract outputs
    if data.get("outputs") and len(data["outputs"]) > 0:
        outputs = data["outputs"][0]
        print("Predictions:", outputs.get("predictions", []))
        print("Count:", outputs.get("count", 0))
        
        # Save annotated image if present
        annotated_b64 = outputs.get("annotated_image")
        if annotated_b64:
            # Saving to scratch directory to avoid cluttering backend
            output_path = r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\scratch\annotated_output.png"
            with open(output_path, "wb") as f:
                f.write(base64.b64decode(annotated_b64))
            print(f"Saved annotated image to {output_path}")
        else:
            print("No annotated_image found in response.")
    else:
        print("No outputs found in response.")

if __name__ == "__main__":
    run_latest_user_logic()
