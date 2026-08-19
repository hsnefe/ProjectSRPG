"""§7 E12 - HTTP client for match_engine's background batch simulation.

Used only by T3/§6.7 (D40): the user's own match never goes through this
client (D33 — FE talks to match_engine directly for that, career_engine
only sees the result via M2). This is exclusively for the fixtures the
user isn't playing.

⚠️ As of this branch, match_engine does NOT yet expose E12 (§7's "v1.2
EKİ" is separate repo work, out of scope here) — this client is written
correctly against the documented contract and will work once match_engine
adds it. Until then, calls fail with engine_unavailable. Tests mock this
module's simulate_batch() rather than requiring a live match_engine.
"""
from typing import List

import httpx

from api import config, errors


def simulate_batch(matches: List[dict]) -> List[dict]:
    """matches: [{"ref": fixture_id, "teams": {"home": {...6 alan...},
    "away": {...}}, "seed": int}]. Returns match_engine's `results` list
    unchanged."""
    if not matches:
        return []
    try:
        resp = httpx.post(
            f"{config.MATCH_ENGINE_BASE_URL}/simulate/batch",
            json={"matches": matches},
            timeout=config.MATCH_ENGINE_TIMEOUT_S,
        )
    except httpx.HTTPError as exc:
        raise errors.engine_unavailable(f"could not reach match_engine: {exc}") from exc
    if resp.status_code != 200:
        raise errors.engine_unavailable(f"match_engine /simulate/batch returned {resp.status_code}")
    return resp.json()["results"]
