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

    def run_specialized_workflow(self, image_path: str):
        try:
            print(f"📡 SDK Processing: {image_path}")
            
            # 1. Run workflow via SDK (Detection + Annotation)
            result = self.client.run_workflow(
                workspace_name=self.workspace,
                workflow_id=self.workflow_id,
                images={"image": image_path},
                use_cache=False
            )

            item = result[0] if result and isinstance(result, list) else {}
            display_b64 = item.get("annotated_image")
            preds_data = item.get("predictions", [])
            
            predictions = []
            if isinstance(preds_data, dict) and "predictions" in preds_data:
                predictions = preds_data["predictions"]
            elif isinstance(preds_data, list):
                predictions = preds_data

            print(f"✅ AI Result: Found {len(predictions)} items")

            # 2. Forensic Step: Using original SFM Project scripts (IDENTIFICATION ONLY)
            forensic_data = {}
            if len(predictions) > 0:
                print("🧠 [DEBUG] Identifying Brand (Gemini Vision logic)...")
                
                try:
                    from app.services.frame_detector import process_frame
                    # 1. Identify Brand & Model using SFM process_frame (Fast-ish)
                    sfm_result = process_frame(image_path, os.getenv("OPENROUTER_API_KEY"))
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
