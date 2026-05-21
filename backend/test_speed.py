import requests
import time
import json
import os

VIDEO_PATH = "test_video.mp4"
API_URL = "http://127.0.0.1:8000/api/video/unified-stream"

if not os.path.exists(VIDEO_PATH):
    print(f"Error: Could not find {VIDEO_PATH}")
    exit(1)

print(f"Testing the ultra-fast pipeline on {VIDEO_PATH}...")
start_time = time.time()

with open(VIDEO_PATH, "rb") as f:
    response = requests.post(API_URL, files={"file": f})

end_time = time.time()
duration = end_time - start_time

if response.status_code == 200:
    data = response.json()
    print(f"\n[SUCCESS] Pipeline completed in {duration:.2f} seconds.")
    print(f"\nFull JSON Response:")
    print(json.dumps(data, indent=2, default=str)[:3000])
else:
    print(f"\n[ERROR] Error {response.status_code}: {response.text[:500]}")

