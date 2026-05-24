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
