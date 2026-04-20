import os
import datetime
import urllib.parse
from pymongo import MongoClient
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

class MongoService:
    def __init__(self):
        # Read URI from environment
        raw_uri = os.getenv("MONGODB_URI")
        
        if not raw_uri or "REPLACE_WITH_YOUR_PASSWORD" in raw_uri:
            print("[MongoDB] WARNING: MONGODB_URI is not set or still contains the placeholder!")
            self.client = None
            return

        try:
            # Automatic Fix: If the password contains special chars like @, :, /, this fixes the "RFC 3986" error
            # We assume the user followed the format mongodb+srv://username:password@cluster...
            if "@" in raw_uri and ":" in raw_uri:
                protocol, rest = raw_uri.split("://", 1)
                user_pass, host_info = rest.rsplit("@", 1)
                
                if ":" in user_pass:
                    user, password = user_pass.split(":", 1)
                    # Escape the password and reconstruct
                    safe_pass = urllib.parse.quote_plus(password)
                    raw_uri = f"{protocol}://{user}:{safe_pass}@{host_info}"

            self.client = MongoClient(raw_uri)
            # Access the database named in the URI or default to detection_db
            self.db = self.client.get_database("ac_detection_db")
            self.detections = self.db.detections
            print("[MongoDB] Connected successfully to Atlas Cluster.")
        except Exception as e:
            print(f"[MongoDB] Connection Error: {e}")
            self.client = None

    def save_detection(self, brand: str, raw_text: str = None, btu: int = None, details: dict = None):
        """Save a new detection event to the cloud"""
        if not self.client:
            print("[MongoDB] No connection. Skipping save.")
            return False

        try:
            document = {
                "timestamp": datetime.datetime.now(),
                "brand": brand,
                "raw_ocr": raw_text,
                "btu": btu,
                "metadata": details,
                "source": "Hybrid Pipeline"
            }
            result = self.detections.insert_one(document)
            print(f"[MongoDB] Saved detection with ID: {result.inserted_id}")
            return True
        except Exception as e:
            print(f"[MongoDB] Failed to save detection: {e}")
            return False

# Global singleton
mongo_db = MongoService()
