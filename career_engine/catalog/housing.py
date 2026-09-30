"""§14.4 D87-D90, D95 - where the player can live. The design doc's 18 properties
and six home upgrades, in the project's own scale.

Three kinds of row, told apart by `kind`:

- `start`   free, always reachable (the academy dorm, the family home).
- `rent`    a lease: `rent_monthly`, paid on the 1st (D89). The hotel room is a
            lease too, but `hotel`: nightly, time-limited and never chosen -
            a transfer hands it over (D90).
- `buy`     owned outright for `price`; upgrades may be fitted (D95).
- `holiday` owned outright, but not a home: it is only visited, in the
            winter break and the summer window, with a `rest` day (D90).

`sleep` is what one night there restores. The design doc writes it on a 0-100
scale (+20 ... +45); this game's day is worth far less, so every value here is
the doc's number x 0.3, rounded (CONTRACT §14.4 D88) - the dorm's +20 becomes +6,
the rehabilitation villa's +45 becomes +14. `grade` is the doc's "karizma" 0-5: the
active home adds grade x CHARISMA_PER_GRADE to `charisma` as a passive bonus.

Two more fields shape the night itself: `noise_chance` (a roll that halves the
sleep; the dorm's roommates) and `modifiers` (flat daily adjustments, e.g. the
family home's breakfast and commute). Everything the doc lists that nothing reads
yet - injury shortening, the post-match sauna, the weekly gym session - sits in
`note` as text, and CONTRACT §14.4 lists it so nobody mistakes it for live.

Every price is ⟦AÇIK-21⟧, pitched against the starting wage (40/week): a room is a
fraction of a month's pay, a villa is most of a season's.

Editing a value is an edit to THIS FILE ONLY; domain/housing.py derives everything
else and validate_housing() fails at import on a row that cannot work (INV-28's
spirit: a typo'd effect key must blow up at startup, not on the first rest day).
"""
from catalog import _is_known_effect_key

KINDS = ("start", "rent", "hotel", "buy", "holiday")


def _home(residence_id, title, kind, sleep, grade, description, note, *,
          price=0, rent_monthly=0, daily_fee=0, noise_chance=0.0, modifiers=None):
    return {
        "residence_id": residence_id, "title": title, "kind": kind, "sleep": sleep,
        "grade": grade, "price": price, "rent_monthly": rent_monthly,
        "daily_fee": daily_fee, "noise_chance": noise_chance,
        # [{"key": "breakfast", "title": "Ev yemeği", "amount": 2}, ...] - shown
        # as the source of each number in the morning forecast.
        "modifiers": modifiers or [],
        "description": description, "note": note,
    }


def _holiday(residence_id, title, grade, price, rest_condition, rest_effects,
             description, note):
    row = _home(residence_id, title, "holiday", 0, grade, description, note, price=price)
    row["rest"] = {"condition": rest_condition, "effects": rest_effects}
    return row


