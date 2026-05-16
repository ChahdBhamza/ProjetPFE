import requests
import json

url = "http://localhost:8000/api/spec-lookup"
payload = {
    "brand": "Samsung",
    "model": "RT38",
    "equipment_type": "refrigerator"
}
headers = {
    "Content-Type": "application/json"
}

print(f"Sending request to {url}...")
try:
    response = requests.post(url, json=payload)
    print(f"Status Code: {response.status_code}")
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print(f"Error: {e}")
