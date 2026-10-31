import os
import json
import base64
import logging
import sqlite3
import firebase_admin
from firebase_admin import auth, credentials
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

try:
    from database import get_connection, initialize_database
except ModuleNotFoundError:
    from backend.database import get_connection, initialize_database

router = APIRouter()
logger = logging.getLogger(__name__)
OWNER_EMAIL = "www.sabtainshah@gmail.com"
_db_initialized = False


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
        logger.error("Firebase token verification failed (%s): %s",
                     type(exc).__name__, str(exc)[:300])
        raise HTTPException(401, "Firebase token rejected") from exc


def ensure_database():
    global _db_initialized
    if not _db_initialized:
        initialize_database()
        _db_initialized = True


def next_user_code(db):
    used = {
        str(row["user_code"])
        for row in db.execute(
            "SELECT user_code FROM users WHERE user_code IS NOT NULL"
        ).fetchall()
    }
    number = 1001
    while str(number) in used:
        number += 1
    return str(number)


def save_google_user(claims):
    uid = str(claims.get("uid") or "").strip()
    email = str(claims.get("email") or "").strip().lower()
    if not uid or not email:
        raise HTTPException(401, "Google account ID or email is missing")

    if claims.get("email_verified") is not True:
        raise HTTPException(403, "Google email is not verified")

    ensure_database()
    is_owner = email == OWNER_EMAIL
    name = str(claims.get("name") or "")
    photo = str(claims.get("picture") or "")
    db = get_connection()

    try:
        db.execute("BEGIN IMMEDIATE")
        row = db.execute(
            "SELECT * FROM users WHERE google_uid = ?", (uid,)
        ).fetchone()

        if row is None:
            row = db.execute(
                "SELECT * FROM users WHERE lower(google_email) = ?", (email,)
            ).fetchone()

        if row is not None and row["google_uid"] not in (None, "", uid):
            raise HTTPException(
                409, "This email is already linked to another Google account"
            )

        if is_owner:
            holder = db.execute(
                "SELECT id FROM users WHERE user_code = '1' AND id != ?",
                (row["id"] if row is not None else -1,)
            ).fetchone()
            if holder:
                raise HTTPException(
                    409, "Owner ID 1 is already assigned; manual account review is required"
                )
            code = "1"
        elif row is not None:
            old_code = str(row["user_code"] or "").strip()
            if old_code.isdigit() and int(old_code) >= 1001:
                code = old_code
            else:
                code = next_user_code(db)
        else:
            code = next_user_code(db)

        if row is None:
            db.execute(
                """INSERT INTO users
                   (google_uid, google_email, user_code, display_name, profile_photo)
                   VALUES (?, ?, ?, ?, ?)""",
                (uid, email, code, name, photo)
            )
        else:
            db.execute(
                """UPDATE users
                   SET google_uid = ?,
                       google_email = CASE
                           WHEN google_email IS NULL OR google_email = '' THEN ?
                           ELSE google_email END,
                       user_code = ?,
                       display_name = CASE
                           WHEN display_name IS NULL OR display_name = '' THEN ?
                           ELSE display_name END,
                       profile_photo = CASE
                           WHEN profile_photo IS NULL OR profile_photo = '' THEN ?
                           ELSE profile_photo END
                   WHERE id = ?""",
                (uid, email, code, name, photo, row["id"])
            )

        saved = db.execute(
            "SELECT id, google_uid, google_email, user_code, display_name, profile_photo "
            "FROM users WHERE google_uid = ?",
            (uid,)
        ).fetchone()
        db.commit()
        return dict(saved)
    except HTTPException:
        db.rollback()
        raise
    except sqlite3.IntegrityError as exc:
        db.rollback()
        logger.error("User account save conflict: %s", str(exc)[:200])
        raise HTTPException(409, "Account or User ID conflict; no changes saved") from exc
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.post("/auth/google")
def google_login(payload: GoogleLoginRequest):
    claims = verify_token(payload.id_token)
    user = save_google_user(claims)
    return {
        "success": True,
        "token": payload.id_token,
        "user": {
            "uid": user["google_uid"],
            "email": user["google_email"],
            "user_code": user["user_code"],
            "display_name": user["display_name"],
            "profile_photo": user["profile_photo"],
            "role": "owner" if user["google_email"].lower() == OWNER_EMAIL else "user"
        }
    }



class CreateVoiceRoomRequest(BaseModel):
    name: str
    description: str = ""


@router.post("/voice/rooms")
def create_voice_room(
    payload: CreateVoiceRoomRequest,
    authorization: str | None = Header(default=None),
):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Bearer token required")

    name = payload.name.strip()
    description = payload.description.strip()

    if not name:
        raise HTTPException(400, "Room name is required")
    if len(name) > 60:
        raise HTTPException(400, "Room name must be 60 characters or fewer")
    if len(description) > 200:
        raise HTTPException(400, "Description must be 200 characters or fewer")

    claims = verify_token(authorization.split(" ", 1)[1].strip())
    user = save_google_user(claims)
    ensure_database()

    db = get_connection()
    try:
        cursor = db.execute(
            "INSERT INTO voice_rooms (owner_uid, owner_code, name, description) VALUES (?, ?, ?, ?)",
            (user["google_uid"], str(user["user_code"]), name, description),
        )
        room_id = cursor.lastrowid
        row = db.execute(
            "SELECT id, owner_code, name, description, created_at, is_active "
            "FROM voice_rooms WHERE id = ?",
            (room_id,),
        ).fetchone()
        db.commit()
        return {"success": True, "room": dict(row)}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()



@router.get("/voice/rooms/mine")
def my_voice_rooms(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Bearer token required")

    claims = verify_token(authorization.split(" ", 1)[1].strip())
    user = save_google_user(claims)
    ensure_database()

    db = get_connection()
    try:
        rows = db.execute(
            "SELECT id, owner_code, name, description, created_at, is_active "
            "FROM voice_rooms WHERE owner_uid = ? ORDER BY id DESC",
            (user["google_uid"],),
        ).fetchall()
        return {"success": True, "rooms": [dict(row) for row in rows]}
    finally:
        db.close()


@router.get("/me")
def current_user(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Bearer token required")
    token = authorization.split(" ", 1)[1].strip()
    claims = verify_token(token)
    user = save_google_user(claims)
    return {
        "success": True,
        "uid": user["google_uid"],
        "email": user["google_email"],
        "user_code": user["user_code"],
        "display_name": user["display_name"],
        "profile_photo": user["profile_photo"],
        "role": "owner" if user["google_email"].lower() == OWNER_EMAIL else "user"
    }
