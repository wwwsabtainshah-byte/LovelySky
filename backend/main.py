from fastapi import FastAPI

app = FastAPI(title="Lovely Sky API", version="1.0.0")

@app.get("/")
def home():
    return {"app": "Lovely Sky API", "status": "online"}

@app.get("/health")
def health():
    return {"status": "ok"}
