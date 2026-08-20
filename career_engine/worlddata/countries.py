"""§5.1 C1 - the nationality catalog a new career picks from.

Country was already a column on `team` and `competition` (003_world.sql,
"paralel ligler için (D18)"), always written as the literal 'TR' because v1
only ships one country's world. This file gives that literal a name and a
single place to grow: adding a country here plus its clubs/competitions in
worlddata/teams.py and worlddata/competitions.py is the whole change —
domain/team_assignment.py finds the new country's bottom league by querying
`competition.tier`, never by knowing 'TR'.

`country_code` is what travels over the API and lands in player.nationality;
`nationality` is only the FE-facing adjective ("Türk"), never a key.
"""

COUNTRIES = [
    {"country_code": "TR", "name": "Türkiye", "nationality": "Türk"},
]

# The default the world seeder stamps onto every team/competition row. Once a
# second country ships, _seed_world stops using this and reads each club's own
# country instead — until then it keeps the literal out of the SQL.
DEFAULT_COUNTRY_CODE = "TR"

_COUNTRIES_BY_CODE = {c["country_code"]: c for c in COUNTRIES}

COUNTRY_CODES = tuple(c["country_code"] for c in COUNTRIES)


def get_country(country_code: str):
    """Returns the country dict, or None if the code isn't in the catalog."""
    return _COUNTRIES_BY_CODE.get(country_code)


assert DEFAULT_COUNTRY_CODE in _COUNTRIES_BY_CODE
assert len(_COUNTRIES_BY_CODE) == len(COUNTRIES), "duplicate country_code"
