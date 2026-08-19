"""§3.3 v1 dünyası (D20) - fixed team roster, D9: names and base ratings are
constant across every career; only fixture order and each match's own
morale/confidence (an engine-side, unpersisted concept - not here) vary by
seed. Fictional club names throughout, matching match_engine's own approach
(api/teams.py's HOME_NAME_POOL/AWAY_NAME_POOL) — no real clubs.

TIER2 keeps ProjectSRPG's existing eight names from league_table_screen.dart
verbatim (B-2): FK Yıldız is the user's club there, per D21's "user always
starts at the bottom tier".
"""

# tier=2, "1. Lig" — 14 takım. Kullanıcının kulübü burada (D21).
TIER2_TEAMS = [
    {"team_id": "t_ykz", "name": "FK Yıldız",     "short_name": "YKZ",
     "attack": 63.0, "midfield": 65.0, "defense": 61.0, "goalkeeper": 64.0,
     "mentality": "balanced", "color_primary": "#1E6FD9", "color_secondary": "#FFFFFF"},
    {"team_id": "t_dnz", "name": "Deniz SK",       "short_name": "DNZ",
     "attack": 68.0, "midfield": 66.0, "defense": 65.0, "goalkeeper": 67.0,
     "mentality": "attacking", "color_primary": "#0B2E5B", "color_secondary": "#E8EAED"},
    {"team_id": "t_and", "name": "Anadolu FC",     "short_name": "AND",
     "attack": 60.0, "midfield": 64.0, "defense": 66.0, "goalkeeper": 62.0,
     "mentality": "defensive", "color_primary": "#7A1F1F", "color_secondary": "#F5A623"},
    {"team_id": "t_krt", "name": "Kartalspor",     "short_name": "KRT",
     "attack": 58.0, "midfield": 59.0, "defense": 60.0, "goalkeeper": 58.0,
     "mentality": "balanced", "color_primary": "#2B2B2B", "color_secondary": "#F5A623"},
    {"team_id": "t_bgz", "name": "Boğaz United",   "short_name": "BGZ",
     "attack": 61.0, "midfield": 62.0, "defense": 59.0, "goalkeeper": 60.0,
     "mentality": "balanced", "color_primary": "#1E6FD9", "color_secondary": "#0B2E5B"},
    {"team_id": "t_yes", "name": "Yeşilova",       "short_name": "YSV",
     "attack": 56.0, "midfield": 57.0, "defense": 58.0, "goalkeeper": 55.0,
     "mentality": "defensive", "color_primary": "#2E9E6B", "color_secondary": "#FFFFFF"},
    {"team_id": "t_sh6", "name": "Sahil 61",       "short_name": "SH6",
     "attack": 57.0, "midfield": 56.0, "defense": 61.0, "goalkeeper": 59.0,
     "mentality": "balanced", "color_primary": "#0E7C86", "color_secondary": "#E8EAED"},
    {"team_id": "t_das", "name": "Doğu AS",        "short_name": "DAS",
     "attack": 54.0, "midfield": 55.0, "defense": 56.0, "goalkeeper": 53.0,
     "mentality": "defensive", "color_primary": "#4B2E83", "color_secondary": "#F5A623"},
    {"team_id": "t_kzb", "name": "Kuzey Birlik",   "short_name": "KZB",
     "attack": 59.0, "midfield": 60.0, "defense": 57.0, "goalkeeper": 58.0,
     "mentality": "balanced", "color_primary": "#1B4332", "color_secondary": "#FFFFFF"},
    {"team_id": "t_plm", "name": "Palamut SK",     "short_name": "PLM",
     "attack": 55.0, "midfield": 54.0, "defense": 55.0, "goalkeeper": 56.0,
     "mentality": "balanced", "color_primary": "#003049", "color_secondary": "#F5A623"},
    {"team_id": "t_mes", "name": "Meşe FK",        "short_name": "MES",
     "attack": 53.0, "midfield": 52.0, "defense": 54.0, "goalkeeper": 52.0,
     "mentality": "defensive", "color_primary": "#606C38", "color_secondary": "#FEFAE0"},
    {"team_id": "t_bte", "name": "Batı Ekspres",   "short_name": "BTE",
     "attack": 60.0, "midfield": 58.0, "defense": 53.0, "goalkeeper": 55.0,
     "mentality": "attacking", "color_primary": "#9E2A2B", "color_secondary": "#E8EAED"},
    {"team_id": "t_ayd", "name": "Aydınlık SK",    "short_name": "AYD",
     "attack": 57.0, "midfield": 58.0, "defense": 56.0, "goalkeeper": 57.0,
     "mentality": "balanced", "color_primary": "#F5A623", "color_secondary": "#2B2B2B"},
    {"team_id": "t_ruz", "name": "Rüzgarspor",     "short_name": "RUZ",
     "attack": 52.0, "midfield": 53.0, "defense": 52.0, "goalkeeper": 51.0,
     "mentality": "defensive", "color_primary": "#4361EE", "color_secondary": "#FFFFFF"},
]

