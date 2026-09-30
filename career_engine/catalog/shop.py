"""§5.6 N3 'shop' - id, title, description, price, note per item. Since §14.2
there are 43: 40 equippable gear rows in six categories and the three
investments. (The three real-estate rows left for the housing system, §14.4.) `category` uses ShopCategory's own identifiers
(clothing/accessory/tech/vehicle/living/special/realEstate/investment) so FE
needs no translation layer.

D27 (real-estate upkeep) is retired by §14.4: only the two subscription gear rows
carry upkeep_weekly now (photographer, media team) — the other rows are
one-off purchases with no ongoing cost. Amounts are
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

§13.3 `passive_effects`: an owned item may also carry a PASSIVE bonus on a
kişi attribute. Kept as its own map rather than folded into `daily_effects`
because the two do different things: `daily_effects` WRITES once a day
through the day loop, `passive_effects` never writes at all — it rides on
top of the stored value at read time (domain/attributes.effective_value) and
disappears the moment the item does. That is what lets §12.12's five
"showroom" rows finally mean something without breaking INV-22: a sold suit
takes its empathy with it, and no attribute ever fell.

§12.13 `weekly_return_rate`: an `investment`-category item's weekly return as
a fraction of `price` (not `effects`/`daily_effects` — it isn't an anchor-key
map, it's a plain rate, same unvalidated-top-level-field status as
`upkeep_weekly`). Frozen into `inventory.weekly_return` at purchase time
(`api/routers/time.py::post_purchase`); domain/investments.py is the only
reader of that frozen column afterward.

§14.2 D80-D82 `slot` / `grade` / `acquire`: equippable gear. Only the item in
an occupied slot's `equipped` row contributes its passive/daily effects
(domain/inventory.py is the only reader of that); a slotless row - the
realEstate and investment rows - always counts, exactly as before. `acquire:
grant` rows (#38-#42's story items) are never sold; `grant_item:<id>` hands
them over; since §14.4 the realEstate rows are gone (catalog/housing.py).
"""

# §14.2 D80 - gear categories (how the shop groups it) and the bonus a grade
# is worth. A grade-N item adds N * CHARISMA_PER_GRADE to `charisma` as a
# passive bonus (§13.3). The scale is deliberately small: with one item per
# slot and ~15 slots, a fully dressed career reads about +25 at the top, and
# charisma starts at 74 - ⟦AÇIK-16⟧ still owns whether that is right.
CHARISMA_PER_GRADE = 0.5
GEAR_CATEGORIES = ("clothing", "accessory", "tech", "vehicle", "living", "special")
ACQUIRE_MODES = ("shop", "grant")


def _gear(catalog_id, title, category, slot, grade, price, note, description, *,
          upkeep_weekly=0, acquire="shop", daily_effects=None, extra_passive=None):
    passive = {"attribute:charisma": grade * CHARISMA_PER_GRADE}
    passive.update(extra_passive or {})
    item = {
        "catalog_id": catalog_id, "title": title, "category": category,
        "description": description, "price": price, "upkeep_weekly": upkeep_weekly,
        "note": note, "slot": slot, "grade": grade, "acquire": acquire,
        "passive_effects": passive,
    }
    if daily_effects:
        item["daily_effects"] = daily_effects
    return item


