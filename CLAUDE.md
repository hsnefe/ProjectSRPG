# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A football career SRPG. A Flutter client (`lib/`, `test/`) plus **two** Python/FastAPI
back-ends that it talks to separately:

| Process | Lives in | Port | Owns |
|---|---|---|---|
| Flutter client | this repo, `lib/` | 5050 (web-server) | all presentation; also *carries* the user's own match between the two back-ends |
| `career_engine` | this repo, `career_engine/` | 8001 | everything that persists: careers, calendar/time loop, money, attributes, world, relationships, transfers, sponsorships, news (SQLite) |
| `match_engine` | **sibling repo** `../match_engine/` | 8000 | stateless single-match simulation: ticks, SSE, intervention offers |

`career_engine` also calls `match_engine`'s `POST /simulate/batch` server-to-server to
run every fixture the user isn't playing.

## Commands

**Flutter is vendored in `./flutter/` (gitignored) and is NOT on PATH.** Always invoke it
by path. From the repo root:

```bash
./flutter/bin/flutter test
```

```bash
./flutter/bin/flutter test test/match_controller_test.dart
```

```bash
./flutter/bin/flutter test test/relationships_screen_test.dart --plain-name "diyalog"
```

```bash
./flutter/bin/flutter analyze lib test
```

```bash
./flutter/bin/dart format lib/widgets/foo.dart
```

From PowerShell the same binary is `& ".\flutter\bin\flutter.bat" test`.

Back-end tests use `career_engine/.venv` (also gitignored; `run_all.bat` creates it if missing):

```bash
cd career_engine && ./.venv/Scripts/python.exe -m pytest -q
```

```bash
cd career_engine && ./.venv/Scripts/python.exe -m pytest tests/test_rollover.py -k promotion
```

455 backend tests pass as of 2026-09-14 (`career_engine/README.md`'s count lags behind — trust
the run, not the README). `tests/test_end_to_end.py` walks every domain area in one session and
is the one to watch after cross-cutting changes.

**Running the app:** `run_all.bat` brings up both back-ends (each in its own window) and then
the Flutter web client, and tears the back-ends down when Flutter exits. `run_web.bat` runs
only the client. `.claude/launch.json` defines a `web` preview config on port 5050.
`career_engine/career.db` is created on first startup; deleting it resets the world.

## Contracts come first

Two signed contract documents are the source of truth for every wire format, and code is
written *against* them rather than the other way round:

- `career_engine/CONTRACT.md` (~3400 lines, Turkish) — the career endpoints (C/P/W/R/T/M/N/S
  ids), the SQLite schema, the numbered decision record (D1–D57), the invariants (INV-1…INV-49),
  error codes, and §10's deliberately open items. Open values are marked `⟦AÇIK-n⟧` in both the
  contract and the code standing in for them — `grep "⟦AÇIK" ` finds every edit point.
- `../API_CONTRACT.md` (workspace root) — the match_engine ↔ match screen contract: tick
  envelope, the 26 `event_type` values, intervention offers and minigame mapping (§7.3),
  directive/effort semantics.

**Precedence inside CONTRACT.md matters.** §1–§10 are the signed v1.0 body. §11 (season
rollover, transfer, contract lifecycle) and §12 (coach talk, squad status, sponsorship) were
appended *after* signature, and each opens with a "Geçersiz kılananlar" table naming exactly
what it overrides — §11 has the last word in its own area, §12 overrides only what it lists.
Reading an older clause without checking those two tables is the main way to get a wrong
answer here.

When touching an endpoint, a response field or a game rule, find its clause first. Comments
throughout both code bases cite sections (`§5.6`, `D38`, `INV-17`, `[İ-33]`) — keep that habit;
those references are how the two repos stay in step.

