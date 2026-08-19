"""Single point of SQLite connection setup. §3 - foreign keys must be ON for
every connection (cascading deletes back INV-9); row_factory lets callers
read columns by name instead of positional index."""
import sqlite3
from pathlib import Path
from typing import Union


def get_connection(db_path: Union[str, Path]) -> sqlite3.Connection:
    # check_same_thread=False: FastAPI dispatches a sync yield-dependency's
    # __enter__ (api/deps.get_db) and the endpoint body to separate
    # threadpool calls, which anyio may hand different worker threads even
    # for a single request - see api/routers/matches.py's module docstring
    # for the sibling async/sync case. Safe here because each connection is
    # single-request, never touched concurrently (api/deps.py).
    conn = sqlite3.connect(str(db_path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    _check_json1_support(conn)
    return conn


def _check_json1_support(conn: sqlite3.Connection) -> None:
    """§3.4 - relationship.traits leans on json_extract() (SQLite's JSON1
    extension, built in by default since 3.38). Fail loudly at connection
    time rather than with a cryptic error the first time a trait is read."""
    try:
        conn.execute("SELECT json_extract('{}', '$.x')")
    except sqlite3.OperationalError as exc:
        raise RuntimeError(
            "SQLite build lacks the JSON1 extension (json_extract) - "
            "required for relationship.traits (§3.4). Upgrade Python's "
            "bundled SQLite to 3.38+ or a build with JSON1 enabled."
        ) from exc
