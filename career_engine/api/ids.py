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
