"""§3.4 - the six relationship rows every new career starts with. Identity
content (person_name, contact_name, age, occupation, bio, hobbies) is
ported verbatim from relationships_screen.dart's _relationships list — the
only thing NOT ported is FE's example scores (74/58/51/63/29): those read
as an already-lived-in playthrough, not day-one values.

Dialogue TREES stay in FE (§1.3/D23) - only the person's card-facing
profile lives here.
"""

# §4's starting-value table, per relationship kind. Replaces the old flat
# STARTING_SCORE = 50 that every kind shared.
#
# partner and family are not in that table. §4 says a value it doesn't list
# "başlangıçta oluşturulmamalı veya 0/null olarak kabul edilmeli" — of those
# two options the row still gets written at 0 rather than skipped, because
# the relationship model has no nullable/absent state: R1/R2 list every kind,
# dialogue and the §6.5 decay tick both assume a row exists, and a missing
# row would make relationships.get_score() raise instead of return. A career
# therefore starts with no rapport with either, which is also the honest
# reading — you haven't called home yet.
STARTING_SCORES = {
    "coach": 70,
    "team": 50,
    "media": 10,
    "fans": 40,
    "partner": 0,
    "family": 0,
}

# §13.1 D68 / §13.2 D71 - the two per-kind facts that used to be implicit.
# `scope` decides whether a transfer wipes the row; `state` decides whether
# R1 lists it at all. Both are asserted against RELATIONSHIP_SEED below, so
# a kind added to one and forgotten in the other fails at import.
SCOPES = {
    "coach": "club", "team": "club", "fans": "club",
    "media": "career", "partner": "career", "family": "career",
}

# Partner is the one relationship you have not met on day one (§13.2). family
# is deliberately NOT absent even though its score is also 0: not having
# called home yet is a different thing from not having a family.
STARTING_STATES = {
    "coach": "active", "team": "active", "media": "active", "fans": "active",
    "family": "active",
    "partner": "absent",
}

RELATIONSHIP_SEED = [
    {
        "relationship_id": "coach", "kind": "coach", "category": "Antrenör",
        "person_name": "Mert Çalışkan", "contact_name": "Antrenör Mert",
        "age": 48, "occupation": "Baş antrenör",
        "bio": "Disiplinli ve veriye güvenen bir isim. Sahada bireysel parlamak "
               "yerine takım oyununu görmek istiyor; kararlarını istatistiklere "
               "dayandırıyor.",
        "hobbies": ["Satranç", "Yüzme", "Maç analizi"],
    },
    {
        "relationship_id": "team", "kind": "team", "category": "Takım Arkadaşları",
        "person_name": "Burak Şen", "contact_name": "Takım grubu",
        "age": 26, "occupation": "Profesyonel futbolcu · Kaptan",
        "bio": "Soyunma odasının sesi. Takım içi gerginlikleri büyümeden çözmesiyle "
               "biliniyor, yeni gelenleri ilk o sahiplenir.",
        "hobbies": ["PlayStation", "Basketbol", "Podcast"],
    },
    {
        "relationship_id": "media", "kind": "media", "category": "Medya",
        "person_name": "Ayça Kılıç", "contact_name": "Spor Manşet",
        "age": 34, "occupation": "Spor muhabiri · Spor Manşet",
        "bio": "Transfer haberlerini ilk veren isimlerden. Verdiğin her demeç "
               "ertesi sabah manşete dönüşebilir, kelimelerini tartarak seç.",
        "hobbies": ["Koşu", "Fotoğrafçılık", "Vinil plak"],
        "traits_extra": {"outlet": "Spor Manşet"},
    },
    {
        "relationship_id": "fans", "kind": "fans", "category": "Taraftarlar",
        "person_name": "Tribün Grubu", "contact_name": "Taraftar grubu",
        "age": None, "occupation": "Kulüp taraftar topluluğu",
        "bio": "Kötü günde de tribünü dolduruyorlar ama sabırları sonsuz değil. "
               "Sahadaki çabanı formundan önce görürler; bir maçta verdiğin "
               "mücadele haftalarca konuşulur.",
        "hobbies": ["Deplasman yolculuğu", "Koreografi", "Tezahürat"],
    },
    {
        "relationship_id": "partner", "kind": "partner", "category": "Partner",
        "person_name": "Elif Demir", "contact_name": "Elif",
        "age": 24, "occupation": "Grafik tasarımcı",
        "bio": "Maç takvimine anlayışla yaklaşıyor ama uzun sessizlikleri sevmiyor. "
               "Kısa bir telefon bile ilişkiye iyi geliyor.",
        "hobbies": ["Resim", "Kahve", "Seyahat"],
    },
    {
        "relationship_id": "family", "kind": "family", "category": "Aile / Sosyal Çevre",
        "person_name": "Sevgi Yılmaz", "contact_name": "Anne",
        "age": 55, "occupation": "Emekli öğretmen",
        "bio": "Her maçını televizyondan takip ediyor. Aramaların seyrekleştiğinde "
               "bunu dile getirmese de ilişki puanı hızla düşüyor.",
        "hobbies": ["Bahçe işleri", "Örgü", "Akşam dizileri"],
    },
]

