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
        # Primary models to try if the main one fails
        self.models_to_try = [
            'gemini-2.5-flash',
            'gemini-1.5-flash',
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

    def verify_ac_unit(self, image_data, best_match: dict, similarity_score: float):
        """Perform Visual RAG verification with Gemini"""
        
        # Structured Prompt
        prompt = f"""
        Extract technical AC specifications from the image. Return ONLY a JSON object. 
        NO preamble. NO conversational text.

        Input Context (Retrieved DB Match):
        {json.dumps(best_match, indent=2, ensure_ascii=False)}
        (Visual similarity score: {similarity_score})

        Required JSON structure:
        {{
          "brand": "string",
          "model_identifier": "string",
          "btu_rating": "string",
          "energy_class": "string",
          "analysis": "2-3 sentences of visual reasoning based on pixels",
          "is_match_verified": boolean
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
                    response = self.client.models.generate_content(
                        model=model_name,
                        contents=[prompt, image_data],
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
        
        return {"error": "All models failed", "last_error": last_error}
