"""Tunable constants for the API layer. Mirrors match_engine/api/config.py's
pattern: plain module-level constants, environment overrides via os.environ."""
import os
from pathlib import Path

# §2 - career_engine listens on 8001, match_engine on 8000.
PORT = int(os.environ.get("CAREER_ENGINE_PORT", "8001"))
HOST = os.environ.get("CAREER_ENGINE_HOST", "127.0.0.1")

# D2/D10 - single SQLite file, multiple careers keyed by career_id.
# Override with CAREER_ENGINE_DB_PATH (tests point this at a temp file).
DB_PATH = Path(os.environ.get("CAREER_ENGINE_DB_PATH", str(Path(__file__).resolve().parent.parent / "career.db")))

# §5.0 - pagination defaults for list endpoints (N1, W3).
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100

# §5.2 P1 - the fixed 11-key attribute catalog (D30). Order is display order,
# not semantically meaningful; INV-21 checks membership against this set.
ATTRIBUTE_KEYS = {
    "condition":       "saha",
    "strength":        "saha",
    "flexibility":     "saha",
    "shooting":        "saha",
    "passing":         "saha",
    "dribbling":       "saha",
    "charisma":        "kişi",
    "politeness":      "kişi",
    "confidence":      "kişi",
    "intelligence":    "kişi",
    "resourcefulness": "kişi",
}

# §3.2 - condition's ceiling never drops below the engine's own floor.
CONDITION_FLOOR = 35.0
CONDITION_CEILING = 100.0

# §3.4 - five fixed relationship rows per career (no roster, D4).
RELATIONSHIP_KINDS = ("coach", "teammates", "media", "partner", "family")

# §6.5 D25/D26/D27 - weekly cadence for wage, upkeep, and bonuses.
WAGE_WEEKDAY = 0  # Monday, per date.weekday()

# §9 - money_ledger.kind values used by wallet.apply() callers.
LEDGER_KINDS = (
    "wage", "appearance_bonus", "goal_bonus",
    "purchase", "upkeep", "lifestyle", "training", "sale",
)
