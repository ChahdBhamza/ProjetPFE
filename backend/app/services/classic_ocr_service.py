import cv2
import numpy as np
import easyocr
from PIL import Image

class ClassicOCRService:
    # Caching the reader to avoid reload
    _reader = None

    @classmethod
    def get_reader(cls):
        if cls._reader is None:
            # We use a single reader for English/French to save VRAM
            cls._reader = easyocr.Reader(['en', 'fr'], gpu=True)
        return cls._reader

    def process_image(self, pil_image: Image.Image, combo: str = "en_fr") -> dict:
        """Turbo Single-Pass OCR"""
        try:
            # --- ADVANCED OPENCV PRE-PROCESSING ---
            # 1. Convert PIL image to OpenCV format (BGR)
            img_cv = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
            
            # 2. Increase Contrast slightly (Gamma Correction or simple alpha/beta)
            # We avoid aggressive binarization because it destroys faint grey logos
            alpha = 1.3 # Contrast control
            beta = 10   # Brightness control
            contrast_img = cv2.convertScaleAbs(img_cv, alpha=alpha, beta=beta)
            
            reader = self.get_reader()
            
            # 3. RUN SINGLE PASS on the lightly enhanced RGB image
            # Added mag_ratio=2.5 to automatically upscale small text (like logos)
            # Added contrast_ths and adjust_contrast to help with faint grey text
            results = reader.readtext(
                contrast_img, 
                detail=1, 
                paragraph=False,
                mag_ratio=2.5,        # Magnify the image by 2.5x before reading
                contrast_ths=0.05,    # Lower contrast threshold (catches faint text)
                adjust_contrast=0.8   # Auto-adjust contrast for shadows
            )
            
            combined_texts = [text for (bbox, text, prob) in results]
            raw_text = "\n".join(combined_texts)
            
            return {
                "raw_text": raw_text if raw_text else "No text found.",
                "status": "success",
                "mode": "Turbo-OCR"
            }
        except Exception as e:
            return {"error": str(e), "status": "error"}
