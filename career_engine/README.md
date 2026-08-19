# career_engine

Career/world back-end for ProjectSRPG — careers, players, competitions,
relationships, and the day-by-day time loop. See [CONTRACT.md](CONTRACT.md)
for the full API contract, schema, and decision record.

`match_engine` (sibling directory) remains the stateless single-match
simulator; this service owns everything that persists between matches.

## Running

```
pip install -r requirements.txt
python run_server.py
```

Serves on `http://127.0.0.1:8001`.

## Tests

```
pytest
```
