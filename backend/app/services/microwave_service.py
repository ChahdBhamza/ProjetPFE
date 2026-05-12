import os
from PIL import Image
from app.services.roboflow_service import RoboflowService

class MicrowaveService:
    def __init__(self):
        self.roboflow = RoboflowService()
        self.workflow_id = "custom-workflow" # Update this ID as needed
        self.confidence_threshold = 0.65

    def detect(self, img):
        """
        Detects microwaves using a specialized Roboflow workflow.
        Returns a dictionary with success status and detections.
        """
        print(f"📡 [MicrowaveService] Running specialized detection (ID: {self.workflow_id})...")
        
        result = self.roboflow.detect(img, workflow_id=self.workflow_id)
        
        if "error" in result:
            return {"success": False, "error": result["error"]}
            
        detections = [d for d in result.get("detections", []) if d.get('confidence', 0) > self.confidence_threshold]
        
        if detections:
            print(f"✅ [MicrowaveService] Found {len(detections)} microwave(s)!")
            return {
                "success": True,
                "category": "microwave",
                "detections": detections,
                "image": result.get("image")
            }
            
        return {"success": False, "detections": []}
