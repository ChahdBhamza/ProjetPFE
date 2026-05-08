import cv2
import numpy as np
import os
from PIL import Image

# CRITICAL FIX for PaddlePaddle 3.0+ PIR Engine bugs on Windows CPU
os.environ["FLAGS_enable_pir_api"] = "0"
os.environ["FLAGS_enable_pir_in_executor"] = "0"
os.environ["FLAGS_enable_new_executor"] = "0"
os.environ["FLAGS_use_mkldnn"] = "0"

from paddleocr import PaddleOCR

class PaddleOCRService:
    def __init__(self):
        self.reader = None

    def _get_reader(self):
        if self.reader is None:
            # Initialize PaddleOCR with absolute bare minimum settings
            self.reader = PaddleOCR(
                use_angle_cls=True, 
                lang='fr'
            )
        return self.reader

    def process_image(self, pil_image: Image.Image) -> dict:
        """High-Accuracy Local OCR using PaddleOCR"""
        try:
            # 1. Convert PIL to OpenCV format
            img_cv = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)

            # 2. Lazy load the reader
            reader = self._get_reader()

            # 3. Run PaddleOCR
            result = reader.ocr(img_cv)

            if not result or not result[0]:
                return {"raw_text": "No text found.", "status": "success", "mode": "PaddleOCR"}

            # 4. Extract text
            extracted_lines = []
            for line in result[0]:
                text = line[1][0]
                extracted_lines.append(text)

            raw_text = "\n".join(extracted_lines)

            return {
                "raw_text": raw_text,
                "status": "success",
                "mode": "PaddleOCR"
            }

        except Exception as e:
            return {"raw_text": f"PaddleOCR Error: {str(e)}", "status": "error"}
