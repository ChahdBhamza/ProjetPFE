
import os
import requests
import base64
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

class RoboflowService:
    def __init__(self, api_key=None, workspace=None):
        self.api_key = api_key or os.getenv("ROBOFLOW_API_KEY", "oesPLELo2uEPnMKXp8dM")
        self.workspace = workspace or os.getenv("ROBOFLOW_WORKSPACE", "devileyess-workspace")
        self.base_url = "https://serverless.roboflow.com"

    def detect(self, image: Image.Image, workflow_id="detect-count-and-visualize"):
        """
        Run a Roboflow workflow on a PIL image using raw HTTP requests (Python 3.13 compatible).
        """
        # Convert PIL to Base64
        buffered = BytesIO()
        image.save(buffered, format="JPEG")
        img_base64 = base64.b64encode(buffered.getvalue()).decode("utf-8")

        # Using the Serverless endpoint as per the user's working script
        url = f"https://serverless.roboflow.com/{self.workspace}/workflows/{workflow_id}"
        
        payload = {
            "api_key": self.api_key,
            "inputs": {
                "image": {
                    "type": "base64",
                    "value": img_base64
                }
            }
        }

        print(f"🚀 Calling Roboflow Workflow: {workflow_id}...")
        response = requests.post(url, json=payload)
        
        # Log status for debugging
        print(f"📡 Roboflow Response Status: {response.status_code}")

        if response.status_code == 200:
            res_json = response.json()
            print(f"✅ Roboflow Response: {str(res_json)[:500]}...") # Print first 500 chars
            
            # Normalize response (Workflow API returns {'outputs': [...]})
            if "outputs" in res_json and len(res_json["outputs"]) > 0:
                output = res_json["outputs"][0]
                # Combine predictions and annotated image into a flat dict
                normalized = {
                    "detections": output.get("predictions", output.get("detections", [])),
                    "image": output.get("annotated_image", {}).get("value")
                }
                # Support nested predictions (some workflows return {'predictions': {'predictions': [...]}})
                if isinstance(normalized["detections"], dict) and "predictions" in normalized["detections"]:
                    normalized["detections"] = normalized["detections"]["predictions"]
                
                return normalized
                
            return res_json
        
        if response.status_code == 500 and workflow_id == "detect-count-and-visualize":
            print("⚠️ Workflow failed with 500. Attempting direct model inference fallback...")
            # Try direct inference on version 2 as a last resort
            direct_model_id = "find-airconditioner-and-air-conditioner-detect/2"
            url = f"https://detect.roboflow.com/{direct_model_id}"
            params = {"api_key": self.api_key}
            print(f"🔄 Trying alternative version: {direct_model_id}...")
            response = requests.post(url, data=img_base64, params=params, headers={"Content-Type": "application/x-www-form-urlencoded"})
            print(f"📡 Version 2 Response Status: {response.status_code}")
            
            if response.status_code == 200:
                res_json = response.json()
                return {
                    "detections": res_json.get("predictions", []),
                    "image": None
                }

        if response.status_code != 200:
            print(f"❌ Roboflow Error: {response.text}")
            return {"error": f"Roboflow API failed: {response.status_code}", "details": response.text}

        data = response.json()
        
        try:
            # The API might return a list or a dictionary with 'outputs'
            if isinstance(data, list):
                result_entry = data[0]
            else:
                outputs = data.get("outputs", [])
                if not outputs:
                    return {"detections": [], "raw": data}
                result_entry = outputs[0]
                
            predictions = result_entry.get("predictions", {})
            if isinstance(predictions, dict):
                predictions = predictions.get("predictions", [])
            
            detections = []
            for pred in predictions:
                # Roboflow coordinates are center-based (x, y, width, height)
                x = pred["x"]
                y = pred["y"]
                w = pred["width"]
                h = pred["height"]
                
                # Convert to x1, y1, x2, y2
                x1 = x - w / 2
                y1 = y - h / 2
                x2 = x + w / 2
                y2 = y + h / 2
                
                detections.append({
                    "class": pred["class"],
                    "confidence": pred["confidence"],
                    "bbox": [x1, y1, x2, y2]
                })
            
            return {"detections": detections, "raw": data}
            
        except Exception as e:
            print(f"⚠️ Parsing Error: {e}")
            return {"error": "Failed to parse Roboflow response", "raw": data}

    def draw_detections(self, image: Image.Image, detections: list):
        """
        Draw bounding boxes using PIL (similar to the user's script).
        """
        draw = ImageDraw.Draw(image)
        try:
            # Try to load a font, fallback to default
            font = ImageFont.load_default()
        except:
            font = None

        for idx, det in enumerate(detections):
            x1, y1, x2, y2 = det["bbox"]
            label = f"{det['class']} {det['confidence']:.1%}"
            
            # Draw rectangle
            draw.rectangle((x1, y1, x2, y2), outline="red", width=5)
            
            # Draw label background
            draw.rectangle((x1, y1 - 25, x1 + 200, y1), fill="red")
            
            # Draw text
            draw.text((x1 + 5, y1 - 20), label, fill="white", font=font)
            
        return image
