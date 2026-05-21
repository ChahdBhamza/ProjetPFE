
import os
import requests
import base64
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

class RoboflowService:
    def __init__(self, api_key=None, workspace=None):
        self.api_key = api_key or os.getenv("ROBOFLOW_API_KEY")
        self.workspace = workspace or os.getenv("ROBOFLOW_WORKSPACE")
        
        if not self.api_key:
            print("[Roboflow] WARNING: No API key found in environment!")
        if not self.workspace:
            print("[Roboflow] WARNING: No workspace found in environment!")
        self.base_url = "https://serverless.roboflow.com"

    @staticmethod
    def decode_annotated_image(annotated_b64):
        """Decode workflow annotated_image (base64, optional data-URL prefix) to PIL."""
        if not annotated_b64:
            return None
        try:
            raw = annotated_b64
            if isinstance(raw, dict):
                raw = raw.get("value") or raw.get("image")
            if not raw or not isinstance(raw, str):
                return None
            if "," in raw:
                raw = raw.split(",", 1)[1]
            data = base64.b64decode(raw)
            return Image.open(BytesIO(data)).convert("RGB")
        except Exception as e:
            print(f"[Roboflow] Could not decode annotated image: {e}")
            return None

    @staticmethod
    def _extract_annotated_b64(output):
        if not output or not isinstance(output, dict):
            return None
        ann = output.get("annotated_image")
        if isinstance(ann, dict):
            return ann.get("value") or ann.get("image")
        if isinstance(ann, str):
            return ann
        for key in ("output", "visualization", "label_visualization"):
            nested = output.get(key)
            if isinstance(nested, dict):
                found = RoboflowService._extract_annotated_b64(nested)
                if found:
                    return found
        return None

    @staticmethod
    def _normalize_predictions(predictions):
        if isinstance(predictions, dict) and "predictions" in predictions:
            predictions = predictions["predictions"]
        if not isinstance(predictions, list):
            return []

        normalized = []
        for pred in predictions:
            if "x" in pred and "y" in pred and "width" in pred and "height" in pred:
                x1 = pred["x"] - pred["width"] / 2
                y1 = pred["y"] - pred["height"] / 2
                x2 = pred["x"] + pred["width"] / 2
                y2 = pred["y"] + pred["height"] / 2
                bbox = [x1, y1, x2, y2]
            else:
                bbox = pred.get("bbox", [0, 0, 0, 0])

            normalized.append({
                "class": pred.get("class", "object"),
                "confidence": pred.get("confidence", 0.0),
                "bbox": bbox,
            })
        return normalized

    def detect(self, image: Image.Image, workflow_id="detect-count-and-visualize", quiet=False):
        """
        Run a Roboflow workflow on a PIL image using raw HTTP requests (Python 3.13 compatible).
        Returns detections plus optional cloud-rendered annotated_image (base64).
        """
        buffered = BytesIO()
        image.save(buffered, format="JPEG", quality=90)
        img_base64 = base64.b64encode(buffered.getvalue()).decode("utf-8")

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

        if not quiet:
            print(f"[Roboflow] Calling workflow: {workflow_id}...")
        response = requests.post(url, json=payload, timeout=45)

        if not quiet:
            print(f"[Roboflow] Response status: {response.status_code}")

        if response.status_code != 200:
            if not quiet:
                print(f"[Roboflow] Error: {response.text[:300]}")
            return {"error": f"Roboflow API failed: {response.status_code}", "details": response.text}

        res_json = response.json()
        if not quiet:
            print(f"[Roboflow] OK")

        if "outputs" in res_json and len(res_json["outputs"]) > 0:
            output = res_json["outputs"][0]
            predictions = output.get("predictions", output.get("detections", []))
            annotated_base64 = self._extract_annotated_b64(output)
            return {
                "detections": self._normalize_predictions(predictions),
                "image": annotated_base64,
            }

        return {"detections": [], "image": None, "raw": res_json}

    def draw_detections(self, image: Image.Image, detections: list):
        """Fallback local boxes when workflow returns no annotated_image."""
        draw = ImageDraw.Draw(image)
        try:
            font = ImageFont.load_default()
        except Exception:
            font = None

        for det in detections:
            x1, y1, x2, y2 = det["bbox"]
            label = f"{det['class']} {det['confidence']:.1%}"
            draw.rectangle((x1, y1, x2, y2), outline="red", width=5)
            draw.rectangle((x1, y1 - 25, x1 + 200, y1), fill="red")
            draw.text((x1 + 5, y1 - 20), label, fill="white", font=font)

        return image
