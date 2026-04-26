import io
import json
import ollama
from PIL import Image, ImageEnhance, ImageOps

class OCRService:
    def __init__(self, model_name="qwen2.5vl:3b"):
        self.model_name = model_name

    def process_image(self, pil_image):
        """Natural-Vision Analyst (Subtle Detail Preservation)"""
        print(f"[OCR] Starting Natural-Vision Analysis...")
        
        img_bytes = self._img_to_bytes(pil_image)
        
        prompt = """
        Analyze this image and be a very careful observer of the hardware pixels. 
        
        SENSITIVITY FOCUS:
        - BRAND: Look at the LEFT SIDE of the white unit. There is a faint grey logo. Tell me exactly what it says (e.g. WESTPOINT).
        - TEMP: Look at the CENTER of the panel for internal glowing numbers (e.g. 26). They are very subtle.
        
        RECOVERY RULE:
        If you see a blurry or faint mark, describe its shape and letters. Don't just say "Not Found".
        
        JSON Structure:
        {
          "brand": "Manufacturer (Check left side plastic).",
          "display_temperature": "Glowing digits (Check center panel).",
          "technology": "Literal tech text (Check right side plastic).",
          "extra_marketing_info": "Info from color banners at top.",
          "model_code": "Any codes on stickers.",
          "description": "Exhaustive summary of hardware vs banners."
        }
        
        Return ONLY valid JSON.
        """
        
        # Add to the Prompt Evolution log as V19: Hierarchical Scanning

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
                "status": "success",
                "mode": "Optimized-Focus"
            }
        except Exception as e:
            return {"raw_output": f"Error: {str(e)}", "status": "error"}
            
        except Exception as e:
            print(f"[OCR] Service Error: {e}")
            return {"raw_output": f"OCR Error: {str(e)}", "status": "error"}

# Factory function for consistency
def get_ocr_service():
    return OCRService()
