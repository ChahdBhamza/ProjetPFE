import requests
import base64
import json
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("ROBOFLOW_API_KEY", "oesPLELo2uEPnMKXp8dM")
WORKSPACE = "devileyess-workspace"
WORKFLOW = "custom-workflow-2"
IMAGE_PATH = r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\pro_test_result.jpg"

def test_infer_endpoint():
    print(f"--- Testing Infer Endpoint ---")
    
    with open(IMAGE_PATH, "rb") as f:
        img_b64 = base64.b64encode(f.read()).decode("utf-8")

    # Trying your exact new URL structure
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
    try:
        print("Response:", json.dumps(response.json(), indent=2))
    except:
        print("Response Text:", response.text)

if __name__ == "__main__":
    test_infer_endpoint()
