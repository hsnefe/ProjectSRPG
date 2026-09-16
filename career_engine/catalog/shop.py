"""§5.6 N3 'shop' - ports shop_screen.dart's fourteen items (four
categories) verbatim: id, title, description, price, note. `category`
uses ShopCategory's own identifiers (home/personal/realEstate/investment)
so FE needs no translation layer.

D27: only the three real-estate items carry upkeep_weekly > 0 — the other
categories are one-off purchases with no ongoing cost. Amounts are
authored, not derived from price by a fixed formula; ⟦AÇIK-5⟧ still covers
whether this scale is right.

§6.6/§12.12 `daily_effects`: an owned item may raise the natural per-day
condition/energy/fame recovery the day loop applies. It is a PASSIVE map —
nobody "uses" a treadmill, owning it is the whole mechanic — which is why it
lives here and not in `effects` (that map belongs to T2 actions and fires
once). catalog/__init__.KNOWN_DAILY_EFFECT_KEYS is the authority on what may
appear here; domain/daytime.py is the only reader.

Adding, removing or re-pricing a bonus is an edit to THIS FILE ONLY: nothing
downstream names an item id, the sum is derived below and the cap lives in
api/config.py.

§12.13 `weekly_return_rate`: an `investment`-category item's weekly return as
a fraction of `price` (not `effects`/`daily_effects` — it isn't an anchor-key
map, it's a plain rate, same unvalidated-top-level-field status as
`upkeep_weekly`). Frozen into `inventory.weekly_return` at purchase time
(`api/routers/time.py::post_purchase`); domain/investments.py is the only
reader of that frozen column afterward.
"""

SHOP_ITEMS = [
    # --- home ---
    {"catalog_id": "home-tv", "title": "Akıllı TV", "category": "home",
     "description": "Oturma odasına 65 inç. Maç akşamları arkadaşları çağırmak için "
                     "yeterince büyük.",
     "price": 90, "upkeep_weekly": 0, "note": "65 inç, 4K"},
    {"catalog_id": "home-espresso", "title": "Espresso makinesi", "category": "home",
     "description": "Sabah antrenmanından önce kahve kuyruğunda beklemeye son.",
     "price": 55, "upkeep_weekly": 0, "note": "Otomatik öğütücülü",
     "daily_effects": {"energy": 3}},
    {"catalog_id": "home-console", "title": "Oyun konsolu", "category": "home",
     "description": "Boş günlerin standart eğlencesi. Takım arkadaşlarıyla online "
                     "turnuvalar için de iyi bahane.",
     "price": 70, "upkeep_weekly": 0, "note": "İki kollu"},
    {"catalog_id": "home-treadmill", "title": "Koşu bandı", "category": "home",
     "description": "Kamp dışı günlerde kondisyonu evde korumanın en kolay yolu.",
     "price": 110, "upkeep_weekly": 0, "note": "Eğimli, 20 km/s",
     "daily_effects": {"condition": 2}},

    # --- personal ---
    {"catalog_id": "personal-watch", "title": "Kol saati", "category": "personal",
     "description": "Röportajlarda ve sponsor çekimlerinde görünen tek takı.",
     "price": 85, "upkeep_weekly": 0, "note": "Çelik kasa",
     "daily_effects": {"fame:overall": 0.3}},
    {"catalog_id": "personal-boots", "title": "Krampon", "category": "personal",
     "description": "Kendi ayağına göre kalıplanmış çift. Islak zeminde fark ediyor.",
     "price": 45, "upkeep_weekly": 0, "note": "Kişiye özel kalıp"},
    {"catalog_id": "personal-suit", "title": "Takım elbise", "category": "personal",
     "description": "Deplasman yolculukları ve kulüp galaları için.",
     "price": 60, "upkeep_weekly": 0, "note": "Ismarlama"},
    {"catalog_id": "personal-headphones", "title": "Kulaklık", "category": "personal",
     "description": "Otobüs yolculuklarında dış sesi kesiyor; maç öncesi rutinin "
                     "parçası.",
     "price": 40, "upkeep_weekly": 0, "note": "Gürültü engelleyici"},

    # --- realEstate (D27: tek gerçek düzenli gider kaynağı) ---
    {"catalog_id": "estate-studio", "title": "Stüdyo daire", "category": "realEstate",
     "description": "Tesise on beş dakika. Küçük ama kendi başına yaşamak için yeterli.",
     "price": 1400, "upkeep_weekly": 4, "note": "1+0, 55 m²",
     "daily_effects": {"energy": 2}},
    {"catalog_id": "estate-flat", "title": "Şehir merkezi daire", "category": "realEstate",
     "description": "Merkezde geniş bir kat. Aile ziyaretleri için yer var.",
     "price": 3200, "upkeep_weekly": 12, "note": "3+1, 120 m²",
     "daily_effects": {"condition": 1}},
    {"catalog_id": "estate-villa", "title": "Deniz manzaralı villa", "category": "realEstate",
     "description": "Sezon arasında kaçılacak yer. Bahçesinde kendi antrenman alanı "
                     "kurulabilir.",
     "price": 9000, "upkeep_weekly": 30, "note": "Havuzlu, 380 m²",
     "daily_effects": {"condition": 1}},

    # --- investment (§12.13: weekly_return_rate, of `price`, frozen into
    # inventory.weekly_return at purchase) ---
    {"catalog_id": "invest-bond", "title": "Devlet tahvili", "category": "investment",
     "description": "Sıkıcı ama öngörülebilir. Kariyerin geri kalanı için güvenli zemin.",
     "price": 2000, "upkeep_weekly": 0, "note": "Yıllık %28 getiri",
     "weekly_return_rate": 0.28 / 52},
    {"catalog_id": "invest-gold", "title": "Altın", "category": "investment",
     "description": "Kasaya girer, unutulur. Enflasyona karşı klasik siper.",
     "price": 3000, "upkeep_weekly": 0, "note": "100 gram · Yıllık %6 getiri",
     "weekly_return_rate": 0.06 / 52},
    {"catalog_id": "invest-fund", "title": "Hisse portföyü", "category": "investment",
     "description": "Menajerin önerdiği karma fon. Dalgalı ama uzun vadede iddialı.",
     "price": 5000, "upkeep_weekly": 0, "note": "Orta risk · Yıllık %20 getiri",
     "weekly_return_rate": 0.20 / 52},
]

