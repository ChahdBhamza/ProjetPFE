import requests
import base64
import json

api_key = "oesPLELo2uEPnMKXp8dM"
workspace = "devileyess-workspace"
workflow_id = "custom-workflow-2"
url = f"https://serverless.roboflow.com/{workspace}/workflows/{workflow_id}"

# Let's use a dummy tiny image
img_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

payload = {
    "api_key": api_key,
    "inputs": {
        "image": {
            "type": "base64",
            "value": img_b64
        }
    }
}

print("Testing input name 'image'...")
resp = requests.post(url, json=payload)
print(resp.status_code)
try:
    print(json.dumps(resp.json(), indent=2))
except:
    print(resp.text)

print("\n----------------\nTesting input name 'image_1'...")
payload["inputs"] = {
    "image_1": {
        "type": "base64",
        "value": img_b64
    }
}
resp = requests.post(url, json=payload)
print(resp.status_code)
try:
    print(json.dumps(resp.json(), indent=2))
except:
    print(resp.text)
