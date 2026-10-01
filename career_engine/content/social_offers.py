"""§5.4 R4-R6, §6.3 D53 - the pool of social offers the day loop draws from.

**Why `content/` and not `catalog/`.** The catalog packages are served in
bulk (N3 hands FE every training item, every shop row) because knowing what
exists is part of playing. An offer pool served in bulk would spoil every
offer the player hasn't been made yet — the same reason the news archetypes
live here. What IS served is the single generated offer, the way `news`
serves a published story's title and body.

**Why the prose lives here and not in Flutter.** The dialogue TREES are FE's
(§1.3/D23) because their branching is a UI structure. An offer has no
branching — it is one paragraph and two buttons — and if the paragraph lived
in Dart, adding a template would be an edit in two repositories that must
agree on an id. Here it is one file.

**What FE never sees:** `accept`/`decline` deltas, `weight`, `cooldown_days`
and the score window. R4 serves the text, the labels and the `requires` gate
(so an unaffordable choice can be greyed out) and nothing else — exactly the
split catalog/dialogue.public_catalog() already draws.

Adding a template is an edit to THIS FILE ONLY: eligibility, weighting and
resolution all read the map below rather than naming any template.
"""

SOCIAL_OFFERS = [
    # --- coach ------------------------------------------------------------
    {
        "template_id": "coach_extra_session",
        "relationship_id": "coach",
        "weight": 3, "cooldown_days": 21,
        "min_score": 30, "max_score": 100,
        "title": "Fazladan idman",
        "body": "Antrenör Mert, yarın sabah antrenmandan önce seninle bire bir "
                "çalışmak istiyor. Bitiricilik üzerine, sadece ikiniz.",
        "accept_label": "Sahada olurum",
        "decline_label": "Bu hafta olmaz",
        "accept": {"relationship_delta": 5, "effects": {"condition": -6, "attribute:shooting": 0.6}},
        "decline": {"relationship_delta": -3, "effects": {}},
        "costs": {"time": 120, "energy": 20},
        # "Yarın sabah": a promise about a specific future day, not "now" or
        # "tonight" like the rest of this pool. `plan_days_ahead` is what
        # turns accepting into a scheduled `social_plan` (due the next day)
        # instead of resolving `costs`/`effects` on the spot — see
        # domain/social.py and CONTRACT.md §12.8/D58.
        "plan_days_ahead": 1,
    },
    {
        "template_id": "coach_video_review",
        "relationship_id": "coach",
        "weight": 2, "cooldown_days": 28,
        "min_score": 0, "max_score": 100,
        "title": "Video toplantısı",
        "body": "Antrenör son maçın görüntülerini birlikte izlemeyi öneriyor. "
                "Duyacakların hoşuna gitmeyebilir.",
        "accept_label": "İzleyelim",
        "decline_label": "Gerek yok",
        "accept": {"relationship_delta": 4, "effects": {}},
        "decline": {"relationship_delta": -4, "effects": {}},
        "costs": {"time": 120},
        # The invitation names a day and a lifestyle activity: accepting books
        # it, attending runs that activity (costs/effects come from the lifestyle
        # catalog) and opens its "it was done" dialogue.
        "catalog_id": "ev-mac-analizi", "plan_days_ahead": 1,
    },

    # --- team -------------------------------------------------------------
    {
        "template_id": "team_dinner",
        "relationship_id": "team",
        "weight": 3, "cooldown_days": 21,
        "min_score": 20, "max_score": 100,
        "title": "Takım yemeği",
        "body": "Kaptan Burak akşam için sofra kuruyor. Kadronun yarısı geliyor; "
                "gelmeyenler bir hafta konuşulur.",
        "accept_label": "Varım",
        "decline_label": "Bu akşam pas",
        "accept": {"relationship_delta": 6, "effects": {}},
        "decline": {"relationship_delta": -4, "effects": {}},
        "costs": {"time": 120},
        "catalog_id": "kulup-kaptan-yemegi", "plan_days_ahead": 2,
    },
    {
        "template_id": "team_console_night",
        "relationship_id": "team",
        "weight": 2, "cooldown_days": 14,
        "min_score": 30, "max_score": 100,
        "title": "Konsol turnuvası",
        "body": "Takımın genç grubu odada turnuva kuruyor. Kısa sürer, öyle diyorlar.",
        "accept_label": "Kolları sıvarım",
        "decline_label": "Erken yatacağım",
        "accept": {"relationship_delta": 3, "effects": {}},
        "decline": {"relationship_delta": -1, "effects": {}},
        "costs": {"time": 180},
        "catalog_id": "kulup-konsol-turnuvasi", "plan_days_ahead": 1,
    },

    # --- media ------------------------------------------------------------
    {
        "template_id": "media_interview_request",
        "relationship_id": "media",
        "weight": 3, "cooldown_days": 21,
        "min_score": 0, "max_score": 100,
        "title": "Podcast daveti",
        "body": "Spor Manşet'ten Ayça Kılıç, podcast kaydına konuk olmanı istiyor. "
                "Sorular önceden gelmiyor.",
        "accept_label": "Konuşurum",
        "decline_label": "Yorum yok",
        "accept": {"relationship_delta": 6, "effects": {}},
        "decline": {"relationship_delta": -5, "effects": {}},
        "costs": {"time": 120},
        "requires": {"empathy": 3},
        "catalog_id": "medya-podcast", "plan_days_ahead": 2,
    },

    # --- fans -------------------------------------------------------------
    {
        "template_id": "fans_school_visit",
        "relationship_id": "fans",
        "weight": 3, "cooldown_days": 28,
        "min_score": 0, "max_score": 100,
        "title": "Mahalle maçı",
        "body": "Taraftar grubu mahalle çocuklarıyla bir futbol günü düzenliyor. "
                "Çocuklar formanı giymiş, seni bekliyorlar.",
        "accept_label": "Giderim",
        "decline_label": "Programım dolu",
        "accept": {"relationship_delta": 7, "effects": {}},
        "decline": {"relationship_delta": -5, "effects": {}},
        "costs": {"time": 90},
        "catalog_id": "gece-sokak-futbolu", "plan_days_ahead": 2,
    },

    # --- partner ----------------------------------------------------------
    {
        "template_id": "partner_evening_out",
        "relationship_id": "partner",
        "weight": 3, "cooldown_days": 14,
        "min_score": 0, "max_score": 100,
        "title": "Sinema daveti",
        "body": "Elif yarın akşam sinemaya gitmeyi öneriyor. Uzun bir haftaydı, "
                "ikiniz için de.",
        "accept_label": "Çıkalım",
        "decline_label": "Yorgunum",
        "accept": {"relationship_delta": 7, "effects": {}},
        "decline": {"relationship_delta": -5, "effects": {}},
        "costs": {"time": 180},
        "catalog_id": "sehir-sinema", "plan_days_ahead": 1,
    },

    # --- family -----------------------------------------------------------
    {
        "template_id": "family_sunday_call",
        "relationship_id": "family",
        "weight": 3, "cooldown_days": 10,
        "min_score": 0, "max_score": 100,
        "title": "Annenden telefon",
        "body": "Anne arıyor. Maçı televizyondan izlemiş, konuşacak çok şeyi var.",
        # No `costs` at all: a phone call is not a thing you schedule a day
        # around, and charging for it would make the cheapest way to keep a
        # relationship alive cost the same as a night out.
        "accept_label": "Açarım",
        "decline_label": "Sonra ararım",
        "accept": {"relationship_delta": 6, "effects": {}},
        "decline": {"relationship_delta": -4, "effects": {}},
    },
]

