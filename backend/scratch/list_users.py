from app.database import mongo_db

def list_users():
    print("Fetching user list from MongoDB...")
    users = list(mongo_db.users.find({}, {"email": 1, "full_name": 1, "_id": 0}))
    if not users:
        print("No users found.")
    else:
        for u in users:
            print(f"User: {u.get('email')} ({u.get('full_name')})")

if __name__ == "__main__":
    list_users()
