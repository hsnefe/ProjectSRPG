"""The five publications that carry the game's news, and the voice each one
writes in.

Why outlets are a separate concept from story archetypes: the same event
should read differently depending on who reports it. A repossessed flat is
a two-line notice in the wire service, a morality tale in the tabloid, and
something the club bulletin would never mention at all. Splitting "what
happened" (news_stories.py) from "who is telling you" doubles the apparent
variety of the catalog for a fraction of the authoring cost, and it gives
the media relationship somewhere to bite: a player the press dislikes gets
written about by the tabloid more often (see pick_outlet).

`sign_off` is the cheapest possible carrier of voice — one closing
paragraph, appended to every body this outlet prints. It is deliberately
NOT optional: an outlet without a recognisable last line reads like every
other outlet.

`source` on the `news` row is the outlet's display NAME, not its id — N1/N2
serve that column straight to FE and FE has no outlet table to join
against. The id lives only in this file and in an archetype's `outlets`
tuple.
"""

OUTLETS = [
    {
        "outlet_id": "spor-manset",
        "name": "Spor Manşet",
        # worlddata/relationships.py's media contact (Ayça Kılıç) works here;
        # her card's `outlet` trait says "Spor Manşet" verbatim. Any story
        # that quotes a reporter by name should list this outlet.
        "tone": "Ciddi spor gazetesi. Kaynak gösterir, abartmaz, ama "
                "transfer haberini ilk veren olmayı da sever.",
        "reporter": "Ayça Kılıç",
        # Kötü medya ilişkisinde payı düşer: seni sevmeyen ciddi gazete
        # senden hiç bahsetmez, tabloid ise tam tersi (pick_outlet).
        "media_affinity": 1.0,
        "sign_off": [
            "Kulüpten konuya ilişkin resmî bir açıklama gelmedi.",
            "Gelişmeler Spor Manşet'ten takip edilebilir.",
            "Dosyanın önümüzdeki günlerde netleşmesi bekleniyor.",
            "Taraflardan biri konuşmadığı sürece haberin ikinci yarısı eksik kalacak.",
        ],
    },
    {
        "outlet_id": "lig-ajansi",
        "name": "Lig Ajansı",
        "tone": "Kuru haber ajansı. Cümleler kısa, sıfat yok, duygu hiç yok. "
                "Bülten geçer, yorum yapmaz.",
        "reporter": "Ajans bülteni",
        "media_affinity": 0.0,   # ajans kimseyi sevmez, kimseden nefret etmez
        "sign_off": [
            "Bülten sonu.",
            "Ek bilgi geldiğinde geçilecektir.",
            "Konuyla ilgili doğrulama beklenmektedir.",
            "Haber, ilgili kulübün açıklamasıyla güncellenebilir.",
        ],
    },
    {
        "outlet_id": "magazin-ekspres",
        "name": "Magazin Ekspres",
        "tone": "Tabloid. Soru işaretli manşet, ima, 'iddiaya göre', "
                "görgü tanığı. Kanıt aramaz, fotoğraf arar.",
        "reporter": "Magazin Servisi",
        "media_affinity": -1.0,  # ilişki kötüyse en çok bu yazar
        "sign_off": [
            "Peki bu kadarı tesadüf olabilir mi? Biz sormaya devam ediyoruz.",
            "Yakınlarına yakın kaynaklar şimdilik suskun.",
            "O fotoğraflar bizde. Yayımlar mıyız? Zamanı gelince.",
            "Bir açıklama beklemiyoruz ama yine de kapıda bekleyeceğiz.",
            "Bu hikâyenin daha çok konuşulacağını not düşelim.",
        ],
    },
    {
        "outlet_id": "tribun-sesi",
        "name": "Tribün Sesi",
        "tone": "Taraftar blogu. Taraflı, sıcak, bazen kırgın. 'Bizim çocuk' "
                "der, hakemden şikâyet eder, yönetimi hedef alır.",
        "reporter": "Tribün Sesi yazı kurulu",
        "media_affinity": -0.3,
        "sign_off": [
            "Biz tribündeyiz. Her hafta, her yerde.",
            "Sahada koşan adamı severiz; gerisi laf.",
            "Yönetim okuyorsa: biz buradayız, siz neredesiniz?",
            "Cumartesi görüşürüz. Sesimizi duyacaksınız.",
            "Not: bu yazıyı bir taraftar yazdı, muhabir değil. Farkı okurken anlarsınız.",
        ],
    },
    {
        "outlet_id": "kulup-bulteni",
        "name": "Kulüp Bülteni",
        "tone": "Resmî kulüp açıklaması. Steril, üçüncü tekil şahıs, "
                "hiçbir şeyi doğrulamaz, hiçbir şeyi yalanlamadan yalanlar.",
        "reporter": "Basın ve Halkla İlişkiler",
        "media_affinity": 0.0,
        "sign_off": [
            "Kamuoyuna saygıyla duyurulur.",
            "Kulübümüz, gündemdeki konularla ilgili tek yetkili kaynağın "
            "resmî kanalları olduğunu hatırlatır.",
            "Basın mensuplarının bilgisine sunulur.",
            "Kulübümüz futbolcularımızın konsantrasyonunu koruma hakkını saklı tutar.",
        ],
    },
]

OUTLETS_BY_ID = {o["outlet_id"]: o for o in OUTLETS}
OUTLET_IDS = frozenset(OUTLETS_BY_ID)


def pick_outlet(rng, outlet_ids, media_score: int) -> dict:
    """Chooses which of an archetype's eligible outlets runs the story.

    The weighting is the one nicety §1.5 allows: `media_affinity` says how
    much an outlet's appetite moves with the player's media relationship.
    A player the press likes (score 80) is written about by Spor Manşet;
    one the press has soured on (score 5) is tabloid property. The wire
    service and the club bulletin have affinity 0 — neither has an opinion
    about you.

    `bias` runs -1..+1 (media 0 -> -1, media 100 -> +1) so the weight
    multiplier stays in a tame 0.35x..2.85x band: no outlet is ever
    impossible, which matters because an archetype may list only one.
    """
    bias = (media_score - 50) / 50.0
    weights = []
    for outlet_id in outlet_ids:
        outlet = OUTLETS_BY_ID[outlet_id]
        # affinity>0: iyi ilişkide payı artar. affinity<0: kötü ilişkide artar.
        weights.append(max(0.05, 1.0 + outlet["affinity_gain"] * bias))
    return OUTLETS_BY_ID[rng.choices(list(outlet_ids), weights=weights, k=1)[0]]


# `affinity_gain` is `media_affinity` under the name pick_outlet uses; kept
# as a derived key rather than a second authored column so the data file
# above has exactly one number per outlet to tune.
for _o in OUTLETS:
    _o["affinity_gain"] = _o["media_affinity"] * 1.85

assert len(OUTLETS) == 5
assert len(OUTLET_IDS) == len(OUTLETS), "duplicate outlet_id"
assert all(o["sign_off"] for o in OUTLETS), "every outlet needs a voice in its last line"
