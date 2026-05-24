""
Quick test: run the new vision prompt on the hero shots from the last session.
Usage: python test_prompt.py
"""

import sys, os, json

# Load env
from dotenv import load_dotenv
load_dotenv()

API_KEY = os.getenv("OPENROUTER_API_KEY") or os.getenv("GEMINI_API_KEY")
if not API_KEY:
    print("ERROR: No API key found in .env (OPENROUTER_API_KEY or GEMINI_API_KEY)")
    sys.exit(1)

HERO_DIR = os.path.join("sessions", "lab_d41745b0", "final_shots")
images = [f for f in os.listdir(HERO_DIR) if f.endswith((".png", ".jpg"))]

if not images:
    print("No hero shots found in", HERO_DIR)
    sys.exit(1)

from app.services.frame_detector import process_frame

print(f"\n{'='*60}")
print(f"  Testing NEW Vision Prompt on {len(images)} hero shot(s)")
print(f"{'='*60}\n")

for img_name in sorted(images):
    img_path = os.path.join(HERO_DIR, img_name)
    print(f"\n[IMAGE] Processing: {img_name}")
    print("-" * 50)
    
    try:
        result = process_frame(img_path, API_KEY)
        llm = result.get("result", {})
        
        detected    = llm.get("detected", False)
        eq_type     = llm.get("equipment_type", "?")
        brand       = llm.get("brand", "Unknown")
        candidates  = llm.get("model_candidates", [])
        visual_cues = llm.get("visual_cues", [])
        
        if not detected:
            print(f"  [X] Not detected: {llm.get('reason', 'unknown reason')}")
            continue
        
        print(f"  [OK] Equipment Type : {eq_type.upper()}")
        print(f"  [BRAND] Brand       : {brand}")
        print(f"\n  [CANDIDATES] Model Candidates:")
        for i, c in enumerate(candidates, 1):
            print(f"     {i}. {c.get('model', '?')} -- {c.get('confidence', '?')}% confidence")
            print(f"        -> {c.get('reasoning', '')}")
        
        if visual_cues:
            print(f"\n  [CUES] Visual Cues:")
            for cue in visual_cues:
                print(f"     * {cue}")
    
    except Exception as e:
        print(f"  [ERROR]: {e}")
        import traceback
        traceback.print_exc()

print(f"\n{'='*60}")
print("Done!")
