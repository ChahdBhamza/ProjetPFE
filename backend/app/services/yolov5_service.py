
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
        
        self.confidence_threshold = 0.25
        self.appliance_classes = {"microwave", "refrigerator", "laptop", "oven", "tvmonitor", "tv"}
        self.allowed_classes = ["laptop", "refrigerator", "microwave", "oven", "tvmonitor", "tv"]

    def detect(self, image: Image.Image):
        """
        Run inference on a PIL image and return detections.
        Includes per-frame IoU deduplication: if two boxes overlap > 50%,
        only the higher-confidence one is kept. This prevents the same
        physical object (e.g. a laptop screen) from appearing as both
        'laptop' and 'tv' in the same frame.
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
                class_name = self.model.names[int(cls)].lower()

                if class_name == "refrigerator":
                    min_conf = 0.20
                elif class_name in self.appliance_classes:
                    min_conf = 0.20
                else:
                    min_conf = self.confidence_threshold
                if confidence < min_conf:
                    continue
                
                # Only include allowed classes if specified
                if self.allowed_classes and class_name not in self.allowed_classes:
                    continue
                
                # Map 'oven' to 'microwave' to improve recall without exposing 'oven' to the user
                if class_name == "oven":
                    class_name = "microwave"
                if class_name == "tvmonitor":
                    class_name = "tv"
                
                # Get coordinates
                x1, y1, x2, y2 = map(float, box)
                
                detections.append({
                    'class': class_name,
                    'confidence': confidence,
                    'bbox': [x1, y1, x2, y2]
                })

        # ── Per-frame IoU deduplication ───────────────────────────────────────
        # If two boxes on the same frame overlap > 50%, keep only the
        # higher-confidence one. This prevents duplicate heroes for the same
        # physical object (e.g. laptop detected as both 'laptop' and 'tv').
        def _iou(a, b):
            ax1, ay1, ax2, ay2 = a
            bx1, by1, bx2, by2 = b
            ix1, iy1 = max(ax1, bx1), max(ay1, by1)
            ix2, iy2 = min(ax2, bx2), min(ay2, by2)
            inter = max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1)
            area_a = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
            area_b = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
            union = area_a + area_b - inter
            return inter / max(union, 1e-6)

        # Sort by confidence descending so we always keep the more confident box
        detections.sort(key=lambda d: -d['confidence'])
        kept = []
        for det in detections:
            dominated = any(
                _iou(det['bbox'], k['bbox']) > 0.50
                for k in kept
            )
            if not dominated:
                kept.append(det)
            else:
                print(f"[YOLO dedup] Dropped '{det['class']}' (conf={det['confidence']:.2f}) — overlaps with a higher-confidence box")

        return kept

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
