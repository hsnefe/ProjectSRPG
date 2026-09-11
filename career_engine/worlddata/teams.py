"""§3.3 v1 dünyası (D20) - fixed team roster, D9: names and base ratings are
constant across every career; only fixture order and each match's own
morale/confidence (an engine-side, unpersisted concept - not here) vary by
seed.

TIER1 (Süper Lig) is transcribed from the project's `takimlar.txt` — 18 real
clubs with two identity colours and a single **Güç** (power) figure each.
That file is the source of truth for tier 1; see `_POWER` below for how its
one column maps onto the schema's four ratings.

TIER2 keeps ProjectSRPG's existing eight names from league_table_screen.dart
verbatim (B-2): FK Yıldız is the user's club there, per D21's "user always
starts at the bottom tier".
"""
from worlddata.formations import FORMATION_IDS

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

# takimlar.txt renk adlarını D17'nin ham kimlik hex'ine çevirir. Tek yer:
# aynı ad iki takımda geçtiğinde ikisi de aynı tonu alır.
_COLORS = {
    "Kırmızı":  "#E30613",
    "Sarı":     "#FDB913",
    "Lacivert": "#0A2240",
    "Siyah":    "#1A1A1A",
    "Beyaz":    "#FFFFFF",
    "Bordo":    "#6E1E2C",
    "Mavi":     "#0F62B4",
    "Turuncu":  "#F26522",
    "Yeşil":    "#1E8449",
    "Mor":      "#6B2E8F",
}

# takimlar.txt, dosyadaki sırayla (güce göre azalan):
# (team_id, short_name, ad, renk 1, renk 2, güç)
_TIER1_SOURCE = [
    ("t_gal", "GAL", "Galatasaray",              "Kırmızı",  "Sarı",     95),
    ("t_fen", "FEN", "Fenerbahçe",               "Sarı",     "Lacivert", 94),
    ("t_bjk", "BJK", "Beşiktaş",                 "Siyah",    "Beyaz",    87),
    ("t_tra", "TRA", "Trabzonspor",              "Bordo",    "Mavi",     83),
    ("t_bas", "BAS", "Başakşehir",               "Turuncu",  "Lacivert", 78),
    ("t_sam", "SAM", "Samsunspor",               "Kırmızı",  "Beyaz",    76),
    ("t_goz", "GOZ", "Göztepe",                  "Kırmızı",  "Sarı",     74),
    ("t_kon", "KON", "Konyaspor",                "Yeşil",    "Beyaz",    70),
    ("t_gaz", "GAZ", "Gaziantep FK",             "Kırmızı",  "Siyah",    69),
    ("t_koc", "KOC", "Kocaelispor",              "Yeşil",    "Siyah",    68),
    ("t_riz", "RIZ", "Çaykur Rizespor",          "Yeşil",    "Mavi",     67),
    ("t_ala", "ALA", "Alanyaspor",               "Turuncu",  "Yeşil",    66),
    ("t_kas", "KAS", "Kasımpaşa",                "Lacivert", "Beyaz",    65),
    ("t_gnc", "GNC", "Gençlerbirliği",           "Kırmızı",  "Siyah",    64),
    ("t_eyp", "EYP", "Eyüpspor",                 "Mor",      "Sarı",     63),
    ("t_erz", "ERZ", "Erzurumspor",              "Mavi",     "Beyaz",    61),
    ("t_cor", "COR", "Çorum FK",                 "Kırmızı",  "Siyah",    59),
    ("t_amd", "AMD", "Amed Sportif Faaliyetler", "Yeşil",    "Sarı",     58),
]


def _mentality(index: int) -> str:
    """Sıradaki yerinden türetilir; takimlar.txt'de mentalite kolonu yok ve
    uydurmak yerine dosyanın kendi sıralamasına bağlanıyor: güçlü altı hücum,
    zayıf altı savunma, ortadaki altı dengeli oynar."""
    if index < 6:
        return "attacking"
    if index >= len(_TIER1_SOURCE) - 6:
        return "defensive"
    return "balanced"


# Mentalite başına oynanabilir şekiller. Bir takımın dizilişi için dosyada
# ayrı bir kolon yok; mentalite ise zaten var, o yüzden şekil ona bağlanıyor —
# hücum eden takım üç forvetli/çift onlu, savunan takım beş savunmalı çıkar.
# Havuz içindeki seçim sıraya göre yapılır (bkz. _formation): aynı mentalitedeki
# on sekiz takımın hepsi aynı dizilişte sahaya çıkmasın diye.
_FORMATION_POOLS = {
    "attacking": ("4-3-3-yuksek-pres", "4-3-3-duz", "3-4-3-cift10", "4-4-2-diamond-st"),
    "balanced":  ("4-2-3-1", "4-4-2-duz", "4-4-2-diamond-kanat", "3-5-2-atak"),
    "defensive": ("5-3-2-savunma", "3-5-2-savunma", "5-3-2-atak"),
}


def _formation(mentality: str, index: int) -> str:
    """Mentaliteden ve takımın kendi listesindeki sırasından türetilir —
    _mentality ile aynı gerekçe: dayanaksız veri uydurmak yerine dosyada
    hâlihazırda bulunan bir kolona bağlanır. Deterministik: aynı takım her
    kariyerde aynı dizilişi oynar (D9)."""
    pool = _FORMATION_POOLS[mentality]
    return pool[index % len(pool)]


# Şema dört rating tutar (attack/midfield/defense/goalkeeper), takimlar.txt tek
# **Güç** kolonu verir. Dördü de o değeri alır: tek sayıyı dört sayıya bölmenin
# dosyada bir dayanağı yok, dayanaksız sayı üretilmez (§3.2'nin aynı ilkesi).
# Hat farkları istendiği gün kolonu takimlar.txt kazanır, burası değil.
TIER1_TEAMS = [
    {"team_id": team_id, "name": name, "short_name": short_name,
     "attack": float(power), "midfield": float(power),
     "defense": float(power), "goalkeeper": float(power),
     "mentality": _mentality(i),
     "formation": _formation(_mentality(i), i),
     "color_primary": _COLORS[color1], "color_secondary": _COLORS[color2]}
    for i, (team_id, short_name, name, color1, color2, power) in enumerate(_TIER1_SOURCE)
]

# TIER2 elle yazıldığı ve _formation'dan önce geldiği için dizilişini burada
# alır — TIER1'in comprehension içinde aldığı değerin aynısı, aynı kuralla.
for _i, _team in enumerate(TIER2_TEAMS):
    _team["formation"] = _formation(_team["mentality"], _i)

ALL_TEAMS = TIER1_TEAMS + TIER2_TEAMS

USER_TEAM_ID = "t_ykz"

assert len(TIER1_TEAMS) == 18
assert len(TIER2_TEAMS) == 14
assert len({t["team_id"] for t in ALL_TEAMS}) == len(ALL_TEAMS), "duplicate team_id"
assert len({t["short_name"] for t in ALL_TEAMS}) == len(ALL_TEAMS), "duplicate short_name"
# Motorun Team.name sınırı (API_CONTRACT §8.1); "Amed Sportif Faaliyetler" tam 24.
assert all(len(t["name"]) <= 24 for t in ALL_TEAMS), "team name over 24 chars"
assert all(len(t["short_name"]) == 3 for t in ALL_TEAMS), "short_name must be 3 chars"
assert all(t["formation"] in FORMATION_IDS for t in ALL_TEAMS), "unknown formation id"
