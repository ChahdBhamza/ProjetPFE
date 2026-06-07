import os
import random
import smtplib
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional
from fastapi import APIRouter, HTTPException, Body
from passlib.context import CryptContext
import jwt

from app.database import mongo_db
from app.schemas import AuthResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "cybersight_neural_link_secure_secret_key_2024_pfe")
GMAIL_USER = os.getenv("GMAIL_USER")
GMAIL_APP_PASSWORD = os.getenv("GMAIL_APP_PASSWORD")
DEV_MODE = os.getenv("DEV_MODE", "false").lower() == "true"
ALGORITHM = "HS256"
ADMIN_EMAIL = "chahdbenhamza4@gmail.com"
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
        is_admin = email.lower() == ADMIN_EMAIL
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
            "is_admin": user["email"].lower() == ADMIN_EMAIL
        }
    }

def _send_otp_email(to_email: str, otp: str):
    if not GMAIL_USER or not GMAIL_APP_PASSWORD:
        raise RuntimeError("Gmail credentials not configured in .env")
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Cybersight — Password Reset Code"
    msg["From"] = GMAIL_USER
    msg["To"] = to_email
    plain = f"Your Cybersight password reset code is: {otp}\n\nThis code expires in 10 minutes."
    html = f"""
    <div style="font-family:monospace;background:#0a0a0a;color:#fff;padding:32px;border-radius:12px;">
      <h2 style="color:#00e5ff;margin-bottom:4px;">CYBERSIGHT</h2>
      <p style="color:#888;margin-top:0;">Password Reset Request</p>
      <p>Your reset code:</p>
      <h1 style="letter-spacing:12px;color:#00e5ff;font-size:36px;">{otp}</h1>
      <p style="color:#888;font-size:12px;">Expires in 10 minutes. If you didn't request this, ignore this email.</p>
    </div>
    """
    msg.attach(MIMEText(plain, "plain"))
    msg.attach(MIMEText(html, "html"))
    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(GMAIL_USER, GMAIL_APP_PASSWORD)
        server.sendmail(GMAIL_USER, to_email, msg.as_string())


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

    if not user:
        raise HTTPException(status_code=500, detail="Database connection failed. Check MongoDB Atlas.")

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
            "is_admin": user["email"].lower() == ADMIN_EMAIL
        }
    }


@router.post("/forgot-password")
async def forgot_password(data: dict = Body(...)):
    email = data.get("email", "").lower().strip()
    if not email:
        raise HTTPException(status_code=400, detail="Email required")

    user = mongo_db.find_user_by_email(email)
    if not user:
        # Don't reveal whether the email exists
        return {"success": True, "message": "If this email is registered, a reset code was sent."}

    if user.get("password_hash") == "GOOGLE_OAUTH_USER":
        raise HTTPException(status_code=400, detail="This account uses Google Sign-In. Password reset is not available.")

    otp = str(random.randint(100000, 999999))
    expires_at = datetime.utcnow() + timedelta(minutes=10)
    mongo_db.save_reset_otp(email, otp, expires_at)

    if DEV_MODE:
        print(f"[DEV MODE] OTP for {email}: {otp}")
        return {"success": True, "message": "Reset code sent to your email.", "dev_otp": otp}

    try:
        _send_otp_email(email, otp)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {e}")

    return {"success": True, "message": "Reset code sent to your email."}


@router.post("/verify-otp")
async def verify_otp(data: dict = Body(...)):
    email = data.get("email", "").lower().strip()
    otp = data.get("otp", "").strip()

    if not email or not otp:
        raise HTTPException(status_code=400, detail="Email and code required")

    record = mongo_db.get_reset_otp(email)
    if not record or not record.get("reset_otp"):
        raise HTTPException(status_code=400, detail="No reset code found. Request a new one.")

    if datetime.utcnow() > record["reset_otp_expires"]:
        mongo_db.clear_reset_otp(email)
        raise HTTPException(status_code=400, detail="Code expired. Request a new one.")

    if record["reset_otp"] != otp:
        raise HTTPException(status_code=400, detail="Invalid code.")

    return {"success": True, "message": "Code verified."}


@router.post("/reset-password")
async def reset_password(data: dict = Body(...)):
    email = data.get("email", "").lower().strip()
    otp = data.get("otp", "").strip()
    new_password = data.get("new_password", "")

    if not email or not otp or not new_password:
        raise HTTPException(status_code=400, detail="Email, code and new password required")

    if len(new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    record = mongo_db.get_reset_otp(email)
    if not record or not record.get("reset_otp"):
        raise HTTPException(status_code=400, detail="No reset code found. Request a new one.")

    if datetime.utcnow() > record["reset_otp_expires"]:
        mongo_db.clear_reset_otp(email)
        raise HTTPException(status_code=400, detail="Code expired. Request a new one.")

    if record["reset_otp"] != otp:
        raise HTTPException(status_code=400, detail="Invalid code.")

    new_hash = get_password_hash(new_password)
    mongo_db.update_password(email, new_hash)
    mongo_db.clear_reset_otp(email)

    return {"success": True, "message": "Password reset successful."}
