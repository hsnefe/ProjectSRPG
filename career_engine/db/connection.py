"""Single point of SQLite connection setup. §3 - foreign keys must be ON for
every connection (cascading deletes back INV-9); row_factory lets callers
read columns by name instead of positional index."""
import sqlite3
from pathlib import Path
from typing import Union


def get_connection(db_path: Union[str, Path]) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn
