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
        
        self.client = genai.Client(api_key=self.api_key)
        # Use stable models that are widely available
        self.models_to_try = [
            'gemini-2.5-flash',
            'gemini-2.0-flash'
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
        
        # Structured Prompt
        prompt = f"""
        Extract technical specifications from the image of the equipment. 
        It could be an Air Conditioner, Refrigerator, Microwave, Laptop, or Printer.
        Return ONLY a JSON object. NO preamble. NO conversational text.
        
        Input Context (Retrieved DB Match):
        {json.dumps(best_match, indent=2, ensure_ascii=False)}
        (Visual similarity score: {similarity_score})

        Required JSON structure:
        {{
          "brand": "string",
          "model_identifier": "string",
          "category": "string",
          "specs": {{
             "capacity": "string (BTU/Litres/Watts as applicable)",
             "energy_class": "string",
             "additional": "string"
          }},
          "analysis": "2-3 sentences of visual reasoning based on pixels",
          "is_match_verified": boolean,
          "confidence": number (0.0-1.0)
        }}
        """

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
        
    def identify_from_raw_image(self, image_data):
        """High-Precision Visual Identification for RAG filtering"""
        # Using Gemini 2.5 for futuristic accuracy
        model_name = 'gemini-2.5-flash' 
        
        prompt = """You are a Forensic Equipment Analyst.
Your mission is to identify the CATEGORY and BRAND of the equipment in the image with 100% precision.

TARGET CATEGORIES:
1. Refrigerator
2. Air Conditioner
3. Microwave
4. Laptop
5. Printer

STRICT PROTOCOL:
1. IDENTIFY CATEGORY: Determine which of the 5 categories the item belongs to.
2. LOGO INSPECTION: Look specifically for brand wordmarks (Samsung, LG, Dell, HP, Epson, Gree, Midea, etc). 
3. TECHNICAL SPECS:
   - For AC/Fridge: Look for BTU, Model Code, or Capacity in Litres.
   - For Laptop/Printer: Look for Model Series (e.g., Latitude, ThinkPad, LaserJet).
   - For Microwave: Look for Wattage or Model.

Return ONLY JSON:
{
  "category": "string",
  "brand": "string | null",
  "btu": "string | null",
  "model_reference": "string | null",
  "confidence": 0.0-1.0,
  "analysis": "Describe the EXACT visual evidence (e.g., 'Saw the HP logo on the laptop lid')"
}

If you are not 80% sure about the brand, return "brand": null."""
        try:
            # Correctly wrap the image bytes
            image_part = types.Part.from_bytes(data=image_data, mime_type="image/jpeg")
            
            response = self.client.models.generate_content(
                model=model_name,
                contents=[prompt, image_part]
            )
            return self._extract_json(response.text)
        except Exception as e:
            print(f"[VisionRAG] Raw identification failed: {e}")
            return {"brand": "Unknown", "model": "Unknown", "btu": "Unknown"}
