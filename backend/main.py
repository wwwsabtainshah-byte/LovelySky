from fastapi import FastAPI
from auth_routes import router as auth_router

app = FastAPI(title="Lovely Sky API", version="1.0.0")

app.include_router(auth_router)

@app.get("/")
def home():
    return {"app": "Lovely Sky API", "status": "online"}

@app.get("/health")
def health():
    return {"status": "ok"}