RESIDENCES = [
    # --- start: free, reachable from anywhere ---
    _home("res-dorm", "Altyapı yurdu", "start", 6, 0,
          "Dört kişilik oda, ortak duş. Kulüp her şeyi karşılıyor.",
          "Oda arkadaşı gürültüsü: %20 ihtimalle o günün uykusu yarıya iner; "
          "takım arkadaşlarıyla ilişki bonusu henüz bir şey okumaz",
          noise_chance=0.2),
    _home("res-family", "Ailenin evi", "start", 8, 0,
          "Anne mutfakta. Tesise bir saat, ama kendi yatağın.",
          "Ev yemeği ile sabah +2, ama tesise uzak olduğu için yolculukta -2",
          modifiers=[
              {"key": "breakfast", "title": "Ev yemeği", "amount": 2},
              {"key": "commute", "title": "Tesise yolculuk", "amount": -2},
          ]),

    # --- rent ---
    _home("res-shared", "Paylaşımlı kiralık daire", "rent", 7, 0,
          "İki ev arkadaşı, bir mutfak, sürekli bir şeyler oluyor.",
          "Ev arkadaşı olayları sonraki fazın işi (§14.5)", rent_monthly=35),
    _home("res-studio", "Merkezi stüdyo daire", "rent", 8, 1,
          "Merkezde küçük bir daire; her yere yürüyerek.",
          "Gece aktivitelerinden sonraki kondisyon kaybı azalması henüz bir şey okumaz",
          rent_monthly=55),
    _home("res-near-flat", "Tesislere yakın 1+1", "rent", 8, 1,
          "İdmana on dakika. Yolculuk yorgunluğu yok.", "Yolculuk kaybı yok",
          rent_monthly=85),
    _home("res-hotel", "Otel odası", "hotel", 9, 1,
          "Kulübün ayarladığı oda. Yeni şehirde ev bulana kadar.",
          "Transferden sonra kulüp verir; günlük ücretli ve süre sınırlı",
          daily_fee=15),
    _home("res-site-flat", "Site içi 2+1", "rent", 9, 2,
          "Güvenlikli site, kapalı otopark, spor salonu.",
          "Site spor salonunun haftalık hafif antrenmanı henüz bir şey okumaz",
          rent_monthly=130),

    # --- buy ---
    _home("res-garden-house", "Bahçeli müstakil ev", "buy", 10, 2,
          "Kendi bahçen, kendi sessizliğin.", "Bahçede hafif koşu ile dinlenme günü +5 henüz bir şey okumaz",
          price=2500),
    _home("res-seaside-flat", "Sahil kenarı daire", "buy", 11, 3,
          "Balkondan deniz. Maçtan sonra yürüyüş yolu kapıda.",
          "Maç sonrası sahil yürüyüşü (toparlanma +10) henüz bir şey okumaz",
          price=4200),
    _home("res-loft", "Şehir manzaralı loft", "buy", 10, 4,
          "Cam cepheli, yüksek tavanlı, gürültülü ve havalı.",
          "Ev partisi bonusu ve maç öncesi gece -3 henüz bir şey okumaz",
          price=7500),
    _home("res-smart-flat", "Akıllı ev donanımlı daire", "buy", 11, 3,
          "Yatağın uykunu ölçer, perde kendi kendine kapanır.",
          "Uyku takibi: sabah ekranındaki kondisyon tahmini zaten herkese açık",
          price=6500),
    _home("res-residence", "Rezidans (havuz, spa, concierge)", "buy", 12, 4,
          "Kapıda bir concierge, çatıda bir havuz.",
          "Sakatlık iyileşme süresi %10 kısalır (sakatlık sistemi gelene dek okunmaz)",
          price=11000),
    _home("res-sea-villa", "Deniz manzaralı villa", "buy", 13, 5,
          "Özel havuz, geniş bahçe, takım arkadaşlarını ağırlayacak kadar yer.",
          "Takım arkadaşlarını ağırlama olayları sonraki fazın işi (§14.5)",
          price=16000),
    _home("res-rehab-villa", "Rehabilitasyon odalı villa", "buy", 14, 4,
          "Hidroterapi havuzu ve kriyoterapi odası evin içinde.",
          "Sakatlık iyileşmesi %25 kısalır (sakatlık sistemi gelene dek okunmaz)",
          price=20000),

    # --- holiday: visited, never lived in ---
    _holiday("hol-village-house", "Memleketteki köy evi", 0, 700, 15,
             {"relationship:family": 2, "attribute:empathy": 0.3},
             "Çocukluğunun sokağı. Komşular hâlâ seni tanıyor.",
             "Aile ve Empati olayları"),
    _holiday("hol-lake-cabin", "Göl kenarı kulübe", 2, 1800, 12,
             {"attribute:discipline": 0.3},
             "Sabah sisi, akşam sessizliği. Telefon çekmiyor.",
             "Meditasyon ile Disiplin bonusu"),
    _holiday("hol-summer-house", "Yazlık", 3, 2600, 14,
             {"attribute:charisma": 0.2, "relationship:media": 1},
             "Komşu sitede bir sürü yüz; biri seni tanıyor.",
             "Sosyal olaylar ve yeni karakter tanışmaları sonraki fazın işi (§14.5)"),
    _holiday("hol-mountain-lodge", "Dağ evi", 3, 6000, 12,
             {},
             "Yüksek irtifa, ince hava. Burada kamp yapmak bir şeydir.",
             "Yüksek irtifa kampı: maksimum kondisyon +5 (tavan zaten 100, henüz okunmaz)"),
]

