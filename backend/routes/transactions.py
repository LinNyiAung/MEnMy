import os
from pathlib import Path
import uuid
from fastapi import APIRouter, File, HTTPException, UploadFile, status, Depends, Query
from datetime import datetime

from fastapi.responses import FileResponse
from models import (
    TransactionCreate, 
    TransactionUpdate, 
    TransactionResponse, 
    MultipleTransactionsCreate
)
from auth_utils import get_current_user, transactions_collection, accounts_collection
from bson import ObjectId
from typing import List, Optional
import logging

# Add this constant after the imports
UPLOAD_DIR = "uploads/transaction_documents"

# Ensure upload directory exists - add this after the router definition
os.makedirs(UPLOAD_DIR, exist_ok=True)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/transactions", tags=["Transactions"])

def cleanup_transaction_files(document_files: List[str]) -> dict:
    """
    Helper function to clean up files associated with a transaction.
    Returns a dictionary with deletion results.
    """
    deleted_files = []
    failed_files = []
    
    for filename in document_files:
        if filename:  # Check if filename is not empty
            file_path = os.path.join(UPLOAD_DIR, filename)
            try:
                if os.path.exists(file_path):
                    os.remove(file_path)
                    deleted_files.append(filename)
                    logger.info(f"Deleted file: {filename}")
                else:
                    logger.warning(f"File not found for deletion: {filename}")
                    failed_files.append(f"{filename} (not found)")
            except Exception as file_error:
                logger.error(f"Error deleting file {filename}: {str(file_error)}")
                failed_files.append(f"{filename} (deletion error)")
    
    return {
        "deleted_files": deleted_files,
        "failed_files": failed_files
    }

@router.post("/upload-files", response_model=dict)
async def upload_transaction_files(
    files: List[UploadFile] = File(...),
    current_user: dict = Depends(get_current_user)
):
    try:
        user_id = str(current_user["_id"])
        uploaded_files = []
        
        # Validate file types and sizes
        allowed_extensions = {'.pdf', '.jpg', '.jpeg', '.png', '.gif', '.doc', '.docx', '.txt'}
        max_file_size = 10 * 1024 * 1024  # 10MB
        
        for file in files:
            # Check file extension
            file_extension = Path(file.filename).suffix.lower()
            if file_extension not in allowed_extensions:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"File type {file_extension} not allowed. Allowed types: {', '.join(allowed_extensions)}"
                )
            
            # Check file size
            file_content = await file.read()
            if len(file_content) > max_file_size:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"File {file.filename} is too large. Maximum size is 10MB"
                )
            
            # Generate unique filename
            unique_filename = f"{user_id}_{uuid.uuid4().hex}_{file.filename}"
            file_path = os.path.join(UPLOAD_DIR, unique_filename)
            
            # Save file
            with open(file_path, "wb") as buffer:
                buffer.write(file_content)
            
            uploaded_files.append({
                "original_filename": file.filename,
                "stored_filename": unique_filename,
                "file_path": file_path,
                "file_size": len(file_content),
                "content_type": file.content_type,
                "upload_date": datetime.utcnow()
            })
        
        return {
            "message": f"{len(uploaded_files)} files uploaded successfully",
            "files": uploaded_files
        }
        
    except Exception as e:
        logger.error(f"Error uploading files: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload files"
        )

# Add this endpoint to serve uploaded files
@router.get("/files/{filename}")
async def get_transaction_file(
    filename: str,
    current_user: dict = Depends(get_current_user)
):
    try:
        user_id = str(current_user["_id"])
        
        # Security check: ensure filename starts with user_id
        if not filename.startswith(user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied"
            )
        
        file_path = os.path.join(UPLOAD_DIR, filename)
        
        if not os.path.exists(file_path):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found"
            )
        
        return FileResponse(
            path=file_path,
            filename=filename.split('_', 2)[-1]  # Return original filename
        )
        
    except Exception as e:
        logger.error(f"Error serving file: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to serve file"
        )


