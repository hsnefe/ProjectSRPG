"""§5.1 C1 - the position/role catalog a new career picks from.

Before this file positions lived as two hand-synced literal tuples (
domain/onboarding.py's _VALID_POSITIONS and api/routers/careers.py's inline
list) and roles didn't exist at all. Both now derive from ROLES below, so
adding a role is a one-line data edit and the two call sites can't drift.

Kaleci is deliberately absent: it has no roles in v1 and a position with no
selectable role can't produce a valid career, so it isn't offered at all.
Re-enabling it is purely additive — append its roles here and it reappears
in POSITIONS, /careers/options and the validators without further changes.

`attributes` is a 2-slot tuple of attribute_key, and the same key may appear
twice: a role that specialises hard in one skill (Stoper, Regista, Fırsatçı
Forvet) spends both slots on it and so gets 2 x ROLE_BONUS_PER_SLOT there
instead of spreading the bonus. Only the four "saha skill" keys
(shooting/passing/dribbling/tackling) may appear — see
worlddata/attributes.ROLE_SKILL_KEYS, which the assert at the bottom checks.
"""

DEFANS = "Defans"
ORTA_SAHA = "Orta saha"
FORVET = "Forvet"

ROLES = [
    # --- Defans / DC (stoper) ------------------------------------------
    {"role_id": "stoper", "name": "Stoper", "position": DEFANS, "group": "DC",
     "attributes": ("tackling", "tackling")},
    {"role_id": "ileri_cikan_stoper", "name": "İleri Çıkan Stoper", "position": DEFANS, "group": "DC",
     "attributes": ("tackling", "dribbling")},
    {"role_id": "libero", "name": "Libero", "position": DEFANS, "group": "DC",
     "attributes": ("passing", "tackling")},

    # --- Defans / DL-DR (bek) ------------------------------------------
    {"role_id": "bek", "name": "Bek", "position": DEFANS, "group": "DL/DR",
     "attributes": ("tackling", "passing")},
    {"role_id": "kanat_bek", "name": "Kanat Bek", "position": DEFANS, "group": "DL/DR",
     "attributes": ("tackling", "dribbling")},
    {"role_id": "oyun_kuran_kanat_bek", "name": "Oyun Kuran Kanat Bek", "position": DEFANS, "group": "DL/DR",
     "attributes": ("passing", "dribbling")},
    {"role_id": "yaratici_kanat_bek", "name": "Yaratıcı Kanat Bek", "position": DEFANS, "group": "DL/DR",
     "attributes": ("dribbling", "shooting")},

    # --- Orta saha / DM ------------------------------------------------
    {"role_id": "defansif_orta_saha", "name": "Defansif Orta Saha", "position": ORTA_SAHA, "group": "DM",
     "attributes": ("tackling", "passing")},
    {"role_id": "yari_bek", "name": "Yarı Bek", "position": ORTA_SAHA, "group": "DM",
     "attributes": ("tackling", "dribbling")},
    {"role_id": "regista", "name": "Regista", "position": ORTA_SAHA, "group": "DM",
     "attributes": ("passing", "passing")},

    # --- Orta saha / MC ------------------------------------------------
    {"role_id": "merkez_orta_saha", "name": "Merkez Orta Saha", "position": ORTA_SAHA, "group": "MC",
     "attributes": ("passing", "passing")},
    {"role_id": "oyun_kurucu", "name": "Oyun Kurucu", "position": ORTA_SAHA, "group": "MC",
     "attributes": ("passing", "dribbling")},
    {"role_id": "box_to_box", "name": "Box-to-Box Orta Saha", "position": ORTA_SAHA, "group": "MC",
     "attributes": ("shooting", "dribbling")},
    {"role_id": "mezzala", "name": "Mezzala", "position": ORTA_SAHA, "group": "MC",
     "attributes": ("dribbling", "shooting")},

    # --- Orta saha / AMC -----------------------------------------------
    {"role_id": "ofansif_orta_saha", "name": "Ofansif Orta Saha", "position": ORTA_SAHA, "group": "AMC",
     "attributes": ("passing", "shooting")},
    {"role_id": "gelismis_oyun_kurucu", "name": "Gelişmiş Oyun Kurucu", "position": ORTA_SAHA, "group": "AMC",
     "attributes": ("passing", "dribbling")},
    {"role_id": "shadow_striker", "name": "Shadow Striker", "position": ORTA_SAHA, "group": "AMC",
     "attributes": ("shooting", "dribbling")},

    # --- Orta saha / kanat ---------------------------------------------
    {"role_id": "kanat", "name": "Kanat", "position": ORTA_SAHA, "group": "Kanat",
     "attributes": ("dribbling", "passing")},
    {"role_id": "ic_kanat", "name": "İç Kanat", "position": ORTA_SAHA, "group": "Kanat",
     "attributes": ("dribbling", "shooting")},

    # --- Forvet / ST ---------------------------------------------------
    {"role_id": "forvet", "name": "Forvet", "position": FORVET, "group": "ST",
     "attributes": ("shooting", "dribbling")},
    {"role_id": "hedef_adam", "name": "Hedef Adam", "position": FORVET, "group": "ST",
     "attributes": ("shooting", "passing")},
    {"role_id": "firsatci_forvet", "name": "Fırsatçı Forvet", "position": FORVET, "group": "ST",
     "attributes": ("shooting", "shooting")},
    {"role_id": "pres_yapan_forvet", "name": "Pres Yapan Forvet", "position": FORVET, "group": "ST",
     "attributes": ("tackling", "shooting")},
    {"role_id": "derine_gelen_forvet", "name": "Derine Gelen Forvet", "position": FORVET, "group": "ST",
     "attributes": ("passing", "dribbling")},
]

# Display order is the order roles are declared above, so POSITIONS follows
# the pitch from back to front without a second hand-maintained list.
POSITIONS = []
for _role in ROLES:
    if _role["position"] not in POSITIONS:
        POSITIONS.append(_role["position"])
POSITIONS = tuple(POSITIONS)

_ROLES_BY_ID = {r["role_id"]: r for r in ROLES}


def get_role(role_id: str):
    """Returns the role dict, or None if role_id is unknown."""
    return _ROLES_BY_ID.get(role_id)


def roles_for_position(position: str) -> list:
    """Every role selectable for `position`, in declaration order. Empty
    list for an unknown position — callers validate the position first."""
    return [r for r in ROLES if r["position"] == position]


def role_belongs_to_position(role_id: str, position: str) -> bool:
    role = get_role(role_id)
    return role is not None and role["position"] == position


assert len({r["role_id"] for r in ROLES}) == len(ROLES), "duplicate role_id"
assert POSITIONS == (DEFANS, ORTA_SAHA, FORVET)
assert all(len(r["attributes"]) == 2 for r in ROLES), "every role needs exactly 2 attribute slots"
