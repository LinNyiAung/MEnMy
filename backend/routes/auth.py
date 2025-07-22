import os
from fastapi import APIRouter, HTTPException, status, Depends
from datetime import timedelta
from models import UserSignUp, UserSignIn, UserResponse, Token
from auth_utils import (  # Changed from 'auth' to 'auth_utils'
    get_password_hash, 
    verify_password, 
    create_access_token, 
    users_collection,
    get_current_user,
    ACCESS_TOKEN_EXPIRE_MINUTES
)
from datetime import datetime
from bson import ObjectId

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/signup", response_model=dict)
async def sign_up(user: UserSignUp):
    # Check if user already exists
    existing_user = users_collection.find_one({"email": user.email})
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Hash password and create user
    hashed_password = get_password_hash(user.password)
    user_doc = {
        "full_name": user.full_name,
        "email": user.email,
        "hashed_password": hashed_password,
        "created_at": datetime.utcnow()
    }
    
    result = users_collection.insert_one(user_doc)
    
    # Create access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    
    return {
        "message": "User created successfully",
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": str(result.inserted_id),
            "full_name": user.full_name,
            "email": user.email
        }
    }

@router.post("/signin", response_model=dict)
async def sign_in(user: UserSignIn):
    # Find user by email
    db_user = users_collection.find_one({"email": user.email})
    
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Debug: Print the user document structure (remove this in production)
    print(f"Debug - User document keys: {list(db_user.keys())}")
    
    # Check for hashed_password field
    if "hashed_password" not in db_user:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="User data corrupted - password field missing"
        )
    
    # Verify password
    if not verify_password(user.password, db_user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": str(db_user["_id"]),
            "full_name": db_user["full_name"],
            "email": db_user["email"]
        }
    }

@router.get("/me", response_model=dict)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    return {
        "id": str(current_user["_id"]),
        "full_name": current_user["full_name"],
        "email": current_user["email"],
        "created_at": current_user["created_at"]
    }

# Debug endpoint to check user structure (remove in production)
@router.get("/debug/user/{email}")
async def debug_user(email: str):
    user = users_collection.find_one({"email": email})
    if user:
        # Remove sensitive data before returning
        user.pop("hashed_password", None)
        user["_id"] = str(user["_id"])
        return user
    return {"message": "User not found"}

# Temporary cleanup endpoint (remove in production)
@router.delete("/debug/cleanup/{email}")
async def cleanup_user(email: str):
    result = users_collection.delete_one({"email": email})
    return {"deleted_count": result.deleted_count}