@router.post("/", response_model=dict)
async def create_transaction(
    transaction: TransactionCreate, 
    current_user: dict = Depends(get_current_user)
):
    try:
        user_id = str(current_user["_id"])
        
        # Validate account ownership for from_account_id
        if transaction.from_account_id:
            from_account = accounts_collection.find_one({
                "_id": ObjectId(transaction.from_account_id),
                "user_id": user_id
            })
            if not from_account:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="From account not found or does not belong to user"
                )
        
        # Validate account ownership for to_account_id
        if transaction.to_account_id:
            to_account = accounts_collection.find_one({
                "_id": ObjectId(transaction.to_account_id),
                "user_id": user_id
            })
            if not to_account:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="To account not found or does not belong to user"
                )
        
        # Create transaction document
        transaction_doc = {
            "type": transaction.type.value,
            "amount": transaction.amount,
            "from_account_id": transaction.from_account_id,
            "to_account_id": transaction.to_account_id,
            "detail": transaction.detail,
            "document_files": transaction.document_files or [],  # Changed from document_record
            "user_id": user_id,
            "transaction_date": transaction.transaction_date or datetime.utcnow(),
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        # Insert into database
        result = transactions_collection.insert_one(transaction_doc)
        
        # Prepare response
        created_transaction = {
            "id": str(result.inserted_id),
            "type": transaction.type.value,
            "amount": transaction.amount,
            "from_account_id": transaction.from_account_id,
            "to_account_id": transaction.to_account_id,
            "detail": transaction.detail,
            "document_files": transaction_doc["document_files"],  # Changed from document_record
            "user_id": user_id,
            "transaction_date": transaction_doc["transaction_date"],
            "created_at": transaction_doc["created_at"],
            "updated_at": transaction_doc["updated_at"]
        }
        
        return {
            "message": "Transaction created successfully",
            "transaction": created_transaction
        }
        
    except ValueError as ve:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(ve)
        )
    except Exception as e:
        logger.error(f"Error creating transaction: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create transaction"
        )

@router.post("/multiple", response_model=dict)
async def create_multiple_transactions(
    request: MultipleTransactionsCreate,
    current_user: dict = Depends(get_current_user)
):
    try:
        user_id = str(current_user["_id"])
        created_transaction_docs = [] # Changed variable name for clarity

        # Get all user accounts for validation
        user_accounts = list(accounts_collection.find({"user_id": user_id}))
        user_account_ids = [str(acc["_id"]) for acc in user_accounts]

        for transaction in request.transactions:
            # Validate account ownership
            if transaction.from_account_id and transaction.from_account_id not in user_account_ids:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"From account {transaction.from_account_id} not found or does not belong to user"
                )

            if transaction.to_account_id and transaction.to_account_id not in user_account_ids:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"To account {transaction.to_account_id} not found or does not belong to user"
                )

            # Create transaction document
            transaction_doc = {
                "type": transaction.type.value,
                "amount": transaction.amount,
                "from_account_id": transaction.from_account_id,
                "to_account_id": transaction.to_account_id,
                "detail": transaction.detail,
                "document_files": transaction.document_files or [],
                "user_id": user_id, # Ensure user_id is a string
                "transaction_date": transaction.transaction_date or datetime.utcnow(),
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            created_transaction_docs.append(transaction_doc)

        # Insert all transactions
        # Use a session for atomicity if needed, but for simple inserts, this is fine.
        if not created_transaction_docs:
             raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No transactions provided to create."
            )
        
        result = transactions_collection.insert_many(created_transaction_docs)

        # Prepare response
        response_transactions_data = []
        # Fetch the inserted documents to ensure correct serialization
        inserted_ids_str = [str(oid) for oid in result.inserted_ids]
        
        # Retrieve the actual documents from the DB to ensure all types are serializable
        # This is the most robust way to handle potential ObjectId issues.
        # We query by the inserted IDs.
        fetched_docs_cursor = transactions_collection.find(
            {"_id": {"$in": result.inserted_ids}}
        )

        for doc in fetched_docs_cursor:
            # Ensure all potential ObjectIds are strings
            serialized_doc = {
                "_id": str(doc["_id"]),
                "type": doc["type"],
                "amount": doc["amount"],
                "from_account_id": doc.get("from_account_id"),
                "to_account_id": doc.get("to_account_id"),
                "detail": doc["detail"],
                "document_files": doc.get("document_files", []),  # Changed from document_record
                "user_id": doc["user_id"],
                "transaction_date": doc["transaction_date"],
                "created_at": doc["created_at"],
                "updated_at": doc["updated_at"]
            }

            response_transactions_data.append(serialized_doc)
            
        # Sort the response to match the order of insertion if necessary,
        # or just return them as fetched. Fetching by $in might not guarantee order.
        # A more robust way would be to map back to the original insertion order.
        # For simplicity now, we'll use the fetched order.

        return {
            "message": f"{len(response_transactions_data)} transactions created successfully",
            "transactions": response_transactions_data,
            "count": len(response_transactions_data)
        }

    except ValueError as ve:
        # This catches validation errors from Pydantic models
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(ve)
        )
    except HTTPException as http_exc:
        # Re-raise HTTPException to preserve status code and detail
        raise http_exc
    except Exception as e:
        logger.error(f"Error creating multiple transactions: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create transactions"
        )


