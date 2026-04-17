import time
import json
import ollama
from pathlib import Path
from PIL import Image
from app.services.classic_ocr_service import ClassicOCRService

class HybridOCRAnalyzer:
    def __init__(self, text_model="llama3:latest"):
        self.text_model = text_model
        print("[Hybrid] Booting up Classic OCR (EasyOCR)...")
        self.ocr_service = ClassicOCRService()

    def extract_specs(self, image_path: str):
        # 1. Start the clock
        start_time = time.time()
        
        print("\n==================================")
        print(f"Testing Hybrid Pipeline on: {Path(image_path).name}")
        print("==================================\n")

        # 2. Run Classic OCR (Fast pass)
        print(">> STEP 1: Running Classic OCR extraction...")
        pil_image = Image.open(image_path)
        
        ocr_start = time.time()
        ocr_result = self.ocr_service.process_image(pil_image, combo="ar_fr") # Dual-pass Auto
        raw_text = ocr_result.get("raw_text", "")
        ocr_time = time.time() - ocr_start
        
        print(f"[Done - {ocr_time:.2f}s]")
        print("Raw OCR Output:")
        print("---")
        # Safely print on Windows terminal
        try:
            print(raw_text)
        except UnicodeEncodeError:
            print("[Raw text contains Arabic/Unicode characters that the Windows console cannot print natively. Proceeding...]")
        print("---\n")

        if not raw_text or "rror" in raw_text:
            return {"error": "OCR failed to find text."}

        # 3. Structure the data using a very fast, text-only LLM
        print(f">> STEP 2: Running Text LLM ({self.text_model}) for JSON parsing...")
        llm_start = time.time()

        prompt = f"""You are an advanced Text Parser. 
I am going to give you raw, messy OCR text retrieved from an air conditioner label. 

Your task is to extract the following attributes exactly as they appear, formatted as JSON:
- brand (String)
- btu (Number)
- extra_info (String: Any features like "Inverter", "Smart", "Chaud Froid")

Raw OCR Text:
{raw_text}

Return ONLY valid JSON (no markdown formatting, no explanations). Use null if something is missing.
"""

        try:
            response = ollama.chat(
                model=self.text_model,
                messages=[{'role': 'user', 'content': prompt}]
            )
            # Clean up the output string, sometimes LLMs wrap JSON in ```json blocks
            response_text = response['message']['content']
            clean_str = response_text.replace("```json", "").replace("```", "").strip()
            
            structured_data = json.loads(clean_str)
            llm_time = time.time() - ocr_start
            print(f"[Done - {llm_time:.2f}s]")
            
        except Exception as e:
            print(f"[LLM Error] Parser failed: {e}")
            structured_data = {"error": "Text LLM Parsing failed", "raw": raw_text}

        # 4. End clock
        total_time = time.time() - start_time
        
        print("\n>> FINAL OUTPUT:")
        print(json.dumps(structured_data, indent=2, ensure_ascii=True))
        print(f"\n==================================")
        print(f"Total Pipeline Execution Time: {total_time:.2f} seconds")
        print("==================================")
        
        return structured_data

if __name__ == "__main__":
    import sys
    
    # Path to one of the test images
    base_dir = Path(__file__).parent.parent / "dataequipment" / "climatiseurs"
    test_image = base_dir / "Condor" / "images" / "Climatiseur Condor Alpha 12000 BTU Inverter Tropical Chaud Froid Blanc.jpg"
    
    if not test_image.exists():
        print(f"Cannot find default test image at {test_image}")
        sys.exit(1)

    # Use llama3 for testing structure. You can switch this to whatever you run fast locally (like gemma, phi3)
    tester = HybridOCRAnalyzer(text_model="qwen2.5:3b") # Using qwen2.5:3b text mode since we know you have qwen locally
    tester.extract_specs(str(test_image))
