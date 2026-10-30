from pathlib import Path
import os
import re

DATA_ROOT = Path(
    os.environ.get(
        "LOVELYSKY_DATA_DIR",
        str(Path.home() / "storage/shared/LovelySky")
    )
)

USERS_DIR = DATA_ROOT / "Users"
BACKUPS_DIR = DATA_ROOT / "Backups"
LOGS_DIR = DATA_ROOT / "ServerLogs"

def setup_storage():
    for folder in (USERS_DIR, BACKUPS_DIR, LOGS_DIR):
        folder.mkdir(parents=True, exist_ok=True)

def user_folder(user_id: str) -> Path:
    user_id = str(user_id)

    if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", user_id):
        raise ValueError("Invalid user ID")

    folder = USERS_DIR / f"USER_{user_id}"
    folder.mkdir(parents=True, exist_ok=True)
    return folder
