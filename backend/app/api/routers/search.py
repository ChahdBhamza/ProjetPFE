from fastapi import APIRouter, UploadFile, File
from fastapi.concurrency import run_in_threadpool
import os
import tempfile

router = APIRouter(tags=["Search"])


@router.post("/search")
async def search_endpoint(file: UploadFile = File(...)):
    """
    Detect equipment from a single image using the Roboflow + Two-Pass Gemini pipeline.
    Returns a standardised equipment_result block alongside legacy fields.
    """
    contents = await file.read()

    tmp_path = None
    try:
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

        # Build standardised equipment_result
        from app.api.routers.video import build_equipment_result
        equipment_result = build_equipment_result(forensic)

        brand = equipment_result["identity"]["brand"]
        model_name = equipment_result["identity"]["top_model"]
        confidence = float(top.get("confidence", 0)) / 100.0 if top else 0.5

        if brand == "Unknown" and not result.get("has_ai", False):
            return {
                "success": False,
                "error": "Could not identify any equipment. Try a clearer image or use Script Lab for video.",
            }

        return {
            "success": True,
            # Primary standardised output
            "equipment_result": equipment_result,
            # Legacy fields for backward compatibility
            "vector_match": {
                "item": {
                    "brand": brand,
                    "model_name": model_name,
                },
                "confidence": round(confidence, 3),
            },
            "verified_details": {
                "equipment_type": equipment_result["identity"]["equipment_category"],
                "model_candidates": candidates,
                "visual_cues": forensic.get("visual_cues", []),
                "annotated_image": result.get("ai_image"),
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
