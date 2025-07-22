import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import auth, accounts, transactions  # Add transactions import
from dotenv import load_dotenv
import uvicorn

# Load environment variables
load_dotenv()

app = FastAPI(
    title="Finance Tracker API", 
    version="1.0.0",
    description="A personal finance tracking application API"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(accounts.router)
app.include_router(transactions.router)  # Add transactions router

@app.get("/")
async def root():
    return {
        "message": "Finance Tracker API is running!",
        "version": "1.0.0",
        "docs": "/docs",
        "database": os.getenv("DATABASE_NAME", "finance_app")
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0", 
        port=8000,
        reload=True
    )