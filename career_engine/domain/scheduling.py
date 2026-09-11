"""§3.3 - fixture/round generation. Two shapes, matching D18's two formats:

- double round-robin (league): calendar AND pairing both known immediately.
  generate_league_season() returns both competition_round and fixture rows
  in one pass.
- single elimination (cup): calendar known immediately, pairing only for
  the round actually being drawn. generate_cup_calendar() lays out the
  competition_round skeleton (drawn=0); draw_cup_round() produces one
  round's fixtures when it's time (§6.3: a "cup draw day" event, §3.3's
  drawn 0→1). This is what lets INV-12 hold without amortization (D40) —
  a round simply isn't playable until its pairing exists.
"""
import random
from datetime import date, timedelta
from typing import List, Optional, Tuple


def _round_robin_pairs(team_ids: List[str]) -> List[List[Tuple[str, str]]]:
    """Circle method. Returns n-1 rounds (n = len(team_ids), must be even),
    each a list of (home, away) pairs covering every team exactly once."""
    n = len(team_ids)
    assert n % 2 == 0, "round-robin needs an even team count"
    fixed = team_ids[0]
    rotating = list(team_ids[1:])
    rounds = []
    for _ in range(n - 1):
        arranged = [fixed] + rotating
        pairs = []
        for i in range(n // 2):
            a, b = arranged[i], arranged[n - 1 - i]
            pairs.append((a, b) if i % 2 == 0 else (b, a))
        rounds.append(pairs)
        rotating = [rotating[-1]] + rotating[:-1]
    return rounds


def _fixture_id(season_id: str, competition_id: str, round_no: int, home: str, away: str) -> str:
    return f"f_{season_id.replace('/', '')}_{competition_id}_r{round_no}_{home}_{away}"


def generate_league_season(
    career_id: str,
    season_id: str,
    competition_id: str,
    team_ids: List[str],
    starts_on: str,
    days_between_rounds: int = 7,
    skip_from: str = None,
    skip_to: str = None,
) -> Tuple[List[dict], List[dict]]:
    """Full double round-robin: (n-1) rounds for the first leg, (n-1) more
    for the second with home/away swapped. Returns (competition_round rows,
    fixture rows) — both fully populated, since a league's pairing needs no
    draw (unlike the cup).

    `skip_from`/`skip_to` bound a holiday no league round may land in
    (§11.1, INV-33). A round that falls inside it shifts by a whole
    `days_between_rounds` at a time rather than to the next free day, so the
    weekly rhythm survives the break instead of drifting onto a Tuesday —
    and every round after it keeps the same offset, because the shift is
    carried rather than recomputed per round."""
    first_leg = _round_robin_pairs(team_ids)
    start = date.fromisoformat(starts_on)
    holiday_from = date.fromisoformat(skip_from) if skip_from else None
    holiday_to = date.fromisoformat(skip_to) if skip_to else None

    def _in_holiday(day: date) -> bool:
        return holiday_from is not None and holiday_from <= day <= holiday_to

    rounds, fixtures = [], []
    round_no = 1
    shift_days = 0
    for leg in (1, 2):
        for pairs in first_leg:
            kickoff_date = start + timedelta(
                days=days_between_rounds * (round_no - 1) + shift_days
            )
            while _in_holiday(kickoff_date):
                kickoff_date += timedelta(days=days_between_rounds)
                shift_days += days_between_rounds
            rounds.append({
                "career_id": career_id, "season_id": season_id, "competition_id": competition_id,
                "round_no": round_no, "stage": "regular",
                "scheduled_on": kickoff_date.isoformat(), "drawn": 1,
            })
            actual_pairs = pairs if leg == 1 else [(away, home) for home, away in pairs]
            for home, away in actual_pairs:
                fixtures.append({
                    "career_id": career_id,
                    "fixture_id": _fixture_id(season_id, competition_id, round_no, home, away),
                    "season_id": season_id, "competition_id": competition_id,
                    "round_no": round_no, "leg": None,
                    "kickoff_at": f"{kickoff_date.isoformat()}T20:00:00+03:00",
                    "home_team_id": home, "away_team_id": away,
                    "status": "scheduled", "home_score": None, "away_score": None, "match_id": None,
                })
            round_no += 1
    return rounds, fixtures


_CUP_STAGES = ["r32", "r16", "qf", "sf", "final"]


def generate_cup_calendar(
    career_id: str,
    season_id: str,
    competition_id: str,
    team_count: int,
    starts_on: str,
    days_between_rounds: int = 14,
) -> List[dict]:
    """competition_round rows only, all drawn=0 — even round 1. Drawing
    round 1 is a separate, explicit call to draw_cup_round(); the calendar
    existing doesn't imply anyone has been paired yet."""
    start = date.fromisoformat(starts_on)
    rounds = []
    remaining = team_count
    for i, stage in enumerate(_CUP_STAGES):
        if remaining < 2:
            break
        scheduled_on = start + timedelta(days=days_between_rounds * i)
        rounds.append({
            "career_id": career_id, "season_id": season_id, "competition_id": competition_id,
            "round_no": i + 1, "stage": stage,
            "scheduled_on": scheduled_on.isoformat(), "drawn": 0,
        })
        remaining //= 2
    return rounds


def draw_cup_round(
    career_id: str,
    season_id: str,
    competition_id: str,
    round_no: int,
    kickoff_at: str,
    team_ids: List[str],
    rng: Optional[random.Random] = None,
) -> List[dict]:
    """Pairs up this round's entrants (must be even-length) into fixture
    rows. rng is injectable so a career's seed (D9) can make the draw
    reproducible instead of using the module's global randomness."""
    rng = rng or random.Random()
    shuffled = list(team_ids)
    rng.shuffle(shuffled)
    fixtures = []
    for i in range(0, len(shuffled), 2):
        home, away = shuffled[i], shuffled[i + 1]
        fixtures.append({
            "career_id": career_id,
            "fixture_id": _fixture_id(season_id, competition_id, round_no, home, away),
            "season_id": season_id, "competition_id": competition_id,
            "round_no": round_no, "leg": None,
            "kickoff_at": kickoff_at,
            "home_team_id": home, "away_team_id": away,
            "status": "scheduled", "home_score": None, "away_score": None, "match_id": None,
        })
    return fixtures
