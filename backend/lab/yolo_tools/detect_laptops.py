import sys
import os
from pathlib import Path
from PIL import Image

# 1. Setup paths to import from backend
BACKEND_DIR = Path(__file__).parent.parent.parent
PROJECT_ROOT = BACKEND_DIR.parent
sys.path.append(str(BACKEND_DIR))

# Import the service from your backend
try:
    from app.services.yolov5_service import YOLOv5Service
except ImportError:
    print("Error: Could not find backend services. Ensure the script is in lab/yolo_tools/")
    sys.exit(1)

def run_laptop_detection(image_path="laptop_sample.jpg"):
    if not os.path.exists(image_path):
        print(f"Error: {image_path} not found. Please provide an image to test.")
        return

    # Initialize the service pointing to the model in the new vision_engine structure
    model_path = str(BACKEND_DIR / "vision_engine" / "weights" / "yolov5s.pt")
    service = YOLOv5Service(model_path=model_path)

    # Load and process image
    img = Image.open(image_path)
    print(f"🔍 Analyzing {image_path} for laptops...")
    
    detections = service.detect(img)

    if not detections:
        print("❌ No laptops detected.")
    else:
        print(f"✅ Found {len(detections)} detection(s):")
        for i, det in enumerate(detections):
            print(f"  [{i+1}] {det['class'].upper()} - Confidence: {det['confidence']:.2%}")
            print(f"      BBox: {det['bbox']}")

        # Save result for visual verification
        result_img = service.draw_detections(img, detections)
        output_path = "laptop_result.jpg"
        result_img.save(output_path)
        print(f"💾 Result saved to {output_path}")

if __name__ == "__main__":
    # You can pass an image path as a command line argument
    test_image = sys.argv[1] if len(sys.argv) > 1 else "laptop_sample.jpg"
    run_laptop_detection(test_image)