# tier=1, "Süper Lig" — 18 takım.
TIER1_TEAMS = [
    {"team_id": "t_bkt", "name": "Başkent FK",     "short_name": "BKT",
     "attack": 82.0, "midfield": 80.0, "defense": 78.0, "goalkeeper": 81.0,
     "mentality": "attacking", "color_primary": "#7A0C2E", "color_secondary": "#F5A623"},
    {"team_id": "t_lmn", "name": "Liman SK",       "short_name": "LMN",
     "attack": 79.0, "midfield": 77.0, "defense": 80.0, "goalkeeper": 78.0,
     "mentality": "balanced", "color_primary": "#003566", "color_secondary": "#FFFFFF"},
    {"team_id": "t_zfr", "name": "Zafer AS",       "short_name": "ZFR",
     "attack": 76.0, "midfield": 78.0, "defense": 75.0, "goalkeeper": 77.0,
     "mentality": "balanced", "color_primary": "#2B2B2B", "color_secondary": "#E8EAED"},
    {"team_id": "t_kzt", "name": "Kızıltepe SK",   "short_name": "KZT",
     "attack": 75.0, "midfield": 74.0, "defense": 76.0, "goalkeeper": 74.0,
     "mentality": "defensive", "color_primary": "#9E2A2B", "color_secondary": "#FFFFFF"},
    {"team_id": "t_mar", "name": "Marmara United", "short_name": "MAR",
     "attack": 74.0, "midfield": 75.0, "defense": 73.0, "goalkeeper": 75.0,
     "mentality": "balanced", "color_primary": "#1E6FD9", "color_secondary": "#0B2E5B"},
    {"team_id": "t_tor", "name": "Toros SK",       "short_name": "TOR",
     "attack": 73.0, "midfield": 72.0, "defense": 74.0, "goalkeeper": 73.0,
     "mentality": "balanced", "color_primary": "#606C38", "color_secondary": "#FEFAE0"},
    {"team_id": "t_krd", "name": "Karadeniz FK",   "short_name": "KRD",
     "attack": 71.0, "midfield": 73.0, "defense": 70.0, "goalkeeper": 72.0,
     "mentality": "attacking", "color_primary": "#1B4332", "color_secondary": "#F5A623"},
    {"team_id": "t_trk", "name": "Trakya Birlik",  "short_name": "TRK",
     "attack": 70.0, "midfield": 69.0, "defense": 71.0, "goalkeeper": 70.0,
     "mentality": "balanced", "color_primary": "#4B2E83", "color_secondary": "#FFFFFF"},
    {"team_id": "t_akd", "name": "Akdeniz SK",     "short_name": "AKD",
     "attack": 69.0, "midfield": 70.0, "defense": 68.0, "goalkeeper": 69.0,
     "mentality": "balanced", "color_primary": "#0E7C86", "color_secondary": "#E8EAED"},
    {"team_id": "t_ova", "name": "Ovaspor",        "short_name": "OVA",
     "attack": 68.0, "midfield": 67.0, "defense": 69.0, "goalkeeper": 68.0,
     "mentality": "defensive", "color_primary": "#606C38", "color_secondary": "#FFFFFF"},
    {"team_id": "t_frt", "name": "Fırtına FK",     "short_name": "FRT",
     "attack": 72.0, "midfield": 68.0, "defense": 65.0, "goalkeeper": 67.0,
     "mentality": "attacking", "color_primary": "#4361EE", "color_secondary": "#FFFFFF"},
    {"team_id": "t_yes2", "name": "Yeşilırmak SK", "short_name": "YSM",
     "attack": 67.0, "midfield": 66.0, "defense": 67.0, "goalkeeper": 66.0,
     "mentality": "balanced", "color_primary": "#2E9E6B", "color_secondary": "#2B2B2B"},
    {"team_id": "t_kzd", "name": "Kuzeydoğu AS",   "short_name": "KZD",
     "attack": 66.0, "midfield": 67.0, "defense": 65.0, "goalkeeper": 65.0,
     "mentality": "balanced", "color_primary": "#003049", "color_secondary": "#F5A623"},
    {"team_id": "t_shr", "name": "Sahra United",   "short_name": "SHR",
     "attack": 65.0, "midfield": 64.0, "defense": 66.0, "goalkeeper": 64.0,
     "mentality": "defensive", "color_primary": "#7A1F1F", "color_secondary": "#E8EAED"},
    {"team_id": "t_dms", "name": "Demirspor",      "short_name": "DMS",
     "attack": 64.0, "midfield": 65.0, "defense": 63.0, "goalkeeper": 63.0,
     "mentality": "balanced", "color_primary": "#2B2B2B", "color_secondary": "#FFFFFF"},
    {"team_id": "t_cnr", "name": "Çınar FK",       "short_name": "CNR",
     "attack": 63.0, "midfield": 62.0, "defense": 64.0, "goalkeeper": 62.0,
     "mentality": "balanced", "color_primary": "#1B4332", "color_secondary": "#FEFAE0"},
    {"team_id": "t_bzt", "name": "Boztepe SK",     "short_name": "BZT",
     "attack": 62.0, "midfield": 63.0, "defense": 61.0, "goalkeeper": 61.0,
     "mentality": "defensive", "color_primary": "#4B2E83", "color_secondary": "#F5A623"},
    {"team_id": "t_gnd", "name": "Gündoğdu AS",    "short_name": "GND",
     "attack": 61.0, "midfield": 60.0, "defense": 62.0, "goalkeeper": 60.0,
     "mentality": "balanced", "color_primary": "#9E2A2B", "color_secondary": "#FFFFFF"},
]

ALL_TEAMS = TIER1_TEAMS + TIER2_TEAMS

USER_TEAM_ID = "t_ykz"

assert len(TIER1_TEAMS) == 18
assert len(TIER2_TEAMS) == 14
assert len({t["team_id"] for t in ALL_TEAMS}) == len(ALL_TEAMS), "duplicate team_id"
assert len({t["short_name"] for t in ALL_TEAMS}) == len(ALL_TEAMS), "duplicate short_name"
