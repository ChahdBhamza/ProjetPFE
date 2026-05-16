
import sys
import os
import torch
import cv2
import numpy as np
from pathlib import Path
from PIL import Image

# Add yolov5 directory to path so we can import models and utils
# This must happen BEFORE importing from models or utils
YOLO_DIR = str(Path(__file__).parent.parent.parent / "vision_engine" / "yolov5")
if YOLO_DIR not in sys.path:
    sys.path.append(YOLO_DIR)

from models.common import AutoShape

class YOLOv5Service:
    def __init__(self, model_path=None):
        from utils.torch_utils import select_device
        
        # Default path to the weights in the new structure
        if model_path is None:
            model_path = str(Path(__file__).parent.parent.parent / "vision_engine" / "weights" / "yolov5s.pt")
            
        self.device = select_device('')
        print(f"🚀 Loading YOLOv5 model: {model_path}")
        
        # Load model using the local yolov5 folder as source
        self.model = torch.hub.load(YOLO_DIR, 'custom', path=model_path, source='local')
        
        # Ensure model is wrapped in AutoShape (required for numpy/cv2 inputs)
        if not isinstance(self.model, AutoShape):
            self.model = AutoShape(self.model)
            
        self.model.to(self.device)
        self.model.eval()
        
        self.confidence_threshold = 0.30
        self.allowed_classes = [] # Allow all, smart_extract will filter

    def detect(self, image: Image.Image):
        """
        Run inference on a PIL image and return detections.
        """
        # Convert PIL to RGB numpy array (YOLOv5 hub model expects this)
        img_rgb = np.array(image.convert("RGB"))
        
        with torch.no_grad():
            results = self.model(img_rgb)
            
        detections = []
        preds = results.pred[0] # predictions (tensor)
        
        if preds is not None and len(preds) > 0:
            for *box, conf, cls in preds:
                confidence = float(conf)
                
                if confidence < self.confidence_threshold:
                    continue
                    
                class_name = self.model.names[int(cls)].lower()
                
                # Only include allowed classes if specified
                if self.allowed_classes and class_name not in self.allowed_classes:
                    continue
                
                # Get coordinates
                x1, y1, x2, y2 = map(float, box)
                
                detections.append({
                    'class': class_name,
                    'confidence': confidence,
                    'bbox': [x1, y1, x2, y2]
                })
                
        return detections

    def draw_detections(self, image: Image.Image, detections: list):
        """
        Draw bounding boxes on the image.
        """
        img_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
        
        for det in detections:
            x1, y1, x2, y2 = map(int, det['bbox'])
            label = f"{det['class']} {det['confidence']:.2f}"
            
            # Draw Rectangle
            cv2.rectangle(img_cv, (x1, y1), (x2, y2), (0, 255, 0), 2)
            
            # Draw Label
            (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 1)
            cv2.rectangle(img_cv, (x1, y1 - th - 10), (x1 + tw, y1), (0, 255, 0), -1)
            cv2.putText(img_cv, label, (x1, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 1)
            
        return Image.fromarray(cv2.cvtColor(img_cv, cv2.COLOR_BGR2RGB))
