import os
from datetime import datetime, timedelta
from pymongo import MongoClient
import urllib.parse
from dotenv import load_dotenv

load_dotenv()

raw_uri = os.getenv("MONGODB_URI")

# Handle password escaping
if "@" in raw_uri and ":" in raw_uri:
    protocol, rest = raw_uri.split("://", 1)
    user_pass, host_info = rest.rsplit("@", 1)

    if ":" in user_pass:
        user, password = user_pass.split(":", 1)
        safe_pass = urllib.parse.quote_plus(password)
        raw_uri = f"{protocol}://{user}:{safe_pass}@{host_info}"

try:
    client = MongoClient(raw_uri, serverSelectionTimeoutMS=5000)
    client.admin.command('ping')
    db = client.get_database("equipment_detection_db")

    print("🔍 Checking storage...")

    # Check scan_sessions
    total_sessions = db.scan_sessions.count_documents({})
    print(f"\n📊 Scan sessions: {total_sessions} total")

    # Delete sessions older than 7 days
    cutoff_date = datetime.now() - timedelta(days=7)
    result = db.scan_sessions.delete_many({"start_time": {"$lt": cutoff_date}})
    print(f"✅ Deleted {result.deleted_count} scan sessions older than 7 days")

    # Check detections
    detections_count = db.detections.count_documents({})
    print(f"\n📊 Detections: {detections_count} documents")

    # Optional: Delete old detections too (older than 30 days)
    old_detections = db.detections.delete_many({"timestamp": {"$lt": datetime.now() - timedelta(days=30)}})
    print(f"✅ Deleted {old_detections.deleted_count} detections older than 30 days")

    # Check auth_sessions
    auth_count = db.auth_sessions.count_documents({})
    print(f"\n📊 Auth sessions: {auth_count} documents")

    # Delete old auth sessions (older than 30 days)
    old_auth = db.auth_sessions.delete_many({"login_time": {"$lt": datetime.now() - timedelta(days=30)}})
    print(f"✅ Deleted {old_auth.deleted_count} auth sessions older than 30 days")

    print("\n✨ Storage cleanup complete! Try saving to inventory now.")

    client.close()
except Exception as e:
    print(f"❌ Error: {e}")
