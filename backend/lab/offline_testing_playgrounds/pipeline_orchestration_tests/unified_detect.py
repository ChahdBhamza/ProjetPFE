import sys
import os
from pathlib import Path
from PIL import Image
import io

# 1. Setup paths to import from backend
BACKEND_DIR = Path(__file__).parent.parent.parent
PROJECT_ROOT = BACKEND_DIR.parent
sys.path.append(str(BACKEND_DIR))

# Import the services from your backend
try:
    from app.services.yolov5_service import YOLOv5Service
    from app.services.roboflow_service import RoboflowService
    from app.services.unused_legacy_services.orchestrator_service import OrchestratorService
except ImportError as e:
    print(f"Error: Could not find backend services: {e}")
    sys.exit(1)

def run_unified_detection(image_path="sample.jpg"):
    if not os.path.exists(image_path):
        print(f"Error: {image_path} not found.")
        return

    # Initialize Services
    print("⚙️ Initializing AI Services...")
    model_path = str(BACKEND_DIR / "vision_engine" / "weights" / "yolov5s.pt")
    yolo = YOLOv5Service(model_path=model_path)
    roboflow = RoboflowService()
    orchestrator = OrchestratorService(yolo, roboflow)

    # Load image as bytes
    with open(image_path, "rb") as f:
        image_bytes = f.read()

    print(f"🚀 Running Unified Detection on: {image_path}")
    print("-" * 50)
    
    result = orchestrator.auto_detect(image_bytes)

    print("-" * 50)
    print(f"🎯 RESULT SUMMARY:")
    print(f"  Source Model: {result['source'].upper()}")
    print(f"  Category:     {result['category'].upper()}")
    print(f"  Tracked Eq:   {'✅ YES' if result['is_known_equipment'] else '❌ NO'}")
    
    detections = result.get('detections', [])
    if not detections:
        print("  Detections: None found.")
    else:
        print(f"  Detections Found: {len(detections)}")
        for det in detections:
            print(f"    - {det['class']} (Confidence: {det['confidence']:.2%})")

    print("-" * 50)

if __name__ == "__main__":
    test_image = sys.argv[1] if len(sys.argv) > 1 else "sample.jpg"
    run_unified_detection(test_image)
