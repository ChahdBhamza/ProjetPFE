import requests
import base64
import os
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

class WorkflowService:
    def __init__(self):
        self.api_key = "oesPLELo2uEPnMKXp8dM"
        self.workspace = "devileyess-workspace"
        self.workflow_id = "custom-workflow-2"
        # Using the EXACT URL pattern that works for your other workflow
        self.api_url = f"https://serverless.roboflow.com/{self.workspace}/workflows/{self.workflow_id}"

    def run_specialized_workflow(self, image_path: str):
        try:
            # 1. Read and encode image (No prefix needed for this endpoint)
            img = Image.open(image_path).convert("RGB")
            buffered = BytesIO()
            img.save(buffered, format="JPEG")
            img_b64 = base64.b64encode(buffered.getvalue()).decode("utf-8")
            
            # 2. Prepare payload
            payload = {
                "api_key": self.api_key,
                "inputs": {
                    "image": {
                        "type": "base64",
                        "value": img_b64
                    }
                }
            }
            
            # 3. Call Roboflow API using requests
            response = requests.post(self.api_url, json=payload)
            if response.status_code != 200:
                print(f"Error: {response.text}")
                response.raise_for_status()
                
            workflow_res = response.json()
            
            print("\n" + "="*50)
            print("🚀 RAW ROBOFLOW WORKFLOW RESPONSE:")
            import json
            print(json.dumps(workflow_res, indent=2))
            print("="*50 + "\n")
            
            display_b64 = None
            found_ai = False
            raw_output_data = workflow_res
            
            # 4. Parse Results
            if "outputs" in workflow_res and len(workflow_res["outputs"]) > 0:
                output = workflow_res["outputs"][0]
                
                # If there's an annotated image returned natively, use it
                if "annotated_image" in output and "value" in output["annotated_image"]:
                    display_b64 = output["annotated_image"]["value"]
                    found_ai = True
                
                # Otherwise, we DRAW IT OURSELVES (This is how we fixed the other workflow!)
                else:
                    predictions = output.get("predictions", output.get("detections", []))
                    if isinstance(predictions, dict) and "predictions" in predictions:
                        predictions = predictions["predictions"]
                        
                    if predictions and isinstance(predictions, list) and len(predictions) > 0:
                        print("Drawing manual boxes...")
                        display_b64 = self.draw_manual_boxes(img, predictions)
                        found_ai = True
                        raw_output_data = predictions

            return {
                "success": True,
                "raw_image": img_b64,
                "ai_image": display_b64,
                "has_ai": found_ai,
                "raw_output": raw_output_data
            }
            
        except Exception as e:
            print(f"Workflow Error: {e}")
            try:
                with open(image_path, "rb") as f:
                    img_b64 = base64.b64encode(f.read()).decode('utf-8')
                return {"success": False, "raw_image": img_b64, "ai_image": None, "has_ai": False, "error": str(e)}
            except:
                return {"success": False, "raw_image": None, "ai_image": None, "has_ai": False, "error": str(e)}

    def draw_manual_boxes(self, image: Image.Image, predictions: list):
        """Draws boxes manually using PIL if the API only returns coordinates."""
        draw = ImageDraw.Draw(image)
        try:
            font = ImageFont.load_default()
        except:
            font = None

        for pred in predictions:
            # Check format
            if "x" in pred and "y" in pred and "width" in pred:
                x1 = pred["x"] - pred["width"] / 2
                y1 = pred["y"] - pred["height"] / 2
                x2 = pred["x"] + pred["width"] / 2
                y2 = pred["y"] + pred["height"] / 2
            else:
                x1, y1, x2, y2 = pred.get("bbox", [0, 0, 0, 0])

            label = f"{pred.get('class', 'Object')} {pred.get('confidence', 0):.2f}"
            
            draw.rectangle((x1, y1, x2, y2), outline="#58a6ff", width=5)
            draw.rectangle((x1, y1 - 25, x1 + 200, y1), fill="#58a6ff")
            draw.text((x1 + 5, y1 - 20), label, fill="black", font=font)
            
        buffered = BytesIO()
        image.save(buffered, format="JPEG")
        return base64.b64encode(buffered.getvalue()).decode("utf-8")
