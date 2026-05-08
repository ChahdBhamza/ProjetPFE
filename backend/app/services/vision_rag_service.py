import os
import json
import time
import random
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv()

class VisionRAGService:
    def __init__(self, api_key: str = None):
        """Initialize Gemini Client"""
        self.api_key = api_key or os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError("GOOGLE_API_KEY not found. Please check your .env file.")
        
        # Use v1beta to access the newest models (3.1, 2.5, etc.)
        self.client = genai.Client(api_key=self.api_key, http_options={'api_version': 'v1beta'})
        # Use stable models that are widely available
        self.models_to_try = [
            'gemini-1.5-flash',
            'gemini-2.0-flash',
            'gemini-1.5-flash-8b',
            'gemini-1.5-pro'
        ]

    def _extract_json(self, text: str) -> dict:
        """Robustly extract JSON from model response"""
        if not text:
            return {"error": "Empty response text from model"}
        
        # Clean markdown code blocks
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        
        text = text.strip()
        
        try:
            return json.loads(text)
        except json.JSONDecodeError as e:
            return {"error": "Failed to parse JSON", "raw_text": text, "exception": str(e)}

    def verify_equipment(self, image_data, best_match: dict, similarity_score: float):
        """Perform Visual RAG verification with Gemini"""
        
        # Structured Forensic Verification Prompt
        prompt = f"""You are a High-Precision Forensic Validator. 
Your task is to verify if the physical object in the photo is EXACTLY the same model as the database entry provided.

DATABASE MATCH DATA:
{json.dumps(best_match, indent=2, ensure_ascii=False)}

VALIDATION PROTOCOL:
1. PHYSICAL AUDIT: Compare the visual features (vents, buttons, display type) with the database description.
2. DISCREPANCY CHECK: Look for any "Red Flags" (e.g., the DB says 'Inverter' but the photo shows a standard label).
3. SERIAL/MODEL MATCH: If a model code is visible, does it match or belong to the same series as the DB entry?
4. LOGO PLACEMENT: Is the brand logo positioned exactly where it should be for this specific brand?

Return ONLY a JSON object:
{{
  "brand": "string",
  "model_identifier": "string",
  "category": "string",
  "specs": {{
     "capacity": "extracted capacity",
     "energy_class": "extracted class (A++, etc)",
     "is_inverter": "boolean | null",
     "additional_features": "string"
  }},
  "analysis": "Provide a 3-step forensic reasoning: 1. Logo check, 2. Feature match, 3. Final verdict.",
  "is_match_verified": boolean (True ONLY if Brand and Capacity match),
  "confidence": number (0.0-1.0)
}}"""

        config = types.GenerateContentConfig(
            tools=[{"google_search": {}}],
            max_output_tokens=1024,
            temperature=0.7
        )

        max_retries = 5
        retry_delay = 10
        last_error = ""

        for model_name in self.models_to_try:
            print(f"[VisionRAG] Attempting with model: {model_name}")
            
            for attempt in range(max_retries):
                try:
                    # Correctly wrap the image bytes for the GenAI SDK
                    image_part = types.Part.from_bytes(data=image_data, mime_type="image/jpeg")
                    
                    response = self.client.models.generate_content(
                        model=model_name,
                        contents=[prompt, image_part],
                        config=config
                    )

                    if not response or not response.text:
                        raise ValueError("Gemini returned an empty response.")

                    result = self._extract_json(response.text)
                    
                    # Extract grounding sources if available
                    sources = []
                    try:
                        if response.candidates and response.candidates[0].grounding_metadata:
                            meta = response.candidates[0].grounding_metadata
                            if meta.grounding_chunks:
                                for chunk in meta.grounding_chunks:
                                    if chunk.web:
                                        sources.append({"title": chunk.web.title, "url": chunk.web.uri})
                    except:
                        pass
                    
                    result["verification_sources"] = sources
                    return result

                except Exception as e:
                    error_msg = str(e).lower()
                    last_error = str(e)
                    
                    if ("503" in error_msg or "unavailable" in error_msg or "429" in error_msg) and attempt < max_retries - 1:
                        wait_time = retry_delay + random.uniform(0, 1)
                        print(f"[VisionRAG] Quota hit on {model_name}, retrying in {int(wait_time)}s... (Attempt {attempt+1})")
                        time.sleep(wait_time)
                        retry_delay *= 2
                    else:
                        print(f"[VisionRAG] Model {model_name} failed: {e}")
                        break # Move to next model
        
    def identify_with_dual_vision(self, color_image_data, gray_image_data):
        """Analyze both Color (Design DNA) and Grayscale (Specs) in one pass with robust failover"""
        prompt = """You are a Master Industrial Design Analyst.
I am providing two views of the same equipment:
1. COLOR VIEW: Use this to identify Brand Design Language, Logo Colors, and Physical DNA (handles, hinges, finish).
2. FORENSIC VIEW: Use this high-contrast view to read small alphanumeric text or technical labels.

STRICT PROTOCOL:
- IDENTIFY BRAND: Use your internal knowledge of product design. Does the handle shape match Samsung? Does the silver finish match LG?
- READ SPECS: Look for BTU, Model Codes, or Capacity in the Forensic View.
- REASONING: Explain which visual cues led you to the brand.

Return ONLY JSON:
{
  "category": "string",
  "brand": "string | null",
  "btu": "string | null",
  "model_reference": "string | null",
  "confidence": 0.0-1.0,
  "analysis": "Provide a 2-step reason: 1. Physical DNA analysis, 2. Label/Sticker confirmation."
}"""
        
        max_retries = 3
        retry_delay = 5

        for model_name in self.models_to_try:
            print(f"[VisionRAG] Dual-Vision attempting with: {model_name}")
            for attempt in range(max_retries):
                try:
                    # Resize images to be smaller to save tokens
                    from PIL import Image
                    from io import BytesIO
                    
                    def resize_for_ai(data, size=(800, 800)):
                        img = Image.open(BytesIO(data))
                        img.thumbnail(size)
                        out = BytesIO()
                        img.save(out, format="JPEG", quality=70)
                        return out.getvalue()

                    color_small = resize_for_ai(color_image_data)
                    gray_small = resize_for_ai(gray_image_data)

                    color_part = types.Part.from_bytes(data=color_small, mime_type="image/jpeg")
                    gray_part = types.Part.from_bytes(data=gray_small, mime_type="image/jpeg")
                    
                    response = self.client.models.generate_content(
                        model=model_name,
                        contents=[prompt, color_part, gray_part]
                    )
                    return self._extract_json(response.text)
                except Exception as e:
                    error_msg = str(e).lower()
                    if ("404" in error_msg):
                        print(f"[VisionRAG] Model {model_name} not found, trying next...")
                        break # Try next model
                    if ("429" in error_msg or "503" in error_msg) and attempt < max_retries - 1:
                        print(f"[VisionRAG] Quota hit on {model_name}, waiting {retry_delay}s...")
                        time.sleep(retry_delay)
                        retry_delay *= 2
                    else:
                        print(f"[VisionRAG] Model {model_name} failed: {e}")
                        break
        
        return {"brand": "Unknown", "category": "Equipment", "analysis": "All models exhausted."}

    def identify_from_raw_image(self, image_data):
        """High-Precision Visual Identification for RAG filtering"""
        max_retries = 3
        retry_delay = 5

        for model_name in self.models_to_try:
            print(f"[VisionRAG] Identification attempting with: {model_name}")
            for attempt in range(max_retries):
                try:
                    img_part = types.Part.from_bytes(data=image_data, mime_type="image/jpeg")
                    response = self.client.models.generate_content(
                        model=model_name,
                        contents=[prompt, img_part]
                    )
                    return self._extract_json(response.text)
                except Exception as e:
                    error_msg = str(e).lower()
                    if "404" in error_msg:
                        print(f"[VisionRAG] Model {model_name} not found, trying next...")
                        break
                    if ("429" in error_msg or "503" in error_msg) and attempt < max_retries - 1:
                        print(f"[VisionRAG] Quota hit on {model_name}, waiting {retry_delay}s...")
                        time.sleep(retry_delay)
                        retry_delay *= 2
                    else:
                        print(f"[VisionRAG] Model {model_name} failed: {e}")
                        break

        return {"brand": "Unknown", "category": "Equipment", "analysis": "All models exhausted."}
