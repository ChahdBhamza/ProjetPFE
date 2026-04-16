import os
import json
import io
import ollama
from PIL import Image, ImageEnhance, ImageOps

class OCRService:
    def __init__(self, model_name="qwen2.5vl:3b"):
        self.model_name = model_name

    def _img_to_bytes(self, pil_image, max_size=1536):
        # 1. Advanced Detail Recovery
        pil_image = pil_image.convert("RGB")
        pil_image = ImageOps.autocontrast(pil_image)
        pil_image = ImageOps.equalize(pil_image) # Pulls text out of blur/shadows
        
        # 2. Aggressive Edge Enhancement
        enhancer = ImageEnhance.Contrast(pil_image)
        pil_image = enhancer.enhance(2.2) 
        
        enhancer = ImageEnhance.Sharpness(pil_image)
        pil_image = enhancer.enhance(3.5) # High sharpness for blur recovery
        
        # Resize to High-Resolution
        if max(pil_image.size) > max_size:
            pil_image.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        
        buffered = io.BytesIO()
        pil_image.save(buffered, format="JPEG", quality=95)
        return buffered.getvalue()

    def process_image(self, pil_image):
        """Vision-Boost Analyst (Detail Recovery)"""
        print(f"[OCR] Starting Vision-Boost Analysis...")
        
        img_bytes = self._img_to_bytes(pil_image)
        
        prompt = """
        I need you to be a World-Class Hardware Analyst. I have digitally enhanced this image to help you see tiny details.
        
        TASK:
        Look at the BOTTOM CORNERS and CENTER of the unit. There is tiny text there. 
        Even if it is slightly blurry, use your visual recognition to tell me what it says. 
        
        JSON Structure:
        {
          "brand": "Manufacturer (found text or best visual estimate).",
          "display_temperature": "The glowing digital numbers (e.g. 23, 18).",
          "technology": "Literal technology text (e.g. Inverter, Quattro).",
          "warranty_labels": "Info from stickers (e.g. 3 Ans).",
          "model_code": "Technical IDs found on the unit.",
          "description": "Exhaustive physical summary. Mention colors and logo locations."
        }
        
        Return ONLY valid JSON.
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
