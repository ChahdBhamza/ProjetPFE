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
                "vertical air conditioner"
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
            # 1. Run inference with a balanced threshold to avoid trash detections
            results = self.model(image, conf=0.25)
            
            if not results or len(results) == 0:
                return image
            
            # Get the first result
            result = results[0]
            boxes = result.boxes
            
            if len(boxes) == 0:
                return image
            
            img_width, img_height = image.size
            
            # Find the bounding box with the HIGHEST EFFECTIVE CONFIDENCE
            highest_conf = -1
            best_box = None
            
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                conf = box.conf[0].item()
                class_id = int(box.cls[0])
                
                # Apply AC Bias
                if class_id in [0, 1, 2]: # AC variants
                    conf = min(conf * 1.5, 1.0)
                elif class_id == 3: # Refrigerator
                    conf = conf * 0.5
                
                if conf > highest_conf:
                    highest_conf = conf
                    best_box = (int(x1), int(y1), int(x2), int(y2))
            
            if best_box:
                print(f"[YoloService] Cropping to best candidate with {highest_conf:.2f} effective confidence")
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
            # Use a very low threshold for visualization so we can see even weak detections
            results = self.model(image, conf=0.1, verbose=False)
            
            if not results or len(results) == 0:
                return image
                
            import cv2
            import numpy as np
            
            # Convert PIL image to OpenCV format (RGB to BGR)
            img_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
            
            boxes = results[0].boxes
            drawn_boxes = 0
            
            if len(boxes) > 0:
                for box in boxes:
                    x1, y1, x2, y2 = box.xyxy[0].tolist()
                    conf = box.conf[0].item()
                    class_id = int(box.cls[0])
                    
                    # BIAS: If it's an AC, we trust it more. If Fridge, we penalize.
                    effective_conf = conf
                    if class_id in [0, 1, 2]:
                        effective_conf = min(conf * 1.5, 1.0)
                    elif class_id == 3:
                        effective_conf = conf * 0.5
                    
                    # We only draw it if the effective confidence is reasonable
                    if effective_conf > 0.1:
                        drawn_boxes += 1
                        class_name = results[0].names[class_id]
                        label = f"{class_name.capitalize()} {effective_conf:.2f}"
                        
                        # Draw Rectangle (Bright Green)
                        cv2.rectangle(img_cv, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 4)
                        
                        # Draw Label
                        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
                        cv2.rectangle(img_cv, (int(x1), int(y1) - th - 10), (int(x1) + tw, int(y1)), (0, 255, 0), -1)
                        cv2.putText(img_cv, label, (int(x1), int(y1) - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2)
            
            if drawn_boxes == 0:
                return image
            
            # Convert back to PIL
            img_rgb = cv2.cvtColor(img_cv, cv2.COLOR_BGR2RGB)
            return Image.fromarray(img_rgb)
            
        except Exception as e:
            print(f"[YoloService] Error during drawing: {e}")
            return image
