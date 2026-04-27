from fastapi import APIRouter, HTTPException, Body
from app.database import mongo_db
import hashlib

router = APIRouter()

def hash_password(password: str):
    """Simple SHA-256 hashing for PFE demonstration (Use bcrypt for production!)"""
    return hashlib.sha256(password.encode()).hexdigest()

@router.post("/signup")
async def signup(data: dict = Body(...)):
    email = data.get("email")
    password = data.get("password")
    full_name = data.get("full_name", "User")

    if not email or not password:
        raise HTTPException(status_code=400, detail="Missing email or password")

    # Check if user already exists
    existing_user = mongo_db.find_user_by_email(email)
    if existing_user:
        raise HTTPException(status_code=400, detail="Account already exists with this email")

    # Create user
    pwd_hash = hash_password(password)
    user_id = mongo_db.create_user(email, pwd_hash, full_name)
    
    if user_id:
        return {"success": True, "message": "Neural Profile Created", "user_id": str(user_id)}
    else:
        raise HTTPException(status_code=500, detail="Cloud database synchronization failed")

@router.post("/login")
async def login(data: dict = Body(...)):
    email = data.get("email")
    password = data.get("password")

    user = mongo_db.find_user_by_email(email)
    if not user:
        raise HTTPException(status_code=401, detail="Neural ID not found")

    if user["password_hash"] != hash_password(password):
        raise HTTPException(status_code=401, detail="Access Denied: Invalid Credentials")

    return {
        "success": True,
        "message": "Access Granted",
        "user": {
            "email": user["email"],
            "full_name": user["full_name"]
        }
    }

@router.post("/google")
async def google_auth(data: dict = Body(...)):
    """
    Handle Google OAuth Login/Signup
    """
    email = data.get("email")
    full_name = data.get("full_name")
    
    if not email:
        raise HTTPException(status_code=400, detail="Google synchronization failed: Missing email")
        
    # Check if user exists
    user = mongo_db.find_user_by_email(email)
    
    if not user:
        # Create new user for Google login
        mongo_db.create_user(
            email=email,
            password_hash="GOOGLE_OAUTH_USER", # Mark as OAuth user
            full_name=full_name or "Google User"
        )
        user = mongo_db.find_user_by_email(email)
        
    return {
        "success": True, 
        "message": "Google Link Established",
        "user": {
            "email": user["email"], 
            "full_name": user["full_name"]
        }
    }
