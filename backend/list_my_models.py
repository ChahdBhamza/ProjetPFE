import os
from google import genai
from dotenv import load_dotenv

load_dotenv()

def list_models():
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        print("GOOGLE_API_KEY not found in .env")
        return

    client = genai.Client(api_key=api_key)
    print("="*50)
    print("AVAILABLE GEMINI MODELS FOR YOUR KEY:")
    print("="*50)
    
    try:
        # The new SDK uses a different structure for the model list
        for model in client.models.list():
            # In the new SDK, model is usually a string or has a .name attribute
            print(f"- {model.name}")
    except Exception as e:
        print(f"Error listing models: {e}")
    
    print("="*50)

if __name__ == "__main__":
    list_models()
