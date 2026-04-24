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
        """Pre-Search Visual Identification to guide the RAG filters"""
        base64_image = self._encode_image(image_data)
        
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
            return {"brand": None, "model": None, "btu": None}