@router.get("/", response_model=dict)
async def get_transactions(
    current_user: dict = Depends(get_current_user),
    limit: Optional[int] = Query(50, ge=1, le=100, description="Number of transactions to return"),
    offset: Optional[int] = Query(0, ge=0, description="Number of transactions to skip"),
    account_id: Optional[str] = Query(None, description="Filter by account ID")
):
    try:
        user_id = str(current_user["_id"])
        
        # Build query
        query = {"user_id": user_id}
        
        if account_id:
            # Validate account ownership
            account = accounts_collection.find_one({
                "_id": ObjectId(account_id),
                "user_id": user_id
            })
            if not account:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Account not found or does not belong to user"
                )
            
            # Filter transactions by account (either from or to)
            query["$or"] = [
                {"from_account_id": account_id},
                {"to_account_id": account_id}
            ]
        
        # Get total count
        total_count = transactions_collection.count_documents(query)
        
        # Get transactions with pagination, sorted by transaction_date descending
        transactions_cursor = transactions_collection.find(query)\
            .sort("transaction_date", -1)\
            .skip(offset)\
            .limit(limit)
        
        transactions = []
        for transaction in transactions_cursor:
            transactions.append({
                "id": str(transaction["_id"]),
                "type": transaction["type"],
                "amount": transaction["amount"],
                "from_account_id": transaction.get("from_account_id"),
                "to_account_id": transaction.get("to_account_id"),
                "detail": transaction["detail"],
                "document_files": transaction.get("document_files", []),  # Changed from document_record
                "user_id": transaction["user_id"],
                "transaction_date": transaction["transaction_date"],
                "created_at": transaction["created_at"],
                "updated_at": transaction["updated_at"]
            })
        
        return {
            "transactions": transactions,  # Fixed: Return the list of transactions
            "count": len(transactions),
            "total": total_count,
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        logger.error(f"Error fetching transactions: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch transactions"
        )

@router.get("/{transaction_id}", response_model=dict)
async def get_transaction(
    transaction_id: str,
    current_user: dict = Depends(get_current_user)
):
    try:
        # Validate ObjectId
        try:
            obj_id = ObjectId(transaction_id)
        except:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid transaction ID"
            )
        
        # Find transaction
        transaction = transactions_collection.find_one({
            "_id": obj_id,
            "user_id": str(current_user["_id"])
        })
        
        if not transaction:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transaction not found"
            )
        
        return {
            "transaction": {
                "id": str(transaction["_id"]),
                "type": transaction["type"],
                "amount": transaction["amount"],
                "from_account_id": transaction.get("from_account_id"),
                "to_account_id": transaction.get("to_account_id"),
                "detail": transaction["detail"],
                "document_files": transaction.get("document_files", []),
                "user_id": transaction["user_id"],
                "transaction_date": transaction["transaction_date"],
                "created_at": transaction["created_at"],
                "updated_at": transaction["updated_at"]
            }
        }
        
    except Exception as e:
        logger.error(f"Error fetching transaction: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch transaction"
        )

