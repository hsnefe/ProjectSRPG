"""§3.3 The formation catalog every team's shape is picked from.

The shapes themselves live outside this service: they are drawn in the
`formation_creator` tool and shipped to the client as
`lib/game/formations.g.dart`. career_engine never needs a slot's coordinates
— it only names which shape a team plays, and FE resolves that name against
its own copy. So this module holds the *ids* and nothing else.

Keeping the ids here rather than as bare strings in teams.py is what makes
the assert at the bottom of that file possible: a typo'd shape is caught at
import time instead of reaching FE, which would silently fall back to its
default formation and show the wrong pitch.
"""

FORMATION_IDS = (
    "3-4-3-cift10",
    "3-5-2-atak",
    "3-5-2-savunma",
    "4-2-3-1",
    "4-3-3-duz",
    "4-3-3-yuksek-pres",
    "4-4-2-diamond-kanat",
    "4-4-2-diamond-st",
    "4-4-2-duz",
    "5-3-2-atak",
    "5-3-2-savunma",
)

# Bir takımın şekli çözülemezse düşülecek yer. FE'nin kendi varsayılanıyla
# aynı olmalı (lib/screens/pre_match_screen.dart, _kDefaultFormationId).
DEFAULT_FORMATION = "4-4-2-duz"

assert len(set(FORMATION_IDS)) == len(FORMATION_IDS), "duplicate formation id"
assert DEFAULT_FORMATION in FORMATION_IDS