# §13.1 D70 - the club-side identities a transfer re-seeds. A new club means
# a new dressing room: the coach who trusted you, the captain who vouched for
# you and the stand that sang your name are all somebody else's now.
#
# **Why a pool and not a row per team.** Writing an authored coach for each of
# the 32 teams is not today's work, but INV-7 (same seed -> same world) breaks
# the moment an unauthored team picks a random name. So the pool below is
# indexed deterministically from (career.seed, team_id) in
# domain/relationships.py::club_identity(); a team that later earns an
# authored entry in CLUB_STAFF simply stops falling through to it. Same
# "authored where it matters, derived where it doesn't" split worlddata/teams
# already draws for strength ratings.
CLUB_STAFF_POOL = {
    "coach": [
        {"person_name": "Kerem Tunç", "contact_name": "Antrenör Kerem", "age": 51,
         "occupation": "Baş antrenör",
         "bio": "Sert bir disiplinci. Oynamak isteyen önce koşacak diyor ve bunu "
                "her yeni gelene ilk gün söylüyor.",
         "hobbies": ["Dağ yürüyüşü", "Tarih kitapları", "Satranç"]},
        {"person_name": "Sinan Aksoy", "contact_name": "Antrenör Sinan", "age": 43,
         "occupation": "Baş antrenör",
         "bio": "Genç kadrolarla çalışmayı seven, oyuncusuna alan tanıyan bir isim. "
                "Hata affeder, isteksizliği affetmez.",
         "hobbies": ["Video analiz", "Bisiklet", "Caz"]},
        {"person_name": "Orhan Demirtaş", "contact_name": "Antrenör Orhan", "age": 57,
         "occupation": "Baş antrenör",
         "bio": "Kırk yıldır sahanın içinde. Sisteme değil oyuncuya bakıyor; "
                "güvenini kazanmak zaman alıyor ama kazanılınca kalıcı oluyor.",
         "hobbies": ["Balık tutma", "Eski maç kasetleri", "Tavla"]},
    ],
    "team": [
        {"person_name": "Onur Bilge", "contact_name": "Takım grubu", "age": 29,
         "occupation": "Profesyonel futbolcu · Kaptan",
         "bio": "Soyunma odasının düzenini kuran isim. Yeni geleni tartar, "
                "kabul ettiyse arkasında durur.",
         "hobbies": ["Kamp", "Podcast", "Masa tenisi"]},
        {"person_name": "Tolga Eren", "contact_name": "Takım grubu", "age": 24,
         "occupation": "Profesyonel futbolcu · Kaptan",
         "bio": "Kadronun en sesli ismi. Şakası da eleştirisi de yüze karşı; "
                "arkadan konuşmayı sevmiyor.",
         "hobbies": ["PlayStation", "Basketbol", "Yemek yapma"]},
        {"person_name": "Serkan Alp", "contact_name": "Takım grubu", "age": 32,
         "occupation": "Profesyonel futbolcu · Kaptan",
         "bio": "Sessiz ama sözü geçen bir kaptan. Antrenmanda en erken gelen, "
                "en geç çıkan o.",
         "hobbies": ["Kitap", "Yüzme", "Koleksiyon"]},
    ],
    "fans": [
        {"person_name": "Tribün Grubu", "contact_name": "Taraftar grubu", "age": None,
         "occupation": "Kulüp taraftar topluluğu",
         "bio": "Deplasman yolunu hiç boş bırakmayan bir grup. Formayı hak eden "
                "herkesi sahiplenirler, hak etmeyeni de aynı sesle söylerler.",
         "hobbies": ["Deplasman yolculuğu", "Koreografi", "Tezahürat"]},
        {"person_name": "Açık Tribün", "contact_name": "Taraftar grubu", "age": None,
         "occupation": "Kulüp taraftar topluluğu",
         "bio": "Sabırlı ama unutmayan bir tribün. İlk maçta alkışlar, üçüncü "
                "kötü maçta sorar.",
         "hobbies": ["Marş yazma", "Bayrak", "Maç sonrası buluşma"]},
        {"person_name": "Kale Arkası", "contact_name": "Taraftar grubu", "age": None,
         "occupation": "Kulüp taraftar topluluğu",
         "bio": "Doksan dakika ayakta duran taraf. Skordan çok mücadeleye "
                "bakıyorlar; koşmayan oyuncuyu affetmiyorlar.",
         "hobbies": ["Koreografi", "Meşale", "Genç takım maçları"]},
    ],
}

assert {r["relationship_id"] for r in RELATIONSHIP_SEED} == set(STARTING_SCORES), (
    "every seeded relationship needs a starting score, and vice versa"
)
assert all(0 <= s <= 100 for s in STARTING_SCORES.values())
assert set(SCOPES) == set(STARTING_SCORES), "every kind needs a scope (§13.1)"
assert set(STARTING_STATES) == set(STARTING_SCORES), "every kind needs a starting state (§13.2)"
assert set(CLUB_STAFF_POOL) == {k for k, v in SCOPES.items() if v == "club"}, (
    "every club-scoped relationship needs an identity pool to re-seed from (§13.1 D70)"
)