@router.put("/{transaction_id}", response_model=dict)
async def update_transaction(
    transaction_id: str,
    transaction_update: TransactionUpdate,
    current_user: dict = Depends(get_current_user)
):
    try:
        # Validate ObjectId
        try:
            obj_id = ObjectId(transaction_id)
        except:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid transaction ID"
            )
        
        user_id = str(current_user["_id"])
        
        # Find existing transaction
        existing_transaction = transactions_collection.find_one({
            "_id": obj_id,
            "user_id": user_id
        })
        
        if not existing_transaction:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transaction not found"
            )
        
        
        # Track files for cleanup if document_files is being updated
        files_to_cleanup = []
        if transaction_update.document_files is not None:
            existing_files = existing_transaction.get("document_files", [])
            new_files = transaction_update.document_files or []
            
            # Find files that are being removed
            files_to_cleanup = [f for f in existing_files if f not in new_files]
        
        # Build update document
        update_doc = {"updated_at": datetime.utcnow()}
        
        # Validate and update account IDs if provided
        if transaction_update.from_account_id is not None:
            if transaction_update.from_account_id:
                from_account = accounts_collection.find_one({
                    "_id": ObjectId(transaction_update.from_account_id),
                    "user_id": user_id
                })
                if not from_account:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="From account not found or does not belong to user"
                    )
            update_doc["from_account_id"] = transaction_update.from_account_id
        
        if transaction_update.to_account_id is not None:
            if transaction_update.to_account_id:
                to_account = accounts_collection.find_one({
                    "_id": ObjectId(transaction_update.to_account_id),
                    "user_id": user_id
                })
                if not to_account:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="To account not found or does not belong to user"
                    )
            update_doc["to_account_id"] = transaction_update.to_account_id
        
        # Update other fields
        # Update other fields
        if transaction_update.type is not None:
            update_doc["type"] = transaction_update.type.value
        if transaction_update.amount is not None:
            update_doc["amount"] = transaction_update.amount
        if transaction_update.detail is not None:
            update_doc["detail"] = transaction_update.detail
        if transaction_update.document_files is not None:
            update_doc["document_files"] = transaction_update.document_files
        if transaction_update.transaction_date is not None:
            update_doc["transaction_date"] = transaction_update.transaction_date



        # Update transaction
        result = transactions_collection.update_one(
            {"_id": obj_id, "user_id": user_id},
            {"$set": update_doc}
        )
        
        if result.matched_count == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transaction not found"
            )
        

        # Clean up removed files from filesystem
        if files_to_cleanup:
            cleanup_result = cleanup_transaction_files(files_to_cleanup)
            logger.info(f"Cleaned up {len(cleanup_result['deleted_files'])} files during transaction update")
            if cleanup_result['failed_files']:
                logger.warning(f"Failed to clean up some files: {cleanup_result['failed_files']}")
        
        # Get updated transaction
        updated_transaction = transactions_collection.find_one({"_id": obj_id})
        
        return {
            "message": "Transaction updated successfully",
            "transaction": {
                "id": str(updated_transaction["_id"]),
                "type": updated_transaction["type"],
                "amount": updated_transaction["amount"],
                "from_account_id": updated_transaction.get("from_account_id"),
                "to_account_id": updated_transaction.get("to_account_id"),
                "detail": updated_transaction["detail"],
                "document_files": updated_transaction.get("document_files", []),  # Changed from document_record
                "user_id": updated_transaction["user_id"],
                "transaction_date": updated_transaction["transaction_date"],
                "created_at": updated_transaction["created_at"],
                "updated_at": updated_transaction["updated_at"]
            }
        }
        
    except ValueError as ve:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(ve)
        )
    except Exception as e:
        logger.error(f"Error updating transaction: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update transaction"
        )

