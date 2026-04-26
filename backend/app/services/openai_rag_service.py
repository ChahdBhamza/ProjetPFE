import os
import json
import base64
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

class OpenAIRAGService:
    def __init__(self, api_key: str = None):
        """Initialize OpenAI Service Settings"""
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        self._client = None
        self.model = "gpt-4o" 

    @property
    def client(self):
        """Lazy load OpenAI client only when needed"""
        if self._client is None:
            if not self.api_key:
                raise ValueError("OpenAI API Key is missing. Please check your .env file.")
            self._client = OpenAI(api_key=self.api_key)
        return self._client

    def _encode_image(self, image_data):
        """Encode binary image data to base64 string"""
        return base64.b64encode(image_data).decode('utf-8')

    def verify_ac_unit(self, image_data, best_match: dict, similarity_score: float):
        """Perform Visual RAG verification with GPT-4o"""
        if not self.api_key:
            return {"error": "OpenAI API Key missing"}

        base64_image = self._encode_image(image_data)
        
        prompt = f"""
        Extract technical AC specifications from the image. Compare it with the retrieved DB match.
        Return ONLY a JSON object.

        Input Context (Retrieved DB Match):
        {json.dumps(best_match, indent=2, ensure_ascii=False)}
        (Visual similarity score: {similarity_score})

        Required JSON structure:
        {{
          "brand": "string",
          "model_identifier": "string",
          "btu_rating": "string",
          "energy_class": "string",
          "analysis": "Detailed visual reasoning (2-3 sentences)",
          "is_match_verified": boolean,
          "discrepancies": ["list of differences if any"]
        }}
        """

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ],
                response_format={ "type": "json_object" },
                max_tokens=1024
            )

            return json.loads(response.choices[0].message.content)
        except Exception as e:
            print(f"[OpenAI RAG] Error: {e}")
            return {"error": str(e), "is_match_verified": False}

    def identify_from_raw_image(self, image_data):
        """Pure Visual Identification for RAG filtering"""
        base64_image = self._encode_image(image_data)
        
        prompt = """You are an Expert HVAC Forensic Analyst. Your task is to decode the technical specifications from the image.

EXTRACTION STRATEGY:
1. BRAND: Identify the manufacturer (e.g., GREE, LG, Samsung, Condor, Iris). Look for stylized logos or embossed text.
2. BTU: Extract capacity (9, 12, 18, 24) or decode from model strings.
3. MODEL REFERENCE: Extract the alphanumeric reference exactly as printed on the label.
4. SERIES: Identify marketing series names (e.g., 'Artcool', 'Pular').

STRICT RULES:
- Focus on pixel-perfect reading of labels and logos.
- If the brand is not 100% identifiable, return null. DO NOT GUESS.
- Return ONLY JSON.

JSON STRUCTURE:
{
  "brand": "string | null",
  "btu": "string | null",
  "model_reference": "string | null",
  "series_name": "string | null",
  "technology": "string | null",
  "confidence": 0.0,
  "visual_markers": ["list labels found"]
}"""
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ],
                response_format={ "type": "json_object" }
            )
            return json.loads(response.choices[0].message.content)
        except Exception as e:
            print(f"[OpenAI RAG] Raw identification failed: {e}")
            return {"brand": None, "model_reference": None, "btu": None}
