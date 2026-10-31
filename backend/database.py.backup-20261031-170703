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

        CREATE TABLE IF NOT EXISTS device_bindings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL UNIQUE,
            device_id TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(user_id) REFERENCES users(id)
        );
        """)
        db.execute("""
            CREATE TABLE IF NOT EXISTS voice_rooms (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                owner_uid TEXT NOT NULL,
                owner_code TEXT NOT NULL,
                name TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                is_active INTEGER NOT NULL DEFAULT 1
            )
        """)


    db.executescript("""
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

        CREATE TABLE IF NOT EXISTS voice_room_visits (
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
    """)

if __name__ == "__main__":
    initialize_database()
    print("LovelySky database tables created:", DB_PATH)