`career_engine/README.md` lists the known gaps (match_engine's E11/E12 still don't exist, so
`advance` and match `result` fail with `502 engine_unavailable` against a real engine; the
player's age never advances) — read it before assuming something is broken.

## career_engine layout and rules

```
api/       FastAPI app + one router per CONTRACT section (careers, player, world,
           relationships, social, time, matches, news, catalog, season, transfer,
           sponsorship); serializers.py builds shared response blocks; errors.py owns
           the {code, message} envelope
domain/    business logic — one module per "single write path" plus the big flows
           (onboarding, daytime, matches, scheduling, rollover, season, contracts,
           transfer, sponsorship, squad, coach_talk) and engine_client
catalog/   static reference data (training, lifestyle, shop, dialogue, match actions)
content/   generated-content templates (social_offers, sponsorships)
worlddata/ the fixed v1 world: teams, competitions, positions, attributes, formations
db/        connection setup + numbered .sql migrations applied in filename order
           (001–011; there is no 008 — the gap is harmless, the loader globs and sorts)
tests/     conftest.py fixtures (db_conn, career_id, player_id, mock_engine) + one file
           per domain module / router
```

The **single write path** rule is load-bearing and enforced by invariants:

| Value | Only writer | Invariant |
|---|---|---|
| `career_state.money` | `wallet.apply()` | INV-17 |
| `relationship.score` | `relationships.apply_delta()` | INV-15 |
| `relationship.traits` | `relationships.apply_trait_delta()` (seeding is the one exception) | INV-42 |
| `player_fame.value` | `fame.apply()` | INV-24 |

Each writes its ledger/log row in the same transaction, and none of them commit — the calling
endpoint owns the transaction so a multi-step action is all-or-nothing (INV-3).

Every state-mutating endpoint returns the full `CareerState` block (D28/INV-18). Every table
carries `career_id` with `ON DELETE CASCADE`; foreign keys are ON per connection (INV-9).

Two recent loops are worth knowing before touching either end of them:

- **coach talk → trust → selection.** `domain/coach_talk.py` moves `CoachTraits.trust`
  separately from the coach's relationship *score*; `domain/squad.py` reads trust when deciding
  whether the user starts, is benched, or is left out. Squad status is computed lazily on first
  ask and then frozen on the fixture row (INV-44), so T1 and M1 always agree about the same match.
- **season rollover.** `domain/season.py` derives every season boundary from the opening
  calendar year (D44) and derives the phase rather than storing it (D45); `domain/rollover.py`
  is the single transaction that turns one season into the next (INV-36). It is its own
  endpoint rather than part of `advance` (D46), and it does not move `game_date` (D47).

## Flutter layout and rules

```
lib/net/     thin clients + models, one per back-end (career_api_client, match_api_client,
             match_sse_client) plus money.dart. Bodies are decoded from bodyBytes as UTF-8
             explicitly — the servers don't always send charset and Turkish names would mojibake.
lib/state/   PlayerState (ChangeNotifier via PlayerScope/InheritedNotifier) and
             MatchController. No Provider/Riverpod — deliberately.
lib/game/    Flame + pure-Dart game logic: the shot/pass minigame (shot_game, pitch_projector,
             shot_scenarios, match_scenarios), the training minigames (bench_press,
             conditioning, flexibility, dribble, skill_exam), match feed mapping.
lib/screens/ one file per screen; lib/widgets/ shared UI; lib/theme/app_colors.dart
```

`CareerSession.instance` is the app-wide holder of "which career are we in"; it is mutable
specifically so tests can point screens that build their own navigation chains at a fake
back-end. Screens and `PlayerScope` also accept an optional `session:` for the same reason.

**Single-owner rules on this side**, each introduced because the thing had been copy-pasted
into five or six files:

- `lib/net/money.dart` owns the currency (**₭ / Kredi**) — symbol, thousands separator, compact
  form. Never write `'₭$amount'` inline; call `formatMoney` / `thousands` / `formatMoneyCompact`.
- `AppColors` takes any tone used in **two or more** files; single-screen tones stay where
  they're used.
- `lib/game/formations.g.dart` is **generated** — copied out of the sibling `../formation_creator`
  tool's output, never hand-edited. `career_engine` ships only formation *ids*
  (`worlddata/formations.py`); slot coordinates live client-side and the two default ids must
  match.
- `lib/game/shot_scenarios.g.dart`, `tackle_scenarios.g.dart` and `dribble_courses.g.dart` are
  **generated** the same way, from the sibling `../scenario_creator` tool (its "Dart'a aktar"
  button writes them straight here). Never hand-edit them; open the editor instead. Each holds
  only the authored fields as import-free records — the camera bearing, the aim reach and the
  session logic are *derived* from them by `shot_scenarios.dart`, `tackle_scenarios.dart` and
  `dribble_courses.dart`, which are ordinary hand-written files. A scenario reaches a match only
  through its own `actionKey`; `match_scenarios.dart` derives the pools from the catalog rather
  than keeping a second list.

- `assets/images/sprites/players/*.png` and its `layout.json` are **generated** by
  `tools/blender/` (`build_match_players.py` builds the low-poly cast, `render_match_sprites.py`
  renders it headless with Blender, `assemble_match_sprites.py` packs the sheets). Never
  hand-edit them. Each kind has a `base` sheet plus white-shaded `shirt` / `shorts` / `socks`
  layers that `lib/game/player_sprites.dart` tints with `BlendMode.modulate`, so a kit is three
  `Color`s. Rows are the 8 headings relative to the camera, columns are the frames listed in
  `layout.json`; `test/player_sprites_test.dart` pins the code's column numbers to that file.
  Re-render with `blender -b --factory-startup -P tools/blender/render_match_sprites.py -- OUT`
  then `python tools/blender/assemble_match_sprites.py OUT`.

Presentation the backend deliberately doesn't send (§5.8) is synthesised client-side:
`character_portrait.dart` derives a face procedurally from the `relationship_id` (there are no
portrait assets), and `dialogue_backdrop.dart` picks the scene from the social-offer template or
the relationship kind. `formation_board.dart` uses its own normalised 0–1 top-down box, not
`pitch_projector.dart`'s perspective world units — the two coordinate systems are kept apart on
purpose.

### Tests

Widget tests stub HTTP with `MockClient` from `package:http/testing.dart` and hand-written JSON
map literals shaped like the contract's response bodies (see `test/career_center_screen_test.dart`).
There is no golden-file or integration harness — a screen is tested by pumping it with a fake
client. Test names and expected strings are Turkish because the UI is.

## Conventions

- **UI text is Turkish.** Doc comments are Turkish in `lib/` and English in `career_engine/`;
  match the file you're editing.
- Comments explain *why*, usually citing a contract clause or the alternative that was
  rejected. Existing files are dense with this — keep the density rather than stripping it.
- **Commits are written in English**, subject and body alike, even though the UI and half the
  comments are Turkish. Subjects are imperative and sentence case, with no prefix or ticket id
  (e.g. "Let contracts run out and clubs come in"); bodies explain what was wrong with the old
  shape and why this one is better.
- **No `Co-Authored-By` trailer and no generated-with footer** on commits or PR descriptions —
  this repo's history has none, and it stays that way.
- Don't add dependencies casually: the client runs on `flame` + `http` and nothing else.
