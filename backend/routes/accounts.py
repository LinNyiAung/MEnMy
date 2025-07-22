from fastapi import APIRouter, HTTPException, status, Depends
from datetime import datetime
from models import AccountCreate, AccountUpdate, AccountResponse
from auth_utils import get_current_user, accounts_collection
from bson import ObjectId
from typing import List

router = APIRouter(prefix="/accounts", tags=["Accounts"])

@router.post("/", response_model=dict)
async def create_account(
    account: AccountCreate, 
    current_user: dict = Depends(get_current_user)
):
    # Create account document
    account_doc = {
        "name": account.name,
        "account_type": account.account_type.value,
        "email": account.email,
        "phone_number": account.phone_number,
        "user_id": str(current_user["_id"]),
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    
    # Insert into database
    result = accounts_collection.insert_one(account_doc)
    
    return {
        "message": "Account created successfully",
        "account": {
            "id": str(result.inserted_id),
            "name": account.name,
            "account_type": account.account_type.value,
            "email": account.email,
            "phone_number": account.phone_number,
            "user_id": str(current_user["_id"]),
            "created_at": account_doc["created_at"],
            "updated_at": account_doc["updated_at"]
        }
    }

@router.get("/", response_model=dict)
async def get_user_accounts(current_user: dict = Depends(get_current_user)):
    # Get all accounts for the current user
    accounts_cursor = accounts_collection.find({"user_id": str(current_user["_id"])})
    accounts = []
    
    for account in accounts_cursor:
        accounts.append({
            "id": str(account["_id"]),
            "name": account["name"],
            "account_type": account["account_type"],
            "email": account.get("email"),
            "phone_number": account.get("phone_number"),
            "user_id": account["user_id"],
            "created_at": account["created_at"],
            "updated_at": account["updated_at"]
        })
    
    return {
        "accounts": accounts,
        "count": len(accounts)
    }

@router.get("/{account_id}", response_model=dict)
async def get_account(
    account_id: str, 
    current_user: dict = Depends(get_current_user)
):
    # Validate ObjectId
    try:
        obj_id = ObjectId(account_id)
    except:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid account ID"
        )
    
    # Find account
    account = accounts_collection.find_one({
        "_id": obj_id,
        "user_id": str(current_user["_id"])
    })
    
    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found"
        )
    
    return {
        "account": {
            "id": str(account["_id"]),
            "name": account["name"],
            "account_type": account["account_type"],
            "email": account.get("email"),
            "phone_number": account.get("phone_number"),
            "user_id": account["user_id"],
            "created_at": account["created_at"],
            "updated_at": account["updated_at"]
        }
    }

@router.put("/{account_id}", response_model=dict)
async def update_account(
    account_id: str,
    account_update: AccountUpdate,
    current_user: dict = Depends(get_current_user)
):
    # Validate ObjectId
    try:
        obj_id = ObjectId(account_id)
    except:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid account ID"
        )
    
    # Build update document
    update_doc = {"updated_at": datetime.utcnow()}
    
    if account_update.name is not None:
        update_doc["name"] = account_update.name
    if account_update.account_type is not None:
        update_doc["account_type"] = account_update.account_type.value
    if account_update.email is not None:
        update_doc["email"] = account_update.email
    if account_update.phone_number is not None:
        update_doc["phone_number"] = account_update.phone_number
    
    # Update account
    result = accounts_collection.update_one(
        {
            "_id": obj_id,
            "user_id": str(current_user["_id"])
        },
        {"$set": update_doc}
    )
    
    if result.matched_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found"
        )
    
    # Get updated account
    updated_account = accounts_collection.find_one({"_id": obj_id})
    
    return {
        "message": "Account updated successfully",
        "account": {
            "id": str(updated_account["_id"]),
            "name": updated_account["name"],
            "account_type": updated_account["account_type"],
            "email": updated_account.get("email"),
            "phone_number": updated_account.get("phone_number"),
            "user_id": updated_account["user_id"],
            "created_at": updated_account["created_at"],
            "updated_at": updated_account["updated_at"]
        }
    }

@router.delete("/{account_id}", response_model=dict)
async def delete_account(
    account_id: str,
    current_user: dict = Depends(get_current_user)
):
    # Validate ObjectId
    try:
        obj_id = ObjectId(account_id)
    except:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid account ID"
        )
    
    # Delete account
    result = accounts_collection.delete_one({
        "_id": obj_id,
        "user_id": str(current_user["_id"])
    })
    
    if result.deleted_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found"
        )
    
    return {"message": "Account deleted successfully"}