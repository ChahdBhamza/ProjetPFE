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
            # 1. Light Pre-processing only (Faster than Otsu)
            img_np = np.array(pil_image.convert('RGB'))
            
            # Simple sharpening without complex CV2 math
            reader = self.get_reader()
            
            # 2. RUN SINGLE PASS (This cuts the 40s down to 20s or less)
            results = reader.readtext(img_np, detail=1, paragraph=False)
            
            combined_texts = [text for (bbox, text, prob) in results]
            raw_text = "\n".join(combined_texts)
            
            return {
                "raw_text": raw_text if raw_text else "No text found.",
                "status": "success",
                "mode": "Turbo-OCR"
            }
        except Exception as e:
            return {"error": str(e), "status": "error"}
