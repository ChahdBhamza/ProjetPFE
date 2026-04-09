import os
from google import genai
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    print("Error: GOOGLE_API_KEY not found in .env")
    exit()

client = genai.Client(api_key=api_key)

print("--- AVAILABLE MODELS FOR YOUR KEY ---")
try:
    # List models
    for model in client.models.list():
        print(f"Model ID: {model.name}")
        print(f"Supported methods: {model.supported_generation_methods}")
        print("-" * 30)
except Exception as e:
    print(f"Failed to list models: {e}")
