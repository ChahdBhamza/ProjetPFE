from fastapi import APIRouter, HTTPException, Body, Depends
from app.database import mongo_db
from app.schemas import BaseResponse, InventoryListResponse
from app.api.dependencies import verify_token

router = APIRouter(prefix="/inventory", tags=["Inventory"])


def _text_value(*values) -> str:
    for value in values:
        if value is not None:
            return str(value).strip().lower()
    return ""


def _is_unknown_value(value: str) -> bool:
    return (
        not value
        or value in {"n/a", "na", "none", "null", "-"}
        or value.startswith("unknown")
        or value.startswith("unkown")
    )


def _is_unknown_unknown_item(item: dict) -> bool:
    identity = item.get("identity") or {}
    metadata = item.get("metadata") or {}
    specs = item.get("specs") or metadata.get("specs") or {}

    brand = _text_value(
        item.get("brand"),
        identity.get("brand"),
        metadata.get("brand"),
        specs.get("brand"),
    )
    model = _text_value(
        item.get("model"),
        item.get("model_name"),
        identity.get("top_model"),
        identity.get("model"),
        metadata.get("model"),
        metadata.get("model_name"),
        metadata.get("top_model"),
        specs.get("model"),
        specs.get("model_name"),
    )

    return _is_unknown_value(brand) and _is_unknown_value(model)

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
    user = mongo_db.find_user_by_email(current_email)
    if user and user.get("is_admin", False):
        inventory = [item for item in inventory if not _is_unknown_unknown_item(item)]

    for item in inventory:
        if "added_at" in item:
            item["added_at"] = item["added_at"].isoformat()
            
    return {"success": True, "inventory": inventory}

@router.post("/filter", response_model=InventoryListResponse)
async def filter_inventory(filters: dict = Body(...), current_email: str = Depends(verify_token)):
    """Filter the authenticated user's inventory using dynamic criteria"""
    inventory = mongo_db.filter_user_inventory(current_email, filters)
    user = mongo_db.find_user_by_email(current_email)
    if user and user.get("is_admin", False):
        inventory = [item for item in inventory if not _is_unknown_unknown_item(item)]

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

@router.get("/my-stats")
async def get_my_stats(current_email: str = Depends(verify_token)):
    """Return per-user stats for the profile page"""
    saved = mongo_db.inventory.count_documents({"user_email": current_email})
    scans = mongo_db.scan_sessions.count_documents({"user_email": current_email})

    detected = 0
    try:
        session_ids = [
            s["session_id"]
            for s in mongo_db.scan_sessions.find(
                {"user_email": current_email}, {"session_id": 1, "_id": 0}
            )
        ]
        if session_ids:
            detected = mongo_db.detections.count_documents(
                {"scan_session_id": {"$in": session_ids}}
            )
    except Exception as e:
        print(f"[MyStats] detections count error: {e}")

    return {"success": True, "stats": {"scans": scans, "detected": detected, "saved": saved}}


