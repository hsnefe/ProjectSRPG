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
RELATIONSHIP_KINDS = ("coach", "team", "media", "partner", "family")

# D4 - a career has exactly one user player; no roster, no id generation needed.
USER_PLAYER_ID = "p_user"

# C1 - new-career defaults, ported from player_state.dart's own starting
# values (_condition = 72, _money = 48200). ⟦B-1⟧ still owns whether these
# (and the starting contract's wage) are the right scale for tier 2.
STARTING_CONDITION = 72
STARTING_MONEY = 48200

# ⟦B-1⟧ v1 sözleşme ölçeği - placeholder, tier 2'ye kabaca uygun küçük
# rakamlar. FE'nin contract_screen.dart'taki sabitleri (haftalık ₺180.000)
# üst düzey bir oyuncuya ait; bu servis kullanıcıyı tier 2'de başlattığı
# için (D21) o değerleri doğrudan kullanmıyor.
STARTING_WEEKLY_WAGE = 3500
STARTING_APPEARANCE_BONUS = 500
STARTING_GOAL_BONUS = 1000
STARTING_RELEASE_CLAUSE = 250000
CONTRACT_LENGTH_DAYS = 730

# §6.5 D25/D26/D27 - weekly cadence for wage, upkeep, and bonuses.
WAGE_WEEKDAY = 0  # Monday, per date.weekday()

# §9 - money_ledger.kind values used by wallet.apply() callers. INV-19 (the
# ledger's total always equals career_state.money) only holds from t=0 if a
# career's starting balance itself arrives as a ledger entry rather than a
# bare INSERT — hence 'starting_balance' alongside the in-play kinds.
LEDGER_KINDS = (
    "starting_balance",
    "wage", "appearance_bonus", "goal_bonus",
    "purchase", "upkeep", "lifestyle", "training", "sale",
)
