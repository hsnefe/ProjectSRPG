"""§5.0 - opaque id formats. FE never parses these, so the only contract is
the prefix and that they're unique."""
import secrets


def new_career_id() -> str:
    return "car_" + secrets.token_hex(6)


def new_news_id() -> str:
    return "n_" + secrets.token_hex(6)


def new_social_offer_id() -> str:
    # 'so_', not 'o_': §11.3 reserves the bare 'o_' prefix for transfer
    # offers, which are a different mechanic with their own error codes.
    return "so_" + secrets.token_hex(6)

def new_transfer_offer_id() -> str:
    """§11.3 - the bare 'o_' prefix, reserved since the social offers took
    'so_' precisely so this family could have it."""
    return "o_" + secrets.token_hex(6)

def new_sponsorship_deal_id() -> str:
    return "sp_" + secrets.token_hex(6)


def new_obligation_id() -> str:
    return "ob_" + secrets.token_hex(6)


def new_social_plan_id() -> str:
    # 'spl_', not 'sp_': that prefix is sponsorship_deal's (§12.7).
    return "spl_" + secrets.token_hex(6)
