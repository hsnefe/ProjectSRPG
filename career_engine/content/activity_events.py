"""§13.4 D75 - the pool of activity events a lifestyle action can spawn.

**Why `content/` and not `catalog/`.** The same split content/social_offers.py
draws: catalogs are served in bulk because knowing what exists is part of
playing, an event pool served in bulk would spoil every event the player has
not had yet. What FE sees is the single generated event (T2's `event` block,
or T5), never this file.

**Why the prose lives here and not in Flutter.** D23 keeps dialogue TREES in
FE because their branching is a UI structure. An activity event has no tree —
one paragraph, N buttons — so the argument that applies to an offer applies
here: in Dart, adding a template would be an edit in two repositories that
have to agree on an id.

**What FE never sees:** an option's `effects`, `starts_relationship`, and the
template's `weight`. R4 already draws this line; T2 serves the text, the
labels, and each option's `requires`/`costs` so a gate can be greyed out
before it is chosen, and nothing else.

**How an event finds its activity.** `catalog_ids` lists the lifestyle rows a
template may fire on. The pairing lives here rather than on the catalog row so
one template can hang off several activities (a stranger recognising you works
in a cafe and at a friends' night) without catalog/lifestyle.py naming any
template. How OFTEN an activity spawns anything at all is the catalog row's
`event_chance` — the two dials are deliberately on opposite sides.

Adding a template is an edit to THIS FILE ONLY: eligibility, weighting and
resolution all read the maps below rather than naming any template.
"""

# An option's `effects` uses T2's own anchor-key space (§5.7):
#   attribute:<key> · condition · energy · money · fame:<scope> · relationship:<rid>
# INV-28 validates it at import, at the bottom of this file.
#
# `starts_relationship` is §13.4's single bridge to §13.2: it moves an ABSENT
# partner to `courting`. It does nothing at all for a partner already courting
# or active (domain/activity_events.py checks the state, the template never
# has to), which is what lets the same template stay in the pool for a career
# that is years past this moment.

