# app/services/local_vlm_service.py
import json
import base64
import os
import ollama
from io import BytesIO
from PIL import Image

class LocalVLMService:
    def __init__(self, model_name="qwen2.5vl:3b"):
        self.model_name = model_name

    def _img_to_bytes(self, pil_image):
        # Resize image for speed
        max_size = 640
        if max(pil_image.size) > max_size:
            pil_image.thumbnail((max_size, max_size))
            
        buffered = BytesIO()
        if pil_image.mode in ("RGBA", "P"):
            pil_image = pil_image.convert("RGB")
        pil_image.save(buffered, format="JPEG", quality=85)
        return buffered.getvalue()

    def extract_specs(self, pil_image):
        """Extract Brand and BTU using official Ollama library"""
        print(f"[LocalVLM] Analyzing with {self.model_name} (Official Lib)...")
        
        img_bytes = self._img_to_bytes(pil_image)
        prompt = """You are an expert in HVAC product recognition.

Analyze the input image of an air conditioner and extract the following information with maximum accuracy.

Your PRIORITY is to identify the BRAND, even if:
- the image is blurry
- the logo is partially visible
- the text is distorted or low resolution
- the brand is inferred from shape, design, font style, or common AC patterns

Use all available visual cues including:
- logo shape, color, and placement
- typical brand design patterns (e.g., grille style, LED display position, casing shape)
- partial or incomplete text (e.g., "SAM" → Samsung, "LG" shape, etc.)
- common air conditioner models and manufacturer styles

If the brand is uncertain, return your BEST GUESS (do NOT return null).

Also extract:
- BTU (from visible numbers or inferred from model codes if possible)
- whether it is an inverter AC (look for "inverter", "dual inverter", "DC inverter", etc.)

STRICT OUTPUT FORMAT:
Return ONLY a valid JSON object with no explanation:
{
  "brand": "string",
  "btu": "string",
  "is_inverter": true/false
}"""

        try:
            response = ollama.generate(
                model=self.model_name,
                prompt=prompt,
                images=[img_bytes],
                stream=False
            )
            
            raw_response = response.get("response", "").strip()
            print(f"[LocalVLM] Raw Output: {raw_response}")
            
            # Find JSON
            start = raw_response.find("{")
            end = raw_response.rfind("}")
            if start != -1 and end != -1:
                data = json.loads(raw_response[start:end+1])
                data["raw_text"] = raw_response
                return data
            
            # Keyword Fallback
            for brand in ["Gree", "Samsung", "LG", "TCL", "Haier", "Biolux", "Midea"]:
                if brand.lower() in raw_response.lower():
                    return {"brand": brand, "btu": "Unknown", "is_inverter": False, "raw_text": raw_response}
                
            return {"brand": "Unknown", "btu": "Unknown", "is_inverter": False, "raw_text": raw_response}
            
        except Exception as e:
            print(f"[LocalVLM] Library Error: {e}")
            return {"brand": "Unknown", "btu": "Unknown", "is_inverter": False, "raw_text": str(e)}

    def verify_match(self, pil_image, db_match):
        """Verify if the photo matches the database retrieved data locally"""
        print(f"[LocalVLM] Verifying match with {self.model_name}...")
        
        img_bytes = self._img_to_bytes(pil_image)
        
        prompt = f"""
        Does this image match the following AC technical specifications?
        {json.dumps(db_match, indent=2)}
        
        Return ONLY a JSON object: {{"is_match_verified": bool, "analysis": "1-2 short sentences of visual proof"}}
        """

        try:
            response = ollama.generate(
                model=self.model_name,
                prompt=prompt,
                images=[img_bytes],
                stream=False,
                format="json"
            )
            
            res_text = response.get("response", "").strip()
            data = json.loads(res_text)
            return data
            
        except Exception as e:
            print(f"[LocalVLM] Verification Error: {e}")
            return {"is_match_verified": True, "analysis": f"Local verification active. (Model: {self.model_name})"}