SHOP_ITEMS = [
    # --- equippable gear (§14.2, D80): `slot` + `grade`. One item per slot is
    # active at a time; a row without a slot (estate, investment) always counts.
    # Prices scale with grade against the starting wage (40/week, STARTING_MONEY
    # 60): grade 1 is a week or two of wages, grade 5 is most of a season's. ---

    # --- clothing ---
    _gear("cloth-sneaker-white", "Temiz beyaz sneaker", "clothing", "shoes", 1, 45,
          "Başlangıç itemi, her kombinle uyumlu",
          "Hiçbir şey söylemeyen ama her şeyle giden ayakkabı."),
    _gear("cloth-basics-set", "Kaliteli basic tişört seti", "clothing", "top", 1, 35,
          "Ucuz ama \"özenli\" izlenimi",
          "Düz, temiz, ütülü. Dikkat çekmez; dikkat dağıtmaz."),
    _gear("cloth-leather-jacket", "Deri ceket", "clothing", "outerwear", 2, 180,
          "Gece etkinliklerinde bonus",
          "Kapıdaki görevlinin seni bir kez daha süzmesine yetecek kadar."),
    _gear("cloth-designer-hoodie", "Tasarım kapüşonlu", "clothing", "top", 2, 140,
          "Genç taraftar kitlesinde daha etkili",
          "Sokakta giyilen, ama etiketi okunan tür."),
    _gear("cloth-tailored-suit", "Ölçüye göre dikilmiş takım elbise", "clothing", "formal", 3, 900,
          "Sözleşme görüşmeleri ve galalarda bonus",
          "Deplasman yolculukları, kulüp galaları ve masanın karşı tarafı için."),
    _gear("cloth-limited-sneaker", "Sınırlı üretim sneaker", "clothing", "shoes", 3, 700,
          "Takım arkadaşlarından sohbet tetikleyebilir",
          "Soyunma odasında biri mutlaka fiyatını sorar."),
    _gear("cloth-cashmere-coat", "Kaşmir palto", "clothing", "outerwear", 3, 850,
          "Sadece kış aylarında aktif",
          "Kış için. Yazın dolapta durması bütün amacı."),
    _gear("cloth-luxury-outfit", "Lüks marka kombin", "clothing", "formal", 4, 3500,
          "Sosyal medyada etkisi yüksek",
          "Baştan aşağı tek markadan; fotoğrafta bile fark ediliyor."),
    _gear("cloth-gala-custom", "Tasarımcıdan özel dikim gala kıyafeti", "clothing", "formal", 5, 12000,
          "Yılın oyuncusu töreni gibi özel eventlerde açılır",
          "Sana göre kesilmiş tek parça. Bir kez giyilir, herkes hatırlar."),

    # --- accessory ---
    _gear("acc-sunglasses", "Güneş gözlüğü", "accessory", "eyewear", 1, 40,
          "Havalimanı ve dış çekim sahnelerinde görünür",
          "Uykusuz sabahların en ucuz çözümü."),
    _gear("acc-leather-bracelet", "Deri bileklik", "accessory", "bracelet", 1, 30,
          "Hediye olarak da alınabilir",
          "Küçük, sade ve kolay hediye edilir."),
    _gear("acc-minimal-wallet", "Minimalist cüzdan", "accessory", "wallet", 1, 25,
          "Düşük etki, düşük fiyat",
          "İçinde fazla bir şey yok; bu da bir tavır."),
    _gear("acc-perfume", "Parfüm", "accessory", "fragrance", 2, 160,
          "Yakın ilişki diyaloglarında ekstra etki",
          "Odaya senden önce giren bir şey."),
    _gear("acc-silver-necklace", "Gümüş kolye", "accessory", "necklace", 2, 200,
          "", "İnce zincir, tek kolye. Gömleğin altından görünür."),
    _gear("acc-leather-backpack", "Kaliteli deri sırt çantası", "accessory", "bag", 2, 220,
          "Antrenmana gidiş sahnelerinde görünür",
          "Antrenman çantası da olur, toplantı çantası da."),
    _gear("acc-smart-watch", "Akıllı saat", "accessory", "watch", 2, 300,
          "Disipline de küçük bonus verebilir",
          "Uykunu, adımlarını ve kalp atışını sayar; sen de izlemeye başlarsın.",
          extra_passive={"attribute:discipline": 0.5}),
    _gear("acc-swiss-watch", "İsviçre mekanik saat", "accessory", "watch", 4, 4500,
          "Basın toplantılarında fark edilir",
          "Kendi kendine kurulan, kameranın tam göreceği yerde duran saat.",
          daily_effects={"fame:overall": 0.3}),
    _gear("acc-custom-ring", "Özel tasarım yüzük", "accessory", "ring", 4, 3000,
          "Kaptanlık gibi bir başarıya bağlı kilit açılabilir",
          "Senin için çizilmiş tek parça."),
    _gear("acc-collector-watch", "Koleksiyonluk kol saati", "accessory", "watch", 5, 18000,
          "Pahalı; alınca bazı karakterler kibirli bulabilir",
          "Müzayededen çıkan, seri numaralı parça. Herkes fiyatını biliyor."),

    # --- tech & media (photographer / media team are monthly costs, paid weekly) ---
    _gear("tech-phone", "Yeni model telefon", "tech", "phone", 1, 80,
          "Sosyal medya aktivitelerini açar",
          "Kamerası iyi, pili hâlâ dolu."),
    _gear("tech-earbuds", "Kablosuz kulaklık", "tech", "earbuds", 1, 50,
          "", "Otobüs yolculuklarında dış sesi kesiyor; maç öncesi rutinin parçası."),
    _gear("tech-stream-kit", "Profesyonel ring light ve mikrofon", "tech", "stream_kit", 2, 350,
          "Canlı yayın aktivitesinin etkisini artırır",
          "Yayın açtığında taraftar senin yüzünü değil, ışığını da fark eder."),
    _gear("tech-photographer", "Kişisel fotoğrafçı aboneliği", "tech", "photographer", 3, 300,
          "Paylaşımların etkisi artar, aylık ödeme",
          "Her paylaşım için bir kare. Abonelik her hafta tahsil edilir.",
          upkeep_weekly=20),
    _gear("tech-youtube-team", "Kendi YouTube kanalı prodüksiyon ekibi", "tech", "media_team", 4, 3000,
          "Haber katmanında düzenli içerik üretir",
          "Kamera, kurgu ve senaryo ekibi; kanal senin adınla yayında.",
          upkeep_weekly=60),

    # --- vehicle ---
    _gear("veh-scooter", "Elektrikli scooter", "vehicle", "vehicle", 1, 90,
          "Gençlerde sempatik bulunur", "Tesise giden en kısa ve en sempatik yol."),
    _gear("veh-compact-car", "Kompakt şehir arabası", "vehicle", "vehicle", 2, 450,
          "Pratik, göze batmaz", "Park yeri bulmak kolay, kimse bakmıyor."),
    _gear("veh-retro-motorcycle", "Retro klasik motosiklet", "vehicle", "vehicle", 3, 1400,
          "Kulüp motosiklet yasağı koyarsa ilginç bir çatışma çıkar",
          "Sesi uzaktan tanınır; kulüp yönetimi pek sevmeyebilir."),
    _gear("veh-premium-suv", "Premium SUV", "vehicle", "vehicle", 3, 2200,
          "Aile ve takım arkadaşı taşımada bonus", "Bagaj geniş, koltuk çok; herkes sığar."),
    _gear("veh-sports-car", "Spor araba", "vehicle", "vehicle", 4, 6500,
          "Taraftar tepkisi forma bağlı: kötü dönemde ters teper",
          "Gaz pedalı hassas. Formun düşükken park yerinde durması bile haber olur."),
    _gear("veh-custom-supercar", "Özel boyalı süper araba", "vehicle", "vehicle", 5, 16000,
          "Haber katmanında manşet olur", "Dünyada tek. Her görüntüsü bir manşet."),

    # --- living ---
    _gear("home-plants", "Şık salon bitkileri", "living", "plants", 1, 35,
          "Ev ziyareti sahnelerinde görünür", "Yaşayan bir köşe."),
    _gear("home-record-player", "Plak çalar ve plak koleksiyonu", "living", "audio_home", 2, 220,
          "Belli karakterlerle özel sohbet açar", "Akşamları yavaşlatan şey."),
    _gear("home-coffee-machine", "Tasarım kahve makinesi", "living", "kitchen", 1, 75,
          "Ev ziyaretinde misafire ikram seçeneği",
          "Sabah antrenmanından önce kahve kuyruğunda beklemeye son.",
          daily_effects={"energy": 3}),
    _gear("home-cinema", "Ev sineması sistemi", "living", "cinema", 2, 400,
          "Evde film aktivitesi açar", "Maç akşamları arkadaşları çağırmak için yeterince büyük."),
    _gear("home-art-painting", "Sanat eseri tablo", "living", "art", 3, 1100,
          "Zeka'ya da küçük bonus", "Duvarda durmasının ayrı bir havası var.",
          extra_passive={"attribute:intelligence": 0.5}),

    # --- special & collection. `acquire: grant` rows are never sold: an event,
    # a goal, a sponsorship deal hands them over (D82, `grant_item:` effect). ---
    _gear("special-signed-jersey", "Çocukluk kahramanının imzalı forması", "special", "jersey", 2, 0,
          "Satın alınamaz, bir event ile kazanılır",
          "Duvarda asılı; çocukluğundan bir hatıra.", acquire="grant"),
    _gear("special-first-goal-ball", "İlk profesyonel golünün topu", "special", "goal_ball", 2, 0,
          "Kazanılan item, duygusal diyaloglar açar",
          "Üstünde tarih yazıyor.", acquire="grant"),
    _gear("special-signature-boots", "Kendi adına sınırlı sayıda krampon serisi", "special", "signature_boots", 4, 0,
          "Sponsorluk anlaşmasıyla gelir",
          "Sponsor bir seri çıkardı; ilk çift sende.", acquire="grant"),
    _gear("special-club-card", "Özel üyelikli lüks kulüp kartı", "special", "membership", 4, 5000,
          "Gece hayatı mekanlarının kilidini açar",
          "Kapıda ismin yeterli; liste hep hazır."),
    _gear("special-foundation", "Kendi adına hayır vakfı", "special", "foundation", 5, 0,
          "Empati'ye de bonus; karizmayı \"gösterişsiz\" yoldan veren tek 5'lik item",
          "Adın bir yardım vakfında yazılı.", acquire="grant",
          extra_passive={"attribute:empathy": 1.5}),

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

assert len(SHOP_ITEMS) == 43
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


# §13.3/D73 - the passive attribute index. Same import-time derivation as the
# three DAILY_* maps above (it cannot drift from the rows), different shape:
# a nested {item_id: {attribute_key: amount}} because one item may carry two
# (estate-villa does) and the reader sums per attribute, not per item.
#
# Keys are stored WITHOUT the "attribute:" prefix: every consumer
# (domain/attributes.passive_bonus, and through it every `requires` gate)
# speaks in bare attribute keys, so stripping it once here beats stripping
# it on every read.
PASSIVE_ATTRIBUTE_BONUS = {
    item["catalog_id"]: {
        key.split(":", 1)[1]: amount
        for key, amount in item["passive_effects"].items()
    }
    for item in SHOP_ITEMS
    if item.get("passive_effects")
}


def daily_fame_bonus(item_ids) -> float:
    """The per-day overall-fame bonus an inventory of `item_ids` is worth."""
    return sum(DAILY_FAME_BONUS.get(item_id, 0) for item_id in item_ids)




def validate_gear(items: list) -> None:
    """§14.2 - a slotted row is equippable gear and must say how good it is and
    how it is obtained; a slotless row (estate, investment) must not pretend to.
    A `grant` row is never sold, so a price on it would be a number nobody can
    pay (INV-28's spirit: fail at import, not in the shop)."""
    for item in items:
        where = f"shop:{item['catalog_id']!r}"
        slot = item.get("slot")
        if slot is None:
            if "grade" in item or item.get("acquire", "shop") != "shop":
                raise ValueError(f"{where} has a grade/acquire mode but no slot")
            continue
        if item["category"] not in GEAR_CATEGORIES:
            raise ValueError(f"{where} is slotted but in category {item['category']!r}")
        grade = item.get("grade")
        if not isinstance(grade, int) or isinstance(grade, bool) or not 1 <= grade <= 5:
            raise ValueError(f"{where} has grade {grade!r}, not 1-5")
        if item.get("acquire") not in ACQUIRE_MODES:
            raise ValueError(f"{where} has acquire {item.get('acquire')!r}")
        if item["acquire"] == "grant" and item["price"] != 0:
            raise ValueError(f"{where} is grant-only but priced {item['price']}")


def gear_by_id(catalog_id: str):
    return next((i for i in SHOP_ITEMS if i["catalog_id"] == catalog_id), None)


from catalog import validate_catalog  # noqa: E402 (after data, INV-28)

validate_catalog(SHOP_ITEMS, "shop")
validate_gear(SHOP_ITEMS)