ACTIVITY_EVENTS = [
    # --- tanışma: §13.2'nin partner kapısı --------------------------------
    {
        "template_id": "kafe-taniyan-birisi",
        "catalog_ids": ["sos-kafe", "sos-arkadas"],
        "weight": 3,
        "requires": {},
        "title": "Tanıdık bir yüz",
        "body": "Yan masadaki biri seni tanıdı. Geçen haftaki maçtan konuşuyor, "
                "hem de takımın kaçırdığı o pozisyonu senden daha iyi hatırlıyor. "
                "Kahvesini alıp kalkmak üzere.",
        "options": [
            {
                "option_id": "masasina_git", "label": "Masasına geç",
                "requires": {"courage": 5},
                "costs": {"time": 45.0, "energy": 5.0},
                "effects": {"attribute:charisma": 0.4},
                "starts_relationship": "partner",
            },
            {
                "option_id": "gulumse", "label": "Gülümseyip geç",
                "costs": {},
                "effects": {"condition": 1},
            },
        ],
    },
    {
        "template_id": "konser-ayni-grup",
        "catalog_ids": ["sos-konser"],
        "weight": 2,
        "requires": {},
        "title": "Aynı grubu dinleyen biri",
        "body": "Sahnenin solunda, senin bildiğin ama kimsenin bilmediği o "
                "parçayı ezbere söyleyen biri var. Konser bitti, kalabalık "
                "dağılıyor.",
        "options": [
            {
                "option_id": "tanis", "label": "Yanına git",
                "requires": {"charisma": 6},
                "costs": {"time": 60.0, "energy": 8.0},
                "effects": {"attribute:courage": 0.3},
                "starts_relationship": "partner",
            },
            {
                "option_id": "cik", "label": "Çıkışa yürü",
                "costs": {},
                "effects": {},
            },
        ],
    },

    # --- kulüp ve tribün ---------------------------------------------------
    {
        "template_id": "taraftar-cocuk-forma",
        "catalog_ids": ["sos-taraftar", "sos-kafe"],
        "weight": 4,
        "requires": {},
        "title": "Formalı bir çocuk",
        "body": "Sekiz yaşlarında, senin numaranı taşıyan bir forma giymiş. "
                "Babası uzaktan bakıyor, çocuğu itelemeye çekiniyor.",
        "options": [
            {
                "option_id": "imza_ver", "label": "İmzala ve fotoğraf çektir",
                "costs": {"time": 20.0, "energy": 2.0},
                "effects": {"relationship:fans": 4, "fame:overall": 0.2,
                            "attribute:empathy": 0.2},
            },
            {
                "option_id": "el_salla", "label": "El sallayıp devam et",
                "costs": {},
                "effects": {"relationship:fans": -2},
            },
        ],
    },
    {
        "template_id": "kosu-muhabir",
        "catalog_ids": ["fiz-kosu", "fiz-bisiklet"],
        "weight": 2,
        "requires": {},
        "title": "Parkta bir muhabir",
        "body": "Parkurun sonunda seni bekleyen bir muhabir var. Telefonu elinde, "
                "kayıtta. Transfer söylentisini soruyor.",
        "options": [
            {
                "option_id": "kisa_cevap", "label": "Kısa ve net cevap ver",
                "requires": {"intelligence": 5},
                "costs": {"time": 15.0, "energy": 3.0},
                "effects": {"relationship:media": 3, "attribute:intelligence": 0.2},
            },
            {
                "option_id": "gecistir", "label": "Gülüp geçiştir",
                "costs": {"time": 5.0},
                "effects": {"relationship:media": -1},
            },
            {
                "option_id": "sert_cevap", "label": "Kamerayı kapattır",
                "costs": {"time": 10.0, "energy": 6.0},
                "effects": {"relationship:media": -5, "attribute:courage": 0.3,
                            "condition": -2},
            },
        ],
    },
    {
        "template_id": "arkadas-eski-takim",
        "catalog_ids": ["sos-arkadas", "sos-konser"],
        "weight": 3,
        "requires": {},
        "title": "Masaya oturan takım arkadaşı",
        "body": "Kulüpten iki isim aynı mekânda. Seni görünce masaya çağırıyorlar; "
                "gece uzayacak gibi.",
        "options": [
            {
                "option_id": "katil", "label": "Masaya geç",
                "costs": {"time": 90.0, "energy": 12.0},
                "effects": {"relationship:team": 5, "condition": -5,
                            "money": -4, "attribute:charisma": 0.3},
            },
            {
                "option_id": "bir_saat", "label": "Bir saat otur, erken çık",
                "requires": {"discipline": 3},
                "costs": {"time": 45.0, "energy": 5.0},
                "effects": {"relationship:team": 2, "money": -2},
            },
            {
                "option_id": "reddet", "label": "Yarın antrenman var de",
                "costs": {},
                "effects": {"relationship:team": -2},
            },
        ],
    },

    # --- ev: dar havuz, düşük sıklık (§13.4) -------------------------------
    {
        "template_id": "ev-aile-telefon",
        "catalog_ids": ["ev-film", "ev-oyun", "ev-yemek"],
        "weight": 3,
        "requires": {},
        "title": "Telefon çalıyor",
        "body": "Ekranda annen yazıyor. Saat geç, ama aramış olması iyi bir şey.",
        "options": [
            {
                "option_id": "ac", "label": "Aç ve konuş",
                "costs": {"time": 30.0, "energy": 2.0},
                "effects": {"relationship:family": 4, "condition": 2,
                            "attribute:empathy": 0.2},
            },
            {
                "option_id": "sonra", "label": "Yarın ararım",
                "costs": {},
                "effects": {"relationship:family": -3},
            },
        ],
    },
    {
        "template_id": "ev-menajer-arama",
        "catalog_ids": ["ev-film", "ev-meditasyon", "ev-uyku"],
        "weight": 1,
        "requires": {},
        "title": "Menajerinden mesaj",
        "body": "Menajerin yazmış: bir markanın ilgilendiğini, yarın sabah "
                "konuşmak istediğini söylüyor. Bu gece cevap beklemiyor ama "
                "okunduğunu görmek istiyor.",
        "options": [
            {
                "option_id": "cevapla", "label": "Kısa bir cevap yaz",
                "costs": {"time": 10.0, "energy": 1.0},
                "effects": {"fame:overall": 0.1, "attribute:discipline": 0.2},
            },
            {
                "option_id": "yarin", "label": "Telefonu bırak",
                "costs": {},
                "effects": {"condition": 1},
            },
        ],
    },
]

