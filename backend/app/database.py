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

            self.client = MongoClient(raw_uri, serverSelectionTimeoutMS=5000)
            # Force a connection check
            self.client.admin.command('ping')
            
            self.db = self.client.get_database("equipment_detection_db")
            self.detections = self.db.detections
            self.users = self.db.users
            print("[MongoDB] Neural Link Established: Atlas Cluster Verified.")
        except Exception as e:
            print(f"[MongoDB] Neural Link Failed (Check Atlas Whitelist): {e}")
            self.client = None

    def create_user(self, email, password_hash, full_name):
        """Create a new user profile in MongoDB"""
        if not self.client: return False
        try:
            user_data = {
                "email": email,
                "password_hash": password_hash,
                "full_name": full_name,
                "created_at": datetime.datetime.now(),
                "inventory": [] # Start with an empty inventory
            }
            return self.users.insert_one(user_data).inserted_id
        except Exception as e:
            print(f"[MongoDB] User Creation Error: {e}")
            return None

    def find_user_by_email(self, email):
        """Find a user by their email address"""
        if not self.client: return None
        return self.users.find_one({"email": email})

    def get_user_inventory(self, email: str):
        """Fetch the inventory list for a specific user"""
        if not self.client: return []
        user = self.users.find_one({"email": email}, {"inventory": 1, "_id": 0})
        if user and "inventory" in user:
            return user["inventory"]
        return []

    def add_to_inventory(self, email: str, item_data: dict):
        """Add a detected item to the user's inventory"""
        if not self.client: return False
        try:
            item_data["added_at"] = datetime.datetime.now()
            result = self.users.update_one(
                {"email": email},
                {"$push": {"inventory": item_data}}
            )
            return result.modified_count > 0
        except Exception as e:
            print(f"[MongoDB] Inventory Save Error: {e}")
            return False

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
