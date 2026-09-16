"""§5.6 N3 'training' - D16 (data in BE, presentation in FE) + D41 (costs/
effects maps instead of a fixed field set) + D31 (kişi attributes train the
same way saha ones do, same catalog).

Every numeric cost/effect below is a placeholder — ⟦AÇIK-5⟧ hasn't settled
the budget's actual resource keys or scale. 'time' (minutes) and 'energy'
(0-100) are ported straight from training_screen.dart's existing energy
values and duration_screen/README's default. The point of this file
existing is the shape, not these specific numbers.

Six saha items match training_screen.dart's six physical cards verbatim
(same energy costs); five kişi items are new (D31) — one per kişi
attribute. 'Müdahale' joined them when tackling became an attribute, so
every one of the 12 §5.2 attributes still has exactly one training path.

Three taktik items (§12.11, D63) round the file out — one per
config.TACTIC_KEYS entry, same placeholder-economy caveat. Unlike the kişi
items they carry no `requires` (kept unlocked on purpose, §12.11) and no
`drill` — a tactic card applies directly (no mini-oyun) the moment
training_screen.dart's 'taktik' tab wires it to postAction.
"""

TRAINING_ITEMS = [
    # --- saha: training_screen.dart'ın altı kartı ---
    {
        "catalog_id": "kondisyon-kosusu", "title": "Kondisyon Koşusu",
        "description": "Tempolu bir koşu ile dayanıklılığını geliştir.",
        "family": "saha", "drill": "conditioning",
        "costs": {"time": 90, "energy": 15},          # ⟦AÇIK-5⟧
        "effects": {"attribute:condition": 1.2},       # ⟦AÇIK-5⟧
    },
    {
        "catalog_id": "guc-antrenmani", "title": "Güç Antrenmanı",
        "description": "Ağırlık çalışmasıyla fiziksel gücünü artır.",
        "family": "saha", "drill": "strength",
        "costs": {"time": 75, "energy": 20},
        "effects": {"attribute:strength": 1.2},
    },
    {
        "catalog_id": "esneklik-toparlanma", "title": "Esneklik & Toparlanma",
        "description": "Germe ve toparlanma çalışmasıyla sakatlık riskini azalt.",
        "family": "saha", "drill": "flexibility",
        "costs": {"time": 45, "energy": 8},
        "effects": {"attribute:flexibility": 1.0, "condition": 4},
    },
    {
        "catalog_id": "sut", "title": "Şut",
        "description": "Şut isabetini ve gücünü çalış.",
        "family": "saha", "drill": "shot",
        "costs": {"time": 60, "energy": 18},
        "effects": {"attribute:shooting": 1.2},
    },
    {
        "catalog_id": "pas", "title": "Pas",
        "description": "Pas isabetini ve zamanlamasını çalış.",
        "family": "saha", "drill": "pass",
        "costs": {"time": 60, "energy": 12},
        "effects": {"attribute:passing": 1.2},
    },
    {
        "catalog_id": "dribling", "title": "Dribling",
        "description": "Koridorda top sürme: aynı yöne kaydırdıkça hızlan, ters yön frenler.",
        "family": "saha", "drill": "dribble",
        "costs": {"time": 60, "energy": 18},
        "effects": {"attribute:dribbling": 1.0},
    },
    {
        "catalog_id": "mudahale", "title": "Müdahale",
        "description": "Baskı zinciri: tempoyu tutturarak rakibe yetiş, açılan pencerede dal.",
        "family": "saha", "drill": "tackling",
        "costs": {"time": 60, "energy": 20},
        "effects": {"attribute:tackling": 1.0},
    },
    # --- kişi: D31, her nitelik için bir yol ---
    # D42: the one gated training path, and the chain it anchors —
    # ozguven-koclugu raises confidence to 6, which unlocks this, which
    # raises charisma to 8, which unlocks media_01's interview reply.
    # A fresh career sits at confidence 5, so the lock is visible on day one.
    {
        "catalog_id": "medya-egitimi", "title": "Medya Eğitimi",
        "description": "Röportaj ve kamera karşısında durmayı öğren.",
        "family": "kişi", "drill": None,
        "costs": {"time": 60, "energy": 5},
        "effects": {"attribute:charisma": 0.8, "money": -10},
        "requires": {"confidence": 6},
    },
    {
        "catalog_id": "gorgu-dersleri", "title": "Görgü Dersleri",
        "description": "Sosyal ortamlarda nezaket ve incelik üzerine çalış.",
        "family": "kişi", "drill": None,
        "costs": {"time": 45, "energy": 5},
        "effects": {"attribute:politeness": 0.8, "money": -5},
    },
    {
        "catalog_id": "ozguven-koclugu", "title": "Özgüven Koçluğu",
        "description": "Baskı altında kararlılığını artırmak için birebir koçluk.",
        "family": "kişi", "drill": None,
        "costs": {"time": 60, "energy": 8},
        "effects": {"attribute:confidence": 0.8, "money": -8},
    },
    {
        "catalog_id": "satranc-kulubu", "title": "Satranç Kulübü",
        "description": "Analitik düşünmeyi geliştiren düzenli bir aktivite.",
        "family": "kişi", "drill": None,
        "costs": {"time": 90, "energy": 5},
        "effects": {"attribute:intelligence": 0.8, "money": -3},
    },
    {
        "catalog_id": "kriz-simulasyonu", "title": "Kriz Simülasyonu",
        "description": "Beklenmedik durumlarda hızlı karar verme pratiği.",
        "family": "kişi", "drill": None,
        "costs": {"time": 60, "energy": 10},
        "effects": {"attribute:resourcefulness": 0.8, "money": -7},
    },
    # --- taktik: §12.11, D63, bir kartı olmayan üç yeterlilik ---
    {
        "catalog_id": "gegenpress", "title": "Gegenpress",
        "description": "Topu kaybettiğin anda yüksek hatta baskıyı çalış.",
        "family": "taktik", "drill": None,
        "costs": {"time": 60, "energy": 8},
        "effects": {"tactic:gegenpress": 0.8},
    },
    {
        "catalog_id": "pozisyonel-oyun", "title": "Pozisyonel Oyun",
        "description": "Topsuz konumlanmayı ve saha genişliğini çalış.",
        "family": "taktik", "drill": None,
        "costs": {"time": 75, "energy": 6},
        "effects": {"tactic:pozisyonel_oyun": 0.8},
    },
    {
        "catalog_id": "derin-blok", "title": "Derin Blok",
        "description": "Geri çekilip alanı daraltmayı ve geçişi çalış.",
        "family": "taktik", "drill": None,
        "costs": {"time": 45, "energy": 5},
        "effects": {"tactic:derin_blok": 0.8},
    },
]

assert len(TRAINING_ITEMS) == 15
assert len({i["catalog_id"] for i in TRAINING_ITEMS}) == len(TRAINING_ITEMS)

from catalog import validate_catalog  # noqa: E402 (after data, INV-28)

validate_catalog(TRAINING_ITEMS, "training")
