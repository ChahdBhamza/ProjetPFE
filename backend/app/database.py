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
            self.inventory = self.db.inventory
            self.auth_sessions = self.db.auth_sessions
            self.scan_sessions = self.db.scan_sessions
            self.system_logs = self.db.system_logs
            self.spec_cache = self.db.spec_cache
            # Unique index so each (brand, model, category) is cached once
            try:
                self.spec_cache.create_index(
                    [("cache_key", 1)], unique=True
                )
            except Exception as _e:
                print(f"[MongoDB] spec_cache index warning: {_e}")
            print("[MongoDB] Neural Link Established: Atlas Cluster Verified.")
        except Exception as e:
            print(f"[MongoDB] Neural Link Failed (Check Atlas Whitelist): {e}")
            self.client = None

    def create_user(self, email, password_hash, full_name, is_admin=None):
        """Create a new user profile in MongoDB"""
        if not self.client: return False
        if is_admin is None:
            is_admin = "admin" in email.lower()
        try:
            user_data = {
                "email": email,
                "password_hash": password_hash,
                "full_name": full_name,
                "is_admin": is_admin,
                "created_at": datetime.datetime.now()
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
        items = list(self.inventory.find({"user_email": email}, {"_id": 0}))
        return items

    def add_to_inventory(self, email: str, item_data: dict):
        """Add a detected item to the user's inventory"""
        if not self.client: return False
        try:
            item_data["user_email"] = email
            item_data["added_at"] = datetime.datetime.now()
            result = self.inventory.insert_one(item_data)
            return bool(result.inserted_id)
        except Exception as e:
            print(f"[MongoDB] Inventory Save Error: {e}")
            return False

    def filter_user_inventory(self, email: str, filters: dict):
        """Filter the user's inventory based on dynamic criteria"""
        if not self.client: return []
        query = {"user_email": email}
        
        # Dynamic query building based on provided filters
        if filters.get("category"):
            query["equipment_category"] = filters["category"]
            
        if filters.get("brand"):
            query["brand"] = {"$regex": filters["brand"], "$options": "i"}
            
        # Price filtering
        min_price = filters.get("min_price")
        max_price = filters.get("max_price")
        if min_price is not None or max_price is not None:
            query["specs.price_tnd"] = {}
            if min_price is not None:
                query["specs.price_tnd"]["$gte"] = float(min_price)
            if max_price is not None:
                query["specs.price_tnd"]["$lte"] = float(max_price)
                
        # BTU filtering (for Air Conditioners)
        min_btu = filters.get("min_btu")
        if min_btu is not None:
            query["specs.capacity_btu"] = {"$gte": int(min_btu)}
            
        items = list(self.inventory.find(query, {"_id": 0}))
        return items

    @staticmethod
    def _spec_cache_key(brand: str, model: str, category: str) -> str:
        """Normalised lookup key so casing/spacing differences still hit the cache."""
        return f"{brand.strip().lower()}|{model.strip().lower()}|{category.strip().lower()}"

    def get_cached_specs(self, brand: str, model: str, category: str):
        """Return a previously-fetched spec result, or None on miss."""
        if not self.client:
            return None
        try:
            key = self._spec_cache_key(brand, model, category)
            doc = self.spec_cache.find_one({"cache_key": key}, {"_id": 0, "cache_key": 0, "cached_at": 0})
            return doc
        except Exception as e:
            print(f"[SpecCache] read error: {e}")
            return None

    def cache_specs(self, brand: str, model: str, category: str, result: dict):
        """Store a spec result keyed by (brand, model, category). Upserts."""
        if not self.client:
            return False
        try:
            key = self._spec_cache_key(brand, model, category)
            doc = dict(result)
            doc["cache_key"] = key
            doc["cached_at"] = datetime.datetime.now()
            self.spec_cache.replace_one({"cache_key": key}, doc, upsert=True)
            return True
        except Exception as e:
            print(f"[SpecCache] write error: {e}")
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

    def record_login(self, email: str, device_info: str = "Unknown"):
        """Record an auth session"""
        if not self.client: return False
        try:
            self.auth_sessions.insert_one({
                "user_email": email,
                "device_info": device_info,
                "login_time": datetime.datetime.now()
            })
            return True
        except Exception:
            return False

    def start_scan_session(self, email: str, session_id: str, device_info: str = "Unknown"):
        """Start a new camera scan session"""
        if not self.client: return False
        try:
            self.scan_sessions.insert_one({
                "session_id": session_id,
                "user_email": email,
                "device_info": device_info,
                "start_time": datetime.datetime.now(),
                "status": "active"
            })
            return True
        except Exception:
            return False

    def end_scan_session(self, session_id: str, status: str = "completed", hero_frame_base64: str = None):
        """End an active camera scan session and attach the hero frame"""
        if not self.client: return False
        try:
            update_data = {"end_time": datetime.datetime.now(), "status": status}
            if hero_frame_base64:
                update_data["hero_frame_base64"] = hero_frame_base64
                
            self.scan_sessions.update_one(
                {"session_id": session_id},
                {"$set": update_data}
            )
            return True
        except Exception:
            return False

    def log_detection(self, session_id: str, data: dict):
        """Log a raw detection event linked to a scan session"""
        if not self.client: return False
        try:
            log_data = data.copy()
            log_data["scan_session_id"] = session_id
            log_data["timestamp"] = datetime.datetime.now()
            self.detections.insert_one(log_data)
            return True
        except Exception:
            return False

    def add_system_log(self, level: str, module: str, message: str, email: str = None):
        """Add a system log"""
        if not self.client: return False
        try:
            self.system_logs.insert_one({
                "timestamp": datetime.datetime.now(),
                "level": level,
                "module": module,
                "message": message,
                "user_email": email
            })
            return True
        except Exception:
            return False

# Global singleton
mongo_db = MongoService()
