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


def requirement_not_met(attribute_key: str, required: int, current: int) -> ApiError:
    """§5.7 D42 - the item's/leaf's `requires` threshold isn't cleared. 409
    rather than 422, same reading as already_owned and
    skill_exam_already_taken: the request is well-formed, it's the career's
    state that rejects it.

    The two levels travel in the message because FE writes the sentence
    (§1.3). In the normal flow this error is never seen — FE greys the
    option out from N3's `requires` and P1's `level` — so it is the
    server-authoritative backstop, not a user-facing state."""
    return ApiError(
        409, "requirement_not_met",
        f"{attribute_key!r} level {current}, needs {required}",
    )


def already_owned(item_id: str) -> ApiError:
    return ApiError(409, "already_owned", f"{item_id!r} is already owned")


# §9 - social offers get their OWN codes rather than a generic offer_*
# family. §11.9 reserves `offer_not_found` / `offer_not_open` for transfer
# offers (S3/S4), a different mechanic with a different lifetime; sharing the
# codes would make one of the two contracts a lie the day both exist.

def social_offer_not_found(offer_id: str) -> ApiError:
    return ApiError(404, "social_offer_not_found", f"no social offer {offer_id!r}")


def social_offer_not_open(offer_id: str) -> ApiError:
    return ApiError(409, "social_offer_not_open", f"social offer {offer_id!r} is already answered")


def social_offer_pending(offer_id: str) -> ApiError:
    """§6.3 D53 - the answer is mandatory, so time cannot move while an offer
    is open. The id travels in the message because the caller's correct
    reaction is to open that offer, not to retry."""
    return ApiError(409, "social_offer_pending", f"social offer {offer_id!r} is waiting for an answer")


def match_day_unplayed(fixture_id: str) -> ApiError:
    """§6.1 D57 - time cannot advance while the user's own match today is
    still 'scheduled'. Replaces the earlier "missed match" auto-play: the
    fixture id travels in the message because the caller's correct reaction
    is to play it (M1 -> M2), not to retry advancing."""
    return ApiError(409, "match_day_unplayed", f"fixture {fixture_id!r} must be played before time can advance")


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


def season_rollover_required() -> ApiError:
    """§11.9 - replaces the retired `season_finished`. The difference is the
    whole point of §11: the season being over is no longer the end of the
    career, it is a thing the player does something about (S1)."""
    return ApiError(
        409, "season_rollover_required",
        "the season is over; POST /season/rollover before advancing",
    )


def season_not_finished(unplayed: int) -> ApiError:
    """§11.9 - S1/S2 called while fixtures remain (INV-13). The count is in
    the message because for the user the two precondition failures are one
    situation ("it isn't over yet") and the number is the only useful
    difference between them."""
    return ApiError(
        409, "season_not_finished",
        f"{unplayed} fixture(s) of this season are still unplayed",
    )


def no_transfer_window() -> ApiError:
    return ApiError(
        409, "no_transfer_window",
        "transfer offers can only be accepted during a transfer window",
    )


def offer_not_found(offer_id: str) -> ApiError:
    return ApiError(404, "offer_not_found", f"unknown offer_id {offer_id!r}")


def offer_not_open(offer_id: str) -> ApiError:
    return ApiError(
        409, "offer_not_open", f"offer {offer_id} is no longer open"
    )


def fixture_not_in_progress(fixture_id: str) -> ApiError:
    return ApiError(409, "fixture_not_in_progress", f"fixture {fixture_id!r} is not in progress")


def no_standings(competition_id: str) -> ApiError:
    return ApiError(409, "no_standings", f"{competition_id!r} is elimination-format, has no table")


def skill_exam_already_taken(exam_ids) -> ApiError:
    """§2 - an exam awards its points once. 409 rather than 422: the request
    is well-formed, it's the career's state that rejects it (same reading as
    already_owned)."""
    return ApiError(
        409, "skill_exam_already_taken",
        f"exam(s) {', '.join(exam_ids)} were already taken by this career",
    )


def coach_talk_already_done(fixture_id: str) -> ApiError:
    """§12.1 - one conversation per match. 409, not 422: the request is
    well-formed, it's the career's state that rejects it (same reading as
    already_owned and skill_exam_already_taken)."""
    return ApiError(
        409, "coach_talk_already_done",
        f"the coach has already been spoken to before {fixture_id}",
    )


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
