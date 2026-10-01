"""§5.6 N3 'training' - D16 (data in BE, presentation in FE) + D41 (costs/
effects maps instead of a fixed field set) + D31 (kişi attributes train the
same way saha ones do, same catalog).

Every numeric cost/effect below is a placeholder — ⟦AÇIK-5⟧ hasn't settled
the budget's actual resource keys or scale. 'time' (minutes) and 'energy'
(0-100) are ported straight from training_screen.dart's existing energy
values and duration_screen/README's default. The point of this file
existing is the shape, not these specific numbers.

Seven saha items match training_screen.dart's physical cards verbatim (same
energy costs); 'Müdahale' joined them when tackling became an attribute.

§13.5/D77 retired the five kişi items (Medya Eğitimi, Görgü Dersleri,
Özgüven Koçluğu, Satranç Kulübü, Kriz Simülasyonu) and with them D31's
"every attribute has a training path" rule. They were the only cards with
`drill: None` that FE could not start — five permanent "Yakında" buttons —
and the concept was wrong anyway: a football club has no politeness drill.
Kişi attributes now grow from lifestyle activities, social offers, dialogue
leaves, activity events (§13.4) and owned items (§13.3) instead — D78.
ATTRIBUTE_KEYS' kişi family is untouched; what went is the path, not the
attribute.

Three taktik items (§12.11, D63) round the file out — one per
config.TACTIC_KEYS entry, same placeholder-economy caveat. They carry no
`requires` (kept unlocked on purpose, §12.11) and no `drill` — a tactic
card applies directly, with no mini-oyun. Since §13.5 removed the kişi
rows, `drill: None` now means exactly that one thing.
"""

TRAINING_ITEMS = [
    # --- saha: training_screen.dart'ın altı kartı ---
    {
        "catalog_id": "kondisyon-kosusu", "title": "Kondisyon Koşusu",
        "description": "Tempolu bir koşu ile dayanıklılığını geliştir.",
        "family": "saha", "drill": "conditioning",
        "costs": {"time": 90, "energy": 15},          # ⟦AÇIK-5⟧
        "effects": {"attribute:condition": 1.2, "condition": -10},       # ⟦AÇIK-5⟧
    },
    {
        "catalog_id": "guc-antrenmani", "title": "Güç Antrenmanı",
        "description": "Ağırlık çalışmasıyla fiziksel gücünü artır.",
        "family": "saha", "drill": "strength",
        "costs": {"time": 75, "energy": 20},
        "effects": {"attribute:strength": 1.2, "condition": -8},
    },
    {
        "catalog_id": "esneklik-toparlanma", "title": "Esneklik & Toparlanma",
        "description": "Germe ve toparlanma çalışmasıyla sakatlık riskini azalt.",
        "family": "saha", "drill": "flexibility",
        "costs": {"time": 45, "energy": 8},
        "effects": {"attribute:flexibility": 1.0, "condition": 2},
    },
    {
        "catalog_id": "sut", "title": "Şut",
        "description": "Şut isabetini ve gücünü çalış.",
        "family": "saha", "drill": "shot",
        "costs": {"time": 60, "energy": 18},
        "effects": {"attribute:shooting": 1.2, "condition": -6},
    },
    {
        "catalog_id": "pas", "title": "Pas",
        "description": "Pas isabetini ve zamanlamasını çalış.",
        "family": "saha", "drill": "pass",
        "costs": {"time": 60, "energy": 12},
        "effects": {"attribute:passing": 1.2, "condition": -5},
    },
    {
        "catalog_id": "dribling", "title": "Dribling",
        "description": "Koridorda top sürme: aynı yöne kaydırdıkça hızlan, ters yön frenler.",
        "family": "saha", "drill": "dribble",
        "costs": {"time": 60, "energy": 18},
        "effects": {"attribute:dribbling": 1.0, "condition": -7},
    },
    {
        "catalog_id": "mudahale", "title": "Müdahale",
        "description": "Baskı zinciri: tempoyu tutturarak rakibe yetiş, açılan pencerede dal.",
        "family": "saha", "drill": "tackling",
        "costs": {"time": 60, "energy": 20},
        "effects": {"attribute:tackling": 1.0, "condition": -8},
    },
    # --- taktik: §12.11, D63, bir kartı olmayan üç yeterlilik ---
    {
        "catalog_id": "gegenpress", "title": "Gegenpress",
        "description": "Topu kaybettiğin anda yüksek hatta baskıyı çalış.",
        "family": "taktik", "drill": None,
        "costs": {"time": 60, "energy": 8},
        "effects": {"tactic:gegenpress": 0.8, "condition": -3},
    },
    {
        "catalog_id": "pozisyonel-oyun", "title": "Pozisyonel Oyun",
        "description": "Topsuz konumlanmayı ve saha genişliğini çalış.",
        "family": "taktik", "drill": None,
        "costs": {"time": 75, "energy": 6},
        "effects": {"tactic:pozisyonel_oyun": 0.8, "condition": -2},
    },
    {
        "catalog_id": "derin-blok", "title": "Derin Blok",
        "description": "Geri çekilip alanı daraltmayı ve geçişi çalış.",
        "family": "taktik", "drill": None,
        "costs": {"time": 45, "energy": 5},
        "effects": {"tactic:derin_blok": 0.8, "condition": -2},
    },
]

# §13.5/D77 - seven saha + three taktik. Was 15 before the five kişi rows went.
assert len(TRAINING_ITEMS) == 10
assert len({i["catalog_id"] for i in TRAINING_ITEMS}) == len(TRAINING_ITEMS)

from catalog import validate_catalog, validate_training  # noqa: E402 (after data, INV-28)

validate_catalog(TRAINING_ITEMS, "training")
validate_training(TRAINING_ITEMS, "training")  # INV-64
