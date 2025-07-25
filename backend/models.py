from pydantic import BaseModel, EmailStr, validator
from typing import List, Optional
from datetime import datetime
from enum import Enum

# Existing user models
class UserSignUp(BaseModel):
    full_name: str
    email: EmailStr
    password: str

class UserSignIn(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: str
    full_name: str
    email: str
    created_at: datetime

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

# New account models
class AccountType(str, Enum):
    BANK = "Bank"
    CREDIT_CARD = "Credit Card"
    CASH = "Cash"
    INVESTMENT = "Investment"
    SAVINGS = "Savings"
    LOAN = "Loan"
    OTHER = "Other"

class AccountCreate(BaseModel):
    name: str
    account_type: AccountType
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None

class AccountUpdate(BaseModel):
    name: Optional[str] = None
    account_type: Optional[AccountType] = None
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None

class AccountResponse(BaseModel):
    id: str
    name: str
    account_type: str
    email: Optional[str] = None
    phone_number: Optional[str] = None
    user_id: str
    created_at: datetime
    updated_at: datetime


class FileUploadResponse(BaseModel):
    filename: str
    file_path: str
    file_size: int
    content_type: str
    upload_date: datetime

class TransactionType(str, Enum):
    INFLOW = "Inflow"
    OUTFLOW = "Outflow"

class TransactionCreate(BaseModel):
    type: TransactionType
    amount: float
    from_account_id: Optional[str] = None
    to_account_id: Optional[str] = None
    detail: str
    document_files: Optional[List[str]] = None  # Store file paths instead of document_record
    transaction_date: Optional[datetime] = None

    @validator('amount')
    def validate_amount(cls, v):
        if v <= 0:
            raise ValueError('Amount must be positive')
        return round(v, 2)

    @validator('detail')
    def validate_detail(cls, v):
        if not v or len(v.strip()) < 0:
            raise ValueError('Detail can\'t be empty')
        return v.strip()

    @validator('from_account_id', 'to_account_id')
    def validate_accounts(cls, v, values):
        if values.get('type') == TransactionType.OUTFLOW:
            if not values.get('from_account_id') and v is None:
                raise ValueError('From account is required for outflow transactions')
        
        if values.get('type') == TransactionType.INFLOW:
            if not values.get('to_account_id') and v is None:
                raise ValueError('To account is required for inflow transactions')
        
        return v

class MultipleTransactionsCreate(BaseModel):
    transactions: List[TransactionCreate]

    @validator('transactions')
    def validate_transactions_list(cls, v):
        if not v or len(v) == 0:
            raise ValueError('At least one transaction is required')
        if len(v) > 50:  # Limit bulk creation to 50 transactions
            raise ValueError('Maximum 50 transactions allowed per batch')
        return v

class TransactionUpdate(BaseModel):
    type: Optional[TransactionType] = None
    amount: Optional[float] = None
    from_account_id: Optional[str] = None
    to_account_id: Optional[str] = None
    detail: Optional[str] = None
    document_files: Optional[List[str]] = None  # Store file paths instead of document_record
    transaction_date: Optional[datetime] = None

    @validator('amount')
    def validate_amount(cls, v):
        if v is not None and v <= 0:
            raise ValueError('Amount must be positive')
        return round(v, 2) if v is not None else v

class TransactionResponse(BaseModel):
    id: str
    type: str
    amount: float
    from_account_id: Optional[str] = None
    to_account_id: Optional[str] = None
    detail: str
    document_files: Optional[List[str]] = None  # Store file paths instead of document_record
    user_id: str
    transaction_date: datetime
    created_at: datetime
    updated_at: datetime