import requests
import json
import os

# Configuration
API_KEY = "oesPLELo2uEPnMKXp8dM"
WORKSPACE = "devileyess-workspace"
WORKFLOW = "detect-count-and-visualize"
IMAGE_PATH = r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\pro_test_result.jpg"

def test_workflow(wf_id):
    url = f"https://serverless.roboflow.com/{WORKSPACE}/workflows/{wf_id}"
    
    with open(IMAGE_PATH, "rb") as f:
        import base64
        img_b64 = base64.b64encode(f.read()).decode("utf-8")

    payload = {
        "api_key": API_KEY,
        "inputs": {
            "image": {
                "type": "base64",
                "value": img_b64
            }
        }
    }

    print(f"Testing Workflow: {wf_id}")
    response = requests.post(url, json=payload)
    print(f"Status: {response.status_code}")
    print(json.dumps(response.json(), indent=2))

if __name__ == "__main__":
    # test_workflow("custom-workflow-2")
    test_workflow("detect-count-and-visualize")
