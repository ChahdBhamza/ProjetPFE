import os
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Body, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
import jwt

from app.database import mongo_db

router = APIRouter()
security = HTTPBearer()

# Authentication Configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "cybersight_neural_link_secure_secret_key_2024_pfe")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 week

# Password Hashing
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

# --- Utility Functions ---

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Dependency to verify JWT token and return user email"""
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid Neural Credentials")
        return email
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Session Expired. Re-link required.")
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

# --- Authentication Endpoints ---

@router.post("/signup")
async def signup(data: dict = Body(...)):
    email = data.get("email", "").lower().strip()
    password = data.get("password")
    full_name = data.get("full_name", "Cyber Operator")

    if not email or not password:
        raise HTTPException(status_code=400, detail="Missing neural coordinates (email/password)")

    # Check if user exists
    existing_user = mongo_db.find_user_by_email(email)
    if existing_user:
        raise HTTPException(status_code=400, detail="Neural ID already registered.")

    # Create user with Bcrypt
    pwd_hash = get_password_hash(password)
    user_id = mongo_db.create_user(email, pwd_hash, full_name)
    
    if user_id:
        # Generate JWT Token
        access_token = create_access_token(
            data={"sub": email}, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        )
        return {
            "success": True, 
            "message": "Neural Profile Created", 
            "token": access_token,
            "user": {"email": email, "full_name": full_name}
        }
    else:
        raise HTTPException(status_code=500, detail="Cloud sync failed")

@router.post("/login")
async def login(data: dict = Body(...)):
    email = data.get("email", "").lower().strip()
    password = data.get("password")

    print(f"[Auth Debug] Login attempt for: '{email}'")
    user = mongo_db.find_user_by_email(email)
    
    if not user:
        print(f"[Auth Debug] User NOT found in database.")
        raise HTTPException(status_code=401, detail="Neural ID not found")

    print(f"[Auth Debug] User found: {user['email']}")

    # If it's a Google OAuth user, don't let them login with a standard password route unless they set one
    if user["password_hash"] == "GOOGLE_OAUTH_USER":
        print(f"[Auth Debug] Rejecting login: This is a Google OAuth account.")
        raise HTTPException(status_code=401, detail="This account uses Google OAuth. Please use 'Continue with Google'.")

    is_correct = verify_password(password, user["password_hash"])
    print(f"[Auth Debug] Password check result: {is_correct}")

    if not is_correct:
        raise HTTPException(status_code=401, detail="Access Denied: Invalid Credentials")

    # Generate JWT Token
    access_token = create_access_token(
        data={"sub": user["email"]}, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    return {
        "success": True,
        "message": "Access Granted",
        "token": access_token,
        "user": {
            "email": user["email"],
            "full_name": user["full_name"]
        }
    }

@router.post("/google")
async def google_auth(data: dict = Body(...)):
    email = data.get("email", "").lower().strip()
    full_name = data.get("full_name")
    
    if not email:
        raise HTTPException(status_code=400, detail="Google synchronization failed")
        
    user = mongo_db.find_user_by_email(email)
    
    if not user:
        # Create Google User
        mongo_db.create_user(
            email=email,
            password_hash="GOOGLE_OAUTH_USER", 
            full_name=full_name or "Google Operator"
        )
        user = mongo_db.find_user_by_email(email)
        
    # Generate JWT Token
    access_token = create_access_token(
        data={"sub": user["email"]}, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    return {
        "success": True, 
        "message": "Google Link Established",
        "token": access_token,
        "user": {
            "email": user["email"], 
            "full_name": user["full_name"]
        }
    }

# --- Inventory Endpoints ---

@router.post("/inventory/save")
async def save_to_inventory(data: dict = Body(...), current_email: str = Depends(verify_token)):
    """Save an item to the authenticated user's inventory"""
    success = mongo_db.add_to_inventory(current_email, data)
    if success:
        return {"success": True, "message": "Item saved to Neural Inventory"}
    else:
        raise HTTPException(status_code=500, detail="Failed to save item")

@router.get("/inventory/list")
async def get_inventory(current_email: str = Depends(verify_token)):
    """Fetch the authenticated user's inventory"""
    inventory = mongo_db.get_user_inventory(current_email)
    # Convert dates to strings for JSON serialization
    for item in inventory:
        if "added_at" in item:
            item["added_at"] = item["added_at"].isoformat()
            
    return {"success": True, "inventory": inventory}
