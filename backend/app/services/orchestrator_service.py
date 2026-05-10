
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
        Force AC Only Mode for testing the new workflow.
        """
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        
        # ONLY TRY NEW AC WORKFLOW
        print("🔍 [Orchestrator] FORCE NEW AC ONLY MODE...")
        ac_results = self.roboflow.detect(img, workflow_id=self.WORKFLOW_AC)
        
        has_ac_detections = len(ac_results.get("detections", [])) > 0 if isinstance(ac_results.get("detections"), list) else False
        
        if "error" not in ac_results and (has_ac_detections or ac_results.get("image")):
            print(f"✅ [Orchestrator] Air Conditioner detected (Detections: {has_ac_detections})")
            return {
                "source": "roboflow",
                "category": "air-conditioner",
                "detections": ac_results.get("detections", []),
                "image": ac_results.get("image")
            }

        return {
            "source": "error",
            "category": "unknown",
            "message": f"AC Only Mode: {ac_results.get('error', 'No AC detected')}",
            "detections": []
        }
