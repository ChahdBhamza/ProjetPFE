import os
import json
import base64
import cv2
import numpy as np
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

class VisionRAGService:
    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=self.api_key,
            default_headers={
                "HTTP-Referer": "http://localhost:8000",
                "X-Title": "Cybersight Forensic Lab",
            }
        )
        self.model = "google/gemini-flash-1.5"

    def enhance_crop_for_ocr(self, crop: np.ndarray) -> np.ndarray:
        """From SFM Project: Enhance brand/logo visibility using CLAHE and upscaling."""
        h, w = crop.shape[:2]
        target_min = 800
        if min(h, w) < target_min:
            scale = target_min / min(h, w)
            crop = cv2.resize(crop, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_LANCZOS4)

        lab = cv2.cvtColor(crop, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
        l = clahe.apply(l)
        enhanced = cv2.merge([l, a, b])
        enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)

        kernel = np.array([[0, -0.5, 0], [-0.5, 3, -0.5], [0, -0.5, 0]])
        enhanced = cv2.filter2D(enhanced, -1, kernel)
        return np.clip(enhanced, 0, 255).astype(np.uint8)

    def process_with_sfm_logic(self, image_path: str, roboflow_bbox: dict):
        """Analyze using the SFM Dual-Image Protocol (Full Scene + Enhanced Crop)."""
        
        frame = cv2.imread(image_path)
        if frame is None: return {"brand": "Unknown"}

        # 1. Extract Crop using Roboflow Coordinates
        try:
            # Roboflow usually returns center_x, center_y, width, height or x,y,w,h
            # We'll adjust based on typical Roboflow format
            x = int(roboflow_bbox.get('x', 0) - roboflow_bbox.get('width', 0)/2)
            y = int(roboflow_bbox.get('y', 0) - roboflow_bbox.get('height', 0)/2)
            w = int(roboflow_bbox.get('width', 0))
            h = int(roboflow_bbox.get('height', 0))
            
            # Boundary checks
            x, y = max(0, x), max(0, y)
            crop = frame[y:y+h, x:x+w]
            enhanced_crop = self.enhance_crop_for_ocr(crop)
        except Exception as e:
            print(f"⚠️ Crop failed, using full frame: {e}")
            enhanced_crop = frame

        # 2. Encode both images
        def to_b64(img):
            _, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 90])
            return base64.b64encode(buf).decode("utf-8")

        b64_full = to_b64(frame)
        b64_crop = to_b64(enhanced_crop)

        # 3. SFM Vision Prompt
        prompt = """You are an Industrial Forensic Analyst. 
        Identify the brand and model from these two images:
        1. FULL SCENE (context)
        2. ENHANCED CROP (for reading logos and labels)

        Return ONLY JSON:
        {
          "brand": "string | null",
          "model_reference": "string | null",
          "category": "string",
          "confidence": 0-100,
          "analysis": "Reasoning based on visible logos/text."
        }"""

        try:
            print(f"🧠 [SFM-Logic] Forensic Scan with {self.model}...")
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[{
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_full}"}},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_crop}"}}
                    ]
                }],
                temperature=0.1
            )
            return self._extract_json(response.choices[0].message.content.strip())
        except Exception as e:
            print(f"❌ SFM Vision Error: {e}")
            return {"brand": "Unknown", "error": str(e)}

    def _extract_json(self, text: str) -> dict:
        try:
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0]
            elif "```" in text:
                text = text.split("```")[1].split("```")[0]
            return json.loads(text.strip())
        except:
            return {"error": "JSON failed", "raw": text}
