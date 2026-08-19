"""Applies db/migrations/NNN_*.sql files in order, once each. This is
implementation bookkeeping only - _schema_migrations is not part of the
domain schema in CONTRACT.md §3, it just tracks which files this particular
.db has already run so re-running the app never re-applies a migration."""
import sqlite3
from pathlib import Path

MIGRATIONS_DIR = Path(__file__).resolve().parent / "migrations"


def _ensure_bookkeeping_table(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS _schema_migrations (
            filename   TEXT PRIMARY KEY,
            applied_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """
    )


def _applied_filenames(conn: sqlite3.Connection) -> set:
    rows = conn.execute("SELECT filename FROM _schema_migrations").fetchall()
    return {row["filename"] for row in rows}


def apply_migrations(conn: sqlite3.Connection, migrations_dir: Path = MIGRATIONS_DIR) -> list:
    """Runs every not-yet-applied *.sql file in migrations_dir, sorted by
    filename (the 001_, 002_... prefix is the ordering). Each file runs in
    its own transaction. Returns the list of filenames that were applied."""
    _ensure_bookkeeping_table(conn)
    already = _applied_filenames(conn)

    applied = []
    for path in sorted(migrations_dir.glob("*.sql")):
        if path.name in already:
            continue
        sql = path.read_text(encoding="utf-8")
        conn.executescript(sql)
        conn.execute(
            "INSERT INTO _schema_migrations (filename) VALUES (?)", (path.name,)
        )
        conn.commit()
        applied.append(path.name)

    return applied
