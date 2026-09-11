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

# §5.2 P1 - the fixed 12-key attribute catalog (D30). Order is display order,
# not semantically meaningful; INV-21 checks membership against this set.
#
# `tackling` joined the saha family with the career-creation work: the Müdahale
# skill exam needs an attribute to land on, and none of the original six covered
# winning the ball back. It is one of the four ROLE_SKILL_KEYS a position/role
# can specialise in (worlddata/attributes.py).
ATTRIBUTE_KEYS = {
    "condition":       "saha",
    "strength":        "saha",
    "flexibility":     "saha",
    "shooting":        "saha",
    "passing":         "saha",
    "dribbling":       "saha",
    "tackling":        "saha",
    "charisma":        "kişi",
    "politeness":      "kişi",
    "confidence":      "kişi",
    "intelligence":    "kişi",
    "resourcefulness": "kişi",
}

# §3.2 - condition's ceiling never drops below the engine's own floor.
CONDITION_FLOOR = 35.0
CONDITION_CEILING = 100.0

# §3.4 - six fixed relationship rows per career (no roster, D4). 'fans' joined
# with the career-creation work: §4's starting table names Taraftarlar as its
# own tracked value, and the only other candidate (player_fame) is unbounded
# and semantically undecided (⟦AÇIK-9⟧), so it can't carry a 0-100 score.
RELATIONSHIP_KINDS = ("coach", "team", "media", "fans", "partner", "family")

# D4 - a career has exactly one user player; no roster, no id generation needed.
USER_PLAYER_ID = "p_user"

# C1 - new-career defaults, §4's starting-value table. These two are the
# whole "money and condition start here" contract; change them and every new
# career changes, no other edit needed.
#
# Condition starts AT its ceiling, and the ceiling is worlddata/attributes.py's
# `condition` attribute (INV-10 binds the daily value to it), so the two
# constants must agree — STARTING_CONDITION_ATTRIBUTE is asserted equal to this
# at import. Starting above the ceiling means the first day advanced silently
# snaps the bar down, which reads as a bug once the day loop runs. A fresh
# career is simply fully fit.
STARTING_CONDITION = 100
STARTING_MONEY = 60

# v1 sözleşme ölçeği, **Kredi (₭)** cinsinden. ⟦B-1⟧'i kapatır: eski ₺ ölçeği
# FE'nin sabitleriyle (haftalık ₺180.000) çelişiyordu ve rakamlar okunamayacak
# kadar uzundu.
#
# Ölçek düz bir bölme değil. ₺ değerlerini 1000'e bölmek ucuz uçtaki her şeyi
# (yaşam tarzı ₺150-1.200, kişi antrenmanı ₺500-1.500) 0-2 aralığına çökertip
# aralarındaki farkı siliyordu. Bunun yerine ekonomi ₭ üzerinde yeniden
# katmanlandı; **haftalık maaş çapa** ve geri kalan ona göre yerleşti — 1 ₭
# kabaca 1.000 ₺'ye denk düşer ama hiçbir yerde bu kur uygulanmaz, katalog
# rakamları elle yazıldı (D16: katalog verisi BE'nin).
#
#   maaş 40/hafta · maç primi 6 · gol primi 12 · yaşam tarzı 1-8
#   kişi antrenmanı 3-10 · dükkân 40-9.000 · haftalık gider 0/4/12/30
STARTING_WEEKLY_WAGE = 40
STARTING_APPEARANCE_BONUS = 6
STARTING_GOAL_BONUS = 12
STARTING_RELEASE_CLAUSE = 900

# D50/INV-35 - length is counted in SEASONS, and the contract always expires
# on a season boundary. The old CONTRACT_LENGTH_DAYS = 730 is retired: 730
# days from a August Saturday lands on an arbitrary Tuesday, which is
# neither of the two dates a contract is allowed to end on.
STARTING_CONTRACT_SEASONS = 2

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

# §6.6 - the ceiling on ONE day's natural recovery, base + owned-item bonus
# included (INV-41). Without it, owning enough of the shop pays a match back
# in two quiet days and condition stops being a resource the player manages,
# which is the whole point of §6.6. Sized so a fully-equipped player recovers
# a match (~30) in three days instead of seven, not in one.
MAX_CONDITION_RECOVERY_PER_DAY = 12

# §6.3 D53 - the chance that any one advanced day brings a social offer.
# Rolled before any query, the way news' TRIGGER_CHANCE is. Sized against the
# week: at 0.12 a quiet seven-day stretch between matches carries roughly a
# 60% chance of one offer, so offers are a thing that happens rather than a
# thing that happens every day — and INV-39 (at most one open at a time)
# caps the worst case regardless.
SOCIAL_OFFER_DAILY_CHANCE = 0.12

# §5.3 W5 - the widest calendar range one request may ask for. Two months
# plus a couple of days: enough that a caller paging month by month never
# hits it, small enough that "give me the whole season" can't be a single
# query. Same spirit as MAX_PAGE_SIZE, different unit.
MAX_CALENDAR_DAYS = 62

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
    "sponsorship",  # §12.7 - weekly, alongside the wage
)
