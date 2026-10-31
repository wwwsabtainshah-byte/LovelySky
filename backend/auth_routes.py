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
            SELECT p.seat_number, p.user_code,
                   u.display_name, u.profile_photo
            FROM voice_room_participants AS p
            LEFT JOIN users AS u ON u.google_uid = p.user_uid
            WHERE p.room_id = ? AND p.seat_number BETWEEN 1 AND 18
            """,
            (room_id,),
        ).fetchall()

        by_seat = {row["seat_number"]: row for row in occupied}
        return {
            "success": True,
            "room_id": room_id,
            "seats": [
                {
                    "seat_number": n,
                    "user_code": by_seat[n]["user_code"] if n in by_seat else None,
                    "display_name": by_seat[n]["display_name"] if n in by_seat else None,
                    "profile_photo": by_seat[n]["profile_photo"] if n in by_seat else None,
                    "is_occupied": n in by_seat,
                    "is_mine": (
                        n in by_seat
                        and by_seat[n]["user_code"] == str(user["user_code"])
                    ),
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

        return result
    except sqlite3.Error:
        raise HTTPException(503, "Database diagnostic could not read the SQLite file")
    finally:
        if db is not None:
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
                "SELECT 1 FROM voice_room_participants WHERE room_id = ? AND user_uid = ?",
                (room_id, user["google_uid"]),
            ).fetchone()
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
            if kind == "mic_status":
                mic_on = message.get("payload")
                if not isinstance(mic_on, bool):
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
