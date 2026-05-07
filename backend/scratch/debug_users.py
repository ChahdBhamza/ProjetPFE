import os
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

def debug_users():
    uri = os.getenv("MONGODB_URI")
    client = MongoClient(uri)
    db = client.get_database("equipment_detection_db")
    users = db.users
    
    print("\n=== CURRENT REGISTERED USERS ===")
    for user in users.find():
        email = user.get("email")
        pwd_hash = user.get("password_hash")
        name = user.get("full_name")
        print(f"Name: {name} | Email: {email} | Hash Start: {str(pwd_hash)[:15]}...")
    print("================================\n")

if __name__ == "__main__":
    debug_users()
