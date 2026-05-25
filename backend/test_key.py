import os
from dotenv import load_dotenv
load_dotenv()

from google import genai

api_key = os.getenv("GOOGLE_API_KEY")
print(f"Testing key: {api_key[:20]}...")

client = genai.Client(api_key=api_key)

# List available models
print("\nAvailable models:")
for m in client.models.list():
    if "flash" in m.name.lower() or "pro" in m.name.lower():
        print(f"  {m.name}")