@router.delete("/{transaction_id}", response_model=dict)
async def delete_transaction(
    transaction_id: str,
    current_user: dict = Depends(get_current_user)
):
    try:
        # Validate ObjectId
        try:
            obj_id = ObjectId(transaction_id)
        except:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid transaction ID"
            )
        
        # First, get the transaction to access its files before deletion
        transaction = transactions_collection.find_one({
            "_id": obj_id,
            "user_id": str(current_user["_id"])
        })
        
        if not transaction:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transaction not found"
            )
        
        # Delete associated files from file system
        document_files = transaction.get("document_files", [])
        file_cleanup_result = cleanup_transaction_files(document_files)
        deleted_files = file_cleanup_result["deleted_files"]
        failed_files = file_cleanup_result["failed_files"]
        
        for filename in document_files:
            if filename:  # Check if filename is not empty
                file_path = os.path.join(UPLOAD_DIR, filename)
                try:
                    if os.path.exists(file_path):
                        os.remove(file_path)
                        deleted_files.append(filename)
                        logger.info(f"Deleted file: {filename}")
                    else:
                        logger.warning(f"File not found for deletion: {filename}")
                        failed_files.append(f"{filename} (not found)")
                except Exception as file_error:
                    logger.error(f"Error deleting file {filename}: {str(file_error)}")
                    failed_files.append(f"{filename} (deletion error)")
        
        # Delete transaction from database
        result = transactions_collection.delete_one({
            "_id": obj_id,
            "user_id": str(current_user["_id"])
        })
        
        if result.deleted_count == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transaction not found"
            )
        
        # Prepare response message
        message = "Transaction deleted successfully"
        if deleted_files:
            message += f". {len(deleted_files)} file(s) removed"
        if failed_files:
            message += f". Warning: {len(failed_files)} file(s) could not be removed"
        
        response = {"message": message}
        
        # Add details about file operations if any files were involved
        if deleted_files or failed_files:
            response["file_operations"] = {
                "deleted_files": deleted_files,
                "failed_files": failed_files
            }
        
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting transaction: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete transaction"
        )

# Analytics endpoints
@router.get("/analytics/summary", response_model=dict)
async def get_transaction_summary(
    current_user: dict = Depends(get_current_user),
    account_id: Optional[str] = Query(None, description="Filter by account ID"),
    start_date: Optional[datetime] = Query(None, description="Start date filter"),
    end_date: Optional[datetime] = Query(None, description="End date filter")
):
    try:
        user_id = str(current_user["_id"])
        
        # Build query
        query = {"user_id": user_id}
        
        if account_id:
            # Validate account ownership
            account = accounts_collection.find_one({
                "_id": ObjectId(account_id),
                "user_id": user_id
            })
            if not account:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Account not found or does not belong to user"
                )
            query["$or"] = [
                {"from_account_id": account_id},
                {"to_account_id": account_id}
            ]
        
        if start_date or end_date:
            date_filter = {}
            if start_date:
                date_filter["$gte"] = start_date
            if end_date:
                date_filter["$lte"] = end_date
            query["transaction_date"] = date_filter
        
        # Aggregate data
        pipeline = [
            {"$match": query},
            {
                "$group": {
                    "_id": "$type",
                    "total_amount": {"$sum": "$amount"},
                    "count": {"$sum": 1}
                }
            }
        ]
        
        results = list(transactions_collection.aggregate(pipeline))
        
        summary = {
            "total_inflow": 0,
            "total_outflow": 0,
            "inflow_count": 0,
            "outflow_count": 0,
            "net_flow": 0
        }
        
        for result in results:
            if result["_id"] == "Inflow":
                summary["total_inflow"] = result["total_amount"]
                summary["inflow_count"] = result["count"]
            elif result["_id"] == "Outflow":
                summary["total_outflow"] = result["total_amount"]
                summary["outflow_count"] = result["count"]
        
        summary["net_flow"] = summary["total_inflow"] - summary["total_outflow"]
        summary["total_transactions"] = summary["inflow_count"] + summary["outflow_count"]
        
        return {"summary": summary}
        
    except Exception as e:
        logger.error(f"Error getting transaction summary: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get transaction summary"
        )