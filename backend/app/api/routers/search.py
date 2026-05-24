from fastapi import APIRouter, UploadFile, File
from fastapi.concurrency import run_in_threadpool
import os
import tempfile

router = APIRouter(tags=["Search"])


@router.post("/search")
async def search_endpoint(file: UploadFile = File(...)):
    """
    Detect equipment from a single image using the Roboflow + LLM pipeline.
    Replaces the old CLIP/Qdrant vector search with WorkflowService.
    """
    contents = await file.read()

    tmp_path = None
    try:
        # WorkflowService needs a real file path on disk
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            tmp.write(contents)
            tmp_path = tmp.name

        def _run_workflow():
            from app.services.workflow_service import WorkflowService
            return WorkflowService().run_specialized_workflow(tmp_path)

        result = await run_in_threadpool(_run_workflow)

        forensic = result.get("forensic_data", {})
        candidates = forensic.get("model_candidates", [])
        top = candidates[0] if candidates else {}

        brand = (forensic.get("brand") or "Unknown").strip()
        model_name = (top.get("model") or "Unknown Model").strip()
        confidence = float(top.get("confidence", 0)) / 100.0 if top else 0.5

        if brand == "Unknown" and not result.get("has_ai", False):
            return {
                "success": False,
                "error": "Could not identify any equipment. Try a clearer image or use Script Lab for video."
            }

        return {
            "success": True,
            "vector_match": {
                "item": {
                    "brand": brand,
                    "model_name": model_name,
                    "btu": None,
                },
                "confidence": round(confidence, 3),
            },
            "verified_details": {
                "equipment_type": forensic.get("equipment_type"),
                "model_candidates": candidates,
                "visual_cues": forensic.get("visual_cues", []),
                "annotated_image": result.get("ai_image"),      # Roboflow annotated frame
                "is_match_verified": result.get("has_ai", False),
            },
            "ocr_text": None,
            "raw_ai_perception": forensic,
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}

    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except Exception:
                pass
