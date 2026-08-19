from domain import formulas


def test_compute_team_rating_is_identity_d37():
    club = {"attack": 68.4, "midfield": 71.0, "defense": 64.2, "goalkeeper": 66.0}
    assert formulas.compute_team_rating(club) == club


def test_compute_team_rating_ignores_extra_keys():
    # A caller might pass the full team row (name, mentality, colors, ...);
    # only the four rating fields should come back.
    club = {
        "attack": 68.4, "midfield": 71.0, "defense": 64.2, "goalkeeper": 66.0,
        "name": "FK Yıldız", "mentality": "balanced",
    }
    result = formulas.compute_team_rating(club)
    assert set(result.keys()) == {"attack", "midfield", "defense", "goalkeeper"}


def test_compute_market_value_returns_none_until_acik8():
    result = formulas.compute_market_value(
        attributes={"shooting": 50.0}, age=21, contract_days_remaining=472, fame=0.0
    )
    assert result is None
