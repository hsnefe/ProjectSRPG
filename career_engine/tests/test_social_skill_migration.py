"""§14.1 (D79): migration 019 renames the three kişi keys in place."""
import sqlite3

from db.migrate import MIGRATIONS_DIR


def test_019_renames_old_keys_and_leaves_the_rest():
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE player_attribute (career_id TEXT, player_id TEXT, "
                 "attribute_key TEXT, value REAL, PRIMARY KEY (career_id, player_id, attribute_key))")
    old = {"charisma": 74, "politeness": 58, "confidence": 51,
           "intelligence": 63, "resourcefulness": 29, "shooting": 40}
    conn.executemany("INSERT INTO player_attribute VALUES ('c', 'p', ?, ?)", list(old.items()))

    conn.executescript((MIGRATIONS_DIR / "019_social_skill_keys.sql").read_text(encoding="utf-8"))

    got = dict(conn.execute("SELECT attribute_key, value FROM player_attribute"))
    assert got == {"charisma": 74, "empathy": 58, "courage": 51,
                   "intelligence": 63, "discipline": 29, "shooting": 40}
