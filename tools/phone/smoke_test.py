"""Desktop smoke test for phone_main + the assembled bundle (no iPhone needed).

    python tools/phone/assemble_bundle.py --out build/phone_app
    <python-with-fastapi-uvicorn-pydantic-httpx> tools/phone/smoke_test.py build/phone_app

Boots both back-ends in this one interpreter exactly as on the device, then:
  1. both /health answer, migrations ran into a temp DB;
  2. a career is created and days are advanced until a batch simulation has
     really gone career_engine -> (httpx, other thread/loop) -> match_engine;
  3. the match_engine listener is killed under the supervisor's feet and must
     be re-bound, after which batch simulation works again.
"""
import json
import os
import sqlite3
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

CAREER = "http://127.0.0.1:8001"
MATCH = "http://127.0.0.1:8000"


def call(method, url, body=None, timeout=60):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read() or b"null")


def played_fixtures():
    """Fixtures that are no longer 'scheduled' - read straight from the temp DB."""
    conn = sqlite3.connect(os.environ["CAREER_ENGINE_DB_PATH"])
    try:
        return conn.execute("SELECT COUNT(*) FROM fixture WHERE status != 'scheduled'").fetchone()[0]
    finally:
        conn.close()


def advance_to_match_day(career_id, n=12):
    """Walk the day loop to the user's own fixture; the days in between make
    career_engine batch-simulate every other fixture through match_engine."""
    for _ in range(n):
        status, day = call("GET", f"{CAREER}/careers/{career_id}/day")
        if status == 200 and day.get("is_match_day"):
            return None
        status, body = call("POST", f"{CAREER}/careers/{career_id}/advance", {"to": "next_event"})
        if status != 200:
            return status, body
    return "no match day reached", None


def play_users_match(career_id):
    """M1 -> M2 (the only way past a match day; mirrors tests/conftest.py)."""
    status, nxt = call("GET", f"{CAREER}/careers/{career_id}/matches/next")
    if status != 200:
        return status, nxt
    stats = {"goals": 0, "shots": 10, "shots_on_target": 4, "corners": 5, "dangerous_attacks": 8,
             "total_attacks": 20, "yellow_cards": 1, "red_cards": 0, "penalties": 0, "penalty_goals": 0,
             "fouls": 6, "substitutions": 2, "possession_ticks": 50}
    status, body = call("POST", f"{CAREER}/careers/{career_id}/matches/{nxt['fixture_id']}/result", {
        "match_id": "m_smoke_0001", "score": {"home": 1, "away": 0},
        "stats": {"home": {**stats, "goals": 1}, "away": stats},
        "final_possession_home": 53.1, "final_condition": 54, "interventions": [],
    })
    return (status, body) if status != 200 else None


def read_sse(match_id, want, last_event_id=None, timeout=25):
    """Read `want` ticks from GET /matches/{id}/stream (optionally replaying from
    Last-Event-ID); returns the list of tick seqs seen."""
    req = urllib.request.Request(f"{MATCH}/matches/{match_id}/stream",
                                 headers={"Accept": "text/event-stream",
                                          **({"Last-Event-ID": str(last_event_id)} if last_event_id else {})})
    seqs, event, deadline = [], None, time.monotonic() + timeout
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        for raw in resp:
            line = raw.decode().rstrip("\n")
            if line.startswith("event:"):
                event = line.split(":", 1)[1].strip()
            elif line.startswith("id:") and event == "tick":
                seqs.append(int(line.split(":", 1)[1]))
            if len(seqs) >= want or time.monotonic() > deadline:
                break
    return seqs


def run_smoke(match, career, boot_s, say=print):
    """Checks against already-running listeners. Returns the list of failed checks."""
    failures = []

    def check(label, ok, detail=""):
        say(("PASS " if ok else "FAIL ") + label + (f"  {detail}" if detail else ""))
        if not ok:
            failures.append(label)

    # Same switches tests/conftest.py throws: random daily events (offers, invitations,
    # sponsorships, relationship triggers) stop the advance loop with a 409, and this
    # test is about the plumbing, not the dice. Only constants move; code paths stay real.
    from api import config as career_config  # noqa: E402 - career_engine's, loaded by run()
    from domain import sponsorship  # noqa: E402

    career_config.SOCIAL_OFFER_DAILY_CHANCE = 0.0
    career_config.SOCIAL_CONFLICT_DAILY_CHANCE = 0.0
    career_config.TRIGGERS_ENABLED = False
    sponsorship.DAILY_CHANCE = 0.0

    check("both /health answer",
          call("GET", f"{MATCH}/health")[0] == 200 and call("GET", f"{CAREER}/health")[0] == 200,
          f"boot {boot_s:.2f}s")
    check("migrations ran into the temp DB", Path(os.environ["CAREER_ENGINE_DB_PATH"]).is_file(),
          os.environ["CAREER_ENGINE_DB_PATH"])

    status, options = call("GET", f"{CAREER}/careers/options")
    midfield = next(p for p in options["positions"] if p["position"] == "Orta saha")
    status, created = call("POST", f"{CAREER}/careers", {
        "first_name": "Efe", "last_name": "Kaan", "nationality": "TR", "position": "Orta saha",
        "role": midfield["roles"][0]["role_id"],
        "target_team_id": options["target_teams"][0]["team"]["team_id"], "seed": 7,
    })
    check("career created", status == 201, str(status))
    career_id = created["career_id"]


    before = played_fixtures()
    err = advance_to_match_day(career_id)
    after_first = played_fixtures()
    check("advance batch-simulated fixtures through match_engine", err is None and after_first > before,
          str(err) if err else f"{before} -> {after_first} fixtures played")

    # kill match_engine's listening sockets; the supervisor must re-bind.
    for srv in match._server.servers:
        srv.close()
    time.sleep(0.2)
    check("match listener is really down", not match.accepting())
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline and not match.accepting():
        time.sleep(0.2)
    check("supervisor re-bound match_engine", match.accepting() and match.restarts >= 1, f"restarts={match.restarts}")

    err = play_users_match(career_id) or advance_to_match_day(career_id)
    after_rebind = played_fixtures()
    check("batch simulation works again after the re-bind", err is None and after_rebind > after_first + 1,
          str(err) if err else f"{after_first} -> {after_rebind} fixtures played")

    # A live match must survive the listener re-bind (its run_loop dies with the old
    # event loop; phone_main re-arms it on the new one) and its stream must replay
    # from Last-Event-ID. Offers are switched off (a documented match_engine switch)
    # so the loop never waits for an answer.
    from match_api import config as match_config  # noqa: E402
    match_config.INTERVENTIONS_ENABLED = False
    status, nxt = call("GET", f"{MATCH}/matches/next")
    mid = nxt["match_id"]
    status, _ = call("POST", f"{MATCH}/matches/{mid}/start", {
        "user_side": "home", "effort": 50, "aggression": 50, "focus": None,
        "position": None, "client_seed": 1})
    call("POST", f"{MATCH}/matches/{mid}/speed", {"speed": "fast"})
    first = read_sse(mid, want=3)
    check("live match streams ticks", status == 201 and len(first) >= 3, f"seqs {first}")
    restarts = match.restarts
    for srv in match._server.servers:
        srv.close()
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline and not (match.restarts > restarts and match.accepting()):
        time.sleep(0.2)
    check("match listener re-bound under a live match", match.restarts > restarts)
    resumed = read_sse(mid, want=3, last_event_id=first[-1])
    check("same match keeps ticking after the re-bind, replaying from Last-Event-ID",
          len(resumed) >= 3 and resumed[0] > first[-1] and resumed == sorted(set(resumed)), f"before {first[-1]}, after {resumed}")

    say("RESULT: " + ("FAILED " + ", ".join(failures) if failures else "all passed"))
    return failures



def main():
    bundle = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
    if bundle is None or not (bundle / "phone_main.py").is_file():
        sys.exit("usage: smoke_test.py <assembled bundle dir>")
    os.chdir(tempfile.mkdtemp(prefix="phone_smoke_"))  # serious_python also runs with a writable cwd
    os.environ["PHONE_ROOT"] = str(bundle)
    sys.path.insert(0, str(bundle))
    import phone_main

    phone_main.WATCH_INTERVAL_S = 0.5
    t0 = time.monotonic()
    match, career = phone_main.run(block=False)
    sys.exit(1 if run_smoke(match, career, time.monotonic() - t0) else 0)


if __name__ == "__main__":
    main()
