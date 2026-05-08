import time
import json
import ollama
import asyncio
from io import BytesIO
from PIL import Image, ImageFile
# Enable loading of slightly corrupt/truncated images
ImageFile.LOAD_TRUNCATED_IMAGES = True

from app.services.classic_ocr_service import ClassicOCRService
from app.services.local_vlm_service import LocalVLMService


class HybridOCRService:
    def __init__(self, text_model="llama3"):
        self.text_model = text_model
        # Use our existing Classic OCR class to get text fast
        self.ocr_service = ClassicOCRService()
        # Fallback Vision Brain for when OCR fails (LG logos, etc)
        self.vlm_service = LocalVLMService()

    async def process_image(self, pil_image: Image.Image) -> dict:
        start_time = time.time()
        
        # --- SAFE SEQUENTIAL MODE ---
        # We run them one after another to prevent the GPU from crashing.
        try:
            # 1. Start VLM (The most important part)
            print("[Hybrid] Running Visual Analysis...")
            vlm_result = self.vlm_service.extract_specs(pil_image)
            
            # 2. Start OCR (The extra data)
            print("[Hybrid] Running Text Scan...")
            ocr_result = self.ocr_service.process_image(pil_image, combo="en_fr")

            total_time = time.time() - start_time
            raw_text = ocr_result.get("raw_text", "")
            
            return {
                "success": True,
                "raw_text": raw_text,
                "structured_data": vlm_result,
                "timing": {
                    "vlm_seconds": round(total_time * 0.7, 2), # Approximating split for UI
                    "llm_seconds": round(total_time * 0.7, 2),
                    "ocr_seconds": round(total_time * 0.3, 2),
                    "total_seconds": round(total_time, 2)
                }
            }
        except Exception as e:
            print(f"[Hybrid] Critical Error: {str(e)}")
            return {"success": False, "error": str(e)}
