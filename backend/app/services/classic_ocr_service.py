import os
import easyocr
import numpy as np
from PIL import Image

class ClassicOCRService:
    # Caching the different required readers to avoid reloading models on every request
    _readers = {}

    @classmethod
    def get_reader(cls, langs):
        key = tuple(sorted(langs))
        if key not in cls._readers:
            print(f"[OCR] Initializing EasyOCR Models for {langs}...")
            cls._readers[key] = easyocr.Reader(langs, gpu=False, verbose=False)
        return cls._readers[key]

    def process_image(self, pil_image: Image.Image, combo: str = "en_fr") -> dict:
        """Standard OCR Verification using select language combinations"""
        try:
            img_np = np.array(pil_image.convert('RGB'))
            combined_texts = []
            if combo == "en_only":
                # Strict English only
                reader = self.get_reader(['en'])
                combined_texts = [text for (bbox, text, prob) in reader.readtext(img_np)]
                mode_name = "Classic-Linear-OCR (Strict English)"

            elif combo == "en_fr":
                # Native English/French
                reader = self.get_reader(['en', 'fr'])
                combined_texts = [text for (bbox, text, prob) in reader.readtext(img_np)]
                mode_name = "Classic-Linear-OCR (English+French)"
                
            elif combo == "ar_en":
                # Native Arabic/English
                reader = self.get_reader(['ar', 'en'])
                combined_texts = [text for (bbox, text, prob) in reader.readtext(img_np)]
                mode_name = "Classic-Linear-OCR (Arabic+English)"
                
            elif combo == "ar_fr":
                # Dual-Pass Hack for Arabic/French
                reader_fr = self.get_reader(['fr'])
                reader_ar = self.get_reader(['ar'])
                
                fr_texts = [text for (bbox, text, prob) in reader_fr.readtext(img_np)]
                ar_texts = [text for (bbox, text, prob) in reader_ar.readtext(img_np)]
                
                # Merge and Deduplicate
                seen = set()
                for text in fr_texts + ar_texts:
                    if text not in seen:
                        combined_texts.append(text)
                        seen.add(text)
                mode_name = "Classic-Linear-OCR (Dual-Pass AR+FR)"
                
            else:
                return {"error": "Invalid language combination.", "status": "error"}

            raw_text = "\n".join(combined_texts)
            
            return {
                "raw_text": raw_text.strip() if raw_text else "No text found.",
                "status": "success",
                "mode": mode_name
            }
        except Exception as e:
            return {"error": f"Classic OCR Failed: {str(e)}", "status": "error"}
