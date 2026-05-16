import requests
import os

url = "http://localhost:8000/api/video/script-process"

# Create a dummy video file or use an existing one
video_file = "test_video.mp4"
with open(video_file, "wb") as f:
    f.write(b"dummy video content")

files = {'file': open(video_file, 'rb')}
try:
    response = requests.post(url, files=files)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
finally:
    if os.path.exists(video_file):
        os.remove(video_file)
