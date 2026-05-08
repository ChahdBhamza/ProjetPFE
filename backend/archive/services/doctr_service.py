import os
import torch
import cv2
from doctr.models import ocr_db_resnet50
from PIL import Image
import numpy as np

class DocTRService:
    def __init__(self):
        # Load models
        # We use a lower confidence threshold for detection to find small logos
        self.model = ocr_db_resnet50(pretrained=True)
        if torch.cuda.is_available():
            self.model = self.model.cuda()

    def process_image(self, pil_image: Image.Image) -> dict:
        """High-Accuracy OCR using DocTR with Scene Text Optimization"""
        try:
            # 1. Image Enhancement for Scene Text (Logos)
            img = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
            
            # A. Scale up 3x (Aggressive)
            img = cv2.resize(img, None, fx=3, fy=3, interpolation=cv2.INTER_CUBIC)
            
            # B. Increase Contrast (Logos are often faint)
            alpha = 1.5 # Contrast control
            beta = 10    # Brightness control
            img = cv2.convertScaleAbs(img, alpha=alpha, beta=beta)
            
            # 2. Convert back to RGB for DocTR
            img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            
            # 3. Perform OCR
            result = self.model([img_rgb])
            
            # 4. Extract text with VERY sensitive threshold
            extracted_lines = []
            
            for page in result.pages:
                for block in page.blocks:
                    for line in block.lines:
                        # Lower confidence threshold to 0.05 to catch faint logos
                        words = [word.value for word in line.words if word.confidence > 0.05]
                        if words:
                            extracted_lines.append(" ".join(words))
            
            raw_text = "\n".join(extracted_lines)
            
            if not raw_text.strip():
                # Fallback: Just return "Unknown Brand" but show the attempt
                return {"raw_text": "No text detected. Try a closer photo of the logo.", "status": "success", "mode": "DocTR-Scene-Mode"}
            
            return {
                "raw_text": raw_text,
                "status": "success",
                "mode": "DocTR-Scene-Mode"
            }

        except Exception as e:
            return {"raw_text": f"DocTR Error: {str(e)}", "status": "error"}
