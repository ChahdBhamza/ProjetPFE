import requests
import base64
import json
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("ROBOFLOW_API_KEY", "oesPLELo2uEPnMKXp8dM")
WORKSPACE = "devileyess-workspace"
WORKFLOW = "custom-workflow-2"

# Trying two different images to be absolutely sure
IMAGES = [
    r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\pro_test_result.jpg",
    r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\yolo_test_result.jpg"
]

def multi_test():
    url = f"https://serverless.roboflow.com/infer/workflows/{WORKSPACE}/{WORKFLOW}"
    
    for img_path in IMAGES:
        print(f"\n--- Testing Image: {os.path.basename(img_path)} ---")
        if not os.path.exists(img_path):
            print("Image not found.")
            continue

        with open(img_path, "rb") as f:
            img_b64 = base64.b64encode(f.read()).decode("utf-8")

        payload = {
            "api_key": API_KEY,
            "inputs": {"image": {"type": "base64", "value": img_b64}}
        }

        response = requests.post(url, json=payload, timeout=60)
        print("Status:", response.status_code)
        print("Response:", response.text)

if __name__ == "__main__":
    multi_test()
