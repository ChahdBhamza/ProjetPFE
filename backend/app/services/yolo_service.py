import os
from PIL import Image
import io

class YoloService:
    def __init__(self, model_name="yolov8s-world.pt"):
        try:
            from ultralytics import YOLO
            # Load YOLO-World model
            self.model = YOLO(model_name)
            # Define custom classes for zero-shot detection
            custom_classes = [
                "air conditioner", 
                "split air conditioner", 
                "ac unit", 
                "wall mounted air conditioner",
                "appliance",
                "black appliance",
                "dark air conditioner",
                "indoor unit"
            ]
            self.model.set_classes(custom_classes)
            print(f"[YoloService] Loaded YOLO-World model: {model_name} with classes: {custom_classes}")
        except Exception as e:
            print(f"[YoloService] Error loading YOLO-World model: {e}")
            self.model = None

    def detect_and_crop(self, image: Image.Image) -> Image.Image:
        """
        Detects objects in the image and crops to the most prominent one.
        If no objects are detected or model fails, returns the original image.
        """
        if self.model is None:
            return image
        
        try:
            # 1. Run inference with a more inclusive threshold
            results = self.model(image, conf=0.1)
            
            if not results or len(results) == 0:
                return image
            
            # Get the first result
            result = results[0]
            boxes = result.boxes
            
            if len(boxes) == 0:
                return image
            
            img_width, img_height = image.size
            
            # Find the VALID bounding box with the HIGHEST CONFIDENCE
            highest_conf = -1
            best_box = None
            
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                width = x2 - x1
                height = y2 - y1
                conf = box.conf[0].item()
                
                if height == 0: continue
                aspect_ratio = width / height
                area = width * height
                
                # HEURISTICS FILTERING:
                # 1. AC units are wider than tall
                if aspect_ratio < 1.2: continue
                if y1 < (img_height * 0.05): continue # Skip top 5% of image (ceiling)
                if area > (img_width * img_height * 0.8): continue
                
                if conf > highest_conf:
                    highest_conf = conf
                    best_box = (int(x1), int(y1), int(x2), int(y2))
            
            if best_box:
                print(f"[YoloService] Cropping image to bounding box: {best_box}")
                cropped_img = image.crop(best_box)
                return cropped_img
                
            return image
            
        except Exception as e:
            print(f"[YoloService] Error during detection/cropping: {e}")
            return image

    def detect_and_draw(self, image: Image.Image) -> Image.Image:
        """
        Detects objects in the image and returns the image with ONLY VALID bounding boxes drawn.
        """
        if self.model is None:
            return image
        
        try:
            # 1. Run inference with a more inclusive threshold
            results = self.model(image, conf=0.1)
            
            if not results or len(results) == 0:
                return image
                
            import cv2
            import numpy as np
            
            # Convert PIL image to OpenCV format (RGB to BGR)
            img_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            img_height, img_width = img_cv.shape[:2]
            
            boxes = results[0].boxes
            drawn_boxes = 0
            
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                width = x2 - x1
                height = y2 - y1
                
                if height == 0: continue
                aspect_ratio = width / height
                area = width * height
                
                # HEURISTICS FILTERING (Same as crop):
                if aspect_ratio < 1.2: continue
                if y1 < (img_height * 0.05): continue # Skip top 5% (ceiling)
                if area > (img_width * img_height * 0.8): continue
                
                # It passed the filter! Draw it manually.
                drawn_boxes += 1
                conf = box.conf[0].item()
                
                # Override the label so it always says Air Conditioner
                label = f"Air Conditioner {conf:.2f}"
                
                # Draw Rectangle
                cv2.rectangle(img_cv, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 5)
                
                # Draw Text Background
                (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.9, 2)
                cv2.rectangle(img_cv, (int(x1), int(y1) - th - 10), (int(x1) + tw, int(y1)), (0, 255, 0), -1)
                
                # Draw Text
                cv2.putText(img_cv, label, (int(x1), int(y1) - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 0), 2)
            
            if drawn_boxes == 0:
                print("[YoloService] No valid boxes passed the heuristics filter.")
                return image
            
            # Convert back to PIL
            img_rgb = cv2.cvtColor(img_cv, cv2.COLOR_BGR2RGB)
            return Image.fromarray(img_rgb)
            
        except Exception as e:
            print(f"[YoloService] Error during drawing: {e}")
            return image
