import cv2
import numpy as np
import easyocr
from PIL import Image

class SuperOCRService:
    def __init__(self):
        self.reader = easyocr.Reader(['en', 'fr'], gpu=False)

    def process_image(self, pil_image: Image.Image) -> dict:
        """Industrial-Grade OCR with Advanced Preprocessing"""
        try:
            # 1. Convert to OpenCV
            img = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)

            # 2. Advanced Preprocessing
            # A. Magnification (3x) - Helps with small logos like Condor
            img = cv2.resize(img, None, fx=3, fy=3, interpolation=cv2.INTER_CUBIC)

            # B. Grayscale
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

            # C. Contrast Enhancement (CLAHE)
            clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
            gray = clahe.apply(gray)

            # D. Sharpness Filter (Laplacian)
            kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
            gray = cv2.filter2D(gray, -1, kernel)

            # 3. Run OCR
            # Use 'latin' specific detail if available, but default en+fr is good
            results = self.reader.readtext(gray)

            if not results:
                return {"raw_text": "No text detected.", "status": "success", "mode": "Super-OCR"}

            # 4. Filter and Join Text
            text_lines = [res[1] for res in results if res[2] > 0.3] # Confidence threshold 0.3
            raw_text = "\n".join(text_lines)

            return {
                "raw_text": raw_text,
                "status": "success",
                "mode": "Super-OCR"
            }

        except Exception as e:
            return {"raw_text": f"Super-OCR Error: {str(e)}", "status": "error"}
