import os
import sys
from pathlib import Path

# Add the backend directory to sys.path so we can import app services
# Path: backend/lab/roboflow_tools/detect_microwaves.py
current_dir = Path(__file__).resolve().parent
backend_root = current_dir.parent.parent
sys.path.append(str(backend_root))

from app.services.unused_legacy_services.microwave_service import MicrowaveService
from PIL import Image

def run_test(image_path):
    print(f"🧪 [Lab] Testing Microwave Detection on: {image_path}")
    
    # 1. Initialize Service
    service = MicrowaveService()
    
    # 2. Load Image
    if not os.path.exists(image_path):
        print(f"❌ Error: Image not found at {image_path}")
        return

    img = Image.open(image_path).convert("RGB")
    
    # 3. Run Detection
    result = service.detect(img)
    
    if result["success"]:
        print("✅ Detection Successful!")
        print(f"📦 Category: {result['category']}")
        for i, det in enumerate(result["detections"]):
            print(f"   [{i+1}] Confidence: {det['confidence']:.2f}")
            
        # 4. Save result if we have an image
        if result.get("image"):
            import base64
            from io import BytesIO
            
            # Create output directory
            output_dir = backend_root / "lab" / "output"
            output_dir.mkdir(exist_ok=True)
            
            # Decode and save
            img_data = base64.b64decode(result["image"])
            output_path = output_dir / f"microwave_test_{Path(image_path).stem}.jpg"
            
            with open(output_path, "wb") as f:
                f.write(img_data)
            print(f"🖼️  Annotated result saved to: {output_path}")
    else:
        print("❌ No microwave detected in this image.")

if __name__ == "__main__":
    # You can change this path to any test image you have
    test_image = str(backend_root / "app" / "static" / "uploads" / "test_frame.jpg")
    
    # Fallback to a generic name if above doesn't exist
    if not os.path.exists(test_image):
         test_image = "test_microwave.jpg" 
         
    run_test(test_image)
