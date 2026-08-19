"""§9 - the contract's binding error-code table, as a single exception type
plus a FastAPI exception handler. Mirrors match_engine/api/errors.py's shape:
ApiError carries (status_code, code, message) and serializes to a flat
{"code": ..., "message": ...} body - no "error" wrapper key."""
from fastapi import Request
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        self.status_code = status_code
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")

    def body(self) -> dict:
        return {"code": self.code, "message": self.message}


# --- §9 factory helpers, one per row of the contract's error table ----------

def career_not_found(career_id: str) -> ApiError:
    return ApiError(404, "career_not_found", f"no career {career_id!r}")


def fixture_not_found(fixture_id: str) -> ApiError:
    return ApiError(404, "fixture_not_found", f"no fixture {fixture_id!r}")


def insufficient_budget(resource_key: str) -> ApiError:
    return ApiError(409, "insufficient_budget", f"not enough {resource_key!r} left today")


def insufficient_funds() -> ApiError:
    return ApiError(409, "insufficient_funds", "balance is too low")


def already_owned(item_id: str) -> ApiError:
    return ApiError(409, "already_owned", f"{item_id!r} is already owned")


def match_in_progress(fixture_id: str) -> ApiError:
    return ApiError(409, "match_in_progress", f"fixture {fixture_id!r} has an unfinished match")


def not_match_day(next_kickoff_on: str = None, days_until: int = None) -> ApiError:
    """§6.1 - a match is playable only on its own day, so the day loop is
    what carries the career forward between matches. The next kickoff date
    and the gap travel in the message because FE writes the sentence
    itself (§1.3); both are None once the season has no fixtures left."""
    if next_kickoff_on is None:
        return ApiError(409, "not_match_day", "no upcoming fixture for the user's team")
    return ApiError(
        409, "not_match_day",
        f"next match is on {next_kickoff_on}, {days_until} day(s) away",
    )


def fixture_already_played(fixture_id: str) -> ApiError:
    return ApiError(409, "fixture_already_played", f"fixture {fixture_id!r} result was already recorded")


def season_finished() -> ApiError:
    return ApiError(409, "season_finished", "the season has ended")


def fixture_not_in_progress(fixture_id: str) -> ApiError:
    return ApiError(409, "fixture_not_in_progress", f"fixture {fixture_id!r} is not in progress")


def no_standings(competition_id: str) -> ApiError:
    return ApiError(409, "no_standings", f"{competition_id!r} is elimination-format, has no table")


def invalid_request(message: str) -> ApiError:
    return ApiError(422, "invalid_request", message)


def invalid_match_result(message: str) -> ApiError:
    return ApiError(422, "invalid_match_result", message)


def engine_unavailable(message: str = "match_engine did not respond") -> ApiError:
    return ApiError(502, "engine_unavailable", message)


async def api_error_handler(request: Request, exc: ApiError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content=exc.body())


def install_exception_handlers(app) -> None:
    app.add_exception_handler(ApiError, api_error_handler)
