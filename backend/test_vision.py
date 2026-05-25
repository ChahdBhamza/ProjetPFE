"""Quick sanity check - sends one real image request to Gemini to confirm key + model work."""
import os, base64, json
from dotenv import load_dotenv
load_dotenv()

from google import genai
from google.genai import types as genai_types

api_key = os.getenv("GOOGLE_API_KEY")
print(f"Key: {api_key[:20]}...")
client = genai.Client(api_key=api_key)

# Create a tiny 1x1 white JPEG in memory (no file needed)
import io
from PIL import Image
img = Image.new("RGB", (100, 100), color=(200, 200, 200))
buf = io.BytesIO()
img.save(buf, format="JPEG")
img_bytes = buf.getvalue()

print("Sending test request to gemini-2.0-flash...")
try:
    resp = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=[
            genai_types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg"),
            "What color is this image? Reply in one word.",
        ],
    )
    print(f"✅ SUCCESS: {resp.text.strip()}")
except Exception as e:
    print(f"❌ FAILED: {e}")

print("\nTesting gemini-2.0-flash-lite...")
try:
    resp = client.models.generate_content(
        model="gemini-2.0-flash-lite",
        contents=[
            genai_types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg"),
            "What color is this image? Reply in one word.",
        ],
    )
    print(f"✅ SUCCESS: {resp.text.strip()}")
except Exception as e:
    print(f"❌ FAILED: {e}")
