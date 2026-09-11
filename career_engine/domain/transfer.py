"""§11.7 - offers, renewals and where the player plays next.

D48 keeps the subject to the user alone: there is still no squad and no NPC
transfer. A club that bids here bids for one player.

The offer's terms come from the on-pitch attributes, fame, and last season's
appearances and goals. The person (kişi) attributes are deliberately not
read — §3.2's "contract negotiation" promise is a later version's job, and
§11.13 puts it out of scope. The wage scale sits on top of
STARTING_WEEKLY_WAGE with a tier multiplier; the real formula waits on
⟦AÇIK-8⟧ (market value), and filling it in later changes no field, so no
version moves with it.

The renewal counter-offer is this repo's addition rather than §11.7's: the
spec defines accept and nothing else, but a club that can only present a
take-it-or-leave-it deal is not a negotiation. One counter, then the club's
answer stands.
"""
import random
import sqlite3
from typing import List, Optional

from api import config, errors, serializers
from api.ids import new_transfer_offer_id
from domain import contracts, fame as fame_mod, relationships, season as season_mod

OPEN = "open"
ACCEPTED = "accepted"
EXPIRED = "expired"

# How many rival clubs look at the player at once. Enough for a choice,
# small enough that the list is read rather than scrolled.
MAX_RIVAL_OFFERS = 3

# Offers run for whole seasons (D50); two or three is the range a club in
# this world commits to.
OFFER_LENGTHS = (2, 3)

# A counter-offer asks for this much more. Not negotiable further: the point
# is one push, not a haggling loop.
COUNTER_MULTIPLIER = 1.25


