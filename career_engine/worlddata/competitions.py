"""§3.3 v1 dünyası (D20) - Süper Lig, 1. Lig, Ulusal Kupa. D18's kind/tier/
format abstraction carries paralel ligler and uluslararası too; this file
just doesn't populate them yet (they're not in scope for v1)."""
from worlddata.teams import TIER1_TEAMS, TIER2_TEAMS

SUPER_LIG = "c_lig1"
BIRINCI_LIG = "c_lig2"
ULUSAL_KUPA = "c_kupa"

COMPETITIONS = [
    {"competition_id": SUPER_LIG, "kind": "league", "name": "Süper Lig",
     "country": "TR", "tier": 1, "format": "double_round_robin",
     "team_count": len(TIER1_TEAMS)},
    {"competition_id": BIRINCI_LIG, "kind": "league", "name": "1. Lig",
     "country": "TR", "tier": 2, "format": "double_round_robin",
     "team_count": len(TIER2_TEAMS)},
    {"competition_id": ULUSAL_KUPA, "kind": "cup", "name": "Ulusal Kupa",
     "country": "TR", "tier": None, "format": "single_elimination",
     "team_count": len(TIER1_TEAMS) + len(TIER2_TEAMS)},
]

# D20: 1. Lig'den 2 takım çıkar, Süper Lig'den 2 takım düşer.
COMPETITION_RULES = {
    SUPER_LIG: {
        "promote_count": 0, "relegate_count": 2,
        "promotes_to_competition_id": None,
        "relegates_to_competition_id": BIRINCI_LIG,
    },
    BIRINCI_LIG: {
        "promote_count": 2, "relegate_count": 0,
        "promotes_to_competition_id": SUPER_LIG,
        "relegates_to_competition_id": None,
    },
}

# competition_entry seed for a career's first season: every team starts in
# the tier its data file places it in.
STARTING_ENTRIES = (
    [(SUPER_LIG, t["team_id"]) for t in TIER1_TEAMS]
    + [(BIRINCI_LIG, t["team_id"]) for t in TIER2_TEAMS]
)

# Ulusal Kupa fields all 32 teams — exactly TIER1 + TIER2, no separate list.
CUP_TEAM_IDS = [t["team_id"] for t in TIER1_TEAMS + TIER2_TEAMS]
