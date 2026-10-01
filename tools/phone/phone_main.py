"""Embedded entry point for the iPhone build: both back-ends in ONE interpreter.

serious_python runs the bundled ``main.py`` on a background thread (a 3-line shim
written by ``assemble_bundle.py`` that calls ``run()`` below). This module:

* points career_engine at a writable DB and at the in-process match_engine,
* serves match_engine on 127.0.0.1:8000 and career_engine on 127.0.0.1:8001,
  each in its own thread with its own event loop,
* watches both listeners and re-binds one whose socket died - iOS may reclaim
  listening sockets while the app is suspended (Apple TN2277). The apps (and
  therefore match_engine's in-memory sessions) are module-level and survive a
  re-bind; only the open connections, e.g. SSE streams, are lost.

Bundle layout (see assemble_bundle.py)::

    <root>/main.py  phone_main.py
    <root>/career/   career_engine tree  (api, db, domain, ...)
    <root>/match/    match_engine tree   (its ``api`` package is renamed ``match_api``,
                                          because career_engine owns the name ``api``)

Environment (all optional):
    CAREER_ENGINE_DB_PATH   default ``<cwd>/career.db`` (serious_python's cwd is writable)
    PHONE_LOG_LEVEL         default ``warning``
"""
import contextlib
import faulthandler
import importlib
import logging
import os
import socket
import sys
import threading
import time
from pathlib import Path
from typing import Callable, Optional

import uvicorn

HOST = "127.0.0.1"
MATCH_PORT = 8000
CAREER_PORT = 8001

START_TIMEOUT_S = 30.0
WATCH_INTERVAL_S = 2.0
PROBE_TIMEOUT_S = 0.75
STOP_TIMEOUT_S = 5.0

log = logging.getLogger("phone_main")


class _Server(uvicorn.Server):
    """uvicorn.Server that never touches signal handlers (we are not the main
    thread: ``signal only works in main thread``) and is stopped via ``should_exit``.
    Current uvicorn already skips signals off the main thread via ``capture_signals``;
    both hooks are neutralised so an older or newer release behaves the same."""

    def install_signal_handlers(self) -> None:  # uvicorn < 0.29
        pass

    @contextlib.contextmanager
    def capture_signals(self):  # uvicorn >= 0.29
        yield


class Listener:
    """One uvicorn server on its own thread; ``start()`` is also the re-bind."""

    def __init__(self, name: str, port: int, load_app: Callable[[], object], lifespan: str):
        self.name = name
        self.port = port
        self._load_app = load_app
        self._lifespan = lifespan
        self._server: Optional[_Server] = None
        self._thread: Optional[threading.Thread] = None
        self.error: Optional[BaseException] = None
        self.restarts = 0

    def _serve(self, server: _Server) -> None:
        try:
            server.run()
        except BaseException as exc:  # noqa: BLE001 - surfaced through .error
            self.error = exc
            log.exception("%s server crashed", self.name)

    def start(self) -> None:
        self.error = None
        server = _Server(
            uvicorn.Config(
                self._load_app(),
                host=HOST,
                port=self.port,
                # log_config=None: uvicorn's default dictConfig() would close our
                # phone_main.log handler (it shuts down every existing handler).
                # uvicorn's loggers then simply propagate to the root handlers.
                log_config=None,
                log_level=os.environ.get("PHONE_LOG_LEVEL", "warning"),
                access_log=False,
                # Pure-Python stack only: no uvloop/httptools/websockets wheels.
                loop="asyncio",
                http="h11",
                ws="none",
                lifespan=self._lifespan,
                reload=False,
                workers=1,
            )
        )
        thread = threading.Thread(target=self._serve, args=(server,), name=f"{self.name}-uvicorn", daemon=True)
        self._server, self._thread = server, thread
        thread.start()
        deadline = time.monotonic() + START_TIMEOUT_S
        while not server.started:
            if not thread.is_alive():
                raise RuntimeError(f"{self.name} failed to start") from self.error
            if time.monotonic() > deadline:
                server.should_exit = True
                raise RuntimeError(f"{self.name} did not start within {START_TIMEOUT_S:.0f}s")
            time.sleep(0.02)

    def stop(self) -> None:
        server, thread = self._server, self._thread
        if server is None or thread is None:
            return
        server.should_exit = True
        thread.join(STOP_TIMEOUT_S)
        if thread.is_alive():
            # A wedged loop must not block the re-bind; force_exit skips the
            # graceful drain on the next iteration if it ever wakes up.
            server.force_exit = True
            log.warning("%s did not stop within %.0fs", self.name, STOP_TIMEOUT_S)

    def accepting(self) -> bool:
        """True when something accepts a TCP connection on our port. A bare connect
        (no HTTP) keeps the check out of the app and off the request log."""
        if self._thread is None or not self._thread.is_alive():
            return False
        try:
            with socket.create_connection((HOST, self.port), timeout=PROBE_TIMEOUT_S):
                return True
        except OSError:
            return False

    def revive_if_dead(self) -> bool:
        if self.accepting():
            return False
        log.warning("%s listener is down; re-binding", self.name)
        self.restarts += 1
        self.stop()
        self.start()
        return True


