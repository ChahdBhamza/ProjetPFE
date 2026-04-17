import time
import json
import ollama
from io import BytesIO
from PIL import Image
from app.services.classic_ocr_service import ClassicOCRService

class HybridOCRService:
    def __init__(self, text_model="qwen2.5:3b"):
        self.text_model = text_model
        # Use our existing Classic OCR class to get text fast
        self.ocr_service = ClassicOCRService()

    def process_image(self, pil_image: Image.Image) -> dict:
        start_time = time.time()
        
        # --- STEP 1: FAST CLASSIC OCR ---
        # Run English and French OCR for higher context coverage
        ocr_result = self.ocr_service.process_image(pil_image, combo="en_fr")
        raw_text = ocr_result.get("raw_text", "")
        
        if not raw_text or raw_text == "No text found.":
            return {
                "success": False, 
                "error": "Classic OCR couldn't detect any text to parse."
            }
            
        step1_time = time.time() - start_time

        # --- STEP 2: FAST TEXT LLM ---
        llm_start = time.time()
        prompt = f"""You are a strict Data Extractor. 
Read this messy OCR text from an AC unit. Ignore all random noise and numbers.
Your ONLY job is to extract the BRAND of the air conditioner.

Raw OCR Text:
{raw_text}

Respond ONLY with valid JSON exactly in this format. Example:
{{"brand": "Condor"}}
"""
        reply = "No response"
        try:
            # Note: We are using the exact model name from your VLM, as vision models can also process text perfectly.
            response = ollama.chat(
                model='qwen2.5vl:3b',
                messages=[{'role': 'user', 'content': prompt}]
            )
            
            # Clean JSON wrapping
            reply = response.get('message', {}).get('content', '')
            clean_str = reply.replace("```json", "").replace("```", "").strip()
            
            structured_data = json.loads(clean_str)
            
        except Exception as e:
            structured_data = {"error": f"LLM parsing failed: {str(e)}", "raw_reply": reply}

        total_time = time.time() - start_time
        
        return {
            "success": True,
            "raw_text": raw_text,
            "structured_data": structured_data,
            "timing": {
                "ocr_seconds": round(step1_time, 2),
                "llm_seconds": round(time.time() - llm_start, 2),
                "total_seconds": round(total_time, 2)
            }
        }
