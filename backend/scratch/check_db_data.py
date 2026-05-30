import os
import sys

# Ensure app can be imported
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__) + "/.."))

from app.database import mongo_db

def check_db():
    print("Connecting to MongoDB...")
    if not mongo_db.client:
        print("Failed: No connection.")
        return

    print("\n--- Users ---")
    users = list(mongo_db.users.find())
    for u in users:
        print(f"User: {u.get('email')} | Name: {u.get('full_name')} | Created: {u.get('created_at')}")

    print("\n--- Inventory Items ---")
    inventory = list(mongo_db.inventory.find())
    print(f"Total inventory items found in database: {len(inventory)}")
    for item in inventory:
        print(f"ID: {item.get('_id')} | User: {item.get('user_email')} | Brand: {item.get('brand')} | Model: {item.get('model')} | Added At: {item.get('added_at')}")

    print("\n--- Scan Sessions ---")
    sessions = list(mongo_db.scan_sessions.find())
    print(f"Total scan sessions found in database: {len(sessions)}")
    for s in sessions:
        print(f"Session: {s.get('session_id')} | User: {s.get('user_email')} | Status: {s.get('status')} | Start: {s.get('start_time')}")

if __name__ == "__main__":
    check_db()
