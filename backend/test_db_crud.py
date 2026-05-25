import os
import sys

# Ensure app can be imported
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.database import mongo_db

def test_crud():
    print("Testing MongoDB CRUD operations...")
    
    if not mongo_db.client:
        print("Failed: No MongoDB client connected. Check your URI in .env.")
        return

    # 1. Test User Creation
    test_email = "test_crud@example.com"
    print("\n--- Testing User CRUD ---")
    user_id = mongo_db.create_user(test_email, "dummy_hash", "Test User")
    if user_id:
        print(f"Success: Created user with ID {user_id}")
    else:
        print("Failed: Could not create user")

    # 2. Test Find User
    user = mongo_db.find_user_by_email(test_email)
    if user:
        print(f"Success: Found user {user['email']}")
    else:
        print("Failed: Could not find user")

    # 3. Test Add to Inventory
    print("\n--- Testing Inventory CRUD ---")
    item_data = {
        "equipment_category": "Air Conditioner",
        "brand": "Samsung",
        "model": "AR12BX",
        "specs": {
            "capacity_btu": 12000,
            "price_tnd": 1500
        }
    }
    inv_result = mongo_db.add_to_inventory(test_email, item_data)
    if inv_result:
        print("Success: Added item to inventory")
    else:
        print("Failed: Could not add item to inventory")

    # 4. Test Get Inventory
    inventory = mongo_db.get_user_inventory(test_email)
    if inventory and len(inventory) > 0:
        print(f"Success: Retrieved {len(inventory)} items from inventory")
        print(f"Sample item brand: {inventory[0].get('brand')}")
    else:
        print("Failed: Could not retrieve inventory")

    # 5. Test Filters
    filtered = mongo_db.filter_user_inventory(test_email, {"brand": "Sam"})
    if filtered and len(filtered) > 0:
        print("Success: Filtered inventory correctly")
    else:
        print("Failed: Inventory filter didn't match")

    # 6. Test Save Detection
    print("\n--- Testing Detection CRUD ---")
    det_result = mongo_db.save_detection("LG", raw_text="LG AC model 123", btu=9000, details={"confidence": 0.95})
    if det_result:
        print("Success: Saved detection")
    else:
        print("Failed: Could not save detection")

    # Cleanup test data
    print("\n--- Cleaning up test data ---")
    try:
        mongo_db.users.delete_one({"email": test_email})
        mongo_db.inventory.delete_many({"user_email": test_email})
        # Note: not cleaning up detections to avoid deleting real data inadvertently,
        # but the test detection is just one record.
        print("Cleanup successful.")
    except Exception as e:
        print(f"Cleanup failed: {e}")

if __name__ == "__main__":
    test_crud()
