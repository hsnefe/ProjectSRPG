"""FastAPI application factory. Routers are wired on as each domain area
(§5.1-§5.7) lands; for now this boots with no routes beyond error handling
so the skeleton can be previewed end-to-end before any endpoint exists."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.errors import install_exception_handlers


def create_app() -> FastAPI:
    app = FastAPI(title="career_engine API", version="1.0")
    install_exception_handlers(app)

    # Local-only, single-player dev backend — wildcard is fine, no auth/cookies
    # involved. Needed so Flutter web builds (browser CORS) can reach the API.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    return app


app = create_app()