# --- INV-28/INV-31: validated at import, the way every catalog file is -----
#
# Built as a catalog-shaped view rather than calling validate_catalog on
# ACTIVITY_EVENTS directly: a template carries no costs/effects of its own,
# its OPTIONS do, and the validator reads one item at a time.

from api.config import RELATIONSHIP_KINDS  # noqa: E402 (after data)
from catalog import validate_catalog, validate_requires  # noqa: E402

# §14.5 - the relationship events are answered through the same T5/T6 path, so
# `template()` and `option()` must find them; `for_catalog()` (and with it every
# lifestyle activity's spawn roll) keeps reading ACTIVITY_EVENTS only, because
# their `catalog_ids` are empty by design. Each file validates its own rows.
from content.relationship_events import RELATIONSHIP_EVENTS  # noqa: E402

_BY_TEMPLATE = {t["template_id"]: t for t in ACTIVITY_EVENTS + RELATIONSHIP_EVENTS}
assert len(_BY_TEMPLATE) == len(ACTIVITY_EVENTS) + len(RELATIONSHIP_EVENTS), "duplicate template_id"

_option_items = []
for _tpl in ACTIVITY_EVENTS:
    validate_requires(_tpl.get("requires"), f"activity_event:{_tpl['template_id']}")
    assert _tpl["options"], f"{_tpl['template_id']} has no options"
    assert _tpl["weight"] > 0, f"{_tpl['template_id']} has a non-positive weight"

    _seen = set()
    for _opt in _tpl["options"]:
        _where = f"activity_event:{_tpl['template_id']}:{_opt['option_id']}"
        assert _opt["option_id"] not in _seen, f"{_where} is a duplicate option_id"
        _seen.add(_opt["option_id"])
        _option_items.append({
            "catalog_id": _where,
            "costs": _opt.get("costs", {}),
            "effects": _opt.get("effects", {}),
            "requires": _opt.get("requires", {}),
        })
        _target = _opt.get("starts_relationship")
        assert _target is None or _target == "partner", (
            f"{_where} starts {_target!r}; only partner has a state machine (INV-59)"
        )
        for _key in _opt.get("effects", {}):
            if _key.startswith("relationship:"):
                assert _key.split(":", 1)[1] in RELATIONSHIP_KINDS, (
                    f"{_where} touches unknown relationship {_key!r}"
                )

    # INV-32's sibling: an event whose every option is gated could leave the
    # player looking at a modal they cannot dismiss. The escape hatch has to
    # be ungated for the same reason declining a social offer can never fail
    # (INV-40).
    assert any(not _o.get("requires") for _o in _tpl["options"]), (
        f"activity_event {_tpl['template_id']!r} has no ungated option"
    )

validate_catalog(_option_items, "activity_event")


def template(template_id: str):
    """The authored row behind a stored event. None for an id this file no
    longer carries — a career can hold an event written by an earlier
    version of it (domain/social.template()'s exact shape and reason)."""
    return _BY_TEMPLATE.get(template_id)


def option(template_id: str, option_id: str):
    tpl = _BY_TEMPLATE.get(template_id)
    if tpl is None:
        return None
    return next((o for o in tpl["options"] if o["option_id"] == option_id), None)


def for_catalog(catalog_id: str):
    """Every template that may fire on a given lifestyle activity, in
    authored order (the weighted pick needs a stable list, §12.9's
    _weighted_pick has the same requirement)."""
    return [t for t in ACTIVITY_EVENTS if catalog_id in t["catalog_ids"]]
