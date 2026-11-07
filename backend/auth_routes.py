import asyncio
import os
import json
import base64
import logging
import sqlite3
import secrets
import uuid

import hashlib
import hmac
import re
import time
import httpx
from decimal import Decimal, InvalidOperation
from fastapi import Request
from fastapi.responses import JSONResponse
import firebase_admin
from firebase_admin import auth, credentials
from fastapi import APIRouter, Header, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

try:
    from database import DB_PATH, get_connection, initialize_database
except ModuleNotFoundError:
    from backend.database import DB_PATH, get_connection, initialize_database

router = APIRouter()
logger = logging.getLogger(__name__)
OWNER_EMAIL = "www.sabtainshah@gmail.com"
_db_initialized = False


class GoogleLoginRequest(BaseModel):
    id_token: str
    device_id: str | None = None


class OwnerCoinIssueRequest(BaseModel):
    user_code: str
    amount: int


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

    user = _voice_authenticated_user(authorization)

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

    user = _voice_authenticated_user(authorization)

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



def _ensure_pakistan_official_room(user):
    if str(user.get("google_email", "")).strip().lower() != OWNER_EMAIL.lower():
        return None

    owner_uid = str(user.get("google_uid", "")).strip()
    owner_code = str(user.get("user_code", "")).strip()
    if not owner_uid or not owner_code:
        raise HTTPException(403, "Verified owner account details are missing")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        verified = db.execute(
            "SELECT google_uid FROM users WHERE lower(google_email) = lower(?)",
            (OWNER_EMAIL,),
        ).fetchone()
        if not verified or str(verified["google_uid"]) != owner_uid:
            raise HTTPException(403, "Pakistan Official owner verification failed")

        official_rooms = db.execute(
            "SELECT id, owner_uid FROM voice_rooms "
            "WHERE is_official = 1 ORDER BY id"
        ).fetchall()

        # Never adopt or modify an official room belonging to another account.
        if any(str(row["owner_uid"]) != owner_uid for row in official_rooms):
            raise HTTPException(
                409,
                "Another account already owns an official room; manual review required",
            )

        room = official_rooms[0] if official_rooms else None

        if not room:
            room = db.execute(
                "SELECT id FROM voice_rooms WHERE owner_uid = ? ORDER BY id LIMIT 1",
                (owner_uid,),
            ).fetchone()

        if room:
            room_id = room["id"]
            db.execute(
                """UPDATE voice_rooms
                   SET owner_uid=?, owner_code=?, name=?, description=?,
                       is_active=1, is_official=1
                   WHERE id=?""",
                (owner_uid, owner_code, "Pakistan Official",
                 "Official Pakistan community room", room_id),
            )
        else:
            cursor = db.execute(
                """INSERT INTO voice_rooms
                   (owner_uid, owner_code, name, description, is_active, is_official)
                   VALUES (?, ?, ?, ?, 1, 1)""",
                (owner_uid, owner_code, "Pakistan Official",
                 "Official Pakistan community room"),
            )
            room_id = cursor.lastrowid

        db.execute(
            "UPDATE voice_rooms SET is_official=0 "
            "WHERE is_official=1 AND owner_uid=? AND id!=?",
            (owner_uid, room_id),
        )
        db.commit()
        return room_id
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def _voice_authenticated_user(authorization: str | None):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Bearer token required")
    claims = verify_token(authorization.split(" ", 1)[1].strip())
    user = save_google_user(claims)
    ensure_database()
    _ensure_pakistan_official_room(user)
    return user


def _require_coin_owner(authorization: str | None):
    user = _voice_authenticated_user(authorization)
    if str(user.get("google_email", "")).lower() != OWNER_EMAIL.lower():
        raise HTTPException(403, "Owner access required")
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
                ORDER BY r.is_official DESC, participant_count DESC, r.id DESC
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

        blocked = db.execute(
            "SELECT 1 FROM voice_room_blocks WHERE room_id = ? AND user_uid = ?",
            (room_id, user["google_uid"]),
        ).fetchone()
        if blocked:
            raise HTTPException(403, "You are blocked from this room")

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


