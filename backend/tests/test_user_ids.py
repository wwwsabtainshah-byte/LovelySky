import sqlite3
import unittest


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


class PermanentUserIDTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.row_factory = sqlite3.Row
        self.db.execute("""
            CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                google_email TEXT UNIQUE,
                user_code TEXT UNIQUE
            )
        """)

    def tearDown(self):
        self.db.close()

    def test_first_regular_user_starts_at_1001(self):
        self.assertEqual(next_user_code(self.db), "1001")

    def test_next_user_gets_next_available_code(self):
        self.db.execute(
            "INSERT INTO users (google_email, user_code) VALUES (?, ?)",
            ("user1@example.com", "1001"),
        )
        self.assertEqual(next_user_code(self.db), "1002")

    def test_existing_codes_are_not_reused(self):
        for email, code in [
            ("a@example.com", "1001"),
            ("b@example.com", "1002"),
            ("c@example.com", "1004"),
        ]:
            self.db.execute(
                "INSERT INTO users (google_email, user_code) VALUES (?, ?)",
                (email, code),
            )
        self.assertEqual(next_user_code(self.db), "1003")

    def test_owner_code_one_does_not_change_regular_sequence(self):
        self.db.execute(
            "INSERT INTO users (google_email, user_code) VALUES (?, ?)",
            ("owner@example.com", "1"),
        )
        self.assertEqual(next_user_code(self.db), "1001")


if __name__ == "__main__":
    unittest.main(verbosity=2)
