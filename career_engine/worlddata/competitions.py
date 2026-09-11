"""§3.3 v1 dünyası (D20) - Süper Lig, 1. Lig, Ulusal Kupa. D18's kind/tier/
format abstraction carries paralel ligler and uluslararası too; this file
just doesn't populate them yet (they're not in scope for v1)."""
from worlddata.teams import TIER1_TEAMS, TIER2_TEAMS

SUPER_LIG = "c_lig1"
BIRINCI_LIG = "c_lig2"
ULUSAL_KUPA = "c_kupa"

# ⟦AÇIK-12⟧ - `international_score` decides the continental quota (§11.4).
# The scale is a placeholder: 45 buys Süper Lig two places, 5 buys 1. Lig
# none. Filling in the real numbers does not change the version (§10's rule)
# because no field or meaning moves, only the value.
COMPETITIONS = [
    {"competition_id": SUPER_LIG, "kind": "league", "name": "Süper Lig",
     "country": "TR", "tier": 1, "format": "double_round_robin",
     "team_count": len(TIER1_TEAMS), "international_score": 45},
    {"competition_id": BIRINCI_LIG, "kind": "league", "name": "1. Lig",
     "country": "TR", "tier": 2, "format": "double_round_robin",
     "team_count": len(TIER2_TEAMS), "international_score": 5},
    {"competition_id": ULUSAL_KUPA, "kind": "cup", "name": "Ulusal Kupa",
     "country": "TR", "tier": None, "format": "single_elimination",
     "team_count": len(TIER1_TEAMS) + len(TIER2_TEAMS),
     "international_score": None},
]

# §11.4's quota table. Promotions equal relegations, so a league's size never
# changes from season to season (INV-34).
CONTINENTAL_QUOTA_BANDS = (
    (80, 4),
    (60, 3),
    (40, 2),
    (20, 1),
)


def continental_slots(international_score) -> int:
    """How many of a league's teams go to the continental tournament.
    D49: v1 computes the quota and writes it down; it does not generate a
    single continental fixture. One country's 32 teams cannot make a
    European tournament, and storing the answer correctly today costs
    nothing the day the tournament arrives."""
    if international_score is None:
        return 0
    for threshold, slots in CONTINENTAL_QUOTA_BANDS:
        if international_score >= threshold:
            return slots
    return 0

# §11.4 overrides D20's two-up-two-down: **three** go up and three come
# down. The counts must match, or a league's size would drift season to
# season (INV-34); the top tier promotes nobody and the bottom tier relegates
# nobody, which is what the NULL target columns mean.
COMPETITION_RULES = {
    SUPER_LIG: {
        "promote_count": 0, "relegate_count": 3,
        "promotes_to_competition_id": None,
        "relegates_to_competition_id": BIRINCI_LIG,
    },
    BIRINCI_LIG: {
        "promote_count": 3, "relegate_count": 0,
        "promotes_to_competition_id": SUPER_LIG,
        "relegates_to_competition_id": None,
    },
}

# Ulusal Kupa fields all 32 teams — exactly TIER1 + TIER2, no separate list.
CUP_TEAM_IDS = [t["team_id"] for t in TIER1_TEAMS + TIER2_TEAMS]

# competition_entry seed for a career's first season: every team starts in
# the tier its data file places it in, AND every team enters the cup —
# competition_entry is the single source of truth for "who's in this
# competition" across every kind, not just leagues (W1's user_participates,
# W4's per-team competition lookup both rely on this being exhaustive).
STARTING_ENTRIES = (
    [(SUPER_LIG, t["team_id"]) for t in TIER1_TEAMS]
    + [(BIRINCI_LIG, t["team_id"]) for t in TIER2_TEAMS]
    + [(ULUSAL_KUPA, tid) for tid in CUP_TEAM_IDS]
)