@router.get("/voice/rooms/{room_id}/members")
def get_voice_room_members(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        _require_voice_room_member(db, room_id, user)
        rows = db.execute(
            """
            SELECT p.user_uid, p.user_code, u.display_name, u.profile_photo,
                   p.seat_number, p.is_muted
            FROM voice_room_participants AS p
            LEFT JOIN users AS u ON u.google_uid = p.user_uid
            WHERE p.room_id = ?
            UNION
            SELECT r.owner_uid, r.owner_code, u.display_name, u.profile_photo,
                   NULL, 0
            FROM voice_rooms AS r
            LEFT JOIN users AS u ON u.google_uid = r.owner_uid
            WHERE r.id = ?
              AND NOT EXISTS (
                  SELECT 1 FROM voice_room_participants AS p
                  WHERE p.room_id = r.id AND p.user_uid = r.owner_uid
              )
            ORDER BY 2
            """,
            (room_id, room_id),
        ).fetchall()
        return {
            "success": True,
            "members": [dict(row) for row in rows],
        }
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
        db.execute(
            "DELETE FROM voice_room_gift_diamonds WHERE room_id = ? AND user_uid = ?",
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




class VoiceRoomAdminRequest(BaseModel):
    user_uid: str


def _voice_room_role(db, room_id: int, user_uid: str):
    room = db.execute(
        "SELECT owner_uid, is_official FROM voice_rooms "
        "WHERE id = ? AND is_active = 1",
        (room_id,),
    ).fetchone()
    if not room:
        raise HTTPException(404, "Voice room not found")

    if int(room["is_official"] or 0) == 1:
        verified_owner = db.execute(
            "SELECT google_uid FROM users WHERE lower(google_email) = lower(?)",
            (OWNER_EMAIL,),
        ).fetchone()
        if (
            verified_owner
            and str(verified_owner["google_uid"]) == str(user_uid)
            and str(room["owner_uid"]) == str(user_uid)
        ):
            return "owner"
    elif str(room["owner_uid"]) == str(user_uid):
        return "owner"

    admin = db.execute(
        "SELECT 1 FROM voice_room_admins WHERE room_id = ? AND user_uid = ?",
        (room_id, user_uid),
    ).fetchone()
    return "admin" if admin else "member"


def _require_voice_room_manager(db, room_id: int, user_uid: str):
    role = _voice_room_role(db, room_id, user_uid)
    if role not in {"owner", "admin"}:
        raise HTTPException(403, "Only the room owner or appointed admin can manage this room")
    return role


@router.post("/voice/rooms/{room_id}/admins")
def appoint_voice_room_admin(
    room_id: int,
    payload: VoiceRoomAdminRequest,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    target_uid = payload.user_uid.strip()
    if not target_uid or target_uid == user["google_uid"]:
        raise HTTPException(400, "Invalid room admin")
    db = get_connection()
    try:
        role = _voice_room_role(db, room_id, user["google_uid"])
        if role != "owner":
            raise HTTPException(403, "Only the room owner can appoint admins")
        target = db.execute(
            "SELECT google_uid FROM users WHERE google_uid = ?",
            (target_uid,),
        ).fetchone()
        if not target:
            raise HTTPException(404, "User not found")
        db.execute(
            """INSERT OR IGNORE INTO voice_room_admins
               (room_id, user_uid, appointed_by_uid) VALUES (?, ?, ?)""",
            (room_id, target_uid, user["google_uid"]),
        )
        db.commit()
        return {"success": True, "room_id": room_id, "admin_uid": target_uid}
    finally:
        db.close()


@router.delete("/voice/rooms/{room_id}/admins/{target_uid}")
def remove_voice_room_admin(
    room_id: int,
    target_uid: str,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        if _voice_room_role(db, room_id, user["google_uid"]) != "owner":
            raise HTTPException(403, "Only the room owner can remove admins")
        db.execute(
            "DELETE FROM voice_room_admins WHERE room_id = ? AND user_uid = ?",
            (room_id, target_uid),
        )
        db.commit()
        return {"success": True, "room_id": room_id, "admin_uid": target_uid}
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/seats/{seat_number}/lock")
def lock_voice_room_seat(
    room_id: int,
    seat_number: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    if not 1 <= seat_number <= 18:
        raise HTTPException(400, "Seat number must be between 1 and 18")
    db = get_connection()
    try:
        _require_voice_room_manager(db, room_id, user["google_uid"])
        db.execute(
            """INSERT OR IGNORE INTO voice_room_locked_seats
               (room_id, seat_number, locked_by_uid) VALUES (?, ?, ?)""",
            (room_id, seat_number, user["google_uid"]),
        )
        db.commit()
        return {"success": True, "room_id": room_id, "seat_number": seat_number, "locked": True}
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/seats/{seat_number}/unlock")
def unlock_voice_room_seat(
    room_id: int,
    seat_number: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    if not 1 <= seat_number <= 18:
        raise HTTPException(400, "Seat number must be between 1 and 18")
    db = get_connection()
    try:
        _require_voice_room_manager(db, room_id, user["google_uid"])
        db.execute(
            "DELETE FROM voice_room_locked_seats WHERE room_id = ? AND seat_number = ?",
            (room_id, seat_number),
        )
        db.commit()
        return {"success": True, "room_id": room_id, "seat_number": seat_number, "locked": False}
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

        role = _voice_room_role(db, room_id, user["google_uid"])
        occupied = db.execute(
            """
            SELECT p.seat_number, p.user_uid, p.user_code, p.is_muted,
                   u.display_name, u.profile_photo,
                   COALESCE(gd.diamonds, 0) AS gift_diamonds
            FROM voice_room_participants AS p
            LEFT JOIN users AS u ON u.google_uid = p.user_uid
            LEFT JOIN voice_room_gift_diamonds AS gd
              ON gd.room_id = p.room_id AND gd.user_uid = p.user_uid
            WHERE p.room_id = ? AND p.seat_number BETWEEN 1 AND 18
            """,
            (room_id,),
        ).fetchall()
        by_seat = {row["seat_number"]: row for row in occupied}
        locked_rows = db.execute(
            "SELECT seat_number FROM voice_room_locked_seats WHERE room_id = ?",
            (room_id,),
        ).fetchall()
        locked_seats = {row["seat_number"] for row in locked_rows}

        return {
            "success": True,
            "room_id": room_id,
            "room_role": role,
            "seats": [
                {
                    "seat_number": n,
                    "user_uid": by_seat[n]["user_uid"] if n in by_seat else None,
                    "user_code": by_seat[n]["user_code"] if n in by_seat else None,
                    "is_muted": bool(by_seat[n]["is_muted"]) if n in by_seat else False,
                    "display_name": by_seat[n]["display_name"] if n in by_seat else None,
                    "profile_photo": by_seat[n]["profile_photo"] if n in by_seat else None,
                    "gift_diamonds": int(by_seat[n]["gift_diamonds"] or 0) if n in by_seat else 0,
                    "is_occupied": n in by_seat,
                    "is_mine": (
                        n in by_seat
                        and by_seat[n]["user_code"] == str(user["user_code"])
                    ),
                    "is_locked": n in locked_seats,
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

        _voice_room_role(db, room_id, user["google_uid"])

        locked = db.execute(
            "SELECT 1 FROM voice_room_locked_seats WHERE room_id = ? AND seat_number = ?",
            (room_id, seat_number),
        ).fetchone()
        if locked:
            raise HTTPException(409, "This seat is locked")

        participant = db.execute(
            "SELECT user_uid FROM voice_room_participants WHERE room_id = ? AND user_uid = ?",
            (room_id, user["google_uid"]),
        ).fetchone()
        if not participant:
            raise HTTPException(409, "Join the room before assigning a seat")

        occupied = db.execute(
            "SELECT user_uid FROM voice_room_participants WHERE room_id = ? AND seat_number = ?",
            (room_id, seat_number),
        ).fetchone()
        if occupied and occupied["user_uid"] != user["google_uid"]:
            raise HTTPException(409, "This seat is already occupied")

        db.execute(
            "UPDATE voice_room_participants SET seat_number = NULL WHERE room_id = ? AND user_uid = ?",
            (room_id, user["google_uid"]),
        )
        db.execute(
            "UPDATE voice_room_participants SET seat_number = ? WHERE room_id = ? AND user_uid = ?",
            (seat_number, room_id, user["google_uid"]),
        )
        db.commit()
        return {"success": True, "room_id": room_id, "seat_number": seat_number}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


class VoiceRoomSeatAssignmentRequest(BaseModel):
    user_uid: str


@router.post("/voice/rooms/{room_id}/seats/{seat_number}/assign")
def assign_voice_room_member_seat(
    room_id: int,
    seat_number: int,
    payload: VoiceRoomSeatAssignmentRequest,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    target_uid = payload.user_uid.strip()
    if not target_uid:
        raise HTTPException(400, "Invalid member")
    if not 1 <= seat_number <= 18:
        raise HTTPException(400, "Seat number must be between 1 and 18")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        _require_voice_room_manager(db, room_id, user["google_uid"])

        locked = db.execute(
            "SELECT 1 FROM voice_room_locked_seats WHERE room_id = ? AND seat_number = ?",
            (room_id, seat_number),
        ).fetchone()
        if locked:
            raise HTTPException(409, "This seat is locked")

        target = db.execute(
            "SELECT user_uid FROM voice_room_participants WHERE room_id = ? AND user_uid = ?",
            (room_id, target_uid),
        ).fetchone()
        if not target:
            raise HTTPException(404, "Member has not joined this room")

        occupied = db.execute(
            "SELECT user_uid FROM voice_room_participants WHERE room_id = ? AND seat_number = ?",
            (room_id, seat_number),
        ).fetchone()
        if occupied and occupied["user_uid"] != target_uid:
            raise HTTPException(409, "This seat is already occupied")

        db.execute(
            "UPDATE voice_room_participants SET seat_number = NULL WHERE room_id = ? AND user_uid = ?",
            (room_id, target_uid),
        )
        db.execute(
            "UPDATE voice_room_participants SET seat_number = ? WHERE room_id = ? AND user_uid = ?",
            (seat_number, room_id, target_uid),
        )
        db.commit()
        return {"success": True, "room_id": room_id, "seat_number": seat_number, "user_uid": target_uid}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/members/{target_uid}/seat/remove")
def remove_voice_room_member_from_seat(
    room_id: int,
    target_uid: str,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        _require_voice_room_manager(db, room_id, user["google_uid"])
        result = db.execute(
            "UPDATE voice_room_participants SET seat_number = NULL WHERE room_id = ? AND user_uid = ?",
            (room_id, target_uid),
        )
        db.commit()
        if result.rowcount == 0:
            raise HTTPException(404, "Member has not joined this room")
        return {"success": True, "room_id": room_id, "user_uid": target_uid, "seat_removed": True}
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



class VoiceRoomInviteRequest(BaseModel):
    user_uid: str


class VoiceRoomInviteResponse(BaseModel):
    accepted: bool


@router.post("/voice/rooms/{room_id}/seats/{seat_number}/invite")
def create_voice_room_seat_invite(
    room_id: int,
    seat_number: int,
    payload: VoiceRoomInviteRequest,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    target_uid = payload.user_uid.strip()
    if not target_uid or target_uid == user["google_uid"]:
        raise HTTPException(400, "Invalid invitation target")
    if not 1 <= seat_number <= 18:
        raise HTTPException(400, "Invalid seat number")

    db = get_connection()
    try:
        _require_voice_room_manager(db, room_id, user["google_uid"])

        target = db.execute(
            "SELECT 1 FROM voice_room_participants WHERE room_id = ? AND user_uid = ?",
            (room_id, target_uid),
        ).fetchone()
        if not target:
            raise HTTPException(404, "Member has not joined this room")

        blocked = db.execute(
            "SELECT 1 FROM voice_room_blocks WHERE room_id = ? AND user_uid = ?",
            (room_id, target_uid),
        ).fetchone()
        if blocked:
            raise HTTPException(403, "This member is blocked from the room")

        occupied = db.execute(
            "SELECT user_uid FROM voice_room_participants WHERE room_id = ? AND seat_number = ?",
            (room_id, seat_number),
        ).fetchone()
        if occupied:
            raise HTTPException(409, "This seat is already occupied")

        db.execute(
            """INSERT INTO voice_room_invites
            (room_id, inviter_uid, invitee_uid, seat_number, status)
            VALUES (?, ?, ?, ?, 'pending')""",
            (room_id, user["google_uid"], target_uid, seat_number),
        )
        db.commit()
        return {"success": True, "message": "Seat invitation sent"}
    finally:
        db.close()


@router.get("/voice/rooms/{room_id}/invites/pending")
def get_voice_room_pending_invites(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        _voice_room_role(db, room_id, user["google_uid"])
        rows = db.execute(
            """SELECT i.id, i.seat_number, i.created_at,
                      i.inviter_uid, u.display_name AS inviter_name,
                      u.user_code AS inviter_code
               FROM voice_room_invites i
               LEFT JOIN users u ON u.google_uid = i.inviter_uid
               WHERE i.room_id = ? AND i.invitee_uid = ?
                 AND i.status = 'pending'
               ORDER BY i.id DESC""",
            (room_id, user["google_uid"]),
        ).fetchall()
        return {"success": True, "invites": [dict(row) for row in rows]}
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/invites/{invite_id}/respond")
def respond_voice_room_seat_invite(
    room_id: int,
    invite_id: int,
    payload: VoiceRoomInviteResponse,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        invite = db.execute(
            """SELECT * FROM voice_room_invites
               WHERE id = ? AND room_id = ? AND invitee_uid = ?
                 AND status = 'pending'""",
            (invite_id, room_id, user["google_uid"]),
        ).fetchone()

        if not invite:
            raise HTTPException(404, "Pending invitation not found")

        if payload.accepted:
            _voice_room_role(db, room_id, user["google_uid"])

            inviter_role = _voice_room_role(
                db, room_id, invite["inviter_uid"]
            )
            if inviter_role not in {"owner", "admin"}:
                raise HTTPException(403, "Inviter is no longer a room admin")

            participant = db.execute(
                """SELECT 1 FROM voice_room_participants
                   WHERE room_id = ? AND user_uid = ?""",
                (room_id, user["google_uid"]),
            ).fetchone()
            if not participant:
                raise HTTPException(409, "Join the room before accepting")

            occupied = db.execute(
                """SELECT user_uid FROM voice_room_participants
                   WHERE room_id = ? AND seat_number = ?""",
                (room_id, invite["seat_number"]),
            ).fetchone()
            if occupied and occupied["user_uid"] != user["google_uid"]:
                raise HTTPException(409, "This seat is already occupied")

            blocked = db.execute(
                """SELECT 1 FROM voice_room_blocks
                   WHERE room_id = ? AND user_uid = ?""",
                (room_id, user["google_uid"]),
            ).fetchone()
            if blocked:
                raise HTTPException(403, "You are blocked from this room")

            db.execute(
                """UPDATE voice_room_participants
                   SET seat_number = NULL
                   WHERE room_id = ? AND user_uid = ?""",
                (room_id, user["google_uid"]),
            )
            db.execute(
                """UPDATE voice_room_participants
                   SET seat_number = ?
                   WHERE room_id = ? AND user_uid = ?""",
                (invite["seat_number"], room_id, user["google_uid"]),
            )
            status = "accepted"
        else:
            status = "rejected"

        db.execute(
            "UPDATE voice_room_invites SET status = ? WHERE id = ?",
            (status, invite_id),
        )
        db.commit()
        return {
            "success": True,
            "status": status,
            "seat_number": invite["seat_number"] if payload.accepted else None,
        }
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()



class VoiceRoomBlockRequest(BaseModel):
    user_uid: str


@router.post("/voice/rooms/{room_id}/members/block")
def block_voice_room_member(
    room_id: int,
    payload: VoiceRoomBlockRequest,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    target_uid = payload.user_uid.strip()

    if not target_uid or target_uid == user["google_uid"]:
        raise HTTPException(400, "Invalid member")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        actor_role = _require_voice_room_manager(
            db, room_id, user["google_uid"]
        )

        target = db.execute(
            "SELECT google_uid FROM users WHERE google_uid = ?",
            (target_uid,),
        ).fetchone()
        if not target:
            raise HTTPException(404, "User not found")

        target_role = _voice_room_role(db, room_id, target_uid)
        if target_role == "owner":
            raise HTTPException(403, "Room owner cannot be blocked")
        if target_role == "admin" and actor_role != "owner":
            raise HTTPException(403, "Only owner can block a room admin")

        db.execute(
            """INSERT OR REPLACE INTO voice_room_blocks
               (room_id, user_uid, blocked_by_uid)
               VALUES (?, ?, ?)""",
            (room_id, target_uid, user["google_uid"]),
        )
        db.execute(
            "DELETE FROM voice_room_participants WHERE room_id = ? AND user_uid = ?",
            (room_id, target_uid),
        )
        db.execute(
            """UPDATE voice_room_invites SET status = 'cancelled'
               WHERE room_id = ? AND invitee_uid = ? AND status = 'pending'""",
            (room_id, target_uid),
        )
        if target_role == "admin":
            db.execute(
                "DELETE FROM voice_room_admins WHERE room_id = ? AND user_uid = ?",
                (room_id, target_uid),
            )

        db.commit()
        return {"success": True, "blocked_uid": target_uid}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.delete("/voice/rooms/{room_id}/members/{target_uid}/block")
def unblock_voice_room_member(
    room_id: int,
    target_uid: str,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        _require_voice_room_manager(db, room_id, user["google_uid"])
        result = db.execute(
            "DELETE FROM voice_room_blocks WHERE room_id = ? AND user_uid = ?",
            (room_id, target_uid),
        )
        db.commit()
        return {"success": True, "unblocked": result.rowcount > 0}
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



@router.get("/owner/database-diagnostic")
def owner_database_diagnostic(
    authorization: str | None = Header(default=None),
):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Bearer token required")

    token = authorization.split(" ", 1)[1].strip()
    claims = verify_token(token)

    email = str(claims.get("email", "")).strip().lower()
    if email != OWNER_EMAIL.lower() or claims.get("email_verified") is not True:
        raise HTTPException(403, "Owner access required")

    result = {
        "database_file_exists": DB_PATH.is_file(),
        "database_readable": False,
        "database_size_bytes": DB_PATH.stat().st_size if DB_PATH.is_file() else 0,
        "users_count": None,
        "voice_rooms_count": None,
        "note": "Read-only diagnostic; database path is not exposed.",
    }

    if not result["database_file_exists"]:
        return result

    db = None
    try:
        db = sqlite3.connect(
            f"{DB_PATH.resolve().as_uri()}?mode=ro",
            uri=True,
            timeout=5,
        )
        db.row_factory = sqlite3.Row
        tables = {
            row[0] for row in db.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }
        result["database_readable"] = True

        if "users" in tables:
            result["users_count"] = db.execute(
                "SELECT COUNT(*) FROM users"
            ).fetchone()[0]

        if "voice_rooms" in tables:
            result["voice_rooms_count"] = db.execute(
                "SELECT COUNT(*) FROM voice_rooms"
            ).fetchone()[0]

        if "voice_rooms" in tables:
            result["room_details"] = [
                dict(row) for row in db.execute(
                    "SELECT id, owner_code, name, is_active "
                    "FROM voice_rooms ORDER BY id DESC LIMIT 20"
                ).fetchall()
            ]

        return result
    except sqlite3.Error:
        raise HTTPException(503, "Database diagnostic could not read the SQLite file")
    finally:
        if db is not None:
            db.close()

@router.get("/owner/coins/lookup/{user_code}")
def owner_lookup_coin_recipient(
    user_code: str,
    authorization: str | None = Header(default=None),
):
    _require_coin_owner(authorization)
    code = user_code.strip()
    if not code.isdigit():
        raise HTTPException(400, "Enter a valid numeric User ID")

    db = get_connection()
    try:
        row = db.execute(
            """SELECT u.user_code, u.display_name, u.profile_photo,
                      COALESCE(w.coins, 0) AS coins
               FROM users u
               LEFT JOIN wallets w ON w.user_id = u.id
               WHERE u.user_code = ?""",
            (code,),
        ).fetchone()
        if not row:
            raise HTTPException(404, "User ID not found")
        return {"success": True, "user": dict(row)}
    finally:
        db.close()


@router.post("/owner/coins/issue")
def owner_issue_coins(
    payload: OwnerCoinIssueRequest,
    authorization: str | None = Header(default=None),
):
    _require_coin_owner(authorization)
    code = payload.user_code.strip()
    allowed_amounts = {1000, 2000, 5000, 10000, 100000, 1000000, 5000000}

    if not code.isdigit():
        raise HTTPException(400, "Invalid User ID")
    if payload.amount not in allowed_amounts:
        raise HTTPException(400, "Select a permitted coin amount")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        target = db.execute(
            "SELECT id, user_code FROM users WHERE user_code = ?",
            (code,),
        ).fetchone()
        if not target:
            raise HTTPException(404, "User ID not found")

        db.execute(
            "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)",
            (target["id"],),
        )
        db.execute(
            "UPDATE wallets SET coins = coins + ? WHERE user_id = ?",
            (payload.amount, target["id"]),
        )
        db.execute(
            """INSERT INTO transactions
               (user_id, transaction_type, amount, currency, description)
               VALUES (?, ?, ?, ?, ?)""",
            (
                target["id"],
                "owner_coin_issue",
                payload.amount,
                "coins",
                f"Owner ID 1 issued {payload.amount} coins to ID {code}",
            ),
        )
        balance = db.execute(
            "SELECT coins FROM wallets WHERE user_id = ?",
            (target["id"],),
        ).fetchone()["coins"]
        db.commit()
        return {
            "success": True,
            "user_code": code,
            "issued_coins": payload.amount,
            "new_balance": balance,
            "message": "Coins added successfully",
        }
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise
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
class VoiceRoomMessageRequest(BaseModel):
    message: str


def _require_voice_room_member(db, room_id: int, user):
    room = db.execute(
        "SELECT id, owner_uid FROM voice_rooms WHERE id = ? AND is_active = 1",
        (room_id,),
    ).fetchone()
    if not room:
        raise HTTPException(404, "Voice room not found")

    # The room owner is allowed even if they have no participant row.
    if str(room["owner_uid"]) == str(user["google_uid"]):
        return

    member = db.execute(
        "SELECT 1 FROM voice_room_participants WHERE room_id = ? AND user_uid = ?",
        (room_id, user["google_uid"]),
    ).fetchone()
    if not member:
        raise HTTPException(403, "Join this voice room before using its chat")


@router.get("/voice/rooms/{room_id}/messages")
def get_voice_room_messages(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        _require_voice_room_member(db, room_id, user)
        rows = db.execute(
            """SELECT id, sender_uid, sender_code, message, created_at
               FROM voice_room_messages
               WHERE room_id = ? ORDER BY id DESC LIMIT 100""",
            (room_id,),
        ).fetchall()
        return {"success": True, "messages": [dict(row) for row in reversed(rows)]}
    finally:
        db.close()


@router.post("/voice/rooms/{room_id}/messages")
def send_voice_room_message(
    room_id: int,
    payload: VoiceRoomMessageRequest,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    message = payload.message.strip()
    if not message:
        raise HTTPException(400, "Message cannot be empty")
    if len(message) > 500:
        raise HTTPException(400, "Message cannot exceed 500 characters")
    db = get_connection()
    try:
        _require_voice_room_member(db, room_id, user)
        cursor = db.execute(
            """INSERT INTO voice_room_messages
               (room_id, sender_uid, sender_code, message)
               VALUES (?, ?, ?, ?)""",
            (room_id, user["google_uid"], str(user["user_code"]), message),
        )
        db.commit()
        row = db.execute(
            """SELECT id, sender_uid, sender_code, message, created_at
               FROM voice_room_messages WHERE id = ?""",
            (cursor.lastrowid,),
        ).fetchone()
        return {"success": True, "message": dict(row)}
    finally:
        db.close()



# Lovely Sky video streaming room APIs.
class CreateVideoRoomRequest(BaseModel):
    title: str
    description: str = ""


class VideoRoomMessageRequest(BaseModel):
    message: str


def _video_room_user(authorization: str | None):
    return _voice_authenticated_user(authorization)


def _require_live_video_room(db, room_id: int):
    room = db.execute(
        """SELECT id, host_uid, host_code, title, description,
                  cover_image, is_live, created_at
           FROM video_rooms WHERE id = ? AND is_live = 1""",
        (room_id,),
    ).fetchone()
    if not room:
        raise HTTPException(404, "Live video room not found")
    return room


@router.post("/video/rooms")
def start_video_room(
    payload: CreateVideoRoomRequest,
    authorization: str | None = Header(default=None),
):
    user = _video_room_user(authorization)
    title = payload.title.strip()
    description = payload.description.strip()

    if not title or len(title) > 60:
        raise HTTPException(400, "Room title must be 1 to 60 characters")
    if len(description) > 200:
        raise HTTPException(400, "Description cannot exceed 200 characters")

    db = get_connection()
    try:
        existing = db.execute(
            "SELECT id FROM video_rooms WHERE host_uid = ? AND is_live = 1",
            (user["google_uid"],),
        ).fetchone()
        if existing:
            raise HTTPException(409, "You already have an active live room")

        cursor = db.execute(
            """INSERT INTO video_rooms
               (host_uid, host_code, title, description)
               VALUES (?, ?, ?, ?)""",
            (user["google_uid"], str(user["user_code"]), title, description),
        )
        db.commit()
        return {
            "success": True,
            "room_id": cursor.lastrowid,
            "message": "Live room created. Media streaming must connect separately.",
        }
    finally:
        db.close()


@router.get("/video/rooms")
def list_video_rooms(
    tab: str = "popular",
    authorization: str | None = Header(default=None),
):
    user = _video_room_user(authorization)
    tab = tab.strip().lower()
    if tab not in {"popular", "following", "visit"}:
        raise HTTPException(400, "tab must be popular, following, or visit")

    db = get_connection()
    try:
        where = "r.is_live = 1"
        params = []
        if tab == "following":
            where += """ AND EXISTS (
                SELECT 1 FROM user_follows f
                WHERE f.follower_uid = ? AND f.followed_uid = r.host_uid
            )"""
            params.append(user["google_uid"])
        elif tab == "visit":
            where += """ AND EXISTS (
                SELECT 1 FROM video_room_visits h
                WHERE h.user_uid = ? AND h.room_id = r.id
            )"""
            params.append(user["google_uid"])

        order = "viewer_count DESC, r.created_at DESC" if tab == "popular" else "r.created_at DESC"
        rows = db.execute(
            f"""SELECT r.id, r.host_uid, r.host_code, r.title,
                       r.description, r.cover_image, r.created_at,
                       u.display_name AS host_name,
                       u.profile_photo AS host_photo,
                       (SELECT COUNT(*) FROM video_room_viewers v
                        WHERE v.room_id = r.id) AS viewer_count
                FROM video_rooms r
                LEFT JOIN users u ON u.google_uid = r.host_uid
                WHERE {where}
                ORDER BY {order}""",
            params,
        ).fetchall()
        return {"success": True, "tab": tab, "rooms": [dict(row) for row in rows]}
    finally:
        db.close()


@router.post("/video/rooms/{room_id}/join")
def join_video_room(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _video_room_user(authorization)
    uid = user["google_uid"]
    db = get_connection()
    try:
        room = _require_live_video_room(db, room_id)
        if room["host_uid"] == uid:
            return {"success": True, "role": "host", "room_id": room_id}

        db.execute(
            """INSERT OR IGNORE INTO video_room_viewers (room_id, viewer_uid)
               VALUES (?, ?)""",
            (room_id, uid),
        )
        db.execute(
            """INSERT INTO video_room_visits (room_id, user_uid)
               VALUES (?, ?)""",
            (room_id, uid),
        )
        db.commit()
        count = db.execute(
            "SELECT COUNT(*) AS total FROM video_room_viewers WHERE room_id = ?",
            (room_id,),
        ).fetchone()["total"]
        return {"success": True, "role": "viewer", "viewer_count": count}
    finally:
        db.close()


@router.post("/video/rooms/{room_id}/leave")
def leave_video_room(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _video_room_user(authorization)
    db = get_connection()
    try:
        db.execute(
            "DELETE FROM video_room_viewers WHERE room_id = ? AND viewer_uid = ?",
            (room_id, user["google_uid"]),
        )
        db.commit()
        return {"success": True}
    finally:
        db.close()


@router.post("/video/rooms/{room_id}/end")
def end_video_room(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _video_room_user(authorization)
    db = get_connection()
    try:
        room = db.execute(
            "SELECT host_uid FROM video_rooms WHERE id = ? AND is_live = 1",
            (room_id,),
        ).fetchone()
        if not room:
            raise HTTPException(404, "Live video room not found")
        if room["host_uid"] != user["google_uid"]:
            raise HTTPException(403, "Only the host can end this live room")

        db.execute(
            """UPDATE video_rooms SET is_live = 0,
               ended_at = CURRENT_TIMESTAMP WHERE id = ?""",
            (room_id,),
        )
        db.execute("DELETE FROM video_room_viewers WHERE room_id = ?", (room_id,))
        db.commit()
        return {"success": True, "message": "Live room ended"}
    finally:
        db.close()



@router.post("/video/rooms/{room_id}/token")
def get_video_room_token(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _video_room_user(authorization)

    livekit_url = os.environ.get("LIVEKIT_URL", "").strip()
    api_key = os.environ.get("LIVEKIT_API_KEY", "").strip()
    api_secret = os.environ.get("LIVEKIT_API_SECRET", "").strip()
    if not livekit_url or not api_key or not api_secret:
        raise HTTPException(503, "Live video streaming is not configured")

    db = get_connection()
    try:
        room = _require_live_video_room(db, room_id)
        is_host = room["host_uid"] == user["google_uid"]

        if not is_host:
            member = db.execute(
                """SELECT 1 FROM video_room_viewers
                   WHERE room_id = ? AND viewer_uid = ?""",
                (room_id, user["google_uid"]),
            ).fetchone()
            if not member:
                raise HTTPException(403, "Join this live room before connecting")

        try:
            from datetime import timedelta
            from livekit import api

            room_name = f"lovelysky_video_{room_id}"
            token = (
                api.AccessToken(api_key, api_secret)
                .with_identity(f"user_{user['user_code']}")
                .with_ttl(timedelta(minutes=60))
                .with_grants(api.VideoGrants(
                    room_join=True,
                    room=room_name,
                    can_publish=is_host,
                    can_subscribe=True,
                    can_publish_data=is_host,
                ))
            )
            jwt = token.to_jwt()
        except Exception as exc:
            logger.error("LiveKit token generation failed: %s", type(exc).__name__)
            raise HTTPException(503, "Could not create live video access") from exc

        return {
            "success": True,
            "url": livekit_url,
            "token": jwt,
            "role": "host" if is_host else "viewer",
            "room_name": room_name,
        }
    finally:
        db.close()


@router.get("/video/rooms/{room_id}/messages")
def get_video_room_messages(
    room_id: int,
    authorization: str | None = Header(default=None),
):
    user = _video_room_user(authorization)
    db = get_connection()
    try:
        room = _require_live_video_room(db, room_id)
        uid = user["google_uid"]
        is_host = room["host_uid"] == uid
        is_viewer = db.execute(
            """SELECT 1 FROM video_room_viewers
               WHERE room_id = ? AND viewer_uid = ?""",
            (room_id, uid),
        ).fetchone()
        if not is_host and not is_viewer:
            raise HTTPException(403, "Join this live room before using chat")

        rows = db.execute(
            """SELECT id, sender_uid, sender_code, message, created_at
               FROM video_room_messages
               WHERE room_id = ? ORDER BY id DESC LIMIT 100""",
            (room_id,),
        ).fetchall()
        return {"success": True, "messages": [dict(row) for row in reversed(rows)]}
    finally:
        db.close()


@router.post("/video/rooms/{room_id}/messages")
def send_video_room_message(
    room_id: int,
    payload: VideoRoomMessageRequest,
    authorization: str | None = Header(default=None),
):
    user = _video_room_user(authorization)
    message = payload.message.strip()
    if not message:
        raise HTTPException(400, "Message cannot be empty")
    if len(message) > 500:
        raise HTTPException(400, "Message cannot exceed 500 characters")

    db = get_connection()
    try:
        room = _require_live_video_room(db, room_id)
        uid = user["google_uid"]
        is_host = room["host_uid"] == uid
        is_viewer = db.execute(
            """SELECT 1 FROM video_room_viewers
               WHERE room_id = ? AND viewer_uid = ?""",
            (room_id, uid),
        ).fetchone()
        if not is_host and not is_viewer:
            raise HTTPException(403, "Join this live room before chatting")

        cursor = db.execute(
            """INSERT INTO video_room_messages
               (room_id, sender_uid, sender_code, message)
               VALUES (?, ?, ?, ?)""",
            (room_id, uid, str(user["user_code"]), message),
        )
        db.commit()
        row = db.execute(
            """SELECT id, sender_uid, sender_code, message, created_at
               FROM video_room_messages WHERE id = ?""",
            (cursor.lastrowid,),
        ).fetchone()
        return {"success": True, "message": dict(row)}
    finally:
        db.close()


# WebRTC signaling connections, indexed by room and user UID.
VOICE_SIGNAL_CONNECTIONS: dict[int, dict[str, WebSocket]] = {}


@router.websocket("/voice/rooms/{room_id}/signal")
async def voice_room_signal(websocket: WebSocket, room_id: int):
    await websocket.accept()
    user = None
    uid = None
    connections = None

    try:
        auth_message = await websocket.receive_json()
        token = auth_message.get("token") if isinstance(auth_message, dict) else None
        if not isinstance(token, str) or not token.strip():
            await websocket.close(code=4401, reason="Authentication required")
            return

        try:
            claims = verify_token(token.strip())
            user = save_google_user(claims)
        except Exception:
            await websocket.close(code=4401, reason="Authentication failed")
            return

        uid = str(user["google_uid"])
        db = get_connection()
        try:
            room = db.execute(
                "SELECT id FROM voice_rooms WHERE id = ? AND is_active = 1",
                (room_id,),
            ).fetchone()
            member = db.execute(
                """SELECT is_muted FROM voice_room_participants WHERE room_id = ? AND user_uid = ?""",
                (room_id, user["google_uid"]),
).fetchone()
            saved_muted = bool(member["is_muted"]) if member else False
        finally:
            db.close()

        if not room or not member:
            await websocket.close(code=4403, reason="Join this voice room first")
            return

        connections = VOICE_SIGNAL_CONNECTIONS.setdefault(room_id, {})
        existing = [
            {"uid": peer_uid}
            for peer_uid in connections
            if peer_uid != uid
        ]
        connections[uid] = websocket

        await websocket.send_json({
            "type": "existing_peers",
            "payload": {"peers": existing},
        })
        if saved_muted:
            await websocket.send_json({
                "type": "moderation_mic",
                "payload": False,
            })

        for peer_uid, peer in list(connections.items()):
            if peer_uid == uid:
                continue
            try:
                await peer.send_json({
                    "type": "peer_joined",
                    "sender_uid": uid,
                    "sender_code": str(user["user_code"]),
                })
            except Exception:
                if connections.get(peer_uid) is peer:
                    connections.pop(peer_uid, None)

        while True:
            try:
                message = await asyncio.wait_for(
                    websocket.receive_json(),
                    timeout=5.0,
                )
            except asyncio.TimeoutError:
                message = None

            # Revalidate room access even when the socket is idle.
            db = get_connection()
            try:
                access_room = db.execute(
                    "SELECT 1 FROM voice_rooms WHERE id = ? AND is_active = 1",
                    (room_id,),
                ).fetchone()
                access_member = db.execute(
                    "SELECT 1 FROM voice_room_participants "
                    "WHERE room_id = ? AND user_uid = ?",
                    (room_id, uid),
                ).fetchone()
                access_block = db.execute(
                    "SELECT 1 FROM voice_room_blocks "
                    "WHERE room_id = ? AND user_uid = ?",
                    (room_id, uid),
                ).fetchone()
            finally:
                db.close()

            if not access_room or not access_member or access_block:
                await websocket.close(
                    code=4403,
                    reason="Room access revoked",
                )
                break

            if message is None or not isinstance(message, dict):
                continue

            kind = message.get("type")
            target_uid = message.get("target_uid")
            if kind == "moderator_mute":
                mic_on = message.get("payload")
                if (
                    not isinstance(target_uid, str)
                    or not target_uid
                    or target_uid == uid
                    or not isinstance(mic_on, bool)
                ):
                    continue

                db = get_connection()
                try:
                    role = _voice_room_role(db, room_id, uid)
                    if role not in {"owner", "admin"}:
                        await websocket.send_json({
                            "type": "moderation_error",
                            "message": "Only the room owner or appointed admin can moderate microphones",
                        })
                        continue

                    target = db.execute(
                        """SELECT 1 FROM voice_room_participants
                           WHERE room_id = ? AND user_uid = ?""",
                        (room_id, target_uid),
                    ).fetchone()
                    target_role = (
                        _voice_room_role(db, room_id, target_uid)
                        if target else None
                    )
                finally:
                    db.close()

                if not target:
                    await websocket.send_json({
                        "type": "moderation_error",
                        "message": "Target member has not joined this room",
                    })
                    continue

                if target_role == "owner" or (
                    target_role == "admin" and role != "owner"
                ):
                    await websocket.send_json({
                        "type": "moderation_error",
                        "message": "Admins cannot moderate the owner or another admin",
                    })
                    continue

                db = get_connection()
                try:
                    db.execute(
                        """UPDATE voice_room_participants
                           SET is_muted = ?
                           WHERE room_id = ? AND user_uid = ?""",
                        (0 if mic_on else 1, room_id, target_uid),
                    )
                    db.commit()
                finally:
                    db.close()

                target_socket = connections.get(target_uid)
                if target_socket is None:
                    await websocket.send_json({
                        "type": "moderation_error",
                        "message": "Target member is not connected to voice",
                    })
                    continue

                await target_socket.send_json({
                    "type": "moderation_mic",
                    "sender_uid": uid,
                    "sender_code": str(user["user_code"]),
                    "payload": mic_on,
                })
                continue

            if kind == "mic_status":
                mic_on = message.get("payload")
                if not isinstance(mic_on, bool):
                    continue
                db = get_connection()
                try:
                    participant = db.execute(
                        """SELECT is_muted FROM voice_room_participants
                           WHERE room_id = ? AND user_uid = ?""",
                        (room_id, uid),
                    ).fetchone()
                finally:
                    db.close()

                if not participant:
                    await websocket.send_json({
                        "type": "moderation_error",
                        "message": "You are not a participant in this voice room",
                    })
                    continue

                if participant["is_muted"] and mic_on:
                    await websocket.send_json({
                        "type": "moderation_mic",
                        "payload": False,
                    })
                    continue
                broadcast = {
                    "type": "mic_status",
                    "sender_uid": uid,
                    "sender_code": str(user["user_code"]),
                    "payload": mic_on,
                }
                for peer_uid, peer in list(connections.items()):
                    if peer_uid == uid:
                        continue
                    try:
                        await peer.send_json(broadcast)
                    except Exception:
                        if connections.get(peer_uid) is peer:
                            connections.pop(peer_uid, None)
                continue

            if kind == "speaking":
                speaking = message.get("payload")
                if not isinstance(speaking, bool):
                    continue
                broadcast = {
                    "type": "speaking",
                    "sender_uid": uid,
                    "sender_code": str(user["user_code"]),
                    "payload": speaking,
                }
                for peer_uid, peer in list(connections.items()):
                    if peer_uid == uid:
                        continue
                    try:
                        await peer.send_json(broadcast)
                    except Exception:
                        if connections.get(peer_uid) is peer:
                            connections.pop(peer_uid, None)
                continue

            if kind not in {"offer", "answer", "candidate"}:
                continue
            if not isinstance(target_uid, str) or target_uid == uid:
                continue

            peer = connections.get(target_uid)
            if peer is None:
                continue

            await peer.send_json({
                "type": kind,
                "sender_uid": uid,
                "sender_code": str(user["user_code"]),
                "payload": message.get("payload"),
            })

    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.warning("Voice signaling disconnected (%s)", type(exc).__name__)
    finally:
        if connections is not None and uid is not None:
            if connections.get(uid) is websocket:
                connections.pop(uid, None)
                for peer_uid, peer in list(connections.items()):
                    try:
                        await peer.send_json({
                            "type": "peer_left",
                            "sender_uid": uid,
                        })
                    except Exception:
                        if connections.get(peer_uid) is peer:
                            connections.pop(peer_uid, None)
            if not connections:
                VOICE_SIGNAL_CONNECTIONS.pop(room_id, None)
        try:
            await websocket.close()
        except Exception:
            pass


@router.get("/games/wallet")
def get_games_wallet(authorization: str | None = Header(default=None)):
    """Return the authenticated user's Lovely Sky coin wallet and recent history."""
    user = _voice_authenticated_user(authorization)
    user_id = int(user["id"])
    db = get_connection()

    try:
        db.execute("BEGIN IMMEDIATE")

        db.execute(
            "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)",
            (user_id,),
        )

        wallet = db.execute(
            "SELECT coins, diamonds FROM wallets WHERE user_id = ?",
            (user_id,),
        ).fetchone()

        transactions = db.execute(
            """
            SELECT id, transaction_type, amount, currency,
                   description, created_at
            FROM transactions
            WHERE user_id = ?
            ORDER BY id DESC
            LIMIT 50
            """,
            (user_id,),
        ).fetchall()

        db.commit()

        return {
            "success": True,
            "user_code": str(user.get("user_code") or ""),
            "coins": int(wallet["coins"]),
            "diamonds": int(wallet["diamonds"]),
            "transactions": [dict(item) for item in transactions],
        }

    except Exception:
        db.rollback()
        raise
    finally:
        db.close()








@router.post("/games/wallet/exchange")
async def exchange_wallet_diamonds(
    request: Request,
    authorization: str | None = Header(default=None),
):
    """Exchange Diamonds into Coins at 2 Diamonds = 1 Coin."""
    user = _voice_authenticated_user(authorization)

    try:
        payload = await request.json()
        amount = int(payload.get("diamonds", 0))
    except Exception:
        raise HTTPException(400, "Invalid diamond amount")

    if amount < 2 or amount % 2 != 0:
        raise HTTPException(400, "Diamonds must be an even amount of at least 2")

    coins = amount // 2
    user_id = int(user["id"])
    db = get_connection()

    try:
        db.execute("BEGIN IMMEDIATE")
        db.execute(
            "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)",
            (user_id,),
        )

        debit = db.execute(
            """UPDATE wallets SET diamonds = diamonds - ?
               WHERE user_id = ? AND diamonds >= ?""",
            (amount, user_id, amount),
        )
        if debit.rowcount != 1:
            raise HTTPException(400, "Not enough Diamonds")

        db.execute(
            "UPDATE wallets SET coins = coins + ? WHERE user_id = ?",
            (coins, user_id),
        )

        db.execute(
            """INSERT INTO transactions
               (user_id, transaction_type, amount, currency, description)
               VALUES (?, 'diamond_exchange', ?, 'diamonds', ?)""",
            (user_id, amount, f"Exchanged {amount} Diamonds for {coins} Coins"),
        )
        db.execute(
            """INSERT INTO transactions
               (user_id, transaction_type, amount, currency, description)
               VALUES (?, 'diamond_exchange', ?, 'coins', ?)""",
            (user_id, coins, f"Received {coins} Coins from {amount} Diamonds"),
        )

        wallet = db.execute(
            "SELECT coins, diamonds FROM wallets WHERE user_id = ?",
            (user_id,),
        ).fetchone()

        db.commit()
        return {
            "success": True,
            "diamonds_exchanged": amount,
            "coins_received": coins,
            "coins": int(wallet["coins"]),
            "diamonds": int(wallet["diamonds"]),
        }
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        logger.exception("Diamond exchange failed")
        raise HTTPException(500, "Could not exchange Diamonds")
    finally:
        db.close()

# Lovely Sky Gifts — 1 Coin spent = 1 Diamond credited.
GIFT_CATALOG = [
    # Standard gifts
    {"code": "rose", "name": "Rose", "emoji": "🌹", "coin_cost": 10, "category": "Gift"},
    {"code": "heart", "name": "Heart", "emoji": "❤️", "coin_cost": 50, "category": "Gift"},
    {"code": "teddy", "name": "Teddy", "emoji": "🧸", "coin_cost": 100, "category": "Gift"},
    {"code": "cake", "name": "Cake", "emoji": "🎂", "coin_cost": 200, "category": "Gift"},
    {"code": "crown", "name": "Crown", "emoji": "👑", "coin_cost": 500, "category": "Gift"},
    {"code": "rocket", "name": "Rocket", "emoji": "🚀", "coin_cost": 1000, "category": "Gift"},

    # CP collection
    {"code": "cp_star", "name": "Star CP", "emoji": "🌟", "coin_cost": 120, "category": "CP"},
    {"code": "cp_love", "name": "Love CP", "emoji": "💞", "coin_cost": 260, "category": "CP"},
    {"code": "cp_diamond", "name": "Diamond CP", "emoji": "💎", "coin_cost": 520, "category": "CP"},
    {"code": "cp_king", "name": "King CP", "emoji": "🤴", "coin_cost": 880, "category": "CP"},

    # Lucky gifts
    {"code": "lucky_box", "name": "Lucky Box", "emoji": "🎁", "coin_cost": 150, "category": "Lucky Gift"},
    {"code": "lucky_clover", "name": "Lucky Clover", "emoji": "🍀", "coin_cost": 300, "category": "Lucky Gift"},
    {"code": "lucky_horse", "name": "Lucky Horse", "emoji": "🐎", "coin_cost": 650, "category": "Lucky Gift"},
    {"code": "lucky_jackpot", "name": "Jackpot", "emoji": "🎰", "coin_cost": 1500, "category": "Lucky Gift"},

    # Flags
    {"code": "flag_pakistan", "name": "Pakistan Flag", "emoji": "🇵🇰", "coin_cost": 100, "category": "Flag"},
    {"code": "flag_love", "name": "Love Flag", "emoji": "🏳️‍🌈", "coin_cost": 180, "category": "Flag"},
    {"code": "flag_world", "name": "World Flag", "emoji": "🌍", "coin_cost": 350, "category": "Flag"},
    {"code": "flag_gold", "name": "Golden Flag", "emoji": "🚩", "coin_cost": 700, "category": "Flag"},

    # Exclusive gifts
    {"code": "exclusive_phoenix", "name": "Phoenix", "emoji": "🔥", "coin_cost": 2500, "category": "Exclusive"},
    {"code": "exclusive_dragon", "name": "Dragon", "emoji": "🐉", "coin_cost": 5000, "category": "Exclusive"},
    {"code": "exclusive_yacht", "name": "Royal Yacht", "emoji": "🛥️", "coin_cost": 10000, "category": "Exclusive"},
    {"code": "exclusive_castle", "name": "Love Castle", "emoji": "🏰", "coin_cost": 20000, "category": "Exclusive"},
    {"code": "heart_rain", "name": "Heart Rain", "emoji": "💗", "coin_cost": 500000, "category": "CP"},
    {"code": "magic_sparkle", "name": "Magic Sparkle", "emoji": "✨", "coin_cost": 500000, "category": "CP"},
    {"code": "neon_aura", "name": "Neon Aura", "emoji": "💫", "coin_cost": 500000, "category": "CP"},
    {"code": "rose_shower", "name": "Rose Shower", "emoji": "🌹", "coin_cost": 500000, "category": "CP"},
    {"code": "snowfall", "name": "Snowfall", "emoji": "❄️", "coin_cost": 500000, "category": "CP"},
    {"code": "celebration", "name": "Celebration", "emoji": "🎉", "coin_cost": 500000, "category": "CP"},
    {"code": "royal_crown", "name": "Royal Crown", "emoji": "👑", "coin_cost": 500000, "category": "CP"},
    {"code": "butterfly_rain", "name": "Butterfly Rain", "emoji": "🦋", "coin_cost": 500000, "category": "CP"},
    {"code": "fire_storm", "name": "Fire Storm", "emoji": "🔥", "coin_cost": 500000, "category": "CP"},
    {"code": "diamond_shower", "name": "Diamond Shower", "emoji": "💎", "coin_cost": 500000, "category": "CP"},
    {"code": "rainbow", "name": "Rainbow", "emoji": "🌈", "coin_cost": 500000, "category": "CP"},
    {"code": "rocket_blast", "name": "Rocket Blast", "emoji": "🚀", "coin_cost": 500000, "category": "CP"},
    {"code": "moonlight", "name": "Moonlight", "emoji": "🌙", "coin_cost": 500000, "category": "CP"},
    {"code": "lightning", "name": "Lightning", "emoji": "⚡", "coin_cost": 500000, "category": "CP"},
    {"code": "peacock_dance", "name": "Peacock Dance", "emoji": "🦚", "coin_cost": 500000, "category": "CP"},
    {"code": "flying_kiss", "name": "Flying Kiss", "emoji": "💋", "coin_cost": 500000, "category": "CP"},
    {"code": "romantic_kiss", "name": "Romantic Kiss", "emoji": "💋", "coin_cost": 500000, "category": "CP"},
    {"code": "couple_kiss", "name": "Couple Kiss", "emoji": "❤️", "coin_cost": 500000, "category": "CP"},
    {"code": "kiss_hearts_rain", "name": "Kiss Hearts Rain", "emoji": "💕", "coin_cost": 500000, "category": "CP"},
    {"code": "love_explosion", "name": "Love Explosion", "emoji": "💖", "coin_cost": 500000, "category": "CP"},
]
GIFT_BY_CODE = {item["code"]: item for item in GIFT_CATALOG}


@router.get("/gifts/catalog")
def get_gift_catalog(authorization: str | None = Header(default=None)):
    _voice_authenticated_user(authorization)
    return {"success": True, "gifts": GIFT_CATALOG, "coin_to_diamond_rate": 1}


@router.post("/gifts/send")
async def send_gift(
    request: Request,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    try:
        payload = await request.json()
    except Exception:
        raise HTTPException(400, "Invalid JSON body")

    if not isinstance(payload, dict):
        raise HTTPException(400, "JSON body must be an object")

    receiver_code = str(payload.get("receiver_code", "")).strip()
    gift_code = str(payload.get("gift_code", "")).strip().lower()

    try:
        quantity = int(payload.get("quantity", 1))
    except (TypeError, ValueError):
        raise HTTPException(400, "Invalid gift quantity")

    if not receiver_code:
        raise HTTPException(400, "Receiver user ID is required")
    if quantity < 1 or quantity > 99:
        raise HTTPException(400, "Gift quantity must be between 1 and 99")

    gift = GIFT_BY_CODE.get(gift_code)
    if not gift:
        raise HTTPException(404, "Gift not found")

    sender_id = int(user["id"])
    total = int(gift["coin_cost"]) * quantity
    db = get_connection()

    try:
        db.execute("BEGIN IMMEDIATE")

        receiver = db.execute(
            "SELECT id, user_code FROM users WHERE user_code = ?",
            (receiver_code,),
        ).fetchone()
        if not receiver:
            raise HTTPException(404, "Receiver user not found")

        receiver_id = int(receiver["id"])

        db.execute(
            "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)",
            (sender_id,),
        )
        db.execute(
            "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)",
            (receiver_id,),
        )

        debit = db.execute(
            """UPDATE wallets SET coins = coins - ?
               WHERE user_id = ? AND coins >= ?""",
            (total, sender_id, total),
        )
        if debit.rowcount != 1:
            raise HTTPException(400, "Not enough Lovely Coins")

        db.execute(
            "UPDATE wallets SET diamonds = diamonds + ? WHERE user_id = ?",
            (total, receiver_id),
        )

        db.execute(
            """INSERT INTO inventory (user_id, item_type, item_code, quantity)
               VALUES (?, 'gift', ?, ?)
               ON CONFLICT(user_id, item_type, item_code)
               DO UPDATE SET quantity = quantity + excluded.quantity""",
            (receiver_id, gift_code, quantity),
        )

        db.execute(
            """INSERT INTO gift_transactions
               (sender_user_id, receiver_user_id, gift_code, gift_name,
                quantity, coins_spent, diamonds_credited)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                sender_id, receiver_id, gift_code, gift["name"],
                quantity, total, total,
            ),
        )

        db.execute(
            """INSERT INTO transactions
               (user_id, transaction_type, amount, currency, description)
               VALUES (?, 'gift_sent', ?, 'coins', ?)""",
            (sender_id, total, f"Sent {quantity} x {gift['name']} to ID {receiver_code}"),
        )
        db.execute(
            """INSERT INTO transactions
               (user_id, transaction_type, amount, currency, description)
               VALUES (?, 'gift_received', ?, 'diamonds', ?)""",
            (receiver_id, total, f"Received {quantity} x {gift['name']} from ID {user.get('user_code', '')}"),
        )

        sender_wallet = db.execute(
            "SELECT coins, diamonds FROM wallets WHERE user_id = ?",
            (sender_id,),
        ).fetchone()
        receiver_wallet = db.execute(
            "SELECT coins, diamonds FROM wallets WHERE user_id = ?",
            (receiver_id,),
        ).fetchone()

        db.commit()
        return {
            "success": True,
            "gift": gift,
            "quantity": quantity,
            "coins_spent": total,
            "diamonds_credited": total,
            "sender_coins": int(sender_wallet["coins"]),
            "receiver_diamonds": int(receiver_wallet["diamonds"]),
            "receiver_code": receiver_code,
            "self_gift": sender_id == receiver_id,
        }
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        logger.exception("Gift sending failed")
        raise HTTPException(500, "Could not send gift")
    finally:
        db.close()




@router.post("/voice/rooms/{room_id}/gifts/send")
async def send_voice_room_gift(
    room_id: int,
    request: Request,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    try:
        payload = await request.json()
    except Exception:
        raise HTTPException(400, "Invalid JSON body")
    if not isinstance(payload, dict):
        raise HTTPException(400, "JSON body must be an object")

    raw_codes = payload.get("receiver_codes", [])
    if not isinstance(raw_codes, list):
        raise HTTPException(400, "receiver_codes must be a list")
    receiver_codes = list(dict.fromkeys(
        str(code).strip() for code in raw_codes if str(code).strip()
    ))
    if not receiver_codes or len(receiver_codes) > 100:
        raise HTTPException(400, "Select between 1 and 100 room members")

    gift_code = str(payload.get("gift_code", "")).strip().lower()
    try:
        quantity = int(payload.get("quantity", 1))
    except (TypeError, ValueError):
        raise HTTPException(400, "Invalid gift quantity")
    if quantity < 1 or quantity > 99:
        raise HTTPException(400, "Gift quantity must be between 1 and 99")

    gift = GIFT_BY_CODE.get(gift_code)
    if not gift:
        raise HTTPException(404, "Gift not found")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        _require_voice_room_member(db, room_id, user)

        room_members = db.execute(
            """
            SELECT p.user_code, p.user_uid, u.id AS user_id,
                   u.display_name, u.profile_photo
            FROM voice_room_participants p
            JOIN users u ON u.google_uid = p.user_uid
            WHERE p.room_id = ?
            UNION
            SELECT r.owner_code, r.owner_uid, u.id,
                   u.display_name, u.profile_photo
            FROM voice_rooms r
            JOIN users u ON u.google_uid = r.owner_uid
            WHERE r.id = ?
            """,
            (room_id, room_id),
        ).fetchall()
        members_by_code = {str(row["user_code"]): row for row in room_members}
        if any(code not in members_by_code for code in receiver_codes):
            raise HTTPException(403, "A selected recipient is not a member of this room")

        sender_id = int(user["id"])
        cost_each = int(gift["coin_cost"]) * quantity
        total_cost = cost_each * len(receiver_codes)

        is_lucky_gift = str(gift.get("category", "")).lower() == "lucky gift"
        cashback_percent = 0
        cashback_amount = 0
        if is_lucky_gift:
            cashback_roll = secrets.randbelow(100)
            if cashback_roll < 50:
                cashback_percent = 10
            elif cashback_roll < 75:
                cashback_percent = 20
            elif cashback_roll < 90:
                cashback_percent = 50
            elif cashback_roll < 98:
                cashback_percent = 100
            else:
                cashback_percent = 500
            cashback_amount = total_cost * cashback_percent // 100

        receiver_diamond_reward = (
            cost_each * 10 // 100 if is_lucky_gift else cost_each
        )

        db.execute(
            "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)",
            (sender_id,),
        )
        debit = db.execute(
            """UPDATE wallets SET coins = coins - ?
               WHERE user_id = ? AND coins >= ?""",
            (total_cost, sender_id, total_cost),
        )
        if debit.rowcount != 1:
            raise HTTPException(400, "Not enough Lovely Coins")

        for code in receiver_codes:
            receiver_id = int(members_by_code[code]["user_id"])
            db.execute(
                "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)",
                (receiver_id,),
            )
            db.execute(
                "UPDATE wallets SET diamonds = diamonds + ? WHERE user_id = ?",
                (receiver_diamond_reward, receiver_id),
            )
            db.execute(
                """INSERT INTO inventory (user_id, item_type, item_code, quantity)
                   VALUES (?, 'gift', ?, ?)
                   ON CONFLICT(user_id, item_type, item_code)
                   DO UPDATE SET quantity = quantity + excluded.quantity""",
                (receiver_id, gift_code, quantity),
            )
            db.execute(
                """INSERT INTO gift_transactions
                   (sender_user_id, receiver_user_id, gift_code, gift_name,
                    quantity, coins_spent, diamonds_credited)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (sender_id, receiver_id, gift_code, gift["name"],
                 quantity, cost_each, receiver_diamond_reward),
            )
            db.execute(
                """INSERT INTO voice_room_gift_diamonds
                   (room_id, user_uid, user_code, diamonds)
                   VALUES (?, ?, ?, ?)
                   ON CONFLICT(room_id, user_uid)
                   DO UPDATE SET
                     diamonds = diamonds + excluded.diamonds,
                     user_code = excluded.user_code""",
                (room_id, members_by_code[code]["user_uid"], code,
                 receiver_diamond_reward),
            )
            db.execute(
                """INSERT INTO transactions
                   (user_id, transaction_type, amount, currency, description)
                   VALUES (?, 'gift_received', ?, 'diamonds', ?)""",
                (receiver_id, receiver_diamond_reward,
                 f"Received {quantity} x {gift['name']} from ID {user.get('user_code', '')}"),
            )

        db.execute(
            """INSERT INTO transactions
               (user_id, transaction_type, amount, currency, description)
               VALUES (?, 'gift_sent', ?, 'coins', ?)""",
            (sender_id, total_cost,
             f"Sent {quantity} x {gift['name']} to {len(receiver_codes)} room member(s)"),
        )
        if cashback_amount > 0:
            db.execute(
                "UPDATE wallets SET coins = coins + ? WHERE user_id = ?",
                (cashback_amount, sender_id),
            )
            db.execute(
                """INSERT INTO transactions
                   (user_id, transaction_type, amount, currency, description)
                   VALUES (?, 'lucky_cashback', ?, 'coins', ?)""",
                (
                    sender_id,
                    cashback_amount,
                    f"Lucky Gift {cashback_percent}% cashback on {total_cost} Coins",
                ),
            )

        sender_profile = db.execute(
            "SELECT user_code, display_name, profile_photo FROM users WHERE id = ?",
            (sender_id,),
        ).fetchone()

        sender_wallet = db.execute(
            "SELECT coins FROM wallets WHERE user_id = ?",
            (sender_id,),
        ).fetchone()
        receiver_gift_diamonds = {}
        for code in receiver_codes:
            total_row = db.execute(
                """SELECT diamonds FROM voice_room_gift_diamonds
                   WHERE room_id = ? AND user_uid = ?""",
                (room_id, members_by_code[code]["user_uid"]),
            ).fetchone()
            receiver_gift_diamonds[code] = int(total_row["diamonds"]) if total_row else 0

        db.commit()

        gift_event = {
            "receiver_gift_diamonds": receiver_gift_diamonds,
            "sender_code": str(user.get("user_code", "")),
            "sender_photo": str(sender_profile["profile_photo"] or "") if sender_profile else "",
            "cashback_percent": cashback_percent,
            "cashback_coins": cashback_amount,
            "lucky_cashback": bool(is_lucky_gift),
            "sender_name": str(
                user.get("display_name") or user.get("name")
                or user.get("user_code") or "Member"
            ),
            "gift_code": gift_code,
            "gift_name": str(gift["name"]),
            "emoji": str(gift.get("emoji", "🎁")),
            "quantity": quantity,
            "receiver_codes": receiver_codes,
            "coins_spent": total_cost,
            "diamonds_per_recipient": receiver_diamond_reward,
        }
        dead_connections = []
        for peer_uid, peer_socket in list(
            VOICE_SIGNAL_CONNECTIONS.get(room_id, {}).items()
        ):
            try:
                await peer_socket.send_json({
                    "type": "gift_event",
                    "payload": gift_event,
                })
            except Exception:
                dead_connections.append(peer_uid)

        for peer_uid in dead_connections:
            VOICE_SIGNAL_CONNECTIONS.get(room_id, {}).pop(peer_uid, None)

        # 50%, 100% and 500% Lucky Cashback announcements go to every
        # currently connected voice room, not only the sender's room.
        if is_lucky_gift and cashback_percent >= 50:
            first_receiver_code = receiver_codes[0]
            first_receiver = members_by_code[first_receiver_code]
            lucky_event = {
                "cashback_percent": cashback_percent,
                "sender_code": str(sender_profile["user_code"] or "") if sender_profile else str(user.get("user_code", "")),
                "sender_name": str((sender_profile["display_name"] or "") if sender_profile else ""),
                "sender_photo": str((sender_profile["profile_photo"] or "") if sender_profile else ""),
                "receiver_code": first_receiver_code,
                "receiver_name": str(first_receiver["display_name"] or ""),
                "receiver_photo": str(first_receiver["profile_photo"] or ""),
            }
            dead_global = []
            for active_room_id, room_connections in list(VOICE_SIGNAL_CONNECTIONS.items()):
                for peer_uid, peer_socket in list(room_connections.items()):
                    try:
                        await peer_socket.send_json({
                            "type": "lucky_cashback_event",
                            "payload": lucky_event,
                        })
                    except Exception:
                        dead_global.append((active_room_id, peer_uid, peer_socket))

            for dead_room_id, dead_uid, dead_socket in dead_global:
                current = VOICE_SIGNAL_CONNECTIONS.get(dead_room_id, {})
                if current.get(dead_uid) is dead_socket:
                    current.pop(dead_uid, None)
                if not current:
                    VOICE_SIGNAL_CONNECTIONS.pop(dead_room_id, None)

        return {
            "success": True,
            "recipients_count": len(receiver_codes),
            "coins_spent": total_cost,
            "diamonds_per_recipient": receiver_diamond_reward,
            "sender_coins": int(sender_wallet["coins"]),
            "lucky_cashback_percent": cashback_percent,
            "cashback_coins": cashback_amount,
            "coin_to_diamond_rate": 1,
        }
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        logger.exception("Voice room gift send failed")
        raise HTTPException(500, "Could not send room gifts")
    finally:
        db.close()

@router.get("/gifts/bag")
def get_gift_bag(authorization: str | None = Header(default=None)):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        rows = db.execute(
            """SELECT item_code AS gift_code, quantity
               FROM inventory
               WHERE user_id = ? AND item_type = 'gift' AND quantity > 0
               ORDER BY id DESC""",
            (int(user["id"]),),
        ).fetchall()
        gifts = []
        for row in rows:
            item = GIFT_BY_CODE.get(row["gift_code"])
            if item:
                gifts.append({**item, "quantity": int(row["quantity"])})
        return {"success": True, "gifts": gifts}
    finally:
        db.close()


@router.get("/gifts/history")
def get_gift_history(authorization: str | None = Header(default=None)):
    user = _voice_authenticated_user(authorization)
    db = get_connection()
    try:
        rows = db.execute(
            """SELECT g.id, g.gift_code, g.gift_name, g.quantity,
                      g.coins_spent, g.diamonds_credited, g.created_at,
                      s.user_code AS sender_code, s.display_name AS sender_name,
                      r.user_code AS receiver_code, r.display_name AS receiver_name
               FROM gift_transactions g
               JOIN users s ON s.id = g.sender_user_id
               JOIN users r ON r.id = g.receiver_user_id
               WHERE g.sender_user_id = ? OR g.receiver_user_id = ?
               ORDER BY g.id DESC LIMIT 100""",
            (int(user["id"]), int(user["id"])),
        ).fetchall()
        return {"success": True, "history": [dict(row) for row in rows]}
    finally:
        db.close()



# Casino API Pro — Sandbox only. Credentials stay on the server.
_CASINO_PROVIDER_BASE = "https://api.casinoapipro.com"
_casino_provider_access_token = None
_casino_provider_token_expires = 0.0


async def _casino_provider_token():
    global _casino_provider_access_token, _casino_provider_token_expires

    if _casino_provider_access_token and time.monotonic() < _casino_provider_token_expires:
        return _casino_provider_access_token

    api_key = os.environ.get("CASINO_API_KEY", "").strip()
    api_secret = os.environ.get("CASINO_API_SECRET", "").strip()

    if not api_key.startswith("ck_test_") or not api_secret.startswith("cs_test_"):
        raise HTTPException(503, "Casino Sandbox credentials are missing or are not test keys.")

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                f"{_CASINO_PROVIDER_BASE}/v1/auth/token",
                json={"api_key": api_key, "api_secret": api_secret},
            )
        data = response.json()
    except (httpx.HTTPError, ValueError):
        logger.exception("Casino provider authentication request failed")
        raise HTTPException(502, "Casino provider authentication failed.")

    if response.status_code >= 400 or not isinstance(data, dict) or not data.get("access_token"):
        logger.error("Casino provider authentication rejected (HTTP %s)", response.status_code)
        raise HTTPException(502, "Casino provider rejected the Sandbox credentials.")

    _casino_provider_access_token = str(data["access_token"])
    expires_in = max(60, int(data.get("expires_in", 3600)))
    _casino_provider_token_expires = time.monotonic() + expires_in - 60
    return _casino_provider_access_token


async def _casino_provider_request(method: str, path: str, payload=None):
    token = await _casino_provider_token()
    try:
        async with httpx.AsyncClient(timeout=25.0) as client:
            response = await client.request(
                method,
                f"{_CASINO_PROVIDER_BASE}{path}",
                headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
                json=payload if payload is not None else None,
            )
        data = response.json() if response.content else {}
    except (httpx.HTTPError, ValueError):
        logger.exception("Casino provider API request failed: %s", path)
        raise HTTPException(502, "Casino provider is temporarily unavailable.")

    if response.status_code == 401:
        global _casino_provider_access_token, _casino_provider_token_expires
        _casino_provider_access_token = None
        _casino_provider_token_expires = 0.0
        raise HTTPException(502, "Casino provider session expired. Please try again.")

    if response.status_code >= 400:
        logger.error("Casino provider returned HTTP %s for %s", response.status_code, path)
        raise HTTPException(502, "Casino provider could not complete the request.")

    if not isinstance(data, dict):
        raise HTTPException(502, "Invalid response from casino provider.")
    return data


async def _casino_provider_games():
    games = []
    cursor = None
    for _ in range(20):
        path = "/v1/games?limit=200&enabled_only=false"
        if cursor:
            from urllib.parse import quote
            path += "&cursor=" + quote(str(cursor), safe="")
        page = await _casino_provider_request("GET", path)
        rows = page.get("data", [])
        if not isinstance(rows, list):
            raise HTTPException(502, "Invalid casino game catalogue.")
        games.extend(item for item in rows if isinstance(item, dict))
        if not page.get("has_more"):
            return games
        cursor = page.get("next_cursor")
        if not cursor:
            break
    raise HTTPException(502, "Casino game catalogue pagination did not complete.")


async def _casino_ensure_pkr_currency(games):
    currencies = {
        str(currency).upper()
        for game in games
        for currency in (game.get("currencies") or [])
    }

    if not currencies:
        raise HTTPException(503, "Could not read Sandbox account currencies.")

    if "PKR" not in currencies:
        await _casino_provider_request(
            "PATCH",
            "/v1/business",
            {"currencies": sorted(currencies | {"PKR"})},
        )
        games = await _casino_provider_games()
        currencies = {
            str(currency).upper()
            for game in games
            for currency in (game.get("currencies") or [])
        }

    if "PKR" not in currencies:
        raise HTTPException(503, "PKR could not be enabled on the Sandbox account.")

    return games


@router.get("/games/provider/catalog")
async def casino_provider_catalog(authorization: str | None = Header(default=None)):
    _voice_authenticated_user(authorization)
    games = await _casino_ensure_pkr_currency(await _casino_provider_games())
    return {
        "success": True,
        "games": [
            {
                "id": str(game.get("id") or ""),
                "slug": str(game.get("slug") or ""),
                "name": str(game.get("name") or game.get("slug") or "Game"),
                "provider": str(game.get("provider") or ""),
                "category": str(game.get("category") or ""),
                "thumbnail_url": game.get("thumbnail_url"),
                "min_bet": game.get("min_bet"),
                "max_bet": game.get("max_bet"),
                "currencies": game.get("currencies") or [],
                "enabled": game.get("enabled") is True,
                "status": str(game.get("status") or ""),
            }
            for game in games
        ],
    }


@router.post("/games/provider/session")
async def casino_provider_session(
    payload: dict,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    game_id = str(payload.get("game_id") or "").strip()
    if not game_id or len(game_id) > 150:
        raise HTTPException(400, "A valid game_id is required.")

    games = await _casino_ensure_pkr_currency(await _casino_provider_games())
    game = next(
        (
            item for item in games
            if game_id in (str(item.get("id") or ""), str(item.get("slug") or ""))
            and item.get("enabled") is True
            and str(item.get("status", "")).upper() == "ACTIVE"
        ),
        None,
    )
    if game is None:
        raise HTTPException(404, "This game is not enabled for your account.")

    currencies = [str(value).upper() for value in (game.get("currencies") or [])]
    if "PKR" not in currencies:
        raise HTTPException(
            409,
            {"message": "PKR is not enabled for this provider account.", "available_currencies": currencies},
        )

    player_id = str(user["user_code"])
    player_name = str(user["display_name"] or player_id)[:40]
    session = await _casino_provider_request(
        "POST",
        "/v1/sessions",
        {
            "game_id": str(game.get("slug") or game_id),
            "player_id": player_id,
            "currency": "PKR",
            "player_name": player_name,
        },
    )

    launch_url = str(session.get("launch_url") or "")
    if not launch_url.startswith("https://games.casinoapipro.com/"):
        logger.error("Casino provider returned an unexpected launch URL host.")
        raise HTTPException(502, "Casino provider returned an invalid game launch URL.")

    return {
        "success": True,
        "launch_url": launch_url,
        "session_id": session.get("session_id"),
        "game": session.get("game") or {"slug": game.get("slug"), "name": game.get("name")},
    }


CASINO_GAMES = [
    "roulette", "blackjack", "baccarat", "dragon_tiger",
    "andar_bahar", "sic_bo", "poker", "slots", "hi_lo",
    "keno", "teen_patti", "seven_up_seven_down",
    "wheel_of_fortune", "color_prediction", "lucky_dice",
    "mini_roulette", "caribbean_stud_poker", "video_poker",
    "red_dog", "crash", "lucky_salmon",
    "lucky_double_salmon", "double_salmon_lucky",
    "delishier", "greedy_king", "greedy_star", "greedy_dayan",
]
CASINO_BET_AMOUNTS = [10000, 20000, 50000, 100000, 500000, 1000000, 10000000]
CASINO_ROUND_SECONDS = 20

CASINO_GAME_OPTIONS = {
    "roulette": [("red","Red",2,4740),("black","Black",2,4740),("green","Zero",36,270)],
    "blackjack": [("player","Player",2,4200),("dealer","Dealer",2,4900),("tie","Tie",9,900)],
    "baccarat": [("player","Player",2,4460),("banker","Banker",1.95,4580),("tie","Tie",9,960)],
    "dragon_tiger": [("dragon","Dragon",2,4850),("tiger","Tiger",2,4850),("tie","Tie",9,300)],
    "andar_bahar": [("andar","Andar",2,4900),("bahar","Bahar",2,4900)],
    "sic_bo": [("big","Big",2,4600),("small","Small",2,4600),("triple","Triple",30,100)],
    "poker": [("pair","Pair",2,4200),("two_pair","Two Pair",3,2400),("three_kind","Three of a Kind",5,1200)],
    "slots": [("two","Two Match",2,3000),("three","Three Match",8,800),("jackpot","Jackpot",25,100)],
    "hi_lo": [("higher","Higher",2,4700),("lower","Lower",2,4700),("same","Same",10,600)],
    "keno": [("one","1 Match",2,5000),("two","2 Matches",4,2500),("three","3 Matches",10,800)],
    "teen_patti": [("pair","Pair",2,4200),("sequence","Sequence",5,1500),("trail","Trail",20,200)],
    "seven_up_seven_down": [("below","Below 7",2,4160),("seven","Exactly 7",5,1670),("above","Above 7",2,4160)],
    "wheel_of_fortune": [("small","Small",2,4500),("medium","Medium",4,2500),("big","Big",8,1000)],
    "color_prediction": [("red","Red",2,4750),("green","Green",5,1000),("violet","Violet",4,1250)],
    "lucky_dice": [("odd","Odd",2,4750),("even","Even",2,4750),("six","Six",5,1670)],
    "mini_roulette": [("red","Red",2,4500),("black","Black",2,4500),("zero","Zero",18,500)],
    "caribbean_stud_poker": [("pair_plus","Pair+",2,4200),("flush_plus","Flush+",5,1000),("straight_flush","Straight Flush",25,100)],
    "video_poker": [("pair","Jacks or Better",2,2500),("two_pair","Two Pair",3,1300),("full_house","Full House",8,300)],
    "red_dog": [("spread_1","Spread 1",2,3000),("spread_2","Spread 2",3,2500),("spread_3","Spread 3+",5,1500)],
    "crash": [("x15","1.5x",1.5,6500),("x2","2x",2,4500),("x5","5x",5,1800)],
    "lucky_salmon": [("red","Red Salmon",2,4500),("blue","Blue Salmon",2,4500),("gold","Golden Salmon",8,500)],
    "lucky_double_salmon": [("red","Red Pair",3,2500),("blue","Blue Pair",3,2500),("gold","Golden Pair",12,300)],
    "double_salmon_lucky": [("red","Red Double",3,2500),("blue","Blue Double",3,2500),("gold","Golden Double",12,300)],
    "delishier": [("low","Low",2,4500),("mid","Middle",3,3000),("high","High",5,1500)],
    "greedy_king": [("king","King",3,2500),("queen","Queen",2,4000),("joker","Joker",8,500)],
    "greedy_star": [("one_star","1 Star",2,4500),("two_star","2 Stars",4,2000),("three_star","3 Stars",8,800)],
    "greedy_dayan": [("low","Low",2,4500),("middle","Middle",3,3000),("high","High",5,1500)],
}

def _casino_option(game, selection):
    return next((o for o in CASINO_GAME_OPTIONS.get(game, []) if o[0] == selection), None)




@router.get("/games/casino/catalog")
def casino_catalog():
    return {
        "success": True,
        "round_seconds": CASINO_ROUND_SECONDS,
        "bet_amounts": CASINO_BET_AMOUNTS,
        "games": [
            {
                "id": game,
                "name": game.replace("_", " ").title(),
                "options": [{"id": o[0], "label": o[1]} for o in CASINO_GAME_OPTIONS[game]],
            }
            for game in CASINO_GAMES
        ],
    }


@router.post("/games/casino/bet")
def casino_place_bet(
    payload: dict,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    user_id = int(user["id"])
    game = str(payload.get("game", "")).strip().lower()
    request_id = str(payload.get("request_id", "")).strip()
    try:
        amount = int(payload.get("amount", 0))
    except (TypeError, ValueError):
        raise HTTPException(400, "Invalid bet amount")

    if game not in CASINO_GAMES:
        raise HTTPException(400, "Unknown casino game")
    if amount not in CASINO_BET_AMOUNTS:
        raise HTTPException(400, "Bet amount is not allowed")
    if not request_id or len(request_id) > 100:
        raise HTTPException(400, "A unique request_id is required")

    selection = str(payload.get("selection", "")).strip().lower()
    if not selection:
        selection = CASINO_GAME_OPTIONS[game][0][0]
    if not _casino_option(game, selection):
        raise HTTPException(400, "Invalid selection for this game")

    db = get_connection()
    db.execute("""CREATE TABLE IF NOT EXISTS casino_bet_selections (
        request_id TEXT PRIMARY KEY,
        round_id TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        game TEXT NOT NULL,
        selection TEXT NOT NULL,
        amount INTEGER NOT NULL
    )""")
    now = int(time.time())
    try:
        db.execute("BEGIN IMMEDIATE")

        previous = db.execute(
            "SELECT round_id, amount FROM casino_bet_entries "
            "WHERE user_id = ? AND request_id = ?",
            (user_id, request_id),
        ).fetchone()
        if previous:
            round_row = db.execute(
                "SELECT * FROM casino_active_rounds WHERE round_id = ?",
                (previous["round_id"],),
            ).fetchone()
            wallet = db.execute(
                "SELECT coins FROM wallets WHERE user_id = ?", (user_id,)
            ).fetchone()
            db.commit()
            return {
                "success": True, "duplicate": True,
                "round_id": previous["round_id"],
                "bet_added": int(previous["amount"]),
                "total_bet": int(round_row["total_bet"]),
                "closes_at": int(round_row["closes_at"]),
                "coins": int(wallet["coins"]),
            }

        db.execute(
            "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)", (user_id,)
        )
        wallet = db.execute(
            "SELECT coins FROM wallets WHERE user_id = ?", (user_id,)
        ).fetchone()
        if int(wallet["coins"]) < amount:
            raise HTTPException(400, "Not enough Lovely Coins")

        active = db.execute(
            "SELECT * FROM casino_active_rounds "
            "WHERE user_id = ? AND game = ? AND status = 'open'",
            (user_id, game),
        ).fetchone()

        if active and now >= int(active["closes_at"]):
            raise HTTPException(409, "Betting closed; resolve this round first")

        if not active:
            round_id = str(uuid.uuid4())
            db.execute(
                """INSERT INTO casino_active_rounds
                   (round_id, user_id, game, total_bet, status, opened_at, closes_at)
                   VALUES (?, ?, ?, 0, 'open', ?, ?)""",
                (round_id, user_id, game, now, now + CASINO_ROUND_SECONDS),
            )
        else:
            round_id = active["round_id"]

        db.execute(
            "UPDATE wallets SET coins = coins - ? WHERE user_id = ?",
            (amount, user_id),
        )
        db.execute(
            "UPDATE casino_active_rounds SET total_bet = total_bet + ? "
            "WHERE round_id = ?",
            (amount, round_id),
        )
        db.execute(
            """INSERT INTO casino_bet_entries
               (round_id, user_id, request_id, amount)
               VALUES (?, ?, ?, ?)""",
            (round_id, user_id, request_id, amount),
        )
        db.execute(
            """INSERT INTO casino_bet_selections
               (request_id, round_id, user_id, game, selection, amount)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (request_id, round_id, user_id, game, selection, amount),
        )
        db.execute(
            """INSERT INTO transactions
               (user_id, transaction_type, amount, currency, description)
               VALUES (?, 'casino_bet', ?, 'coins', ?)""",
            (user_id, amount, f"Casino bet: {game}"),
        )
        round_row = db.execute(
            "SELECT total_bet, closes_at FROM casino_active_rounds WHERE round_id = ?",
            (round_id,),
        ).fetchone()
        new_balance = int(wallet["coins"]) - amount
        db.commit()
        return {
            "success": True, "duplicate": False,
            "round_id": round_id, "game": game,
            "bet_added": amount,
            "total_bet": int(round_row["total_bet"]),
            "closes_at": int(round_row["closes_at"]),
            "seconds_left": max(0, int(round_row["closes_at"]) - now),
            "coins": new_balance,
        }
    except HTTPException:
        db.rollback()
        raise
    except sqlite3.IntegrityError:
        db.rollback()
        raise HTTPException(409, "Bet request already processed or round conflict")
    except Exception:
        db.rollback()
        logger.exception("Casino bet failed")
        raise HTTPException(500, "Could not place casino bet")
    finally:
        db.close()


@router.post("/games/casino/resolve")
def casino_resolve_round(
    payload: dict,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    user_id = int(user["id"])
    round_id = str(payload.get("round_id", "")).strip()
    if not round_id:
        raise HTTPException(400, "round_id is required")

    db = get_connection()
    now = int(time.time())
    try:
        db.execute("BEGIN IMMEDIATE")
        row = db.execute(
            "SELECT * FROM casino_active_rounds WHERE round_id = ? AND user_id = ?",
            (round_id, user_id),
        ).fetchone()
        if not row:
            raise HTTPException(404, "Round not found")

        if row["status"] == "resolved":
            wallet = db.execute(
                "SELECT coins FROM wallets WHERE user_id = ?", (user_id,)
            ).fetchone()
            db.commit()
            return {
                "success": True, "resolved": True, "duplicate": True,
                "round_id": round_id, "outcome": json.loads(row["outcome_json"]),
                "total_bet": int(row["total_bet"]),
                "payout": int(row["payout"]), "coins": int(wallet["coins"]),
            }

        seconds_left = int(row["closes_at"]) - now
        if seconds_left > 0:
            db.commit()
            return {
                "success": True, "resolved": False,
                "seconds_left": seconds_left, "round_id": round_id,
            }

        bets = db.execute(
            """SELECT selection, amount FROM casino_bet_selections
               WHERE round_id = ? AND user_id = ? ORDER BY rowid""",
            (round_id, user_id),
        ).fetchall()
        if not bets:
            raise HTTPException(409, "Round has no saved selections")

        bet_results = []
        payout = 0
        for bet in bets:
            option = _casino_option(row["game"], bet["selection"])
            if option is None:
                raise HTTPException(409, "Invalid saved game selection")
            selection, label, multiplier, chance = option
            won = secrets.randbelow(10000) < chance
            bet_payout = int(int(bet["amount"]) * multiplier) if won else 0
            payout += bet_payout
            bet_results.append({
                "selection": selection,
                "label": label,
                "result": "win" if won else "loss",
                "multiplier": multiplier if won else 0,
                "bet": int(bet["amount"]),
                "payout": bet_payout,
            })

        total_bet = int(row["total_bet"])
        outcome = {
            "label": "Round complete",
            "bets": bet_results,
            "total_bet": total_bet,
            "payout": payout,
        }

        if payout:
            db.execute(
                "UPDATE wallets SET coins = coins + ? WHERE user_id = ?",
                (payout, user_id),
            )
            db.execute(
                """INSERT INTO transactions
                   (user_id, transaction_type, amount, currency, description)
                   VALUES (?, 'casino_win', ?, 'coins', ?)""",
                (user_id, payout, f"Casino payout: {row['game']}"),
            )

        db.execute(
            """UPDATE casino_active_rounds
               SET status = 'resolved', outcome_json = ?, payout = ?, resolved_at = ?
               WHERE round_id = ? AND status = 'open'""",
            (json.dumps(outcome), payout, now, round_id),
        )
        wallet = db.execute(
            "SELECT coins FROM wallets WHERE user_id = ?", (user_id,)
        ).fetchone()
        db.commit()
        return {
            "success": True, "resolved": True, "duplicate": False,
            "round_id": round_id, "game": row["game"],
            "total_bet": total_bet, "payout": payout,
            "net": payout - total_bet, "outcome": outcome,
            "coins": int(wallet["coins"]),
        }
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        logger.exception("Casino round resolution failed")
        raise HTTPException(500, "Could not resolve casino round")
    finally:
        db.close()


@router.get("/games/casino/round")
def casino_current_round(
    game: str,
    authorization: str | None = Header(default=None),
):
    user = _voice_authenticated_user(authorization)
    game = game.strip().lower()
    if game not in CASINO_GAMES:
        raise HTTPException(400, "Unknown casino game")
    db = get_connection()
    try:
        row = db.execute(
            """SELECT round_id, game, total_bet, status, opened_at, closes_at,
                      outcome_json, payout
               FROM casino_active_rounds
               WHERE user_id = ? AND game = ?
               ORDER BY opened_at DESC LIMIT 1""",
            (int(user["id"]), game),
        ).fetchone()
        if not row:
            return {"success": True, "round": None}
        result = dict(row)
        result["seconds_left"] = max(0, int(result["closes_at"]) - int(time.time()))
        result["outcome"] = json.loads(result.pop("outcome_json"))
        return {"success": True, "round": result}
    finally:
        db.close()


# Casino API Pro Sandbox wallet callbacks.
# Provider PKR amounts are converted to Lovely Coins at 1 PKR = 10,000 coins.

def _casino_error(status: int, code: str):
    return JSONResponse(status_code=status, content={"error_code": code})


async def _casino_read_callback(request: Request):
    secret = os.environ.get("CASINO_WALLET_HMAC_SECRET", "").strip()
    if not secret:
        return None, _casino_error(503, "wallet_not_configured")

    timestamp = request.headers.get("x-timestamp", "").strip()
    signature = request.headers.get("x-signature", "").strip().lower()
    if not timestamp.isdigit() or not signature:
        return None, _casino_error(401, "invalid_signature")

    if abs(int(time.time()) - int(timestamp)) > 300:
        return None, _casino_error(401, "expired_signature")

    raw = await request.body()
    signed = timestamp.encode() + b"." + raw
    expected = hmac.new(secret.encode(), signed, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature):
        return None, _casino_error(401, "invalid_signature")

    try:
        data = json.loads(raw)
        if not isinstance(data, dict):
            raise ValueError("JSON object required")
    except (ValueError, UnicodeDecodeError):
        return None, _casino_error(400, "invalid_request")

    if str(data.get("currency") or "").upper() != "PKR":
        return None, _casino_error(422, "currency_mismatch")

    player_id = str(data.get("playerId") or "").strip()
    if not player_id:
        return None, _casino_error(400, "invalid_request")

    return (data, player_id), None


def _casino_amount_to_coins(value):
    if not isinstance(value, (str, int, Decimal)) or isinstance(value, bool):
        raise ValueError("Invalid amount")
    raw = str(value).strip()
    if not re.fullmatch(r"(?:0|[1-9][0-9]*)(?:\.[0-9]{1,2})?", raw):
        raise ValueError("Invalid amount")
    amount = Decimal(raw)
    if not amount.is_finite() or amount <= 0:
        raise ValueError("Invalid amount")
    coins = amount * Decimal(10000)
    if coins != coins.to_integral_value():
        raise ValueError("Invalid amount")
    return int(coins)


def _casino_balance_text(coins: int):
    return format(Decimal(coins) / Decimal(10000), ".2f")


@router.post("/casino/wallet/balance")
async def casino_wallet_balance(request: Request):
    parsed, error = await _casino_read_callback(request)
    if error:
        return error
    data, player_id = parsed

    db = get_connection()
    try:
        user = db.execute(
            "SELECT id FROM users WHERE user_code = ?", (player_id,)
        ).fetchone()
        if user is None:
            return _casino_error(403, "player_not_found")

        wallet = db.execute(
            "SELECT coins FROM wallets WHERE user_id = ?", (int(user["id"]),)
        ).fetchone()
        coins = int(wallet["coins"]) if wallet else 0
        return {
            "balance": _casino_balance_text(coins),
            "currency": "PKR",
            "reference": "lovelysky-balance",
        }
    finally:
        db.close()


async def _casino_move_wallet(request: Request, action: str):
    parsed, error = await _casino_read_callback(request)
    if error:
        return error
    data, player_id = parsed

    transaction_id = str(data.get("transactionId") or "").strip()
    reference_id = str(data.get("referenceTransactionId") or "").strip() or None
    if not transaction_id or len(transaction_id) > 200:
        return _casino_error(400, "invalid_request")

    supplied_amount = data.get("amount")
    try:
        if action in ("debit", "credit", "refund") and supplied_amount is None:
            raise ValueError("Amount required")
        requested_coins = (
            _casino_amount_to_coins(supplied_amount)
            if supplied_amount is not None else None
        )
    except (ValueError, InvalidOperation):
        return _casino_error(400, "invalid_request")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")

        user = db.execute(
            "SELECT id FROM users WHERE user_code = ?", (player_id,)
        ).fetchone()
        if user is None:
            db.rollback()
            return _casino_error(403, "player_not_found")
        user_id = int(user["id"])

        # Provider retries must never move the same transaction twice.
        previous = db.execute(
            "SELECT * FROM casino_wallet_transactions WHERE transaction_id = ?",
            (transaction_id,),
        ).fetchone()
        if previous:
            same = (
                int(previous["user_id"]) == user_id
                and previous["player_id"] == player_id
                and previous["action"] == action
                and (
                    requested_coins is None
                    or int(previous["amount_coins"]) == requested_coins
                )
                and (
                    action not in ("refund", "rollback")
                    or previous["reference_transaction_id"] == reference_id
                )
            )
            if not same:
                db.rollback()
                return _casino_error(409, "transaction_id_conflict")
            balance = int(previous["balance_after"])
            db.commit()
            return {
                "balance": _casino_balance_text(balance),
                "currency": "PKR",
                "reference": transaction_id,
                "duplicate": True,
            }

        db.execute(
            "INSERT OR IGNORE INTO wallets (user_id) VALUES (?)", (user_id,)
        )
        wallet = db.execute(
            "SELECT coins FROM wallets WHERE user_id = ?", (user_id,)
        ).fetchone()
        current = int(wallet["coins"])

        if action in ("refund", "rollback"):
            if not reference_id:
                db.rollback()
                return _casino_error(400, "invalid_request")

            original = db.execute(
                """SELECT * FROM casino_wallet_transactions
                   WHERE transaction_id = ? AND user_id = ?""",
                (reference_id, user_id),
            ).fetchone()
            if original is None or original["action"] not in ("debit", "credit"):
                db.rollback()
                return _casino_error(404, "transaction_not_found")

            original_coins = int(original["amount_coins"])
            if requested_coins is not None and requested_coins != original_coins:
                db.rollback()
                return _casino_error(422, "invalid_request")
            if action == "refund" and original["action"] != "debit":
                db.rollback()
                return _casino_error(422, "invalid_request")

            reversed_row = db.execute(
                """SELECT transaction_id FROM casino_wallet_transactions
                   WHERE reference_transaction_id = ?""",
                (reference_id,),
            ).fetchone()
            if reversed_row:
                db.rollback()
                return _casino_error(409, "already_reversed")

            amount_coins = original_coins
            if action == "refund" or original["action"] == "debit":
                delta = amount_coins
                transaction_type = "casino_refund" if action == "refund" else "casino_rollback"
            else:
                delta = -amount_coins
                transaction_type = "casino_rollback_debit"
        else:
            amount_coins = requested_coins
            delta = -amount_coins if action == "debit" else amount_coins
            transaction_type = "casino_bet" if action == "debit" else "casino_win"

        new_balance = current + delta
        if new_balance < 0:
            db.rollback()
            return _casino_error(402, "insufficient_funds")

        db.execute(
            "UPDATE wallets SET coins = ? WHERE user_id = ?",
            (new_balance, user_id),
        )
        db.execute(
            """INSERT INTO transactions
               (user_id, transaction_type, amount, currency, description)
               VALUES (?, ?, ?, 'coins', ?)""",
            (
                user_id,
                transaction_type,
                amount_coins,
                "Casino Sandbox " + action,
            ),
        )
        db.execute(
            """INSERT INTO casino_wallet_transactions
               (transaction_id, user_id, player_id, action, amount_coins,
                delta_coins, balance_after, reference_transaction_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                transaction_id, user_id, player_id, action, amount_coins,
                delta, new_balance, reference_id,
            ),
        )
        db.commit()
        return {
            "balance": _casino_balance_text(new_balance),
            "currency": "PKR",
            "reference": transaction_id,
            "duplicate": False,
        }
    except sqlite3.IntegrityError:
        db.rollback()
        return _casino_error(409, "already_reversed")
    except Exception:
        db.rollback()
        logger.exception("Casino Sandbox wallet callback failed")
        return _casino_error(500, "wallet_error")
    finally:
        db.close()


@router.post("/casino/wallet/debit")
async def casino_wallet_debit(request: Request):
    return await _casino_move_wallet(request, "debit")


@router.post("/casino/wallet/credit")
async def casino_wallet_credit(request: Request):
    return await _casino_move_wallet(request, "credit")


@router.post("/casino/wallet/refund")
async def casino_wallet_refund(request: Request):
    return await _casino_move_wallet(request, "refund")


@router.post("/casino/wallet/rollback")
async def casino_wallet_rollback(request: Request):
    return await _casino_move_wallet(request, "rollback")


# ============================================================
# AGENCY / BD / HOST HIERARCHY
# ============================================================

class AgencyInviteRequest(BaseModel):
    user_code: str
    invite_type: str


class AgencyInviteResponse(BaseModel):
    accept: bool


class SuperAdminRequest(BaseModel):
    user_code: str
    active: bool = True


def _agency_user(authorization):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "Bearer token required")

    claims = verify_token(authorization.split(" ", 1)[1].strip())
    user = save_google_user(claims)
    ensure_database()
    return user


def _agency_super_admin(db, uid, email):
    if str(email).lower() == OWNER_EMAIL:
        db.execute(
            """INSERT INTO super_admins(user_uid, activated_by, is_active)
               VALUES (?, ?, 1)
               ON CONFLICT(user_uid) DO UPDATE SET is_active = 1""",
            (uid, uid),
        )
        return True

    row = db.execute(
        "SELECT 1 FROM super_admins WHERE user_uid=? AND is_active=1",
        (uid,),
    ).fetchone()
    return row is not None


def _agency_role(db, uid, email):
    if _agency_super_admin(db, uid, email):
        return "super_admin"

    row = db.execute(
        "SELECT role FROM agency_memberships WHERE user_uid=?",
        (uid,),
    ).fetchone()
    return str(row["role"]) if row else "user"


def _agency_require_role(db, user, allowed):
    role = _agency_role(
        db, user["google_uid"], user["google_email"]
    )
    if role not in allowed:
        raise HTTPException(403, "You are not allowed to perform this action")
    return role


@router.get("/agency/status")
def agency_status(authorization: str | None = Header(default=None)):
    user = _agency_user(authorization)
    db = get_connection()
    try:
        role = _agency_role(db, user["google_uid"], user["google_email"])

        invites = db.execute(
            """
            SELECT i.id, i.invite_type, i.created_at,
                   u.user_code AS inviter_code,
                   u.display_name AS inviter_name
            FROM agency_invites i
            LEFT JOIN users u ON u.google_uid=i.inviter_uid
            WHERE i.invitee_uid=? AND i.status='pending'
            ORDER BY i.id DESC
            """,
            (user["google_uid"],),
        ).fetchall()

        child_role = {
            "super_admin": "bd",
            "bd": "agency",
            "agency": "host",
        }.get(role)

        direct_member_count = 0
        if child_role:
            count_row = db.execute(
                """
                SELECT COUNT(*) AS total
                FROM agency_memberships
                WHERE parent_uid=? AND role=?
                """,
                (user["google_uid"], child_role),
            ).fetchone()
            direct_member_count = int(count_row["total"] or 0)

        return {
            "success": True,
            "role": role,
            "is_super_admin": role == "super_admin",
            "direct_member_count": direct_member_count,
            "show_host_center": role in ("user", "host"),
            "show_agency_center": role == "agency",
            "show_bd_center": role == "bd",
            "show_super_admin_center": role == "super_admin",
            "pending_invites": [dict(row) for row in invites],
        }
    finally:
        db.close()


@router.get("/agency/search")
def agency_search(
    q: str,
    authorization: str | None = Header(default=None),
):
    user = _agency_user(authorization)
    q = q.strip()
    if len(q) < 1:
        raise HTTPException(400, "Enter at least 1 character")

    db = get_connection()
    try:
        role = _agency_role(db, user["google_uid"], user["google_email"])
        if role not in ("super_admin", "bd", "agency"):
            raise HTTPException(403, "Invite permission required")

        rows = db.execute(
            """
            SELECT u.google_uid, u.user_code, u.display_name
            FROM users u
            LEFT JOIN agency_memberships m ON m.user_uid=u.google_uid
            LEFT JOIN super_admins s ON s.user_uid=u.google_uid AND s.is_active=1
            WHERE (u.user_code LIKE ? OR u.display_name LIKE ?)
              AND u.google_uid != ?
              AND m.user_uid IS NULL
              AND s.user_uid IS NULL
            ORDER BY u.user_code
            LIMIT 20
            """,
            (f"%{q}%", f"%{q}%", user["google_uid"]),
        ).fetchall()

        return {
            "success": True,
            "users": [
                {
                    "user_code": r["user_code"],
                    "display_name": r["display_name"],
                }
                for r in rows
            ],
        }
    finally:
        db.close()


@router.get("/agency/hosts")
def agency_list_hosts(authorization: str | None = Header(default=None)):
    user = _agency_user(authorization)
    db = get_connection()
    try:
        role = _agency_role(db, user["google_uid"], user["google_email"])
        if role != "agency":
            raise HTTPException(403, "Only an Agency Owner can view their Hosts")

        rows = db.execute(
            """
            SELECT m.user_uid AS host_uid, u.user_code, u.display_name
            FROM agency_memberships m
            JOIN users u ON u.google_uid=m.user_uid
            WHERE m.role='host' AND m.parent_uid=?
            ORDER BY u.user_code
            """,
            (user["google_uid"],),
        ).fetchall()

        return {"success": True, "hosts": [dict(row) for row in rows]}
    finally:
        db.close()


@router.post("/agency/invites")
def agency_create_invite(
    payload: AgencyInviteRequest,
    authorization: str | None = Header(default=None),
):
    user = _agency_user(authorization)
    invite_type = payload.invite_type.strip().lower()
    if invite_type not in ("bd", "agent", "host"):
        raise HTTPException(400, "Invalid invitation type")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        role = _agency_role(db, user["google_uid"], user["google_email"])

        required = {
            "bd": "super_admin",
            "agent": "bd",
            "host": "agency",
        }[invite_type]

        owner_agency_invite = (
            invite_type == "agent"
            and role == "super_admin"
            and str(user["google_email"]).lower() == OWNER_EMAIL.lower()
        )
        if role != required and not owner_agency_invite:
            raise HTTPException(403, "You cannot send this invitation")

        target = db.execute(
            "SELECT google_uid FROM users WHERE user_code=?",
            (payload.user_code.strip(),),
        ).fetchone()

        if not target:
            raise HTTPException(404, "User ID not found")

        target_uid = str(target["google_uid"])
        if target_uid == user["google_uid"]:
            raise HTTPException(400, "You cannot invite yourself")

        if db.execute(
            "SELECT 1 FROM agency_memberships WHERE user_uid=?",
            (target_uid,),
        ).fetchone():
            raise HTTPException(409, "User already belongs to a hierarchy")

        if db.execute(
            "SELECT 1 FROM super_admins WHERE user_uid=? AND is_active=1",
            (target_uid,),
        ).fetchone():
            raise HTTPException(409, "User is already a Super Admin")

        pending = db.execute(
            """SELECT 1 FROM agency_invites
               WHERE invitee_uid=? AND status='pending'""",
            (target_uid,),
        ).fetchone()
        if pending:
            raise HTTPException(409, "User already has a pending invitation")

        cur = db.execute(
            """INSERT INTO agency_invites
               (inviter_uid, invitee_uid, invite_type)
               VALUES (?, ?, ?)""",
            (user["google_uid"], target_uid, invite_type),
        )

        db.commit()
        return {"success": True, "invite_id": cur.lastrowid}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.post("/agency/invites/{invite_id}/respond")
def agency_respond_invite(
    invite_id: int,
    payload: AgencyInviteResponse,
    authorization: str | None = Header(default=None),
):
    user = _agency_user(authorization)
    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        invite = db.execute(
            """SELECT * FROM agency_invites
               WHERE id=? AND invitee_uid=? AND status='pending'""",
            (invite_id, user["google_uid"]),
        ).fetchone()

        if not invite:
            raise HTTPException(404, "Invitation not found or already answered")

        if not payload.accept:
            db.execute(
                """UPDATE agency_invites
                   SET status='rejected', responded_at=CURRENT_TIMESTAMP
                   WHERE id=?""",
                (invite_id,),
            )
            db.commit()
            return {"success": True, "status": "rejected"}

        inviter_uid = str(invite["inviter_uid"])
        invite_type = str(invite["invite_type"])

        inviter = db.execute(
            "SELECT google_email FROM users WHERE google_uid=?",
            (inviter_uid,),
        ).fetchone()
        if not inviter:
            raise HTTPException(409, "Inviter account no longer exists")

        inviter_role = _agency_role(
            db, inviter_uid, inviter["google_email"]
        )
        required = {
            "bd": "super_admin",
            "agent": "bd",
            "host": "agency",
        }[invite_type]

        owner_agency_invite = (
            invite_type == "agent"
            and inviter_role == "super_admin"
            and str(inviter["google_email"]).lower() == OWNER_EMAIL.lower()
        )
        if inviter_role != required and not owner_agency_invite:
            raise HTTPException(409, "Inviter no longer has permission")

        if db.execute(
            "SELECT 1 FROM agency_memberships WHERE user_uid=?",
            (user["google_uid"],),
        ).fetchone():
            raise HTTPException(409, "You already belong to a hierarchy")

        new_role = {
            "bd": "bd",
            "agent": "agency",
            "host": "host",
        }[invite_type]

        db.execute(
            """INSERT INTO agency_memberships(user_uid, role, parent_uid)
               VALUES (?, ?, ?)""",
            (user["google_uid"], new_role, inviter_uid),
        )
        db.execute(
            """UPDATE agency_invites
               SET status='accepted', responded_at=CURRENT_TIMESTAMP
               WHERE id=?""",
            (invite_id,),
        )
        db.commit()
        return {"success": True, "status": "accepted", "role": new_role}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.get("/agency/super-admins")
def agency_list_super_admins(authorization: str | None = Header(default=None)):
    user = _agency_user(authorization)
    if str(user["google_email"]).lower() != OWNER_EMAIL:
        raise HTTPException(403, "Only the Owner can view Super Admins")

    db = get_connection()
    try:
        _agency_role(db, user["google_uid"], user["google_email"])
        db.commit()

        rows = db.execute(
            """
            SELECT
                u.user_code,
                u.display_name,
                u.google_email,
                CASE
                    WHEN lower(u.google_email)=? THEN 1
                    ELSE COALESCE(s.is_active, 0)
                END AS is_active,
                COALESCE(s.activated_by, '') AS activated_by,
                COALESCE(s.created_at, '') AS created_at
            FROM users u
            LEFT JOIN super_admins s ON s.user_uid=u.google_uid
            WHERE s.user_uid IS NOT NULL
               OR lower(u.google_email)=?
            ORDER BY
                CASE WHEN lower(u.google_email)=? THEN 0 ELSE 1 END,
                CAST(u.user_code AS INTEGER)
            """,
            (OWNER_EMAIL, OWNER_EMAIL, OWNER_EMAIL),
        ).fetchall()

        return {
            "success": True,
            "super_admins": [dict(row) for row in rows],
        }
    finally:
        db.close()


@router.post("/agency/super-admins")
def agency_manage_super_admin(
    payload: SuperAdminRequest,
    authorization: str | None = Header(default=None),
):
    user = _agency_user(authorization)
    if str(user["google_email"]).lower() != OWNER_EMAIL:
        raise HTTPException(403, "Only the Owner can manage Super Admins")

    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        target = db.execute(
            "SELECT google_uid FROM users WHERE user_code=?",
            (payload.user_code.strip(),),
        ).fetchone()

        if not target:
            raise HTTPException(404, "User ID not found")

        target_uid = str(target["google_uid"])
        if target_uid == user["google_uid"]:
            raise HTTPException(400, "Owner Super Admin cannot be changed")

        if payload.active:
            if db.execute(
                "SELECT 1 FROM agency_memberships WHERE user_uid=?",
                (target_uid,),
            ).fetchone():
                raise HTTPException(409, "User already has an agency role")

            db.execute(
                """INSERT INTO super_admins(user_uid, activated_by, is_active)
                   VALUES (?, ?, 1)
                   ON CONFLICT(user_uid) DO UPDATE SET
                   activated_by=excluded.activated_by, is_active=1""",
                (target_uid, user["google_uid"]),
            )
        else:
            db.execute(
                "UPDATE super_admins SET is_active=0 WHERE user_uid=?",
                (target_uid,),
            )

        db.commit()
        return {"success": True, "active": payload.active}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.delete("/agency/hosts/{host_uid}")
def agency_remove_host(
    host_uid: str,
    authorization: str | None = Header(default=None),
):
    user = _agency_user(authorization)
    db = get_connection()
    try:
        db.execute("BEGIN IMMEDIATE")
        actor = db.execute(
            """SELECT role FROM agency_memberships
               WHERE user_uid=?""",
            (user["google_uid"],),
        ).fetchone()

        if not actor or actor["role"] != "agency":
            raise HTTPException(
                403, "Only an Agency Owner can remove their own Host"
            )

        result = db.execute(
            """DELETE FROM agency_memberships
               WHERE user_uid=? AND role='host' AND parent_uid=?""",
            (host_uid, user["google_uid"]),
        )

        if result.rowcount != 1:
            raise HTTPException(404, "Your Host was not found")

        db.commit()
        return {"success": True, "removed": True}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


# ============================================================
# TARGET SALARY SYSTEM - MONTHLY HIERARCHY
# Host -> Agency -> BD -> Super Admin
# ============================================================

TARGET_LADDERS = {
    "host": [(100_000, 10_000)],
    "agency": [(50_000_000, 5_000_000)],
    "bd": [
        (200_000_000, 20_000_000),
        (400_000_000, 40_000_000),
        (800_000_000, 80_000_000),
    ],
    "super_admin": [
        (500_000_000, 100_000_000),
        (1_000_000_000, 200_000_000),
    ],
}


def _target_salary_result(role, amount):
    ladder = TARGET_LADDERS.get(role, [])
    completed = [
        {"target": target, "benefit": benefit}
        for target, benefit in ladder
        if amount >= target
    ]

    completed_target = completed[-1]["target"] if completed else 0
    total_benefit = completed[-1]["benefit"] if completed else 0
    next_entries = [
        (target, benefit) for target, benefit in ladder
        if target > amount
    ]
    next_entry = next_entries[0] if next_entries else None
    next_target = next_entry[0] if next_entry else None
    target_benefit = next_entry[1] if next_entry else total_benefit
    current_level = min(len(completed) + 1, len(ladder)) if ladder else 0
    display_target = next_target if next_target is not None else (
        ladder[-1][0] if ladder else 0
    )

    return {
        "completed_target": completed_target,
        "completed_targets": completed,
        "benefit": total_benefit,
        "next_target": next_target,
        "target": display_target,
        "target_benefit": target_benefit,
        "level": current_level,
        "progress": 100 if next_target is None else min(
            100, round(amount * 100 / next_target, 2)
        ),
    }


@router.get("/agency/targets")
def agency_target_salary(
    month: str | None = None,
    parent_uid: str | None = None,
    view_role: str | None = None,
    authorization: str | None = Header(default=None),
):
    user = _agency_user(authorization)

    from datetime import datetime

    if month is None:
        month = datetime.now().strftime("%Y-%m")

    try:
        datetime.strptime(month, "%Y-%m")
    except ValueError:
        raise HTTPException(400, "Month must use YYYY-MM format")

    db = get_connection()

    try:
        role = _agency_role(
            db, user["google_uid"], user["google_email"]
        )

        if role not in ("host", "agency", "bd", "super_admin"):
            raise HTTPException(403, "Hierarchy access required")

        target_uid = str(user["google_uid"])
        target_role = role

        if view_role is not None:
            if view_role != "bd":
                raise HTTPException(400, "Invalid target view")

            if (
                role != "super_admin"
                or str(user["google_email"]).lower() != OWNER_EMAIL.lower()
            ):
                raise HTTPException(403, "Only the Owner can open the BD target view")

            if parent_uid:
                raise HTTPException(400, "A target view cannot be combined with parent_uid")

            # Separate BD calculation; Owner remains Super Admin.
            target_role = "bd"

        if parent_uid:
            # Every role can open only its own direct child.
            expected_child = {
                "super_admin": "bd",
                "bd": "agency",
                "agency": "host",
            }.get(role)

            if expected_child is None:
                raise HTTPException(403, "Further hierarchy access not allowed")

            target_uid = str(parent_uid)
            child_row = db.execute(
                """
                SELECT role, parent_uid
                FROM agency_memberships
                WHERE user_uid = ?
                """,
                (target_uid,),
            ).fetchone()

            if (
                not child_row
                or str(child_row["role"]) != expected_child
                or str(child_row["parent_uid"]) != str(user["google_uid"])
            ):
                raise HTTPException(403, "Not your direct member")

            target_role = expected_child

        diamond_rows = db.execute(
            """
            SELECT u.google_uid,
                   COALESCE(SUM(g.diamonds_credited), 0) AS diamonds
            FROM users u
            LEFT JOIN gift_transactions g
                ON g.receiver_user_id = u.id
                AND substr(g.created_at, 1, 7) = ?
            GROUP BY u.google_uid
            """,
            (month,),
        ).fetchall()

        diamond_income = {
            str(row["google_uid"]): int(row["diamonds"] or 0)
            for row in diamond_rows
        }

        membership_rows = db.execute(
            """
            SELECT user_uid, role, parent_uid
            FROM agency_memberships
            """
        ).fetchall()

        children = {}
        roles = {}

        for row in membership_rows:
            uid = str(row["user_uid"])
            parent = str(row["parent_uid"])
            member_role = str(row["role"])

            roles[uid] = member_role
            children.setdefault(parent, []).append(uid)

        user_rows = db.execute(
            """
            SELECT google_uid, user_code, display_name, profile_photo
            FROM users
            """
        ).fetchall()

        user_info = {
            str(row["google_uid"]): dict(row)
            for row in user_rows
        }

        membership_parent = {
            str(row["user_uid"]): str(row["parent_uid"])
            for row in membership_rows
        }

        # On a child page, the logged-in user is the child's parent.
        # On the user's own page, use the actual saved inviter.
        parent_profile_uid = (
            str(user["google_uid"])
            if parent_uid
            else membership_parent.get(target_uid)
        )
        parent_profile = user_info.get(parent_profile_uid) if parent_profile_uid else None

        cache = {}

        def calculate(uid, current_role=None):
            if uid in cache:
                return cache[uid]

            current_role = current_role or roles.get(uid)

            if current_role is None:
                current_role = _agency_role(
                    db,
                    uid,
                    user_info.get(uid, {}).get("google_email", ""),
                )

            if current_role == "host":
                amount = diamond_income.get(uid, 0)

            elif current_role == "agency":
                # Agency owner is also a host in their own agency.
                agency_host_diamonds = diamond_income.get(uid, 0)
                agency_host_diamonds += sum(
                    diamond_income.get(child, 0)
                    for child in children.get(uid, [])
                    if roles.get(child) == "host"
                )
                amount = agency_host_diamonds * 10 // 100

            elif current_role == "bd":
                amount = sum(
                    calculate(child, "agency")["benefit"]
                    for child in children.get(uid, [])
                    if roles.get(child) == "agency"
                )

            elif current_role == "super_admin":
                amount = sum(
                    calculate(child, "bd")["benefit"]
                    for child in children.get(uid, [])
                    if roles.get(child) == "bd"
                )

            else:
                amount = 0

            result = _target_salary_result(current_role, int(amount))
            result["role"] = current_role
            result["income"] = int(amount)

            if current_role == "host":
                result["diamonds"] = diamond_income.get(uid, 0)

            cache[uid] = result
            return result

        own = calculate(target_uid, target_role)

        if role == "super_admin" and parent_uid and target_role == "bd":
            own = {
                "role": "bd",
                "benefit": int(own.get("benefit", 0)),
            }

        child_role = None if parent_uid else {
            "super_admin": "bd",
            "bd": "agency",
            "agency": "host",
        }.get(target_role)

        members = []

        if child_role:
            for child_uid in children.get(target_uid, []):
                if roles.get(child_uid) != child_role:
                    continue

                info = user_info.get(child_uid, {})
                summary = calculate(child_uid, child_role)

                if target_role == "super_admin":
                    # Super Admin sees only BD identity and salary/benefit.
                    members.append({
                        "uid": child_uid,
                        "user_code": info.get("user_code", ""),
                        "display_name": info.get("display_name", ""),
                        "profile_photo": info.get("profile_photo", ""),
                        "role": "bd",
                        "benefit": int(summary.get("benefit", 0)),
                    })
                else:
                    members.append({
                        "uid": child_uid,
                        "user_code": info.get("user_code", ""),
                        "display_name": info.get("display_name", ""),
                        "profile_photo": info.get("profile_photo", ""),
                        **summary,
                    })

        members.sort(
            key=lambda item: item.get("benefit", 0),
            reverse=True,
        )

        joined_at_row = db.execute(
            "SELECT created_at FROM users WHERE google_uid = ?",
            (target_uid,),
        ).fetchone()

        return {
            "success": True,
            "month": month,
            "joined_at": joined_at_row["created_at"] if joined_at_row else None,
            "role": target_role,
            "view_uid": target_uid,
            "parent": ({
                "uid": parent_profile.get("google_uid", ""),
                "user_code": parent_profile.get("user_code", ""),
                "display_name": parent_profile.get("display_name", ""),
                "profile_photo": parent_profile.get("profile_photo", ""),
            } if parent_profile else None),
            "own": own,
            "members": members,
            "member_count": len(members),
            "all_targets_benefit": sum(
                item.get("benefit", 0) for item in members
            ),
        }

    finally:
        db.close()
