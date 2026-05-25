"""Quick test - Groq vision with actual image."""
import os, base64, io
from dotenv import load_dotenv
load_dotenv()

from groq import Groq
from PIL import Image

api_key = os.getenv("GROQ_API_KEY")
print(f"Testing Groq key: {api_key[:20]}...")

client = Groq(api_key=api_key)

# Create a simple test image
img = Image.new("RGB", (100, 100), color=(200, 50, 50))
buf = io.BytesIO()
img.save(buf, format="JPEG")
b64 = base64.b64encode(buf.getvalue()).decode()

print("Sending vision request to Groq llama-4-scout...")
resp = client.chat.completions.create(
    model="meta-llama/llama-4-scout-17b-16e-instruct",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "What color is this image? One word."},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
        ],
    }],
    max_tokens=10,
)
print(f"SUCCESS: {resp.choices[0].message.content.strip()}")
