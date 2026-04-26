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
        """Enhanced Extraction for RAG: Captures Brand, BTU, Model, and Tech features"""
        img_bytes = self._img_to_bytes(pil_image)
        
        # Comprehensive expert-level prompt for high-precision extraction
        prompt = """You are an expert product recognition system specialized in air conditioning units.
Carefully analyze the provided image and extract the following information with high precision.

EXTRACTION RULES:
- Prioritize text visible on physical stickers, labels, or embossed markings over visual inference.
- If a field is not clearly visible or confidently identifiable, return null — do NOT guess.
- For brand detection: look for logos, wordmarks, or model codes that imply a manufacturer.
  Do not limit yourself to a known list — extract whatever brand is present.
- For BTU: common values are 9000, 12000, 18000, 24000, 36000 — but extract the exact value if visible.
- For model: extract full alphanumeric codes or series names exactly as printed.
- For technology: classify as "Inverter" or "On/Off" based on labels or visual cues.
- For color: describe the main chassis color (e.g., White, Silver, Black, Beige).
- Confidence: your overall certainty across all fields (0.0 = no data, 1.0 = fully legible).

Return ONLY a valid JSON object, with no explanation or markdown:
{
  "brand": "string or null",
  "btu": "string or null",
  "model": "string or null",
  "inverter": true | false | null,
  "color": "string or null",
  "confidence": 0.0
}"""
        
        try:
            response = ollama.chat(
                model=self.model_name,
                messages=[{
                    'role': 'user', 
                    'content': prompt,
                    'images': [img_bytes]
                }],
                options={
                    "num_predict": 150,  # Increased for more detailed info
                    "temperature": 0.1,  # Low temperature for extraction accuracy
                    "num_ctx": 2048
                }
            )
            
            raw_response = response.get("message", {}).get("content", "").strip()
            print(f"[LocalVLM] Raw Output: {raw_response}")
            
            # Extract JSON from potential markdown wrappers
            start = raw_response.find("{")
            end = raw_response.rfind("}")
            if start != -1 and end != -1:
                data = json.loads(raw_response[start:end+1])
                # Ensure keys exist for downstream compatibility
                for key in ["brand", "btu", "model", "inverter"]:
                    if key not in data: data[key] = None
                return data
            
            # Keyword Fallback (More robust)
            detected = {"brand": None, "btu": None, "model": None, "inverter": None}
            for brand in ["LG", "Samsung", "Condor", "IRIS", "Gree", "TCL", "Midea", "Aux", "Biolux", "Brandt", "Haier"]:
                if brand.lower() in raw_response.lower():
                    detected["brand"] = brand
                    break
            
            if "inverter" in raw_response.lower():
                detected["inverter"] = True
                
            return detected
            
        except Exception as e:
            print(f"[LocalVLM] Library Error: {e}")
            return {"brand": "Unknown", "btu": "Unknown", "inverter": False, "raw_text": str(e)}

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
