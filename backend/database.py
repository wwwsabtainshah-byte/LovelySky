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

        CREATE TABLE IF NOT EXISTS voice_room_gift_diamonds (
            room_id INTEGER NOT NULL,
            user_uid TEXT NOT NULL,
            user_code TEXT NOT NULL,
            diamonds INTEGER NOT NULL DEFAULT 0 CHECK(diamonds >= 0),
            PRIMARY KEY (room_id, user_uid)
        );
        CREATE INDEX IF NOT EXISTS idx_room_gift_diamonds_user
            ON voice_room_gift_diamonds(room_id, user_code);

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

    if "seat_capacity" not in columns:
        db.execute("ALTER TABLE voice_rooms ADD COLUMN seat_capacity INTEGER NOT NULL DEFAULT 5")
    if "photo_url" not in columns:
        db.execute("ALTER TABLE voice_rooms ADD COLUMN photo_url TEXT NOT NULL DEFAULT ''")

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
    seat_number INTEGER NOT NULL CHECK (seat_number BETWEEN 1 AND 36),
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
    seat_number INTEGER NOT NULL CHECK (seat_number BETWEEN 1 AND 36),
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

        CREATE TABLE IF NOT EXISTS voice_room_chat_state (
            room_id INTEGER NOT NULL,
            user_uid TEXT NOT NULL,
            visible_from_id INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (room_id, user_uid),
            FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
        );

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

        CREATE TABLE IF NOT EXISTS luck77_shared_rounds (
            round_id TEXT PRIMARY KEY,
            status TEXT NOT NULL DEFAULT 'open'
                CHECK(status IN ('open','resolved')),
            total_bet INTEGER NOT NULL DEFAULT 0 CHECK(total_bet >= 0),
            opened_at INTEGER NOT NULL,
            closes_at INTEGER NOT NULL,
            outcome_json TEXT NOT NULL DEFAULT '{}',
            resolved_at INTEGER
        );
        CREATE INDEX IF NOT EXISTS idx_luck77_shared_status
            ON luck77_shared_rounds(status, closes_at);

        CREATE TABLE IF NOT EXISTS luck77_shared_bets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round_id TEXT NOT NULL,
            user_id INTEGER NOT NULL,
            request_id TEXT NOT NULL,
            selection TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK(amount > 0),
            payout INTEGER NOT NULL DEFAULT 0 CHECK(payout >= 0),
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, request_id),
            FOREIGN KEY(round_id) REFERENCES luck77_shared_rounds(round_id),
            FOREIGN KEY(user_id) REFERENCES users(id)
        );
        CREATE INDEX IF NOT EXISTS idx_luck77_shared_bets_round
            ON luck77_shared_bets(round_id, selection);
        CREATE INDEX IF NOT EXISTS idx_luck77_shared_bets_user
            ON luck77_shared_bets(user_id, round_id);

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


    with get_connection() as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS super_admins (
            user_uid TEXT PRIMARY KEY,
            activated_by TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS agency_memberships (
            user_uid TEXT PRIMARY KEY,
            role TEXT NOT NULL CHECK(role IN ('bd','agency','host')),
            parent_uid TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_agency_parent
            ON agency_memberships(parent_uid, role);

        CREATE TABLE IF NOT EXISTS agency_invites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inviter_uid TEXT NOT NULL,
            invitee_uid TEXT NOT NULL,
            invite_type TEXT NOT NULL CHECK(
                invite_type IN ('bd','agent','host')
            ),
            status TEXT NOT NULL DEFAULT 'pending' CHECK(
                status IN ('pending','accepted','rejected','cancelled')
            ),
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            responded_at TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_agency_invitee
            ON agency_invites(invitee_uid, status);
        """)


    # Safe profile-field migration: preserve all existing user rows.
    with get_connection() as db:
        user_columns = {
            row["name"] for row in db.execute("PRAGMA table_info(users)")
        }
        if "gender" not in user_columns:
            db.execute(
                "ALTER TABLE users ADD COLUMN gender TEXT NOT NULL DEFAULT ''"
            )
        if "bio" not in user_columns:
            db.execute(
                "ALTER TABLE users ADD COLUMN bio TEXT NOT NULL DEFAULT ''"
            )


    # VIP Wings and verified coin-purchase migration.
    with get_connection() as db:
        db.executescript("""
            CREATE TABLE IF NOT EXISTS vip_frame_ownership (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                set_number INTEGER NOT NULL CHECK(set_number IN (1, 2)),
                level INTEGER NOT NULL CHECK(level BETWEEN 1 AND 12),
                granted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                expires_at TEXT NOT NULL,
                granted_by_user_id INTEGER,
                grant_type TEXT NOT NULL DEFAULT 'qualified'
                    CHECK(grant_type IN ('qualified', 'owner_grant')),
                active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1)),
                UNIQUE(user_id, set_number, level),
                FOREIGN KEY(user_id) REFERENCES users(id),
                FOREIGN KEY(granted_by_user_id) REFERENCES users(id)
            );

            CREATE INDEX IF NOT EXISTS idx_vip_ownership_user_expiry
                ON vip_frame_ownership(user_id, active, expires_at);

            CREATE TABLE IF NOT EXISTS verified_coin_purchases (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                provider TEXT NOT NULL,
                provider_transaction_id TEXT NOT NULL,
                coins INTEGER NOT NULL CHECK(coins > 0),
                payment_amount INTEGER,
                payment_currency TEXT,
                verification_status TEXT NOT NULL DEFAULT 'pending'
                    CHECK(verification_status IN ('pending', 'verified', 'rejected')),
                purchased_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                verified_at TEXT,
                UNIQUE(provider, provider_transaction_id),
                FOREIGN KEY(user_id) REFERENCES users(id)
            );

            CREATE INDEX IF NOT EXISTS idx_verified_purchases_user_time
                ON verified_coin_purchases(user_id, verification_status, purchased_at);
        """)


    # Backpack equipment is separate from item ownership.
    with get_connection() as db:
        db.execute("""
            CREATE TABLE IF NOT EXISTS user_profile_equipment (
                user_id INTEGER PRIMARY KEY,
                vip_set_number INTEGER NOT NULL DEFAULT 0,
                vip_level INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(user_id) REFERENCES users(id)
            )
        """)


    # HARDWEAR frames: separate ownership and equipment from VIP.
    with get_connection() as db:
        db.executescript("""
            CREATE TABLE IF NOT EXISTS hardwear_frame_ownership (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                frame_code TEXT NOT NULL,
                granted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                expires_at TEXT NOT NULL,
                granted_by_user_id INTEGER,
                active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1)),
                UNIQUE(user_id, frame_code),
                FOREIGN KEY(user_id) REFERENCES users(id),
                FOREIGN KEY(granted_by_user_id) REFERENCES users(id)
            );
            CREATE INDEX IF NOT EXISTS idx_hardwear_ownership_expiry
                ON hardwear_frame_ownership(user_id, active, expires_at);
        """)
        equipment_columns = {
            row["name"]
            for row in db.execute("PRAGMA table_info(user_profile_equipment)")
        }
        if "hardwear_frame_id" not in equipment_columns:
            db.execute(
                "ALTER TABLE user_profile_equipment "
                "ADD COLUMN hardwear_frame_id TEXT NOT NULL DEFAULT ''"
            )

        if "hardwear_badge_id" not in equipment_columns:
            db.execute(
                "ALTER TABLE user_profile_equipment "
                "ADD COLUMN hardwear_badge_id TEXT NOT NULL DEFAULT ''"
            )

        db.executescript("""
            CREATE TABLE IF NOT EXISTS hardwear_badge_ownership (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                badge_code TEXT NOT NULL,
                granted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                expires_at TEXT NOT NULL,
                granted_by_user_id INTEGER,
                active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1)),
                UNIQUE(user_id, badge_code),
                FOREIGN KEY(user_id) REFERENCES users(id),
                FOREIGN KEY(granted_by_user_id) REFERENCES users(id)
            );

            CREATE INDEX IF NOT EXISTS idx_hardwear_badge_ownership_expiry
                ON hardwear_badge_ownership(user_id, active, expires_at);
        """)



    # Expand voice room locks and invites to 36 seats.
    # Existing records are preserved.
    with get_connection() as db:
        locked = db.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='voice_room_locked_seats'"
        ).fetchone()

        if locked and "BETWEEN 1 AND 36" not in (locked["sql"] or ""):
            db.execute("""
                CREATE TABLE voice_room_locked_seats_new (
                    room_id INTEGER NOT NULL,
                    seat_number INTEGER NOT NULL CHECK (seat_number BETWEEN 1 AND 36),
                    locked_by_uid TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (room_id, seat_number),
                    FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
                )
            """)
            db.execute("""
                INSERT INTO voice_room_locked_seats_new
                (room_id, seat_number, locked_by_uid, created_at)
                SELECT room_id, seat_number, locked_by_uid, created_at
                FROM voice_room_locked_seats
            """)
            db.execute("DROP TABLE voice_room_locked_seats")
            db.execute("ALTER TABLE voice_room_locked_seats_new RENAME TO voice_room_locked_seats")

        invites = db.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='voice_room_invites'"
        ).fetchone()

        if invites and "BETWEEN 1 AND 36" not in (invites["sql"] or ""):
            db.execute("""
                CREATE TABLE voice_room_invites_new (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    room_id INTEGER NOT NULL,
                    inviter_uid TEXT NOT NULL,
                    invitee_uid TEXT NOT NULL,
                    seat_number INTEGER NOT NULL CHECK (seat_number BETWEEN 1 AND 36),
                    status TEXT NOT NULL DEFAULT 'pending',
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE
                )
            """)
            db.execute("""
                INSERT INTO voice_room_invites_new
                (id, room_id, inviter_uid, invitee_uid, seat_number, status, created_at)
                SELECT id, room_id, inviter_uid, invitee_uid, seat_number, status, created_at
                FROM voice_room_invites
            """)
            db.execute("DROP TABLE voice_room_invites")
            db.execute("ALTER TABLE voice_room_invites_new RENAME TO voice_room_invites")
            db.execute("""
                CREATE INDEX IF NOT EXISTS idx_voice_invites_user
                ON voice_room_invites(room_id, invitee_uid, status)
            """)


    # Independent Lovely Sky Lucky 77 tables
    with get_connection() as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS lucky77_settings (
            id INTEGER PRIMARY KEY CHECK(id=1),
            commission_enabled INTEGER NOT NULL DEFAULT 1 CHECK(commission_enabled IN (0,1)),
            commission_rate INTEGER NOT NULL DEFAULT 20 CHECK(commission_rate BETWEEN 0 AND 100),
            available_cycle_targets_json TEXT NOT NULL DEFAULT '[500,800,1000,1200,1500,2000]',
            updated_by_user_id INTEGER,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(updated_by_user_id) REFERENCES users(id)
        );
        INSERT OR IGNORE INTO lucky77_settings(id) VALUES(1);

        CREATE TABLE IF NOT EXISTS lucky77_commission_wallet (
            id INTEGER PRIMARY KEY CHECK(id=1),
            balance INTEGER NOT NULL DEFAULT 0 CHECK(balance>=0),
            total_earned INTEGER NOT NULL DEFAULT 0 CHECK(total_earned>=0),
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        INSERT OR IGNORE INTO lucky77_commission_wallet(id) VALUES(1);

        CREATE TABLE IF NOT EXISTS lucky77_cycles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_id TEXT NOT NULL UNIQUE,
            status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','completed','cancelled')),
            target_bet_count INTEGER NOT NULL CHECK(target_bet_count>0),
            bet_count INTEGER NOT NULL DEFAULT 0,
            total_bet_amount INTEGER NOT NULL DEFAULT 0,
            commission_enabled INTEGER NOT NULL DEFAULT 1,
            commission_rate INTEGER NOT NULL DEFAULT 20,
            commission_amount INTEGER NOT NULL DEFAULT 0,
            prize_pool INTEGER NOT NULL DEFAULT 0,
            opened_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            completed_at TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_lucky77_cycles_status ON lucky77_cycles(status,id);

        CREATE TABLE IF NOT EXISTS lucky77_bets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bet_id TEXT NOT NULL UNIQUE,
            cycle_id TEXT NOT NULL,
            user_id INTEGER NOT NULL,
            request_id TEXT NOT NULL,
            selection TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK(amount>0),
            payout INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending','won','lost','refunded')),
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at TEXT NOT NULL,
            settled_at TEXT,
            UNIQUE(user_id,request_id),
            FOREIGN KEY(cycle_id) REFERENCES lucky77_cycles(cycle_id),
            FOREIGN KEY(user_id) REFERENCES users(id)
        );
        CREATE INDEX IF NOT EXISTS idx_lucky77_bets_cycle ON lucky77_bets(cycle_id,id);
        CREATE INDEX IF NOT EXISTS idx_lucky77_bets_user ON lucky77_bets(user_id,created_at);
        CREATE INDEX IF NOT EXISTS idx_lucky77_bets_expiry ON lucky77_bets(expires_at);

        CREATE TABLE IF NOT EXISTS lucky77_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            result_id TEXT NOT NULL UNIQUE,
            cycle_id TEXT NOT NULL UNIQUE,
            result TEXT NOT NULL,
            result_details_json TEXT NOT NULL DEFAULT '{}',
            total_bet_amount INTEGER NOT NULL DEFAULT 0,
            total_payout INTEGER NOT NULL DEFAULT 0,
            commission_amount INTEGER NOT NULL DEFAULT 0,
            completed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at TEXT NOT NULL,
            FOREIGN KEY(cycle_id) REFERENCES lucky77_cycles(cycle_id)
        );
        CREATE INDEX IF NOT EXISTS idx_lucky77_results_expiry ON lucky77_results(expires_at);

        CREATE TABLE IF NOT EXISTS lucky77_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id TEXT NOT NULL UNIQUE,
            cycle_id TEXT,
            bet_id TEXT,
            user_id INTEGER,
            transaction_type TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK(amount>0),
            currency TEXT NOT NULL DEFAULT 'coins',
            description TEXT NOT NULL DEFAULT '',
            details_json TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at TEXT NOT NULL,
            FOREIGN KEY(cycle_id) REFERENCES lucky77_cycles(cycle_id),
            FOREIGN KEY(bet_id) REFERENCES lucky77_bets(bet_id),
            FOREIGN KEY(user_id) REFERENCES users(id)
        );
        CREATE INDEX IF NOT EXISTS idx_lucky77_transactions_user ON lucky77_transactions(user_id,created_at);
        CREATE INDEX IF NOT EXISTS idx_lucky77_transactions_expiry ON lucky77_transactions(expires_at);
        CREATE INDEX IF NOT EXISTS idx_lucky77_transactions_cycle ON lucky77_transactions(cycle_id,id);
        CREATE TABLE IF NOT EXISTS lucky77_commission_fund_ledger (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id TEXT NOT NULL UNIQUE,
            cycle_id TEXT NOT NULL,
            bet_id TEXT NOT NULL,
            entry_type TEXT NOT NULL CHECK(entry_type IN ('borrowed','repaid')),
            amount INTEGER NOT NULL CHECK(amount>0),
            balance_after INTEGER NOT NULL CHECK(balance_after>=0),
            outstanding_after INTEGER NOT NULL CHECK(outstanding_after>=0),
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_lucky77_commission_ledger_cycle
            ON lucky77_commission_fund_ledger(cycle_id,id);

        """)

        # Safe additive migrations for Lucky 77 cycle settlement.
        cycle_columns = {
            row["name"] for row in db.execute("PRAGMA table_info(lucky77_cycles)")
        }
        for name, definition in {
            "total_payout": "INTEGER NOT NULL DEFAULT 0",
            "outcome_schedule_json": "TEXT NOT NULL DEFAULT '[]'",
        }.items():
            if name not in cycle_columns:
                db.execute(f"ALTER TABLE lucky77_cycles ADD COLUMN {name} {definition}")

        wallet_columns = {
            row["name"] for row in db.execute("PRAGMA table_info(lucky77_commission_wallet)")
        }
        for name, definition in {
            "outstanding_borrowed": "INTEGER NOT NULL DEFAULT 0 CHECK(outstanding_borrowed>=0)",
            "total_borrowed": "INTEGER NOT NULL DEFAULT 0 CHECK(total_borrowed>=0)",
            "total_repaid": "INTEGER NOT NULL DEFAULT 0 CHECK(total_repaid>=0)",
        }.items():
            if name not in wallet_columns:
                db.execute(
                    f"ALTER TABLE lucky77_commission_wallet ADD COLUMN {name} {definition}"
                )

        bet_columns = {
            row["name"] for row in db.execute("PRAGMA table_info(lucky77_bets)")
        }
        for name, definition in {
            "outcome": "TEXT",
            "multiplier": "INTEGER NOT NULL DEFAULT 0",
        }.items():
            if name not in bet_columns:
                db.execute(f"ALTER TABLE lucky77_bets ADD COLUMN {name} {definition}")


if __name__ == "__main__":
    initialize_database()
    print("LovelySky database tables created:", DB_PATH)
