# career_engine

Career/world back-end for ProjectSRPG — careers, players, competitions,
relationships, and the day-by-day time loop. See [CONTRACT.md](CONTRACT.md)
for the full API contract, schema, and decision record (D1-D43, INV-1
through INV-32, and the remaining open items in §10).

`match_engine` (sibling directory) remains the stateless single-match
simulator; this service owns everything that persists between matches —
the world, the calendar, money, relationships, attributes.

## Running

```
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt   # .venv/bin/pip on macOS/Linux
.venv/Scripts/python run_server.py               # .venv/bin/python on macOS/Linux
```

Serves on `http://127.0.0.1:8001`. The SQLite file (`career.db`, gitignored)
and its schema are created automatically on first startup.

## Tests

```
.venv/Scripts/python -m pytest -q
```

108 tests: one file per domain module and per router, plus
`tests/test_end_to_end.py` — a single session walking every domain area in
sequence (create a career, train, shop, play a match, advance the world,
read the results, delete the career and verify INV-9 holds exhaustively).

## Structure

```
api/          FastAPI app, routers (one per §5 section), request schemas,
              shared response builders (serializers.py), error types
domain/       Business logic — one module per "single write path"
              (wallet, relationships, fame, attributes, condition,
              day_budget) plus the bigger flows (onboarding, daytime,
              matches, scheduling) and engine_client (match_engine E12)
catalog/      Static reference data: training/lifestyle/shop items,
              dialogue outcomes, match_engine's action/outcome vocabulary
worlddata/    The fixed v1 world: 32 teams, 3 competitions, starting
              attributes, the five relationship seed profiles
db/           SQLite connection setup + migrations (001-005, applied in
              order, tracked in an internal _schema_migrations table)
tests/        conftest.py's fixtures (db_conn, api_client, mock_engine)
              plus one test file per domain module / router
```

## ⚠️ Known limitation: match_engine's E11/E12 don't exist yet

CONTRACT.md §7 documents two additions match_engine needs — `POST /matches`
(E11, used by nothing in *this* repo directly; FE calls it) and
`POST /simulate/batch` (E12, used by `domain/engine_client.py` for every
fixture the user isn't playing). Adding them is separate repo work,
out of scope for this branch.

Until match_engine has E12, `POST /careers/{cid}/advance` and
`POST /careers/{cid}/matches/{fid}/result` will fail with
`502 engine_unavailable` against a real match_engine server — the client
code is written correctly against the documented contract and needs
nothing further on this side once E12 lands. Tests don't depend on a live
match_engine: `tests/conftest.py`'s `mock_engine` fixture stands in for
`domain.engine_client.simulate_batch()`.

## Known follow-ups (not bugs, deliberately out of scope)

- **Season rollover isn't implemented.** `POST /advance` stops cleanly at
  `stop_reason: "season_end"` when it reaches the season boundary, but
  promotion/relegation, next-season fixture generation, and contract/age
  updates aren't built — CONTRACT.md documents *that* they happen "within
  that call" but not the generation algorithm itself. See
  `domain/daytime.py`'s module docstring.
- **⟦AÇIK-5⟧, ⟦AÇIK-8⟧, ⟦AÇIK-9⟧** — day_budget's real resource scale,
  the market-value formula, and what fame actually means are all still
  open per CONTRACT.md §10. Everywhere a placeholder value stands in
  (`api/config.py`'s `DAY_BUDGET_DEFAULTS` etc.) is marked with a `⟦AÇIK-n⟧`
  comment; `grep "⟦" CONTRACT.md` finds the corresponding contract text.
- **§10.1's B-1/B-2/B-3** — starting contract scale, confirming the FE
  league maps to tier 2, and naming the FE's second training tab are
  content/FE-side decisions, not backend work.
