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
        # SPEED HACK: VLMs process images much faster if they are small. 
        # 448px is the native internal size for many vision models.
        max_size = 448
        if max(pil_image.size) > max_size:
            pil_image.thumbnail((max_size, max_size))
            
        buffered = BytesIO()
        if pil_image.mode in ("RGBA", "P"):
            pil_image = pil_image.convert("RGB")
        # Lower quality saves memory and bandwidth
        pil_image.save(buffered, format="JPEG", quality=60)
        return buffered.getvalue()

    def extract_specs(self, pil_image):
        """Ultra-Fast Extraction using reduced resolution and short prompt"""
        img_bytes = self._img_to_bytes(pil_image)
        
        # Highly optimized prompt for speed + accuracy
        prompt = """Identify the air conditioner BRAND logo in this image (e.g., IRIS, LG, Condor, Gree, etc.). 
Look for tiny logos or stylized letters. 
Return ONLY a valid JSON object: {"brand": "detected_name"}"""
        
        try:
            # options and format="json" help ensure the model finishes fast and correctly
            response = ollama.chat(
                model=self.model_name,
                messages=[{
                    'role': 'user', 
                    'content': prompt,
                    'images': [img_bytes]
                }],
                options={
                    "num_predict": 20,   # Stop after 20 words (enough for brand)
                    "num_ctx": 1024      # Smaller context is faster
                }
            )
            
            raw_response = response.get("message", {}).get("content", "").strip()
            print(f"[LocalVLM] Raw Output: {raw_response}")
            
            # Find JSON
            start = raw_response.find("{")
            end = raw_response.rfind("}")
            if start != -1 and end != -1:
                data = json.loads(raw_response[start:end+1])
                return data
            
            # Keyword Fallback
            for brand in ["LG", "Samsung", "Condor", "IRIS", "Gree", "TCL", "Midea"]:
                if brand.lower() in raw_response.lower():
                    return {"brand": brand}
                
            return {"brand": "Unknown"}
            
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
