import os
import io
from PIL import Image
from app.services.yolov5_service import YOLOv5Service
from app.services.roboflow_service import RoboflowService
from app.services.vision_rag_service import VisionRAGService
from app.services.unused_legacy_services.microwave_service import MicrowaveService

class OrchestratorService:
    def __init__(self, yolov5_service: YOLOv5Service, roboflow_service: RoboflowService):
        self.yolo = yolov5_service
        self.roboflow = roboflow_service
        self.vision_rag = VisionRAGService() 
        self.microwave = MicrowaveService() # New Modular Service
        
        # Specialized Workflows
        self.WORKFLOW_AC = "air-conditioner-detector-1778448466329"
        self.WORKFLOW_REFRIGERATOR = "refrigerator-detector-1778362486109"

    def auto_detect(self, img_bytes):
        """
        Orchestrates the detection (YOLO MUTED):
        1. Roboflow Refrigerator Pass
        2. Roboflow Air Conditioner Pass (with Gemini Forensic Verification)
        3. Specialized Microwave Pass (Modular Service)
        """
        from PIL import Image
        import io
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        
        # 1. Try specialized Refrigerator detection
        print("🔍 [Orchestrator] Attempting Refrigerator detection...")
        fridge_results = self.roboflow.detect(img, workflow_id=self.WORKFLOW_REFRIGERATOR)
        
        if "error" not in fridge_results:
            detections = [d for d in fridge_results.get("detections", []) if d.get('confidence', 0) > 0.7]
            if detections:
                print(f"✅ [Orchestrator] Refrigerator verified!")
                return {
                    "source": "roboflow",
                    "category": "refrigerator",
                    "is_known_equipment": True,
                    "detections": detections,
                    "image": fridge_results.get("image")
                }

        # 2. Try specialized Air Conditioner detection
        print("🔍 [Orchestrator] Attempting Air Conditioner detection...")
        ac_results = self.roboflow.detect(img, workflow_id=self.WORKFLOW_AC)
        
        if "error" not in ac_results:
            detections = [d for d in ac_results.get("detections", []) if d.get('confidence', 0) > 0.7]
            if detections:
                print(f"✅ [Orchestrator] Air Conditioner verified!")
                return {
                    "source": "roboflow",
                    "category": "air-conditioner",
                    "is_known_equipment": True,
                    "detections": detections,
                    "image": ac_results.get("image")
                }

        # 3. Modular Microwave Pass
        print("🔍 [Orchestrator] Attempting Microwave detection...")
        micro_res = self.microwave.detect(img)
        if micro_res["success"]:
            print("✅ [Orchestrator] Microwave verified via specialized service!")
            return {
                "source": "roboflow/microwave-service",
                "category": "microwave",
                "is_known_equipment": True,
                "detections": micro_res["detections"],
                "image": micro_res.get("image")
            }

        # YOLO is Muted - Returning unrecognized if specialized models fail
        print("❌ [Orchestrator] No specialized equipment found. (YOLO is Muted)")
        return {
            "source": "multi-model-orchestrator",
            "category": "unrecognized",
            "is_known_equipment": False,
            "detections": [],
            "image": None 
        }
