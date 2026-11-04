import sqlite3

try:
    from backend.storage import DATA_ROOT, setup_storage
except ModuleNotFoundError:
    from storage import DATA_ROOT, setup_storage

setup_storage()
DB_PATH = DATA_ROOT / "lovely_sky.db"

def get_connection():
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def initialize_database():
    with get_connection() as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            google_uid TEXT UNIQUE,
            google_email TEXT UNIQUE,
            user_code TEXT UNIQUE,
            display_name TEXT NOT NULL DEFAULT '',
            profile_photo TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender_user_id INTEGER NOT NULL,
            receiver_user_id INTEGER NOT NULL,
            message TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(sender_user_id) REFERENCES users(id),
            FOREIGN KEY(receiver_user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS wallets (
            user_id INTEGER PRIMARY KEY,
            coins INTEGER NOT NULL DEFAULT 0 CHECK(coins >= 0),
            diamonds INTEGER NOT NULL DEFAULT 0 CHECK(diamonds >= 0),
            FOREIGN KEY(user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            transaction_type TEXT NOT NULL,
            amount INTEGER NOT NULL,
            currency TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS fruit_game_rounds (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round_id TEXT NOT NULL UNIQUE,
            user_id INTEGER NOT NULL,
            bet INTEGER NOT NULL CHECK(bet > 0),
            fruit_grid TEXT NOT NULL,
            multiplier REAL NOT NULL DEFAULT 0,
            payout INTEGER NOT NULL DEFAULT 0 CHECK(payout >= 0),
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id)
        );
        CREATE INDEX IF NOT EXISTS idx_fruit_game_user
            ON fruit_game_rounds(user_id, id);
        CREATE TABLE IF NOT EXISTS inventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            item_type TEXT NOT NULL,
            item_code TEXT NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity >= 0),
            expires_at TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id),
            UNIQUE(user_id, item_type, item_code)
        );

        CREATE TABLE IF NOT EXISTS gift_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender_user_id INTEGER NOT NULL,
            receiver_user_id INTEGER NOT NULL,
            gift_code TEXT NOT NULL,
            gift_name TEXT NOT NULL,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            coins_spent INTEGER NOT NULL CHECK(coins_spent > 0),
            diamonds_credited INTEGER NOT NULL CHECK(diamonds_credited > 0),
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(sender_user_id) REFERENCES users(id),
            FOREIGN KEY(receiver_user_id) REFERENCES users(id)
        );
        CREATE INDEX IF NOT EXISTS idx_gift_transactions_receiver
            ON gift_transactions(receiver_user_id, id);
        CREATE INDEX IF NOT EXISTS idx_gift_transactions_sender
            ON gift_transactions(sender_user_id, id);

        CREATE TABLE IF NOT EXISTS device_bindings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL UNIQUE,
            device_id TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id)
        );
        """)
        fruit_columns = {
            row["name"]
            for row in db.execute("PRAGMA table_info(fruit_game_rounds)")
        }
        if "request_id" not in fruit_columns:
            db.execute(
                "ALTER TABLE fruit_game_rounds ADD COLUMN request_id TEXT"
            )

        db.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_fruit_game_request
            ON fruit_game_rounds(user_id, request_id)
            WHERE request_id IS NOT NULL
        """)

        db.execute("""
            CREATE TABLE IF NOT EXISTS voice_rooms (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                owner_uid TEXT NOT NULL,
                owner_code TEXT NOT NULL,
                name TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                is_active INTEGER NOT NULL DEFAULT 1,
                is_official INTEGER NOT NULL DEFAULT 0
            )
        """)


    columns = {row["name"] for row in db.execute("PRAGMA table_info(voice_rooms)")}
    if "is_official" not in columns:
        db.execute("ALTER TABLE voice_rooms ADD COLUMN is_official INTEGER NOT NULL DEFAULT 0")

    official = db.execute(
        "SELECT id FROM voice_rooms WHERE owner_code = '1' ORDER BY id LIMIT 1"
    ).fetchone()
    if official:
        db.execute("UPDATE voice_rooms SET is_official = 0")
        db.execute(
            "UPDATE voice_rooms SET name = 'Pak Official Room', is_official = 1 WHERE id = ?",
            (official["id"],),
        )

    db.executescript("""
        CREATE TABLE IF NOT EXISTS voice_room_messages (
id INTEGER PRIMARY KEY AUTOINCREMENT,
room_id INTEGER NOT NULL,
sender_uid TEXT NOT NULL,
sender_code TEXT NOT NULL,
message TEXT NOT NULL,
created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
);

    CREATE INDEX IF NOT EXISTS idx_voice_room_messages_room
        ON voice_room_messages(room_id, id);

        CREATE TABLE IF NOT EXISTS voice_room_participants (
            room_id INTEGER NOT NULL,
            user_uid TEXT NOT NULL,
            user_code TEXT NOT NULL,
            joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            is_muted INTEGER NOT NULL DEFAULT 0,
            seat_number INTEGER,
            PRIMARY KEY (room_id, user_uid),
            FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS voice_room_admins (
    room_id INTEGER NOT NULL,
    user_uid TEXT NOT NULL,
    appointed_by_uid TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (room_id, user_uid),
    FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS voice_room_locked_seats (
    room_id INTEGER NOT NULL,
    seat_number INTEGER NOT NULL CHECK (seat_number BETWEEN 1 AND 18),
    locked_by_uid TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (room_id, seat_number),
    FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
);

    CREATE TABLE IF NOT EXISTS voice_room_invites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_id INTEGER NOT NULL,
    inviter_uid TEXT NOT NULL,
    invitee_uid TEXT NOT NULL,
    seat_number INTEGER NOT NULL CHECK (seat_number BETWEEN 1 AND 18),
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_voice_invites_user
ON voice_room_invites(room_id, invitee_uid, status);

CREATE TABLE IF NOT EXISTS voice_room_blocks (
    room_id INTEGER NOT NULL,
    user_uid TEXT NOT NULL,
    blocked_by_uid TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (room_id, user_uid),
    FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
);CREATE TABLE IF NOT EXISTS voice_room_visits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id INTEGER NOT NULL,
            user_uid TEXT NOT NULL,
            visited_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_voice_visits_user
            ON voice_room_visits(user_uid, visited_at);

        CREATE TABLE IF NOT EXISTS user_follows (
            follower_uid TEXT NOT NULL,
            followed_uid TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (follower_uid, followed_uid),
            CHECK (follower_uid != followed_uid)
        );

        CREATE INDEX IF NOT EXISTS idx_voice_rooms_active
            ON voice_rooms(is_active);

        CREATE TABLE IF NOT EXISTS video_rooms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            host_uid TEXT NOT NULL,
            host_code TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            cover_image TEXT NOT NULL DEFAULT '',
            is_live INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            ended_at TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_video_rooms_live
            ON video_rooms(is_live, created_at);

        CREATE TABLE IF NOT EXISTS video_room_viewers (
            room_id INTEGER NOT NULL,
            viewer_uid TEXT NOT NULL,
            joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (room_id, viewer_uid),
            FOREIGN KEY (room_id) REFERENCES video_rooms(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS video_room_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id INTEGER NOT NULL,
            sender_uid TEXT NOT NULL,
            sender_code TEXT NOT NULL,
            message TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (room_id) REFERENCES video_rooms(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_video_messages_room
            ON video_room_messages(room_id, id);
        CREATE TABLE IF NOT EXISTS video_room_visits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id INTEGER NOT NULL,
            user_uid TEXT NOT NULL,
            visited_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (room_id) REFERENCES video_rooms(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_video_visits_user
            ON video_room_visits(user_uid, visited_at);

        CREATE TABLE IF NOT EXISTS casino_wallet_transactions (
            transaction_id TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            player_id TEXT NOT NULL,
            action TEXT NOT NULL CHECK(action IN ('debit','credit','refund','rollback')),
            amount_coins INTEGER NOT NULL CHECK(amount_coins > 0),
            delta_coins INTEGER NOT NULL,
            balance_after INTEGER NOT NULL CHECK(balance_after >= 0),
            reference_transaction_id TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id)
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_casino_wallet_reversal_reference
            ON casino_wallet_transactions(reference_transaction_id)
            WHERE reference_transaction_id IS NOT NULL;

        CREATE TABLE IF NOT EXISTS casino_game_rounds (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round_id TEXT NOT NULL UNIQUE,
            user_id INTEGER NOT NULL,
            game TEXT NOT NULL,
            bet INTEGER NOT NULL CHECK(bet > 0),
            outcome_json TEXT NOT NULL,
            payout INTEGER NOT NULL DEFAULT 0 CHECK(payout >= 0),
            request_id TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id)
        );

        CREATE UNIQUE INDEX IF NOT EXISTS idx_casino_game_request
            ON casino_game_rounds(user_id, request_id);

        CREATE INDEX IF NOT EXISTS idx_casino_game_user
            ON casino_game_rounds(user_id, id);

        CREATE TABLE IF NOT EXISTS casino_active_rounds (
            round_id TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            game TEXT NOT NULL,
            total_bet INTEGER NOT NULL DEFAULT 0 CHECK(total_bet >= 0),
            status TEXT NOT NULL DEFAULT 'open'
                CHECK(status IN ('open','resolved')),
            opened_at INTEGER NOT NULL,
            closes_at INTEGER NOT NULL,
            outcome_json TEXT NOT NULL DEFAULT '{}',
            payout INTEGER NOT NULL DEFAULT 0 CHECK(payout >= 0),
            resolved_at INTEGER,
            FOREIGN KEY(user_id) REFERENCES users(id)
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_casino_one_open_round
            ON casino_active_rounds(user_id, game) WHERE status = 'open';
        CREATE INDEX IF NOT EXISTS idx_casino_round_user
            ON casino_active_rounds(user_id, opened_at);

        CREATE TABLE IF NOT EXISTS casino_bet_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round_id TEXT NOT NULL,
            user_id INTEGER NOT NULL,
            request_id TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK(amount > 0),
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, request_id),
            FOREIGN KEY(round_id) REFERENCES casino_active_rounds(round_id),
            FOREIGN KEY(user_id) REFERENCES users(id)
        );

""")

if __name__ == "__main__":
    initialize_database()
    print("LovelySky database tables created:", DB_PATH)
