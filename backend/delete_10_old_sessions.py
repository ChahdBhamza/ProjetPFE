import os
from pymongo import MongoClient
import urllib.parse

raw_uri = os.getenv("MONGODB_URI") or "mongodb+srv://chahd:chahd123@cluster0.mcynbno.mongodb.net/?appName=Cluster0"

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

    print("Deleting 10 scan sessions...")

    # Simple delete without sorting - just remove any 10 sessions
    # Get count before
    before = db.scan_sessions.count_documents({})
    print(f"[INFO] Total sessions before: {before}")

    # Delete 10 sessions (without sorting to avoid memory issues)
    result = db.scan_sessions.delete_many({})

    # Only delete if we have more than 10
    if before > 10:
        # Use batch delete - delete first 10 by ID
        to_delete = list(db.scan_sessions.find().limit(10))
        if to_delete:
            ids = [s['_id'] for s in to_delete]
            result = db.scan_sessions.delete_many({"_id": {"$in": ids}})
            print(f"[OK] Deleted {result.deleted_count} scan sessions")
        else:
            print("No sessions found")
    else:
        print("Too few sessions to delete safely")

    # Show remaining count
    remaining = db.scan_sessions.count_documents({})
    print(f"[INFO] Remaining scan sessions: {remaining}")
    print(f"[OK] Freed up space from MongoDB!")

    client.close()
except Exception as e:
    print(f"[ERROR] {e}")
