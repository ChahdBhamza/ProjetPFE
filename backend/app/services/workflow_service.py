from inference_sdk import InferenceHTTPClient
import base64
import os
import json
from io import BytesIO
from PIL import Image
from dotenv import load_dotenv

load_dotenv()

class WorkflowService:
    def __init__(self):
        self.api_key = os.getenv("ROBOFLOW_API_KEY", "oesPLELo2uEPnMKXp8dM")
        self.workspace = "devileyess-workspace"
        self.workflow_id = "custom-workflow-3"
        
        # Initialize official client
        self.client = InferenceHTTPClient(
            api_url="https://serverless.roboflow.com",
            api_key=self.api_key
        )

    def _yolo_hint_from_path(self, image_path: str) -> str | None:
        """
        Extract the YOLO-detected equipment category from the hero filename.
        Example: 'hero_1_tv_monitor.png' -> 'monitor'
                 'hero_2_air_conditioner.png' -> 'airconditioner'
                 'hero_1_computer.png' -> 'laptop'
        """
        import re
        filename = os.path.basename(image_path).lower()
        # Strip prefix like 'hero_1_' and extension
        m = re.match(r'hero_\d+_(.+?)(?:_f\d+)?\.(png|jpg|jpeg)$', filename)
        if not m:
            return None
        raw = m.group(1)  # e.g. 'tv_monitor', 'air_conditioner', 'computer'
        # Map to Groq-compatible type strings
        mapping = {
            "tv_monitor": "monitor",
            "monitor":    "monitor",
            "tv":         "monitor",
            "computer":   "laptop",
            "laptop":     "laptop",
            "air_conditioner": "airconditioner",
            "airconditioner":  "airconditioner",
            "refrigerator":    "refrigerator",
            "fridge":          "refrigerator",
            "microwave":       "microwave",
            "oven":            "microwave",
        }
        return mapping.get(raw)

    def _draw_single_box(self, image_path: str, pred: dict) -> str | None:
        """Draw one clean bounding box on the raw frame and return as base64."""
        try:
            import cv2
            import numpy as np
            img = cv2.imread(image_path)
            if img is None:
                return None
            h, w = img.shape[:2]
            # Roboflow returns center x/y + width/height
            cx = pred.get("x", 0); cy = pred.get("y", 0)
            bw = pred.get("width", 0); bh = pred.get("height", 0)
            x1 = int(cx - bw / 2); y1 = int(cy - bh / 2)
            x2 = int(cx + bw / 2); y2 = int(cy + bh / 2)
            color = (30, 180, 100)
            cv2.rectangle(img, (x1, y1), (x2, y2), color, 3)
            label = f"{pred.get('class', '')} {pred.get('confidence', 0):.0%}"
            (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.65, 2)
            cv2.rectangle(img, (x1, y1 - th - 12), (x1 + tw + 4, y1), color, -1)
            cv2.putText(img, label, (x1 + 2, y1 - 6), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (255, 255, 255), 2)
            _, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 85])
            return base64.b64encode(buf).decode("utf-8")
        except Exception:
            return None

    def run_specialized_workflow(self, image_path: str):
        try:
            print(f"📡 SDK Processing: {image_path}")
            
            # Extract yolo_hint from the original hero image path before we potentially update it
            yolo_hint = self._yolo_hint_from_path(image_path)
            
            # Locate the clean, unannotated raw frame if this is a hero image
            import re
            m = re.search(r"hero_\d+_.+?_f(\d+)\.(png|jpg|jpeg)$", os.path.basename(image_path))
            original_hero_path = image_path
            
            if m:
                fid_str = m.group(1)
                base_session_dir = os.path.dirname(os.path.dirname(image_path))
                clean_path = os.path.join(base_session_dir, "raw", f"frame_{fid_str}.jpg")
                if os.path.exists(clean_path):
                    print(f"🎯 FOUND CLEAN FRAME: Using clean {clean_path} instead of annotated hero image!")
                    image_path = clean_path

            # 1. Run workflow via SDK (Detection + Annotation) on the clean frame
            import time
            max_retries = 4
            result = None
            for attempt in range(max_retries):
                try:
                    result = self.client.run_workflow(
                        workspace_name=self.workspace,
                        workflow_id=self.workflow_id,
                        images={"image": image_path},
                        use_cache=False
                    )
                    break
                except Exception as api_err:
                    if "503" in str(api_err) or "500" in str(api_err) or "store full" in str(api_err).lower():
                        if attempt < max_retries - 1:
                            wait_time = (attempt + 1) * 2  # 2s, 4s, 6s
                            print(f"⚠️ Roboflow Server busy (503). Retrying in {wait_time}s... (Attempt {attempt + 1}/{max_retries})")
                            time.sleep(wait_time)
                        else:
                            raise api_err
                    else:
                        raise api_err

            item = result[0] if result and isinstance(result, list) else {}
            display_b64 = item.get("annotated_image")
            preds_data = item.get("predictions", [])
            
            predictions = []
            if isinstance(preds_data, dict) and "predictions" in preds_data:
                predictions = preds_data["predictions"]
            elif isinstance(preds_data, list):
                predictions = preds_data

            def _pred_category(cls: str) -> str:
                """Map a Roboflow class name to the canonical category used by yolo_hint."""
                c = cls.lower()
                if any(k in c for k in ("fridge", "refrigerator")):
                    return "refrigerator"
                if "microwave" in c:
                    return "microwave"
                if any(k in c for k in ("air_conditioner", "airconditioner", "ac")):
                    return "airconditioner"
                if any(k in c for k in ("laptop", "computer")):
                    return "laptop"
                if any(k in c for k in ("tv", "monitor")):
                    return "monitor"
                return c

            # Per-category confidence thresholds — fridges score lower on partial/angle views
            def _min_conf(cls: str) -> float:
                c = cls.lower()
                if any(k in c for k in ("fridge", "refrigerator")):
                    return 0.30
                if any(k in c for k in ("air_conditioner", "airconditioner", "ac")):
                    return 0.45
                return 0.60

            predictions = [
                p for p in predictions
                if p.get("confidence", 0) >= _min_conf(p.get("class", ""))
            ]

            # When yolo_hint is known (from hero filename), prefer the prediction that
            # matches that category over a higher-confidence prediction of the wrong type.
            # Example: frame_0028 has both fridge + microwave; hero is tagged refrigerator,
            # so we must use the fridge bbox, NOT the higher-confidence microwave bbox.
            if yolo_hint and len(predictions) > 1:
                matching = [p for p in predictions if _pred_category(p.get("class", "")) == yolo_hint]
                if matching:
                    predictions = [max(matching, key=lambda p: p.get("confidence", 0))]
                    print(f"🎯 Category-matched prediction: kept '{predictions[0].get('class')}' to match yolo_hint='{yolo_hint}'")
                else:
                    predictions = [max(predictions, key=lambda p: p.get("confidence", 0))]
            elif len(predictions) > 1:
                predictions = [max(predictions, key=lambda p: p.get("confidence", 0))]

            if predictions:
                display_b64 = self._draw_single_box(image_path, predictions[0])

            print(f"✅ AI Result: Found {len(predictions)} items")

            # 2. Forensic Step: Brand + Model identification (Pass 1 SKIPPED - see frame_detector.py)
            # Always run if yolo_hint is known (hero frame already confirmed the equipment type).
            forensic_data = {}
            if len(predictions) > 0 or yolo_hint:
                print("🧠 [OPTIMIZED] Single-pass Groq identification (Pass 1 skipped)...")

                try:
                    from app.services.frame_detector import process_frame
                    if yolo_hint:
                        print(f"🎯 Using equipment type hint='{yolo_hint}' from Roboflow")

                    # Convert Roboflow center-x/y/w/h bbox → x/y/w/h for process_frame.
                    # Only use the bbox if it matches the expected category (yolo_hint).
                    # This prevents passing a microwave bbox to the fridge identification
                    # when both appear in the same frame.
                    rf_bbox_override = None
                    if predictions:
                        pred = predictions[0]
                        pred_cat = _pred_category(pred.get("class", ""))
                        if not yolo_hint or pred_cat == yolo_hint:
                            cx, cy = pred.get("x", 0), pred.get("y", 0)
                            bw, bh = pred.get("width", 0), pred.get("height", 0)
                            if bw > 0 and bh > 0:
                                rf_bbox_override = (int(cx - bw / 2), int(cy - bh / 2), int(bw), int(bh))
                                print(f"🔲 Passing Roboflow bbox to process_frame: {rf_bbox_override}")
                        else:
                            print(f"⚠️ Roboflow pred '{pred.get('class')}' doesn't match yolo_hint='{yolo_hint}' — using detect_dominant_object fallback")

                    sfm_result = process_frame(image_path, os.getenv("OPENROUTER_API_KEY"), yolo_type_hint=yolo_hint, bbox_override=rf_bbox_override)
                    llm_data = sfm_result.get("result", {})

                    forensic_data = llm_data

                    brand = forensic_data.get("brand", "Unknown")
                    print(f"✅ Brand detected: {brand}")

                except Exception as e:
                    print(f"❌ Identification error: {e}")
                    forensic_data = {"brand": "Unknown", "equipment_type": predictions[0].get("class", "unknown") if predictions else "unknown"}

            # 3. Read raw image for UI display
            with open(image_path, "rb") as f:
                raw_b64 = base64.b64encode(f.read()).decode('utf-8')

            return {
                "success": True,
                "raw_image": raw_b64,
                "ai_image": display_b64,
                "has_ai": len(predictions) > 0,
                "raw_output": predictions,
                "forensic_data": forensic_data
            }
            
        except Exception as e:
            print(f"❌ Workflow Error: {e}")
            try:
                with open(image_path, "rb") as f:
                    img_b64 = base64.b64encode(f.read()).decode('utf-8')
                return {"success": False, "raw_image": img_b64, "error": str(e)}
            except:
                return {"success": False, "error": str(e)}
