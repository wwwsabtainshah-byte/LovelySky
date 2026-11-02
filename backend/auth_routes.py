import os
import json
import base64
import logging
import sqlite3
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
            SELECT
                p.user_uid,
                p.user_code,
                u.display_name,
                u.profile_photo,
                p.seat_number,
                p.is_muted
            FROM voice_room_participants AS p
            LEFT JOIN users AS u ON u.google_uid = p.user_uid
            WHERE p.room_id = ?
            ORDER BY p.joined_at ASC
            """,
            (room_id,),
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
        "SELECT owner_uid FROM voice_rooms WHERE id = ? AND is_active = 1",
        (room_id,),
    ).fetchone()
    if not room:
        raise HTTPException(404, "Voice room not found")
    if room["owner_uid"] == user_uid:
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
            SELECT p.seat_number, p.user_uid, p.user_code, p.is_muted, u.display_name, u.profile_photo
            FROM voice_room_participants AS p
            LEFT JOIN users AS u ON u.google_uid = p.user_uid
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
    if code == "1":
        raise HTTPException(400, "Owner cannot issue coins to the Owner ID")

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
        "SELECT id FROM voice_rooms WHERE id = ? AND is_active = 1",
        (room_id,),
    ).fetchone()
    if not room:
        raise HTTPException(404, "Voice room not found")
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
            message = await websocket.receive_json()
            if not isinstance(message, dict):
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
                finally:
                    db.close()

                if not target:
                    await websocket.send_json({
                        "type": "moderation_error",
                        "message": "Target member has not joined this room",
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
