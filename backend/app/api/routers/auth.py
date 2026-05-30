import os
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Body
from passlib.context import CryptContext
import jwt

from app.database import mongo_db
from app.schemas import AuthResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "cybersight_neural_link_secure_secret_key_2024_pfe")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 week

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

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

@router.post("/signup", response_model=AuthResponse)
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
        mongo_db.record_login(email, device_info="Signup")
        is_admin = "admin" in email.lower()
        return {
            "success": True, 
            "message": "Neural Profile Created", 
            "token": access_token,
            "user": {"email": email, "full_name": full_name, "is_admin": is_admin}
        }
    else:
        raise HTTPException(status_code=500, detail="Cloud sync failed")

@router.post("/login", response_model=AuthResponse)
async def login(data: dict = Body(...)):
    email = data.get("email", "").lower().strip()
    password = data.get("password")

    user = mongo_db.find_user_by_email(email)
    
    if not user:
        raise HTTPException(status_code=401, detail="Neural ID not found")

    if user["password_hash"] == "GOOGLE_OAUTH_USER":
        raise HTTPException(status_code=401, detail="This account uses Google OAuth. Please use 'Continue with Google'.")

    is_correct = verify_password(password, user["password_hash"])

    if not is_correct:
        raise HTTPException(status_code=401, detail="Access Denied: Invalid Credentials")

    # Generate JWT Token
    access_token = create_access_token(
        data={"sub": user["email"]}, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    mongo_db.record_login(user["email"], device_info="Login")

    return {
        "success": True,
        "message": "Access Granted",
        "token": access_token,
        "user": {
            "email": user["email"],
            "full_name": user["full_name"],
            "is_admin": user.get("is_admin", False)
        }
    }

@router.post("/google", response_model=AuthResponse)
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
    mongo_db.record_login(user["email"], device_info="Google Auth")

    return {
        "success": True, 
        "message": "Google Link Established",
        "token": access_token,
        "user": {
            "email": user["email"], 
            "full_name": user["full_name"],
            "is_admin": user.get("is_admin", False)
        }
    }
