#!/usr/bin/env python
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from app.database import mongo_db
from dotenv import load_dotenv

load_dotenv()
uri = os.getenv("MONGODB_URI")
print(f"Using URI: {uri}")

if mongo_db.client:
    print("SUCCESS: MongoDB Connected!")
    print(f"Database: {mongo_db.db.name}")
    collections = mongo_db.db.list_collection_names()
    print(f"Collections: {collections}")
else:
    print("FAILED: MongoDB Connection Failed")
