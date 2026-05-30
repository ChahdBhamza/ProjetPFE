from pydantic import BaseModel
from typing import Optional, List, Dict, Any

class BaseResponse(BaseModel):
    success: bool
    error: Optional[str] = None
    message: Optional[str] = None

class ErrorResponse(BaseModel):
    success: bool = False
    error: str

class UserSchema(BaseModel):
    email: str
    full_name: str
    is_admin: Optional[bool] = False

class AuthResponse(BaseResponse):
    token: Optional[str] = None
    user: Optional[UserSchema] = None

class DetectionVectorMatch(BaseModel):
    item: Dict[str, Any]
    confidence: float

class SearchResponse(BaseResponse):
    raw_ai_perception: Optional[Dict[str, Any]] = None
    vector_match: Optional[DetectionVectorMatch] = None
    ocr_text: Optional[str] = None
    web_grounding: Optional[Dict[str, Any]] = None
    verified_details: Optional[Dict[str, Any]] = None
    local_vlm_raw: Optional[Dict[str, Any]] = None


class ExtractedFrame(BaseModel):
    raw: str
    frame_idx: int

class ExtractFramesResponse(BaseResponse):
    frame_count: Optional[int] = None
    frames: Optional[List[ExtractedFrame]] = None
    auto_search_result: Optional[SearchResponse] = None

class InventorySaveRequest(BaseModel):
    brand: str
    model: str
    btu: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

class InventoryListResponse(BaseResponse):
    inventory: List[Dict[str, Any]]
