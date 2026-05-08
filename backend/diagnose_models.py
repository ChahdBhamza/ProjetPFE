import os
import time
from google import genai
from dotenv import load_dotenv

load_dotenv()

def diagnose():
    api_key = os.getenv("GOOGLE_API_KEY")
    client = genai.Client(api_key=api_key, http_options={'api_version': 'v1beta'})
    
    test_models = [
        'gemini-3.1-flash-live-preview',
        'gemini-2.5-flash-native-audio-latest',
        'gemini-2.0-flash',
        'gemini-1.5-flash-latest',
        'gemini-1.5-flash',
        'gemini-1.5-flash-8b',
        'gemini-1.5-pro'
    ]
    
    print("="*60)
    print("CYBERSIGHT MODEL DIAGNOSTIC")
    print("="*60)

    for m in test_models:
        print(f"Testing {m}...", end=" ", flush=True)
        try:
            response = client.models.generate_content(
                model=m,
                contents="hi"
            )
            print("[OK] ONLINE")
        except Exception as e:
            msg = str(e).lower()
            if "404" in msg:
                print("[ERROR] 404 NOT FOUND")
            elif "429" in msg or "503" in msg:
                print("[LIMIT] QUOTA EXHAUSTED")
            else:
                print(f"[ERROR] {e}")
        time.sleep(1) # Don't spam

    print("="*60)

if __name__ == "__main__":
    diagnose()
