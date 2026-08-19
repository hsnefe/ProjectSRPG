import random

from domain import scheduling
from worlddata.competitions import BIRINCI_LIG, CUP_TEAM_IDS, SUPER_LIG, ULUSAL_KUPA
from worlddata.teams import TIER1_TEAMS, TIER2_TEAMS


def _team_ids(teams):
    return [t["team_id"] for t in teams]


def test_super_lig_season_matches_contract_count():
    # §7: 18 takım, 34 hafta, 306 maç.
    rounds, fixtures = scheduling.generate_league_season(
        "c1", "25/26", SUPER_LIG, _team_ids(TIER1_TEAMS), "2026-08-01"
    )
    assert len(rounds) == 34
    assert len(fixtures) == 306


def test_birinci_lig_season_matches_contract_count():
    # §7: 14 takım, 26 hafta, 182 maç.
    rounds, fixtures = scheduling.generate_league_season(
        "c1", "25/26", BIRINCI_LIG, _team_ids(TIER2_TEAMS), "2026-08-01"
    )
    assert len(rounds) == 26
    assert len(fixtures) == 182


def test_league_season_every_team_plays_every_other_team_twice():
    ids = _team_ids(TIER2_TEAMS)
    _, fixtures = scheduling.generate_league_season("c1", "25/26", BIRINCI_LIG, ids, "2026-08-01")

    seen = {}
    for f in fixtures:
        key = tuple(sorted((f["home_team_id"], f["away_team_id"])))
        seen[key] = seen.get(key, 0) + 1

    from itertools import combinations
    expected_pairs = set(combinations(sorted(ids), 2))
    assert set(seen.keys()) == expected_pairs
    assert all(count == 2 for count in seen.values())


def test_league_season_each_team_plays_exactly_once_per_round():
    ids = _team_ids(TIER2_TEAMS)
    rounds, fixtures = scheduling.generate_league_season("c1", "25/26", BIRINCI_LIG, ids, "2026-08-01")
    by_round = {}
    for f in fixtures:
        by_round.setdefault(f["round_no"], []).append(f)

    for round_no, round_fixtures in by_round.items():
        teams_in_round = [t for fx in round_fixtures for t in (fx["home_team_id"], fx["away_team_id"])]
        assert sorted(teams_in_round) == sorted(ids)


def test_cup_calendar_has_five_stages_for_32_teams():
    # §7: Ulusal Kupa, 32 takım, 5 tur.
    rounds = scheduling.generate_cup_calendar("c1", "25/26", ULUSAL_KUPA, len(CUP_TEAM_IDS), "2026-08-15")
    assert [r["stage"] for r in rounds] == ["r32", "r16", "qf", "sf", "final"]
    assert all(r["drawn"] == 0 for r in rounds)


def test_draw_cup_round_pairs_every_entrant_exactly_once():
    fixtures = scheduling.draw_cup_round(
        "c1", "25/26", ULUSAL_KUPA, 1, "2026-08-15T20:00:00+03:00",
        CUP_TEAM_IDS, rng=random.Random(42),
    )
    assert len(fixtures) == len(CUP_TEAM_IDS) // 2
    paired_teams = [t for fx in fixtures for t in (fx["home_team_id"], fx["away_team_id"])]
    assert sorted(paired_teams) == sorted(CUP_TEAM_IDS)


def test_draw_cup_round_is_deterministic_for_same_seed():
    a = scheduling.draw_cup_round("c1", "25/26", ULUSAL_KUPA, 1, "x", CUP_TEAM_IDS, rng=random.Random(7))
    b = scheduling.draw_cup_round("c1", "25/26", ULUSAL_KUPA, 1, "x", CUP_TEAM_IDS, rng=random.Random(7))
    assert a == b
