"""FastAPI application factory. Routers are wired on as each domain area
(§5.1-§5.7) lands."""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api import config
from api.errors import install_exception_handlers
from api.routers import (
    careers, catalog, housing, inventory, matches, news, player, relationships, season, social,
    sponsorship, time, transfer, world,
)
from db.connection import get_connection
from db.migrate import apply_migrations
from domain import legacy_items


@asynccontextmanager
async def _lifespan(app: FastAPI):
    # Reads config.DB_PATH at call time (not import time) so tests can
    # monkeypatch it before the TestClient triggers this.
    conn = get_connection(config.DB_PATH)
    try:
        apply_migrations(conn)
        # §14.2 D81 - pays back or converts pre-gear shop rows; idempotent.
        legacy_items.reconcile(conn)
    finally:
        conn.close()
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="career_engine API", version="1.0", lifespan=_lifespan)
    install_exception_handlers(app)

    # Local-only, single-player dev backend — wildcard is fine, no auth/cookies
    # involved. Needed so Flutter web builds (browser CORS) can reach the API.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(careers.router)
    app.include_router(player.router)
    app.include_router(world.router)
    app.include_router(relationships.router)
    app.include_router(social.router)
    app.include_router(time.router)
    app.include_router(matches.router)
    app.include_router(news.router)
    app.include_router(catalog.router)
    app.include_router(season.router)
    app.include_router(transfer.router)
    app.include_router(sponsorship.router)
    app.include_router(inventory.router)
    app.include_router(housing.router)

    return app


app = create_app()