assert len(SHOP_ITEMS) == 14
assert len({i["catalog_id"] for i in SHOP_ITEMS}) == len(SHOP_ITEMS)

# D45 says derived values aren't stored; this one is derived at IMPORT from the
# rows above, so it can't drift from them — it's an index, not a second source.
DAILY_CONDITION_BONUS = {
    item["catalog_id"]: item["daily_effects"]["condition"]
    for item in SHOP_ITEMS
    if "condition" in item.get("daily_effects", {})
}


def daily_condition_bonus(item_ids) -> float:
    """The per-day condition bonus an inventory of `item_ids` is worth.
    Unknown ids contribute nothing: an item can be dropped from the catalog
    while an old career still has its inventory row, and a KeyError there
    would break the day loop rather than the shop."""
    return sum(DAILY_CONDITION_BONUS.get(item_id, 0) for item_id in item_ids)


# §12.12 - energy/fame:overall's own index+sum pair, same derivation and same
# "unknown id contributes nothing" shape as DAILY_CONDITION_BONUS above. Kept
# as separate dicts/functions rather than generalizing the condition one:
# three call sites in domain/daytime.py reading three named things is plainer
# than one generic "bonus_for(key, ids)" nobody else needs yet.
DAILY_ENERGY_BONUS = {
    item["catalog_id"]: item["daily_effects"]["energy"]
    for item in SHOP_ITEMS
    if "energy" in item.get("daily_effects", {})
}

DAILY_FAME_BONUS = {
    item["catalog_id"]: item["daily_effects"]["fame:overall"]
    for item in SHOP_ITEMS
    if "fame:overall" in item.get("daily_effects", {})
}


def daily_energy_bonus(item_ids) -> float:
    """The per-day energy bonus an inventory of `item_ids` is worth."""
    return sum(DAILY_ENERGY_BONUS.get(item_id, 0) for item_id in item_ids)


def daily_fame_bonus(item_ids) -> float:
    """The per-day overall-fame bonus an inventory of `item_ids` is worth."""
    return sum(DAILY_FAME_BONUS.get(item_id, 0) for item_id in item_ids)


from catalog import validate_catalog  # noqa: E402 (after data, INV-28)

validate_catalog(SHOP_ITEMS, "shop")
