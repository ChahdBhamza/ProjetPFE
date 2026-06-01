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
        m = re.match(r'hero_\d+_(.+?)\.(png|jpg|jpeg)$', filename)
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

            # Air conditioners score lower from Roboflow due to wall-mount variability
            predictions = [
                p for p in predictions
                if p.get("confidence", 0) >= (
                    0.45 if p.get("class", "").lower() in ("air_conditioner", "airconditioner", "ac")
                    else 0.60
                )
            ]

            print(f"✅ AI Result: Found {len(predictions)} items")

            # 2. Forensic Step: Using original SFM Project scripts (IDENTIFICATION ONLY)
            forensic_data = {}
            if len(predictions) > 0:
                print("🧠 [DEBUG] Identifying Brand (Gemini Vision logic)...")
                
                try:
                    from app.services.frame_detector import process_frame
                    if yolo_hint:
                        print(f"🎯 [SAFEGUARD] Anchoring Groq to type='{yolo_hint}' (from filename)")
                    # Run forensic identification on the clean frame as well for maximum OCR accuracy
                    sfm_result = process_frame(image_path, os.getenv("OPENROUTER_API_KEY"), yolo_type_hint=yolo_hint)
                    llm_data = sfm_result.get("result", {})
                    
                    # Return identification immediately
                    forensic_data = llm_data
                    
                    brand = forensic_data.get("brand", "Unknown")
                    if brand.lower() == "unknown":
                        print(f"⚠️ [DEBUG] Could NOT detect a clear brand in this frame.")
                    else:
                        print(f"🎯 [DEBUG] Brand DETECTED: {brand.upper()}")
                        
                except Exception as e:
                    print(f"❌ [DEBUG] SFM ID Error (Quota limit or API issue): {e}")
                    forensic_data = {"brand": "Unknown", "error": str(e)}

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
