import os
import pymongo
from dotenv import load_dotenv

load_dotenv()

MONGODB_URL = os.getenv("MONGODB_URL")
DATABASE_NAME = os.getenv("DATABASE_NAME", "finance_app")

def create_indexes():
    try:
        client = pymongo.MongoClient(MONGODB_URL)
        db = client[DATABASE_NAME]
        
        # Transaction indexes
        transactions_collection = db.transactions
        
        # Index for user_id (most common query)
        transactions_collection.create_index("user_id")
        
        # Index for user_id + transaction_date (for sorting and date filtering)
        transactions_collection.create_index([("user_id", 1), ("transaction_date", -1)])
        
        # Index for user_id + from_account_id
        transactions_collection.create_index([("user_id", 1), ("from_account_id", 1)])
        
        # Index for user_id + to_account_id
        transactions_collection.create_index([("user_id", 1), ("to_account_id", 1)])
        
        # Compound index for analytics queries
        transactions_collection.create_index([("user_id", 1), ("type", 1), ("transaction_date", -1)])
        
        # Account indexes (if not already created)
        accounts_collection = db.accounts
        accounts_collection.create_index("user_id")
        accounts_collection.create_index([("user_id", 1), ("name", 1)])
        
        # User indexes
        users_collection = db.users
        users_collection.create_index("email", unique=True)
        
        print("✅ Database indexes created successfully!")
        
    except Exception as e:
        print(f"❌ Error creating indexes: {e}")

if __name__ == "__main__":
    create_indexes()