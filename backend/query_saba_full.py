import os
import json
from bson import ObjectId
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv('.env')
uri = os.getenv('MONGODB_URI')
if not uri:
    raise SystemExit('MONGODB_URI missing')
client = MongoClient(uri, serverSelectionTimeoutMS=5000)
db = client.get_database('equipment_detection_db')
ids = [
    '6a1d38cfac10b013d3b10e5c',
    '6a19906ab22c92f721427f33',
    '6a1ae02cda2f5e0ba0a0c2d5',
    '6a1d32e9a2acb5710dfb45b3'
]
for _id in ids:
    doc = db.inventory.find_one({'_id': ObjectId(_id)})
    if doc:
        doc['_id'] = str(doc['_id'])
        print(json.dumps(doc, default=str, ensure_ascii=False, indent=2))
        print('---')
