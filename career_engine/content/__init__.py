"""Story-archetype validation, run the moment content/news_stories.py is
imported — catalog/__init__.py's pattern, applied to a second data package.

Why `content/` and not `catalog/`: `catalog/` holds career-independent
static data that is SERVED to FE through `GET /catalog/{kind}` (N3). News
templates are the opposite of that. They are never served — publishing the
archetype table would spoil every story the player has not seen yet, the
same reason catalog/dialogue.py refuses to publish its deltas. Two packages
with two different audiences (`catalog/` = FE, `content/` = the generator)
beats one package with a "do not serve these rows" comment.

The validation is INV-28's spirit: an archetype with an unknown category,
an unknown outlet, a malformed effect key or a headline referencing a slot
the generator cannot fill fails IMPORT, not runtime. A news generator that
silently skips a broken template would produce a quieter game rather than a
loud error, and nobody would ever notice the template was dead.
"""
import string

from catalog import _is_known_effect_key
from content.news_outlets import OUTLET_IDS

# §3.5 / CONTRACT.md — the six categories a `news` row may carry. The first
# four shipped with the table; 'Magazin' and 'Yaşam' arrive with this layer.
# FE's news_style.dart falls back to a neutral tone for anything it does not
# know, so adding a category is forward-compatible by construction — but
# both this set and that file must be updated together for the new ones to
# get their own icon.
CATEGORIES = frozenset({"Transfer", "Maç", "Röportaj", "Analiz", "Magazin", "Yaşam"})

# §1.2 — the events a story can hang off. `generate(trigger=...)` refuses an
# unknown one, so this tuple is the whole vocabulary of "when can news
# happen". Adding a trigger means adding a call site; there is no dynamic
# discovery.
TRIGGERS = frozenset({
    "match_played",     # M2 — the user's own match, right after the result lands
    "match_missed",     # T3 — advanced off a match day (§6.1)
    "interview",        # R3 with relationship_id == 'media'
    "dialogue",         # R3 with any other relationship
    "lifestyle",        # T2, a lifestyle catalog item
    "training",         # T2, a training catalog item
    "purchase",         # T2 POST /purchases
    "day_tick",         # T3 — every advanced day, the ambient news of the world
    "money_trouble",    # _pay_upkeep repossessed something
    "upkeep_warning",   # the Monday the budget was warned about
})

# The slot vocabulary a headline may use. Declared HERE rather than in
# domain/news.py so the dependency runs content -> (nothing): the data
# package must not import the domain layer. domain/news.py's slot builder
# is asserted against this set (see tests/test_news_generation.py), which
# makes the two halves of the contract check each other.
SLOT_KEYS = frozenset({
    # kimlik
    "player", "first_name", "last_name", "position", "role", "age",
    # kulüp ve çevresi
    "team", "team_short", "coach", "captain", "league", "rank",
    # kişiler
    "partner", "mother", "reporter", "outlet",
    # transfer
    "rival", "rival_short", "clause", "wage",
    # maç
    "opponent", "opponent_short", "score", "scoreline", "competition",
    # kariyer sayıları
    "goals", "assists", "appearances", "money",
    # tetikleyiciye özel
    "item",
})

_FORMATTER = string.Formatter()

MIN_HEADLINE_VARIANTS = 3


def _headline_slots(headline: str) -> set:
    """Every {slot} name a headline template references. Raises ValueError
    on a malformed template (an unbalanced brace) rather than letting it
    reach str.format_map at runtime, where it would take down a day tick."""
    try:
        parsed = list(_FORMATTER.parse(headline))
    except ValueError as exc:
        raise ValueError(f"malformed headline template {headline!r}: {exc}") from exc
    names = set()
    for _literal, field_name, _spec, _conv in parsed:
        if field_name is None:
            continue
        if not field_name:
            raise ValueError(f"headline {headline!r} uses a positional {{}} slot; name it")
        # "{player}" only — no attribute/index access, so the slot dict stays
        # a flat str->str map and a typo can't resolve to something truthy.
        names.add(field_name.split(".", 1)[0].split("[", 1)[0])
    return names


def validate_stories(stories: list) -> None:
    seen = set()
    for story in stories:
        story_id = story.get("story_id")
        where = f"news_story:{story_id!r}"
        if not story_id:
            raise ValueError("a story archetype is missing its story_id")
        if story_id in seen:
            raise ValueError(f"duplicate story_id {story_id!r}")
        seen.add(story_id)

        if story["category"] not in CATEGORIES:
            raise ValueError(f"{where} has unknown category {story['category']!r}")

        if not story["triggers"]:
            raise ValueError(f"{where} has no triggers")
        for trigger in story["triggers"]:
            if trigger not in TRIGGERS:
                raise ValueError(f"{where} has unknown trigger {trigger!r}")

        if not isinstance(story["weight"], int) or story["weight"] < 1:
            raise ValueError(f"{where} has weight {story['weight']!r}, must be an int >= 1")
        if not isinstance(story["cooldown_days"], int) or story["cooldown_days"] < 0:
            raise ValueError(f"{where} has a negative or non-integer cooldown_days")

        if not story["outlets"]:
            raise ValueError(f"{where} lists no outlets")
        for outlet_id in story["outlets"]:
            if outlet_id not in OUTLET_IDS:
                raise ValueError(f"{where} has unknown outlet {outlet_id!r}")

        headlines = story["headlines"]
        if len(headlines) < MIN_HEADLINE_VARIANTS:
            raise ValueError(
                f"{where} has {len(headlines)} headline(s); at least "
                f"{MIN_HEADLINE_VARIANTS} are required so the same event does "
                "not print the same words twice in one career"
            )
        if len(set(headlines)) != len(headlines):
            raise ValueError(f"{where} repeats a headline variant verbatim")
        for headline in headlines:
            unknown = _headline_slots(headline) - SLOT_KEYS
            if unknown:
                raise ValueError(f"{where} headline uses unknown slot(s) {sorted(unknown)}")

        if not callable(story["applies"]):
            raise ValueError(f"{where} has a non-callable `applies`")
        if not callable(story["body"]):
            raise ValueError(f"{where} has a non-callable `body`")

        # Same key space as a catalog item's effects (INV-28), reusing
        # catalog/__init__.py's own predicate so the two never drift. A
        # news effect is applied through fame.apply()/relationships
        # .apply_delta() exactly like a catalog item's is (INV-24/INV-15).
        for key in story.get("effects", {}):
            if not _is_known_effect_key(key):
                raise ValueError(f"{where} has unknown effect key {key!r}")
