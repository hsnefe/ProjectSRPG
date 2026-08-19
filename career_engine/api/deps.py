"""FastAPI dependencies. A fresh connection per request - the shared state
is the database file itself, not a shared connection object - closed when
the request finishes either way."""
import sqlite3
from typing import Iterator

from api import config
from db.connection import get_connection


def get_db() -> Iterator[sqlite3.Connection]:
    conn = get_connection(config.DB_PATH)
    try:
        yield conn
    finally:
        conn.close()
