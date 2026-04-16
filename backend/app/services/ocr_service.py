import os
import json
import ollama
from io import BytesIO
from PIL import Image

class OCRService:
    def __init__(self, model_name="qwen2.5vl:3b"):
        self.model_name = model_name

    def _img_to_bytes(self, pil_image):
        # Resize for speed - 768 is a good balance for OCR
        max_size = 768
        if max(pil_image.size) > max_size:
            pil_image.thumbnail((max_size, max_size))
            
        buffered = BytesIO()
        if pil_image.mode in ("RGBA", "P"):
            pil_image = pil_image.convert("RGB")
        pil_image.save(buffered, format="JPEG", quality=90)
        return buffered.getvalue()

    def process_image(self, pil_image):
        """Perform raw OCR text extraction using the VLM"""
        print(f"[OCR] Processing image with {self.model_name}...")
        
        img_bytes = self._img_to_bytes(pil_image)
        
        # Specialized OCR Prompt
        prompt = """
        ACT AS A RAW OCR ENGINE. 
        Read all the text visible in the image.
        Maintain original relative line structure where possible.
        Extract specifically any model codes, BTU ratings, serial numbers, and labels.
        Exclude common noise or meaningless symbols.
        
        Output the result in a CLEAN RAW TEXT FORMAT. 
        Do not add any preamble or conversational text.
        """

        try:
            response = ollama.generate(
                model=self.model_name,
                prompt=prompt,
                images=[img_bytes],
                stream=False
            )
            
            raw_text = response.get("response", "").strip()
            return {
                "raw_output": raw_text,
                "model_used": self.model_name,
                "status": "success"
            }
            
        except Exception as e:
            print(f"[OCR] Service Error: {e}")
            return {"raw_output": f"OCR Error: {str(e)}", "status": "error"}

# Factory function for consistency
def get_ocr_service():
    return OCRService()
