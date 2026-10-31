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



def _voice_authenticated_user(authorization: str | None):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Bearer token required")
    claims = verify_token(authorization.split(" ", 1)[1].strip())
    user = save_google_user(claims)
    ensure_database()
    return user


@router.get("/voice/rooms")
def list_voice_rooms(
    tab: str = "popular",
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    tab = tab.strip().lower()
    if tab not in {"popular", "following", "visit"}:
        raise HTTPException(400, "tab must be popular, following, or visit")

    db = get_connection()
    try:
        base = """
            SELECT r.id, r.owner_uid, r.owner_code, r.name, r.description,
                   r.created_at, r.is_active,
                   COUNT(DISTINCT p.user_uid) AS participant_count
            FROM voice_rooms r
            LEFT JOIN voice_room_participants p ON p.room_id = r.id
        """
        if tab == "following":
            rows = db.execute(
                base + """
                JOIN user_follows f ON f.followed_uid = r.owner_uid
                WHERE r.is_active = 1 AND f.follower_uid = ?
                GROUP BY r.id
                ORDER BY participant_count DESC, r.id DESC
                """,
                (user["google_uid"],),
            ).fetchall()
        elif tab == "visit":
            rows = db.execute(
                base + """
                WHERE r.is_active = 1
                  AND (
                    r.owner_uid = ?
                    OR r.id IN (
                        SELECT room_id FROM voice_room_visits
                        WHERE user_uid = ?
                    )
                  )
                GROUP BY r.id
                ORDER BY
                  CASE WHEN r.owner_uid = ? THEN 0 ELSE 1 END,
                  r.id DESC
                """,
                (user["google_uid"], user["google_uid"], user["google_uid"]),
            ).fetchall()
        else:
            rows = db.execute(
                base + """
                WHERE r.is_active = 1
                GROUP BY r.id
                ORDER BY participant_count DESC, r.id DESC
                """
            ).fetchall()

        return {"success": True, "tab": tab, "rooms": [dict(row) for row in rows]}
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/join")
def join_voice_room(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        room = db.execute(
            "SELECT id FROM voice_rooms WHERE id = ? AND is_active = 1",
            (room_id,),
        ).fetchone()
        if not room:
            raise HTTPException(404, "Voice room not found")

        db.execute(
            """
            INSERT INTO voice_room_participants (room_id, user_uid, user_code)
            VALUES (?, ?, ?)
            ON CONFLICT(room_id, user_uid) DO UPDATE SET
                joined_at = CURRENT_TIMESTAMP
            """,
            (room_id, user["google_uid"], str(user["user_code"])),
        )
        db.execute(
            "INSERT INTO voice_room_visits (room_id, user_uid) VALUES (?, ?)",
            (room_id, user["google_uid"]),
        )
        db.commit()
        count = db.execute(
            "SELECT COUNT(*) AS n FROM voice_room_participants WHERE room_id = ?",
            (room_id,),
        ).fetchone()["n"]
        return {"success": True, "room_id": room_id, "participant_count": count}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/leave")
def leave_voice_room(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        db.execute(
            "DELETE FROM voice_room_participants WHERE room_id = ? AND user_uid = ?",
            (room_id, user["google_uid"]),
        )
        db.commit()
        count = db.execute(
            "SELECT COUNT(*) AS n FROM voice_room_participants WHERE room_id = ?",
            (room_id,),
        ).fetchone()["n"]
        return {"success": True, "room_id": room_id, "participant_count": count}
    finally:
        db.close()



@router.get("/voice/rooms/{room_id}/seats")
def get_voice_room_seats(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        room = db.execute(
            "SELECT id FROM voice_rooms WHERE id = ? AND is_active = 1",
            (room_id,),
        ).fetchone()
        if not room:
            raise HTTPException(404, "Voice room not found")

        occupied = db.execute(
            """
            SELECT seat_number, user_code
            FROM voice_room_participants
            WHERE room_id = ? AND seat_number BETWEEN 1 AND 18
            """,
            (room_id,),
        ).fetchall()

        by_seat = {row["seat_number"]: row["user_code"] for row in occupied}
        return {
            "success": True,
            "room_id": room_id,
            "seats": [
                {
                    "seat_number": n,
                    "user_code": by_seat.get(n),
                    "is_occupied": n in by_seat,
                    "is_mine": n in by_seat and by_seat.get(n) == str(user["user_code"]),
                }
                for n in range(1, 19)
            ],
        }
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/seats/{seat_number}/sit")
def sit_voice_room_seat(
    room_id: int,
    seat_number: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    if seat_number < 1 or seat_number > 18:
        raise HTTPException(400, "Seat number must be between 1 and 18")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        room = db.execute(
            "SELECT id FROM voice_rooms WHERE id = ? AND is_active = 1",
            (room_id,),
        ).fetchone()
        if not room:
            raise HTTPException(404, "Voice room not found")

        participant = db.execute(
            """
            SELECT seat_number FROM voice_room_participants
            WHERE room_id = ? AND user_uid = ?
            """,
            (room_id, user["google_uid"]),
        ).fetchone()
        if not participant:
            raise HTTPException(409, "Join the room before taking a seat")

        occupied = db.execute(
            """
            SELECT user_uid FROM voice_room_participants
            WHERE room_id = ? AND seat_number = ?
            """,
            (room_id, seat_number),
        ).fetchone()
        if occupied and occupied["user_uid"] != user["google_uid"]:
            raise HTTPException(409, "This seat is already occupied")

        db.execute(
            """
            UPDATE voice_room_participants
            SET seat_number = NULL
            WHERE room_id = ? AND user_uid = ?
            """,
            (room_id, user["google_uid"]),
        )
        db.execute(
            """
            UPDATE voice_room_participants
            SET seat_number = ?
            WHERE room_id = ? AND user_uid = ?
            """,
            (seat_number, room_id, user["google_uid"]),
        )
        db.commit()
        return {"success": True, "room_id": room_id, "seat_number": seat_number}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/seats/leave")
def leave_voice_room_seat(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        db.execute(
            """
            UPDATE voice_room_participants
            SET seat_number = NULL
            WHERE room_id = ? AND user_uid = ?
            """,
            (room_id, user["google_uid"]),
        )
        db.commit()
        return {"success": True, "room_id": room_id}
    finally:
        db.close()


class VoiceFollowRequest(BaseModel):
    user_uid: str


@router.post("/voice/follow")
def follow_voice_user(
    payload: VoiceFollowRequest,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    target_uid = payload.user_uid.strip()
    if not target_uid or target_uid == user["google_uid"]:
        raise HTTPException(400, "Invalid user to follow")

    db = get_connection()
    try:
        target = db.execute(
            "SELECT google_uid FROM users WHERE google_uid = ?",
            (target_uid,),
        ).fetchone()
        if not target:
            raise HTTPException(404, "User not found")
        db.execute(
            "INSERT OR IGNORE INTO user_follows (follower_uid, followed_uid) VALUES (?, ?)",
            (user["google_uid"], target_uid),
        )
        db.commit()
        return {"success": True, "followed_uid": target_uid}
    finally:
        db.close()


@router.delete("/voice/follow/{target_uid}")
def unfollow_voice_user(
    target_uid: str,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        db.execute(
            "DELETE FROM user_follows WHERE follower_uid = ? AND followed_uid = ?",
            (user["google_uid"], target_uid),
        )
        db.commit()
        return {"success": True, "unfollowed_uid": target_uid}
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
