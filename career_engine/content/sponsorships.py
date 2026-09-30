"""§12.7 - the sponsorship deals a player can be offered.

In `content/` for the same reason the social offers are: serving the pool in
bulk would spoil every deal the player has not been offered yet. What is
served is the one generated offer.

A deal is two things at once, and that is the whole mechanic: money that
arrives every week without being earned, and — for some of them — days that
stop belonging to the player. A deal with no obligation pays less. Signing
the biggest cheque means handing over afternoons.

`requires` is D42's gate, read against the person (kişi) attributes: a brand
does not put its name on someone who cannot hold a camera. That is also the
one place the kişi family does real work in the money system, since §11.13
keeps it out of transfer negotiation.

Adding a deal is an edit to THIS FILE ONLY.
"""

SPONSORSHIPS = [
    # --- no obligations: small, quiet money -------------------------------
    {
        "template_id": "local_sports_shop",
        "brand": "Kale Spor",
        "weight": 4,
        "cooldown_days": 60,
        "seasons": 1,
        "weekly_income": 6,
        "title": "Kale Spor mağaza anlaşması",
        "body": "Mahallenin spor mağazası formanı vitrine koymak istiyor. "
                "Küçük bir anlaşma, hiçbir yükümlülüğü yok.",
        "accept_label": "İmzala",
        "decline_label": "İlgilenmiyorum",
        "obligation": None,
    },
    {
        "template_id": "energy_drink",
        "brand": "Volt",
        "weight": 3,
        "cooldown_days": 90,
        "seasons": 1,
        "weekly_income": 14,
        "title": "Volt enerji içeceği",
        "body": "Volt, soyunma odası buzdolabına adını yazdırmak istiyor. "
                "Senden istedikleri tek şey elinde bir kutuyla görünmek.",
        "accept_label": "Anlaştık",
        "decline_label": "Hayır",
        "requires": {"charisma": 5},
        "obligation": None,
    },

    # --- obligations: the money is bigger and the days are not yours -------
    {
        "template_id": "bank_campaign",
        "brand": "Anadolu Bank",
        "weight": 3,
        "cooldown_days": 120,
        "seasons": 2,
        "weekly_income": 30,
        "title": "Anadolu Bank reklam yüzü",
        "body": "Banka bir sezonluk kampanyasının yüzü olmanı istiyor. "
                "Karşılığı iyi, ama ayda bir çekim günün onlara ait.",
        "accept_label": "Kabul ediyorum",
        "decline_label": "Takvimim kaldırmaz",
        "requires": {"charisma": 6},
        "obligation": {
            "every_days": 30,
            "title": "Reklam çekimi",
            "costs": {"time": 300.0, "energy": 25.0},
            "condition": -8,
        },
    },
    {
        "template_id": "boot_brand",
        "brand": "Vento",
        "weight": 2,
        "cooldown_days": 150,
        "seasons": 2,
        "weekly_income": 45,
        "title": "Vento krampon sözleşmesi",
        "body": "Vento sana özel kalıp çıkaracak ve her lansmana seni "
                "çağıracak. Bu ligdeki en iyi krampon anlaşması.",
        "accept_label": "İmzala",
        "decline_label": "Şimdilik hayır",
        "requires": {"charisma": 7, "courage": 6},
        # §14.6/D82 - signing hands over the story item (#40), the first pair of
        # the signature series. domain/sponsorship.accept() is the only reader.
        "grant_item": "special-signature-boots",
        "obligation": {
            "every_days": 45,
            "title": "Lansman etkinliği",
            "costs": {"time": 360.0, "energy": 30.0},
            "condition": -10,
        },
    },
    {
        "template_id": "telecom_tour",
        "brand": "Telnet",
        "weight": 2,
        "cooldown_days": 180,
        "seasons": 1,
        "weekly_income": 60,
        "title": "Telnet okul turu",
        "body": "Telnet, sezon boyunca okulları gezecek bir tanıtım turu "
                "kuruyor ve başında seni istiyor. Rakam büyük, takvim ağır.",
        "accept_label": "Turu kabul et",
        "decline_label": "Bu kadarına giremem",
        "requires": {"charisma": 8, "empathy": 6},
        "obligation": {
            "every_days": 21,
            "title": "Okul ziyareti",
            "costs": {"time": 420.0, "energy": 35.0},
            "condition": -12,
        },
    },
]

BY_ID = {t["template_id"]: t for t in SPONSORSHIPS}


def template(template_id: str):
    return BY_ID.get(template_id)


def public_view(deal_template: dict) -> dict:
    """What FE is allowed to see about a deal on offer: the prose, the
    labels, the money and the gate — never the weight or the cooldown, which
    are the generator's business (the same split R4 draws)."""
    obligation = deal_template.get("obligation")
    return {
        "template_id": deal_template["template_id"],
        "brand": deal_template["brand"],
        "title": deal_template["title"],
        "body": deal_template["body"],
        "accept_label": deal_template["accept_label"],
        "decline_label": deal_template["decline_label"],
        "weekly_income": deal_template["weekly_income"],
        "seasons": deal_template["seasons"],
        "requires": deal_template.get("requires", {}),
        # The obligation's shape is shown before signing on purpose: "every
        # 30 days, five hours" is the price, and a price you only discover
        # afterwards is a trap rather than a decision.
        "obligation": None if obligation is None else {
            "title": obligation["title"],
            "every_days": obligation["every_days"],
            "costs": obligation["costs"],
            "condition": obligation.get("condition", 0),
        },
    }


# Every template must be gated on attributes the catalog actually knows, and
# must price its obligation if it has one. Checked at import so a bad edit
# fails on startup rather than the day the deal is rolled.
for _t in SPONSORSHIPS:
    assert _t["weekly_income"] > 0, _t["template_id"]
    assert _t["seasons"] >= 1, _t["template_id"]
    _ob = _t.get("obligation")
    if _ob is not None:
        assert _ob["every_days"] >= 7, _t["template_id"]
        assert _ob["costs"], _t["template_id"]
assert len(BY_ID) == len(SPONSORSHIPS), "duplicate template_id"