@router.get("/admin/stats")
async def get_admin_stats(current_email: str = Depends(verify_token)):
    """Fetch global KPIs and metrics for the Admin Dashboard"""
    import datetime
    
    # 1. Authorize Admin
    user = mongo_db.find_user_by_email(current_email)
    if not user or not user.get("is_admin", False):
        raise HTTPException(
            status_code=403, 
            detail="Neural clearance denied. Authorized Operators only."
        )

    # 2. Core counts
    total_assets = mongo_db.inventory.count_documents({})
    total_scans  = mongo_db.scan_sessions.count_documents({})

    # Total AI detections (much higher than scans — each scan finds multiple items)
    total_detections = mongo_db.detections.count_documents({})

    # Active operators = those who ran at least one scan session
    active_operators = len(mongo_db.scan_sessions.distinct("user_email"))

    # 3. Average VLM Confidence Score
    avg_confidence = 80.0
    try:
        pipeline = [
            {
                "$project": {
                    "conf": {
                        "$ifNull": [
                            "$identity.confidence",
                            {"$ifNull": ["$metadata.confidence", {"$ifNull": ["$confidence", 80.0]}]}
                        ]
                    }
                }
            },
            {
                "$group": {
                    "_id": None,
                    "avg_conf": {"$avg": "$conf"}
                }
            }
        ]
        res = list(mongo_db.inventory.aggregate(pipeline))
        if res and res[0].get("avg_conf") is not None:
            avg_confidence = round(res[0]["avg_conf"], 1)
    except Exception as e:
        print(f"[AdminStats] Conf error: {e}")

    # 4. Equipment by Category Breakdown
    categories = {}
    try:
        pipeline = [
            {
                "$project": {
                    "cat": {
                        "$ifNull": [
                            "$equipment_category",
                            {"$ifNull": ["$metadata.category", "unknown"]}
                        ]
                    }
                }
            },
            {
                "$group": {
                    "_id": "$cat",
                    "count": {"$sum": 1}
                }
            },
            {"$sort": {"count": -1}}
        ]
        for item in mongo_db.inventory.aggregate(pipeline):
            cat_name = item["_id"] if item["_id"] else "unknown"
            categories[cat_name] = item["count"]
    except Exception as e:
        print(f"[AdminStats] Category error: {e}")

    # 5. Top Brands Breakdown
    brands = {}
    try:
        pipeline = [
            {
                "$project": {
                    "brand_name": {
                        "$ifNull": [
                            "$brand",
                            {"$ifNull": ["$identity.brand", "Unknown"]}
                        ]
                    }
                }
            },
            {
                "$group": {
                    "_id": "$brand_name",
                    "count": {"$sum": 1}
                }
            },
            {"$sort": {"count": -1}},
            {"$limit": 5}
        ]
        for item in mongo_db.inventory.aggregate(pipeline):
            brand_name = item["_id"] if item["_id"] else "Unknown"
            brands[brand_name] = item["count"]
    except Exception as e:
        print(f"[AdminStats] Brands error: {e}")

    # 6. Operator Performance List
    operators_performance = []
    try:
        pipeline = [
            {
                "$project": {
                    "user_email": 1,
                    "conf": {
                        "$ifNull": [
                            "$identity.confidence",
                            {"$ifNull": ["$metadata.confidence", {"$ifNull": ["$confidence", 80.0]}]}
                        ]
                    }
                }
            },
            {
                "$group": {
                    "_id": "$user_email",
                    "items_saved": {"$sum": 1},
                    "avg_conf": {"$avg": "$conf"}
                }
            }
        ]
        for item in mongo_db.inventory.aggregate(pipeline):
            op_email = item["_id"]
            if not op_email: continue

            op_user = mongo_db.find_user_by_email(op_email)
            op_name = op_user.get("full_name", "Operator") if op_user else "Operator"

            # Count raw detections for this operator via their scan sessions
            op_session_ids = [
                s["session_id"]
                for s in mongo_db.scan_sessions.find(
                    {"user_email": op_email}, {"session_id": 1, "_id": 0}
                )
            ]
            op_detected = mongo_db.detections.count_documents(
                {"scan_session_id": {"$in": op_session_ids}}
            ) if op_session_ids else 0

            operators_performance.append({
                "email": op_email,
                "name": op_name,
                "items_detected": op_detected,
                "items_saved": item["items_saved"],
                "avg_confidence": round(item["avg_conf"], 1) if item["avg_conf"] else 80.0
            })
    except Exception as e:
        print(f"[AdminStats] Operator performance error: {e}")

    # 7. Activity Over Time — detections per day (last 7 days)
    activity_over_time = []
    try:
        pipeline = [
            {"$match": {"timestamp": {"$gte": datetime.datetime.now() - datetime.timedelta(days=7)}}},
            {"$group": {
                "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}},
                "scans": {"$sum": 1}
            }},
            {"$sort": {"_id": 1}}
        ]
        for item in mongo_db.detections.aggregate(pipeline):
            activity_over_time.append({"date": item["_id"], "scans": item["scans"]})

        # Fill missing days with 0 so the chart always has 7 bars
        today = datetime.datetime.now()
        existing_dates = {d["date"] for d in activity_over_time}
        for i in range(6, -1, -1):
            d = (today - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            if d not in existing_dates:
                activity_over_time.append({"date": d, "scans": 0})
        activity_over_time.sort(key=lambda x: x["date"])
        activity_over_time = activity_over_time[-7:]
    except Exception as e:
        print(f"[AdminStats] Activity trend error: {e}")

    # 8. Anomaly/Quality Alerts
    alerts = []
    try:
        low_conf_items = list(mongo_db.inventory.find({
            "$or": [
                {"identity.confidence": {"$lt": 60}},
                {"metadata.confidence": {"$lt": 60}},
                {"confidence": {"$lt": 60}}
            ]
        }, {"_id": 0}).limit(5))
        
        for item in low_conf_items:
            brand = item.get("brand") or item.get("identity", {}).get("brand") or "Unknown"
            model = item.get("model") or item.get("identity", {}).get("top_model") or "Unknown Model"
            op = item.get("user_email", "system")
            conf = item.get("confidence") or item.get("identity", {}).get("confidence") or 50
            
            alerts.append({
                "type": "low_confidence",
                "message": f"Low VLM confidence ({conf}%) for {brand} {model}",
                "operator": op,
                "timestamp": item.get("added_at").isoformat() if hasattr(item.get("added_at"), "isoformat") else datetime.datetime.now().isoformat()
            })
            
        unknown_brands = list(mongo_db.inventory.find({
            "$or": [
                {"brand": {"$regex": "^unknown", "$options": "i"}},
                {"identity.brand": {"$regex": "^unknown", "$options": "i"}}
            ]
        }, {"_id": 0}).limit(5))
        
        for item in unknown_brands:
            model = item.get("model") or item.get("identity", {}).get("top_model") or "Unknown Model"
            op = item.get("user_email", "system")
            
            alerts.append({
                "type": "unknown_brand",
                "message": f"VLM failed to read brand for model: {model}",
                "operator": op,
                "timestamp": item.get("added_at").isoformat() if hasattr(item.get("added_at"), "isoformat") else datetime.datetime.now().isoformat()
            })
            
        if not alerts:
            alerts.append({
                "type": "info",
                "message": "All assets verified within nominal specs.",
                "operator": "Cybersight Neural Link",
                "timestamp": datetime.datetime.now().isoformat()
            })
    except Exception as e:
        print(f"[AdminStats] Alerts error: {e}")

    # 9. Unknown brand count (identification failures)
    unknown_brand_count = 0
    try:
        unknown_brand_count = mongo_db.inventory.count_documents({
            "$or": [
                {"brand": {"$regex": "^unknown", "$options": "i"}},
                {"brand": {"$exists": False}},
                {"brand": ""},
                {"brand": None},
            ]
        })
    except Exception as e:
        print(f"[AdminStats] unknown brand count error: {e}")

    # 10. Assets detected today
    assets_today = 0
    try:
        today_start = datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        assets_today = mongo_db.inventory.count_documents({
            "added_at": {"$gte": today_start}
        })
    except Exception as e:
        print(f"[AdminStats] assets_today error: {e}")

    # ID success rate — % of saved items where AI identified the brand
    id_success_rate = 0
    if total_assets > 0:
        id_success_rate = round((total_assets - unknown_brand_count) / total_assets * 100)

    # Detections today
    detections_today = 0
    try:
        today_start = datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        detections_today = mongo_db.detections.count_documents(
            {"timestamp": {"$gte": today_start}}
        )
    except Exception as e:
        print(f"[AdminStats] detections_today error: {e}")

    # Assemble response
    stats_data = {
        "total_assets": total_assets,
        "total_detections": total_detections,
        "total_scans": total_scans,
        "active_operators": active_operators,
        "id_success_rate": id_success_rate,
        "unknown_brand_count": unknown_brand_count,
        "assets_today": assets_today,
        "detections_today": detections_today,
        "categories": categories,
        "brands": brands,
        "operator_performance": operators_performance,
        "activity_over_time": activity_over_time,
    }
    
    return {"success": True, "stats": stats_data}
