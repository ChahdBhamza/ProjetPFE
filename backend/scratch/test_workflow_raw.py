import requests
import json
import os

# Configuration
API_KEY = "oesPLELo2uEPnMKXp8dM"
WORKSPACE = "devileyess-workspace"
WORKFLOW = "custom-workflow-2"
IMAGE_PATH = r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\pro_test_result.jpg"

def test_via_http():
    url = f"https://serverless.roboflow.com/{WORKSPACE}/workflows/{WORKFLOW}"
    
    if not os.path.exists(IMAGE_PATH):
        print(f"Error: {IMAGE_PATH} not found")
        return

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

    print(f"Sending request to {url}...")
    response = requests.post(url, json=payload)
    
    print(f"Status Code: {response.status_code}")
    try:
        data = response.json()
        print("\n--- RESPONSE DATA ---")
        print(json.dumps(data, indent=2))
        
        # Check if there's an error in the response
        if "error" in data:
            print(f"\nAPI Error: {data['error']}")
            
        # Check outputs
        if "outputs" in data and isinstance(data["outputs"], list) and len(data["outputs"]) > 0:
            output0 = data["outputs"][0]
            print("\nAvailable keys in output[0]:", output0.keys())
            
            # Help user find where predictions are
            for key in output0.keys():
                if isinstance(output0[key], list):
                    print(f"Key '{key}' is a list with {len(output0[key])} elements.")
                else:
                    print(f"Key '{key}': {output0[key]}")
    except Exception as e:
        print(f"Error parsing JSON or analyzing response: {e}")
        print(response.text)

if __name__ == "__main__":
    test_via_http()
