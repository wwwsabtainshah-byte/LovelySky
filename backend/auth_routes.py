import os
import json
import base64
import firebase_admin
from firebase_admin import auth, credentials
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

router = APIRouter()

class GoogleLoginRequest(BaseModel):
    id_token: str
    device_id: str | None = None

def get_firebase_app():
    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    encoded = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON_B64", "").strip()
    if not encoded:
        raise HTTPException(503, "Firebase service account is not configured")

    try:
        info = json.loads(base64.b64decode(encoded, validate=True))
        cred = credentials.Certificate(info)
        project = os.environ.get("GOOGLE_CLOUD_PROJECT") or info.get("project_id")
        return firebase_admin.initialize_app(cred, {"projectId": project})
    except Exception as exc:
        raise HTTPException(503, "Firebase service account configuration is invalid") from exc

def verify_token(token: str):
    try:
        return auth.verify_id_token(token, app=get_firebase_app())
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(401, "Firebase token rejected") from exc

@router.post("/auth/google")
def google_login(payload: GoogleLoginRequest):
    claims = verify_token(payload.id_token)
    if not claims.get("uid"):
        raise HTTPException(401, "Firebase user ID missing")
    if claims.get("email") and claims.get("email_verified") is not True:
        raise HTTPException(403, "Google email is not verified")

    return {
        "success": True,
        "token": payload.id_token,
        "user": {
            "uid": claims["uid"],
            "email": claims.get("email", ""),
            "display_name": claims.get("name", ""),
            "profile_photo": claims.get("picture", "")
        }
    }

@router.get("/me")
def current_user(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Bearer token required")

    claims = verify_token(authorization.split(" ", 1)[1].strip())
    return {
        "success": True,
        "uid": claims.get("uid", ""),
        "email": claims.get("email", ""),
        "display_name": claims.get("name", ""),
        "profile_photo": claims.get("picture", "")
    }