def _saha_average(conn: sqlite3.Connection, career_id: str) -> float:
    """The on-pitch attributes only. A club is buying a footballer."""
    row = conn.execute(
        "SELECT AVG(value) AS avg FROM player_attribute "
        "WHERE career_id = ? AND player_id = ? AND attribute_key IN "
        "('condition','strength','flexibility','shooting','passing','dribbling','tackling')",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    return float(row["avg"] or 0.0)


def _last_season_output(conn: sqlite3.Connection, career_id: str) -> tuple:
    """Appearances and goals across every competition of the most recent
    season the player actually featured in."""
    row = conn.execute(
        "SELECT COALESCE(SUM(appearances), 0) AS apps, COALESCE(SUM(goals), 0) AS goals "
        "FROM player_season_stat WHERE career_id = ? AND player_id = ? "
        "AND season_id = (SELECT season_id FROM player_season_stat "
        "                 WHERE career_id = ? AND player_id = ? "
        "                 ORDER BY season_id DESC LIMIT 1)",
        (career_id, config.USER_PLAYER_ID, career_id, config.USER_PLAYER_ID),
    ).fetchone()
    return int(row["apps"] or 0), int(row["goals"] or 0)


def _tier_multiplier(tier: Optional[int]) -> float:
    """A top-flight club pays more for the same player. ⟦AÇIK-8⟧ will
    replace this whole scale; until then it is the one thing that makes a
    promotion worth something in wage terms."""
    return {1: 2.4, 2: 1.0}.get(tier, 1.0)


def valuation(conn: sqlite3.Connection, career_id: str) -> float:
    """A single number the terms are built from. Attributes lead, output and
    fame adjust. Placeholder for ⟦AÇIK-8⟧ and marked as such — the shape of
    the offer does not depend on it, only the numbers inside."""
    saha = _saha_average(conn, career_id)
    apps, goals = _last_season_output(conn, career_id)
    fame = fame_mod.get_value(conn, career_id, config.USER_PLAYER_ID, "overall")

    return (
        saha
        + min(20.0, apps * 0.4)
        + min(25.0, goals * 1.5)
        + min(15.0, float(fame or 0) * 0.15)
    )


def _terms_for(
    conn: sqlite3.Connection, career_id: str, tier: Optional[int], rng: random.Random
) -> dict:
    """One club's offer. The spread comes from the club, not the dice: two
    clubs in the same tier differ by how much they want the player, which is
    the rng's whole job here."""
    base = config.STARTING_WEEKLY_WAGE * _tier_multiplier(tier)
    strength = valuation(conn, career_id) / 55.0
    wage = max(config.STARTING_WEEKLY_WAGE, int(base * strength * rng.uniform(0.85, 1.2)))
    return {
        "weekly_wage": wage,
        "appearance_bonus": max(1, round(wage * 0.15)),
        "goal_bonus": max(1, round(wage * 0.30)),
        "release_clause": wage * 20,
        "length_seasons": rng.choice(OFFER_LENGTHS),
    }


def _row_to_offer(conn: sqlite3.Connection, career_id: str, row: sqlite3.Row) -> dict:
    competition_id = conn.execute(
        "SELECT e.competition_id FROM competition_entry e "
        "JOIN competition c ON c.career_id = e.career_id "
        "AND c.competition_id = e.competition_id "
        "WHERE e.career_id = ? AND e.team_id = ? AND c.kind = 'league' "
        "ORDER BY e.season_id DESC LIMIT 1",
        (career_id, row["team_id"]),
    ).fetchone()
    return {
        "offer_id": row["offer_id"],
        "team": serializers.fetch_team_ref(conn, career_id, row["team_id"]),
        "competition": (
            serializers.fetch_competition_ref(conn, career_id, competition_id["competition_id"])
            if competition_id else None
        ),
        "weekly_wage": row["weekly_wage"],
        "appearance_bonus": row["appearance_bonus"],
        "goal_bonus": row["goal_bonus"],
        "release_clause": row["release_clause"],
        "length_seasons": row["length_seasons"],
        "expires_at": row["expires_at"],
        "status": row["status"],
        "is_renewal": bool(row["is_renewal"]),
        "counter_used": bool(row["counter_used"]),
    }


def list_open(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT * FROM transfer_offer WHERE career_id = ? AND status = ? "
        "ORDER BY is_renewal DESC, weekly_wage DESC",
        (career_id, OPEN),
    ).fetchall()
    return [_row_to_offer(conn, career_id, r) for r in rows]


def get(conn: sqlite3.Connection, career_id: str, offer_id: str) -> Optional[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM transfer_offer WHERE career_id = ? AND offer_id = ?",
        (career_id, offer_id),
    ).fetchone()


def _insert(
    conn: sqlite3.Connection, career_id: str, team_id: str, opened_on: str,
    window: str, terms: dict, is_renewal: bool,
) -> str:
    offer_id = new_transfer_offer_id()
    expires_at = contracts.expiry_for(
        conn, career_id, opened_on, terms["length_seasons"]
    )
    conn.execute(
        "INSERT INTO transfer_offer (career_id, offer_id, opened_on, window, team_id, "
        "weekly_wage, appearance_bonus, goal_bonus, release_clause, length_seasons, "
        "expires_at, status, is_renewal, counter_used) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)",
        (career_id, offer_id, opened_on, window, team_id,
         terms["weekly_wage"], terms["appearance_bonus"], terms["goal_bonus"],
         terms["release_clause"], terms["length_seasons"], expires_at, OPEN,
         int(is_renewal)),
    )
    return offer_id


def generate(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: int,
    window: str, include_renewal: bool = True,
) -> List[str]:
    """Opens this window's offers. Idempotent per window: if anything is
    already open, nobody bids again — a window is one round of interest, not
    a daily auction.

    The current club is among the bidders (§11.7), and its offer is flagged
    as a renewal: that is the one the player can push back on once, and the
    one that keeps them where they are.
    """
    if list_open(conn, career_id):
        return []

    rng = random.Random(f"{seed}:transfer:{window}:{on_date}")
    user_team_id = serializers.fetch_user_team_id(conn, career_id)
    created = []

    if include_renewal and user_team_id:
        tier = conn.execute(
            "SELECT c.tier FROM competition_entry e "
            "JOIN competition c ON c.career_id = e.career_id "
            "AND c.competition_id = e.competition_id "
            "WHERE e.career_id = ? AND e.team_id = ? AND c.kind = 'league' "
            "ORDER BY e.season_id DESC LIMIT 1",
            (career_id, user_team_id),
        ).fetchone()
        created.append(_insert(
            conn, career_id, user_team_id, on_date, window,
            _terms_for(conn, career_id, tier["tier"] if tier else None, rng),
            is_renewal=True,
        ))

    # Rivals are drawn from the leagues, never the cup entry list, and never
    # the player's own club (that bid is the renewal above).
    rivals = conn.execute(
        "SELECT e.team_id, c.tier FROM competition_entry e "
        "JOIN competition c ON c.career_id = e.career_id "
        "AND c.competition_id = e.competition_id "
        "WHERE e.career_id = ? AND c.kind = 'league' AND e.team_id != ? "
        "AND e.season_id = (SELECT season_id FROM career_state WHERE career_id = ?) "
        "ORDER BY e.team_id",
        (career_id, user_team_id or "", career_id),
    ).fetchall()
    if not rivals:
        return created

    # How many clubs come in scales with the player: a squad filler gets one
    # look, a season's top scorer gets the full field.
    interest = valuation(conn, career_id) / 100.0
    count = max(1, min(MAX_RIVAL_OFFERS, round(interest * MAX_RIVAL_OFFERS)))
    for row in rng.sample(list(rivals), min(count, len(rivals))):
        created.append(_insert(
            conn, career_id, row["team_id"], on_date, window,
            _terms_for(conn, career_id, row["tier"], rng),
            is_renewal=False,
        ))
    return created


def counter(
    conn: sqlite3.Connection, career_id: str, offer_id: str, seed: int
) -> dict:
    """Ask for more, once. The club's answer comes from the coach
    relationship, the player's trust with him, and last season's output —
    the same things that decide whether he plays you.

    Seeded on the offer, so the answer cannot be re-rolled and does not need
    a separate guard: `counter_used` closes the door either way.
    """
    row = get(conn, career_id, offer_id)
    if row is None:
        raise errors.offer_not_found(offer_id)
    if row["status"] != OPEN:
        raise errors.offer_not_open(offer_id)
    if row["counter_used"]:
        raise errors.offer_not_open(offer_id)

    coach_score = relationships.get_score(conn, career_id, "coach")
    trust = relationships.get_traits(conn, career_id, "coach")["trust"]
    _, goals = _last_season_output(conn, career_id)

    chance = max(0.05, min(0.85, 0.10 + coach_score / 300.0 + trust / 300.0 + goals * 0.02))
    accepted = random.Random(f"{seed}:counter:{offer_id}").random() < chance

    if accepted:
        wage = round(row["weekly_wage"] * COUNTER_MULTIPLIER)
        conn.execute(
            "UPDATE transfer_offer SET weekly_wage = ?, appearance_bonus = ?, "
            "goal_bonus = ?, release_clause = ?, counter_used = 1 "
            "WHERE career_id = ? AND offer_id = ?",
            (wage, max(1, round(wage * 0.15)), max(1, round(wage * 0.30)),
             wage * 20, career_id, offer_id),
        )
    else:
        conn.execute(
            "UPDATE transfer_offer SET counter_used = 1 WHERE career_id = ? AND offer_id = ?",
            (career_id, offer_id),
        )

    return {
        "accepted": accepted,
        "offer": _row_to_offer(conn, career_id, get(conn, career_id, offer_id)),
    }


def accept(conn: sqlite3.Connection, career_id: str, offer_id: str, on_date: str) -> dict:
    """S4. One transaction: the player moves, the contract is written, this
    offer closes and every other open one expires — a club that has been
    turned down is not still waiting."""
    row = get(conn, career_id, offer_id)
    if row is None:
        raise errors.offer_not_found(offer_id)
    if row["status"] != OPEN:
        raise errors.offer_not_open(offer_id)

    phase = season_mod.derive_phase(conn, career_id, on_date)
    if season_mod.transfer_window(phase) is None:
        raise errors.no_transfer_window()

    conn.execute(
        "UPDATE player SET team_id = ? WHERE career_id = ? AND player_id = ?",
        (row["team_id"], career_id, config.USER_PLAYER_ID),
    )
    contract = contracts.sign(
        conn, career_id, row["team_id"], on_date, row["expires_at"],
        row["weekly_wage"], row["appearance_bonus"], row["goal_bonus"],
        row["release_clause"],
    )
    conn.execute(
        "UPDATE transfer_offer SET status = ? WHERE career_id = ? AND offer_id = ?",
        (ACCEPTED, career_id, offer_id),
    )
    conn.execute(
        "UPDATE transfer_offer SET status = ? WHERE career_id = ? AND status = ?",
        (EXPIRED, career_id, OPEN),
    )

    competition_id = conn.execute(
        "SELECT e.competition_id FROM competition_entry e "
        "JOIN competition c ON c.career_id = e.career_id "
        "AND c.competition_id = e.competition_id "
        "WHERE e.career_id = ? AND e.team_id = ? AND c.kind = 'league' "
        "ORDER BY e.season_id DESC LIMIT 1",
        (career_id, row["team_id"]),
    ).fetchone()

    return {
        "team": serializers.fetch_team_ref(conn, career_id, row["team_id"]),
        "competition": (
            serializers.fetch_competition_ref(conn, career_id, competition_id["competition_id"])
            if competition_id else None
        ),
        "contract": contract,
    }


def expire_all(conn: sqlite3.Connection, career_id: str) -> None:
    """Closes the window: whatever was not taken is gone. Called when the
    phase leaves a transfer window, so an old bid cannot be accepted three
    months later."""
    conn.execute(
        "UPDATE transfer_offer SET status = ? WHERE career_id = ? AND status = ?",
        (EXPIRED, career_id, OPEN),
    )