def _bundle_root() -> Path:
    return Path(os.environ.get("PHONE_ROOT") or Path(__file__).resolve().parent)


def configure_paths_and_env(root: Path) -> None:
    """Must run before either engine is imported: career_engine reads its config
    at import time, and the two source trees go on sys.path (career first)."""
    os.environ.setdefault("CAREER_ENGINE_DB_PATH", str(Path.cwd() / "career.db"))
    os.environ["MATCH_ENGINE_BASE_URL"] = f"http://{HOST}:{MATCH_PORT}"
    for sub in ("match", "career"):  # career ends up first on sys.path
        path = str(root / sub)
        if path not in sys.path:
            sys.path.insert(0, path)
    Path(os.environ["CAREER_ENGINE_DB_PATH"]).parent.mkdir(parents=True, exist_ok=True)


def _with_health(app, name: str):
    """Neither engine has a /health route (CONTRACT.md lists none), but the phone
    client needs a cheap liveness probe. It is added here, to the live app object
    only - the engines' sources and contracts stay as they are."""
    if not any(getattr(r, "path", None) == "/health" for r in app.routes):
        app.add_api_route("/health", lambda: {"ok": True, "service": name}, include_in_schema=False)
    return app


def _rearm_matches_on_startup(app):
    """A re-bound match listener runs on a NEW event loop, while the live matches'
    run_loop tasks died with the old one. Re-attach them as the new server starts
    (match_engine's registry.rearm_sessions); on first boot there is nothing to do."""
    if getattr(app.state, "phone_rearm", False):
        return app
    inner = app.router.lifespan_context

    @contextlib.asynccontextmanager
    async def lifespan(a):
        registry = importlib.import_module("match_api.registry")
        rearmed = registry.rearm_sessions()
        if rearmed:
            log.warning("re-armed %d live match(es) on the new event loop", rearmed)
        async with inner(a):
            yield

    app.router.lifespan_context = lifespan
    app.state.phone_rearm = True
    return app


def build_listeners() -> "tuple[Listener, Listener]":
    match = Listener(
        "match_engine", MATCH_PORT,
        lambda: _rearm_matches_on_startup(
            _with_health(importlib.import_module("match_api.app").app, "match_engine")
        ),
        lifespan="on",
    )
    # lifespan "on": career_engine applies its migrations at startup; if they
    # fail the server must not come up looking healthy.
    career = Listener(
        "career_engine", CAREER_PORT,
        lambda: _with_health(importlib.import_module("api.app").app, "career_engine"),
        lifespan="on",
    )
    return match, career


def _setup_logging() -> None:
    """stderr is invisible on a phone, so everything also goes to ``phone_main.log``
    in the (writable) working directory - pull it with ``devicectl ... copy from``.
    The file is truncated per launch, which keeps it small."""
    handlers = [logging.StreamHandler()]
    try:
        handlers.append(logging.FileHandler(Path.cwd() / "phone_main.log", mode="w", encoding="utf-8"))
    except OSError:
        pass  # read-only cwd (desktop tests): stderr only
    logging.basicConfig(
        level=logging.INFO, handlers=handlers, force=True,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )


def run(block: bool = True) -> "tuple[Listener, Listener]":
    _setup_logging()
    try:
        return _run(block)
    except BaseException:
        # serious_python runs us on a thread nobody joins: without this a startup
        # failure (port taken, import error, bad migration) would leave no trace.
        log.exception("phone_main failed to start")
        raise


def _run(block: bool) -> "tuple[Listener, Listener]":
    log.info("starting; python %s, cwd=%s", sys.version.split()[0], Path.cwd())
    configure_paths_and_env(_bundle_root())
    match, career = build_listeners()
    t0 = time.monotonic()
    # If startup wedges, dump every thread's stack into the log after 20s.
    dump = open(Path.cwd() / "phone_main.hang.log", "w") if os.access(Path.cwd(), os.W_OK) else None
    if dump:
        faulthandler.dump_traceback_later(20, file=dump)
    log.info("starting match_engine")
    match.start()  # career's batch simulation calls it, so it comes up first
    log.info("match_engine up in %.2fs; starting career_engine", time.monotonic() - t0)
    career.start()
    if dump:
        faulthandler.cancel_dump_traceback_later()
        dump.close()
    log.info("both back-ends up in %.2fs (db=%s)", time.monotonic() - t0, os.environ["CAREER_ENGINE_DB_PATH"])

    def watch() -> None:
        while True:
            time.sleep(WATCH_INTERVAL_S)
            for listener in (match, career):
                try:
                    listener.revive_if_dead()
                except Exception:  # noqa: BLE001 - keep watching; retry next tick
                    log.exception("could not revive %s", listener.name)

    threading.Thread(target=watch, name="phone-watchdog", daemon=True).start()
    if block:
        threading.Event().wait()
    return match, career
