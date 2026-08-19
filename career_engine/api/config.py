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
# values (_money = 48200). ⟦B-1⟧ still owns whether these (and the starting
# contract's wage) are the right scale for tier 2.
#
# Condition starts AT its ceiling, not at player_state.dart's own literal
# 72: the ceiling is worlddata/attributes.py's condition attribute (64,
# ported from the training radar's mock data) and INV-10 binds the daily
# value to it. Starting above the ceiling meant the first day advanced —
# the first time condition.apply_delta() ran at all — silently snapped the
# bar from 72 down to 64, which reads as a bug once the day loop actually
# runs. A fresh career is simply fully fit.
STARTING_CONDITION = 64
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

# §7 - where match_engine listens, for T3's background-sim calls (E12).
MATCH_ENGINE_BASE_URL = os.environ.get("MATCH_ENGINE_BASE_URL", "http://127.0.0.1:8000")
MATCH_ENGINE_TIMEOUT_S = 30.0

# §6.2 D41 - day_budget's resource keys and their daily refill. ⟦AÇIK-5⟧
# owns the real scale; these reuse CONTRACT.md's own illustrative numbers
# (§6.2's worked example) so the day loop is runnable today. Change only
# this constant when AÇIK-5 closes — no schema or endpoint change needed.
DAY_BUDGET_DEFAULTS = {"time": 720.0, "energy": 100.0}

# §5.5 T1/§6.3 - event-day thresholds. Not pinned by CONTRACT.md beyond
# naming the event kinds; picked as reasonable defaults.
CONTRACT_EXPIRING_DAYS = 30
RELATIONSHIP_LOW_THRESHOLD = 20

# §6.3 - "atlanan her gün için doğal kondisyon toparlanması uygulanır".
# Scaled against the match cost: a match at normal effort burns roughly 30
# points (§6.6), and league rounds are 7 days apart, so 7 x 5 = 35 lets a
# quiet week roughly pay a match back. Anything the user does on top —
# sleep (+14), sauna (+16), a late night (-12) — is the margin they
# actually manage.
NATURAL_CONDITION_RECOVERY_PER_DAY = 5

# §5.5 T3 - safety cap so `to: "next_event"` can't loop forever if no
# event condition is ever met (not a documented behavior, defensive only).
MAX_ADVANCE_DAYS = 400

# §9 - money_ledger.kind values used by wallet.apply() callers. INV-19 (the
# ledger's total always equals career_state.money) only holds from t=0 if a
# career's starting balance itself arrives as a ledger entry rather than a
# bare INSERT — hence 'starting_balance' alongside the in-play kinds.
LEDGER_KINDS = (
    "starting_balance",
    "wage", "appearance_bonus", "goal_bonus",
    "purchase", "upkeep", "lifestyle", "training", "sale",
)