# Fitted to a home the player owns (D95). `sleep` adds to the night,
# `cancels_noise` removes the roommates' roll, `morning` adds to the day,
# `monthly_fee` is charged on the 1st (D89).
UPGRADES = [
    {"upgrade_id": "up-orthopedic-bed", "title": "Ortopedik yatak", "price": 120,
     "sleep": 1, "note": "Uyku kazancı +1"},
    {"upgrade_id": "up-blackout", "title": "Karartma perdesi ve ses yalıtımı", "price": 150,
     "sleep": 1, "cancels_noise": True, "note": "Uyku +1, gürültü cezalarını iptal eder"},
    {"upgrade_id": "up-home-gym", "title": "Ev spor salonu", "price": 600,
     "note": "Dinlenme günü hafif antrenman seçeneği henüz bir şey okumaz"},
    {"upgrade_id": "up-sauna", "title": "Sauna", "price": 1200,
     "note": "Maç sonrası toparlanma +5 henüz bir şey okumaz"},
    {"upgrade_id": "up-cold-plunge", "title": "Soğuk dalma havuzu", "price": 1800,
     "note": "Sakatlık iyileşmesi %5 kısalır (sakatlık sistemi gelene dek okunmaz)"},
    {"upgrade_id": "up-chef", "title": "Özel aşçı", "price": 400, "monthly_fee": 60,
     "morning": 2, "note": "Her sabah +2, aylık ücretli; ödenemezse aşçı gider"},
]

assert len(RESIDENCES) == 18
assert len(UPGRADES) == 6

_BY_ID = {r["residence_id"]: r for r in RESIDENCES}
_UPGRADE_BY_ID = {u["upgrade_id"]: u for u in UPGRADES}

# A home a player can sleep in. A holiday row is visited, never lived in (D87).
HABITABLE_KINDS = ("start", "rent", "hotel", "buy")


def get(residence_id: str):
    return _BY_ID.get(residence_id)


def upgrade(upgrade_id: str):
    return _UPGRADE_BY_ID.get(upgrade_id)


def validate_housing() -> None:
    if len(_BY_ID) != len(RESIDENCES) or len(_UPGRADE_BY_ID) != len(UPGRADES):
        raise ValueError("housing: duplicate id")
    for row in RESIDENCES:
        where = f"housing:{row['residence_id']!r}"
        kind = row["kind"]
        if kind not in KINDS:
            raise ValueError(f"{where} has kind {kind!r}")
        if not 0 <= row["grade"] <= 5:
            raise ValueError(f"{where} has grade {row['grade']!r}, not 0-5")
        if not 0.0 <= row["noise_chance"] < 1.0:
            raise ValueError(f"{where} has noise_chance {row['noise_chance']!r}")
        # Each kind is paid one way; a number on the wrong kind is a number
        # nothing ever charges.
        money = {"price": row["price"], "rent_monthly": row["rent_monthly"], "daily_fee": row["daily_fee"]}
        expected = {"rent": "rent_monthly", "hotel": "daily_fee", "buy": "price", "holiday": "price"}.get(kind)
        for field, amount in money.items():
            if field == expected:
                if amount <= 0:
                    raise ValueError(f"{where} is {kind} but {field} is {amount}")
            elif amount:
                raise ValueError(f"{where} is {kind} but carries {field}={amount}")
        if kind == "holiday":
            rest = row.get("rest")
            if not rest or rest["condition"] <= 0:
                raise ValueError(f"{where} is a holiday home without a rest gain")
            for key in rest["effects"]:
                if not _is_known_effect_key(key):
                    raise ValueError(f"{where} rest effect {key!r} is not a known effect key")
        elif row["sleep"] <= 0:
            raise ValueError(f"{where} is a home with sleep {row['sleep']!r}")
    for up in UPGRADES:
        if up["price"] <= 0:
            raise ValueError(f"upgrade {up['upgrade_id']!r} is free")


validate_housing()
