from fastapi import APIRouter, HTTPException, Body, Depends
from app.database import mongo_db
from app.schemas import BaseResponse, InventoryListResponse
from app.api.dependencies import verify_token

router = APIRouter(prefix="/inventory", tags=["Inventory"])

@router.post("/save", response_model=BaseResponse)
async def save_to_inventory(data: dict = Body(...), current_email: str = Depends(verify_token)):
    """Save an item to the authenticated user's inventory"""
    success = mongo_db.add_to_inventory(current_email, data)
    if success:
        return {"success": True, "message": "Item saved to Neural Inventory"}
    else:
        raise HTTPException(status_code=500, detail="Failed to save item")

@router.get("/list", response_model=InventoryListResponse)
async def get_inventory(current_email: str = Depends(verify_token)):
    """Fetch the authenticated user's inventory"""
    inventory = mongo_db.get_user_inventory(current_email)
    for item in inventory:
        if "added_at" in item:
            item["added_at"] = item["added_at"].isoformat()
            
    return {"success": True, "inventory": inventory}

@router.post("/filter", response_model=InventoryListResponse)
async def filter_inventory(filters: dict = Body(...), current_email: str = Depends(verify_token)):
    """Filter the authenticated user's inventory using dynamic criteria"""
    inventory = mongo_db.filter_user_inventory(current_email, filters)
    for item in inventory:
        if "added_at" in item:
            try:
                # Handle both datetime objects and strings just in case
                if hasattr(item["added_at"], "isoformat"):
                    item["added_at"] = item["added_at"].isoformat()
            except Exception:
                pass
            
    return {"success": True, "inventory": inventory}

@router.get("/history")
async def get_history(current_email: str = Depends(verify_token)):
    """Fetch the authenticated user's scan history and raw detections"""
    scan_sessions = list(mongo_db.scan_sessions.find({"user_email": current_email}, {"_id": 0}).sort("start_time", -1))
    
    # Optional: could also fetch detections for each session, but let's just return the sessions for now
    for session in scan_sessions:
        if "start_time" in session:
            try:
                session["start_time"] = session["start_time"].isoformat()
            except Exception: pass
        if "end_time" in session and session["end_time"]:
            try:
                session["end_time"] = session["end_time"].isoformat()
            except Exception: pass
            
    return {"success": True, "scan_sessions": scan_sessions}
