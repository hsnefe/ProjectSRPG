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

assert {r["relationship_id"] for r in RELATIONSHIP_SEED} == set(STARTING_SCORES), (
    "every seeded relationship needs a starting score, and vice versa"
)
assert all(0 <= s <= 100 for s in STARTING_SCORES.values())
