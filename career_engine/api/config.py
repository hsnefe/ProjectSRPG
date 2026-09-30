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
    # §14 (D79): the kişi family IS the five social skills — Karizma, Empati,
    # Cesaret, Zeka, Disiplin. Only three keys changed name (politeness ->
    # empathy, confidence -> courage, resourcefulness -> discipline); the set
    # stays closed at 12 (INV-21).
    "charisma":        "kişi",
    "empathy":         "kişi",
    "courage":         "kişi",
    "intelligence":    "kişi",
    "discipline":      "kişi",
}

# §12.11 D63 - the fixed 3-key tactical-training catalog. Kept separate from
# ATTRIBUTE_KEYS rather than a 13th/14th/15th entry in it: that set is
# INV-21's closed space, tied to level()/requires, and a tactic has neither —
# folding it in would mean three dead cells no requires threshold ever reads.
TACTIC_KEYS = ("gegenpress", "pozisyonel_oyun", "derin_blok")

# §3.2 - condition's ceiling never drops below the engine's own floor.
CONDITION_FLOOR = 35.0
CONDITION_CEILING = 100.0

# §13.5 D77 - the two training families. `kişi` retired with §13: its five
# items were the only `drill: None` cards FE could not start ("Yakında"), and
# kişi attributes now grow from lifestyle, social offers, dialogue, activity
# events and owned items (D78) instead. ATTRIBUTE_KEYS' kişi family is
# untouched — what went is the training path, not the attribute.
TRAINING_FAMILIES = ("saha", "taktik")

# §13.4 D75 - a lifestyle action's chance of spawning an event when its
# catalog row doesn't name its own `event_chance`. Sized against
# SOCIAL_OFFER_DAILY_CHANCE's reasoning, one axis over: that one rolls per
# DAY, this one per ACTION, so it can be higher without the player drowning —
# a quiet day with no actions rolls nothing at all, and INV-62 caps the worst
# case at one open event regardless.
ACTIVITY_EVENT_DEFAULT_CHANCE = 0.15

# §3.4 - six fixed relationship rows per career (no roster, D4). 'fans' joined
# with the career-creation work: §4's starting table names Taraftarlar as its
# own tracked value, and the only other candidate (player_fame) is unbounded
# and semantically undecided (⟦AÇIK-9⟧), so it can't carry a 0-100 score.
RELATIONSHIP_KINDS = ("coach", "team", "media", "fans", "partner", "family")

# §13.1 D68 - which of those six belong to the CLUB rather than the career.
# These three are re-seeded from scratch on a transfer (§13.1); the other
# three (media, partner, family) survive it. The ids stay fixed either way —
# the scope lives in relationship.scope, never in the id.
CLUB_SCOPED_RELATIONSHIPS = ("coach", "team", "fans")

# §13.2 D71 - relationship.state's three values. The machine runs for
# `partner` only (INV-59); every other kind is born and stays STATE_ACTIVE.
STATE_ABSENT = "absent"
STATE_COURTING = "courting"
STATE_ACTIVE = "active"
RELATIONSHIP_STATES = (STATE_ABSENT, STATE_COURTING, STATE_ACTIVE)

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

# §14.3 D84/⟦AÇIK-20⟧ - an S/B activity done alone earns this much more skill
# than the same one done with someone (who earns the relationship instead).
# That is the whole solo-vs-partner trade; the number is a placeholder.
SOLO_SKILL_BONUS = 1.25

# §14.3 D85 - a skill can lower a risky activity's chance, but never to zero.
MIN_RISK_CHANCE = 0.05

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

# §6.3 - "atlanan her gün için doğal kondisyon toparlanması uygulanır". Since
# §14.4 (D88) that number is no longer a flat constant: it is the ACTIVE
# RESIDENCE's sleep (catalog/housing.py), so where the player lives is what
# decides how fast a match is paid back. The old flat 5 is gone; the academy
# dorm every career opens in sleeps +6, which keeps day one close to it.

# §6.6 - the ceiling on ONE day's natural recovery, residence sleep + its
# modifiers + owned-item bonus included (INV-41). Without it, owning enough of
# the shop pays a match back in two quiet days and condition stops being a
# resource the player manages, which is the whole point of §6.6. §14.4 raised
# it 12 -> 20 because the best home alone now sleeps +14; sized so a fully
# equipped player still needs two to three days for a ~30-point match, not one.
# ⟦AÇIK-21⟧ owns the number.
MAX_CONDITION_RECOVERY_PER_DAY = 20

# §14.4 D87/D90 - the home every career opens in, and the free one an eviction
# or an expired hotel stay falls back to.
STARTING_RESIDENCE = "res-dorm"
FALLBACK_RESIDENCE = "res-family"

# §14.4 D90 - how long the club's hotel room lasts after a transfer. ⟦AÇIK-21⟧
HOTEL_STAY_DAYS = 14

# §14.5 D92 - a relationship event opens at most once in this many days. The
# triggers are many and the season is long; the gap is what keeps them from
# arriving as a wall. ⟦AÇIK-5⟧
TRIGGER_EVENT_MIN_GAP_DAYS = 2

# §14.5 - the master switch for calendar and post-match triggers. True in the
# game; the test suite turns it off by default (tests/conftest.py) for the same
# reason it turns off social offers: a random event that stops the advance loop
# makes every test that walks the calendar quietly test the dice as well.
TRIGGERS_ENABLED = True

# §14.4 D89 - rent falls due on this day of the month, whatever the weekday.
RENT_DAY_OF_MONTH = 1

# §6.3 D53 - the chance that any one advanced day brings a social offer.
# Rolled before any query, the way news' TRIGGER_CHANCE is. Sized against the
# week: at 0.12 a quiet seven-day stretch between matches carries roughly a
# 60% chance of one offer, so offers are a thing that happens rather than a
# thing that happens every day — and INV-39 (at most one open at a time)
# caps the worst case regardless.
SOCIAL_OFFER_DAILY_CHANCE = 0.12

# §12.9 D59 - the chance that a day with no plan due brings TWO offers at once
# instead of one. Deliberately a quarter of the single-offer chance: two people
# inviting you to the same evening without knowing about each other is a thing
# that should happen a few times a season, not weekly. The other source of a
# conflict — two plans falling on the same day — is certain and rolls nothing.
SOCIAL_CONFLICT_DAILY_CHANCE = 0.03

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
    "refund",       # §14.2 D81 - a retired shop item paid back in full
    "rent",         # §14.4 D89 - monthly rent, hotel nights and the private chef
)
