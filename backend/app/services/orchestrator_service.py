
import os
import io
from PIL import Image
from app.services.yolov5_service import YOLOv5Service
from app.services.roboflow_service import RoboflowService

class OrchestratorService:
    def __init__(self, yolov5_service: YOLOv5Service, roboflow_service: RoboflowService):
        self.yolo = yolov5_service
        self.roboflow = roboflow_service
        
        # Mapping classes to workflows
        self.WORKFLOW_AC = "air-conditioner-detector-1778448466329"
        self.WORKFLOW_REFRIGERATOR = "refrigerator-detector-1778362486109"

    def auto_detect(self, image_bytes: bytes):
        """
        Unified AI routing: Tries specialized Roboflow workflows before falling back to YOLOv5.
        """
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        
        # 1. Try REFRIGERATOR Workflow
        print("🔍 [Orchestrator] Attempting Refrigerator detection...")
        fridge_results = self.roboflow.detect(img, workflow_id=self.WORKFLOW_REFRIGERATOR)
        
        has_fridge = False
        if "error" not in fridge_results:
            # We require VERY high confidence (70%) for specialized models to avoid false positives
            detections = [d for d in fridge_results.get("detections", []) if d.get('confidence', 0) > 0.7]
            if len(detections) > 0:
                has_fridge = True 

        if has_fridge:
            best_det = detections[0]
            print(f"✅ [Orchestrator] Refrigerator verified! ({best_det['class']} @ {best_det['confidence']:.2f})")
            return {
                "source": "roboflow",
                "category": "refrigerator",
                "detections": detections,
                "image": fridge_results.get("image")
            }

        # 2. Try AIR CONDITIONER Workflow
        print("🔍 [Orchestrator] Attempting Air Conditioner detection...")
        ac_results = self.roboflow.detect(img, workflow_id=self.WORKFLOW_AC)
        
        has_ac = False
        if "error" not in ac_results:
            # We require VERY high confidence (70%) for specialized models
            detections = [d for d in ac_results.get("detections", []) if d.get('confidence', 0) > 0.7]
            if len(detections) > 0:
                has_ac = True

        if has_ac:
            best_det = detections[0]
            print(f"✅ [Orchestrator] Air Conditioner verified! ({best_det['class']} @ {best_det['confidence']:.2f})")
            return {
                "source": "roboflow",
                "category": "air-conditioner",
                "detections": detections,
                "image": ac_results.get("image")
            }

        # 3. Fallback to local YOLOv5 for general hardware (Laptops, TVs)
        print("🔍 [Orchestrator] No specialized appliance detected. Falling back to YOLOv5...")
        yolo_results = self.yolo.detect(img)
        
        # Determine category based on YOLO detections
        category = "general"
        if any(det['class'] == 'laptop' for det in yolo_results):
            category = "laptop"
            print("✅ [Orchestrator] Laptop detected via YOLOv5!")

        return {
            "source": "yolov5",
            "category": category,
            "detections": yolo_results,
            "image": None # YOLOv5 service returns raw detections
        }