# Every relationship needs at least one template, or has_pending_request could
# never be true for some cards — a mechanic that is silently unreachable for a
# third of its surface.
assert len({t["template_id"] for t in SOCIAL_OFFERS}) == len(SOCIAL_OFFERS)

from api.config import RELATIONSHIP_KINDS  # noqa: E402 (after data, INV-28)

assert {t["relationship_id"] for t in SOCIAL_OFFERS} == set(RELATIONSHIP_KINDS), (
    "every relationship kind needs at least one offer template"
)

from content import validate_social_offers  # noqa: E402

validate_social_offers(SOCIAL_OFFERS)


# A template that names a lifestyle activity (`catalog_id`) is an invitation TO
# that activity: accepting must schedule it (`plan_days_ahead`), and the
# relationship must be one the activity can be done with, or the plan could
# never be attended.
from catalog.lifestyle import LIFESTYLE_ITEMS  # noqa: E402

_LIFESTYLE_BY_ID = {i["catalog_id"]: i for i in LIFESTYLE_ITEMS}
for _t in SOCIAL_OFFERS:
    _cid = _t.get("catalog_id")
    if _cid is None:
        continue
    _item = _LIFESTYLE_BY_ID.get(_cid)
    assert _item is not None, f"social_offer {_t['template_id']!r} names unknown activity {_cid!r}"
    assert _t.get("plan_days_ahead"), f"social_offer {_t['template_id']!r} names an activity but is not a plan"
    assert _item.get("mode", "S") != "S" and _t["relationship_id"] in _item["with"], (
        f"{_cid!r} cannot be done with {_t['relationship_id']!r}"
    )
    assert not _t["accept"].get("effects"), (
        f"social_offer {_t['template_id']!r}: the activity supplies the effects"
    )
