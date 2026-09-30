"""§5.6 N3 'lifestyle' - ports lifestyle_screen.dart's fifteen activities
(three groups) into D41's costs/effects shape. `duration` (a free-text
label like 'Tüm gece') becomes costs.time in minutes — a reasonable literal
reading of each label, e.g. '1 saat' → 60, 'Yarım gün' → 360. `cost` (₭)
becomes effects.money as a negative; `conditionDelta` becomes
effects.condition unchanged. Every number here is ⟦AÇIK-5⟧ — placeholder
until the budget's actual scale is decided.

D42/D31: the five SOSYAL items also move kişi attributes now. They are
deliberately an order of magnitude below a kişi training session (0.1-0.5
vs 0.8): time spent among people grows you, but it is not a substitute for
actually working on it.
"""

LIFESTYLE_ITEMS = [
    # --- EV AKTİVİTELERİ ---
    {"catalog_id": "ev-uyku", "title": "Uyku", "group": "EV AKTİVİTELERİ",
     "description": "Erken yatıp dokuz saat kesintisiz uyu. Kaslar toparlanır, "
                     "ertesi güne kondisyonun tazelenmiş başlarsın.",
     "duration_label": "Tüm gece",
     "costs": {"time": 540}, "effects": {"condition": 14},
     "event_chance": 0.02},
    {"catalog_id": "ev-yemek", "title": "Sağlıklı Yemek", "group": "EV AKTİVİTELERİ",
     "description": "Kendi mutfağında dengeli bir öğün hazırla. Doğru beslenme, "
                     "antrenmandan aldığın verimi doğrudan artırır.",
     "duration_label": "1 saat",
     "costs": {"time": 60}, "effects": {"condition": 6, "money": -2},
     "event_chance": 0.04},
    {"catalog_id": "ev-meditasyon", "title": "Meditasyon", "group": "EV AKTİVİTELERİ",
     "description": "Sessiz bir odada nefes çalışması yap. Maç öncesi baskıyı "
                     "yönetmeni kolaylaştırır.",
     "duration_label": "30 dakika",
     "costs": {"time": 30}, "effects": {"condition": 5},
     "event_chance": 0.03},
    {"catalog_id": "ev-oyun", "title": "Video Oyunu", "group": "EV AKTİVİTELERİ",
     "description": "Birkaç saat oyun oyna, kafanı dağıt. Keyifli ama geç saate "
                     "kalırsan kondisyonundan yersin.",
     "duration_label": "3 saat",
     "costs": {"time": 180}, "effects": {"condition": -6},
     "event_chance": 0.08},
    {"catalog_id": "ev-film", "title": "Film Gecesi", "group": "EV AKTİVİTELERİ",
     "description": "Kanepeye kurul ve uzun bir film izle. Zihnini boşaltır, "
                     "bedenini pek dinlendirmez.",
     "duration_label": "2 saat",
     "costs": {"time": 120}, "effects": {"condition": 2},
     "event_chance": 0.05},

    # --- FİZİKSEL AKTİVİTELER ---
    {"catalog_id": "fiz-kosu", "title": "Sabah Koşusu", "group": "FİZİKSEL AKTİVİTELER",
     "description": "Güneş doğarken parkta tempolu koş. Dayanıklılığını besler ama "
                     "gün içinde biraz yorgun hissedersin.",
     "duration_label": "45 dakika",
     "costs": {"time": 45}, "effects": {"condition": -8},
     "event_chance": 0.1},
    {"catalog_id": "fiz-yuzme", "title": "Yüzme", "group": "FİZİKSEL AKTİVİTELER",
     "description": "Havuzda düşük tempolu kulaç at. Eklemleri zorlamadan "
                     "toparlanmayı hızlandıran ideal aktif dinlenme.",
     "duration_label": "1 saat",
     "costs": {"time": 60}, "effects": {"condition": 8, "money": -1},
     "event_chance": 0.08},
    {"catalog_id": "fiz-bisiklet", "title": "Bisiklet", "group": "FİZİKSEL AKTİVİTELER",
     "description": "Sahil boyunca uzun bir tur at. Bacak kaslarını çalıştırır, "
                     "kafanı da açar.",
     "duration_label": "1,5 saat",
     "costs": {"time": 90}, "effects": {"condition": -4},
     "event_chance": 0.12},
    {"catalog_id": "fiz-yoga", "title": "Yoga", "group": "FİZİKSEL AKTİVİTELER",
     "description": "Esneme ve denge çalışması yap. Sakatlanma riskini düşürür, "
                     "kaslarındaki gerginliği alır.",
     "duration_label": "50 dakika",
     "costs": {"time": 50}, "effects": {"condition": 7, "money": -2},
     "event_chance": 0.06},
    {"catalog_id": "fiz-sauna", "title": "Sauna & Masaj", "group": "FİZİKSEL AKTİVİTELER",
     "description": "Profesyonel bir merkezde tam toparlanma seansı. Pahalı ama "
                     "kondisyonu en hızlı geri getiren yöntem.",
     "duration_label": "2 saat",
     "costs": {"time": 120}, "effects": {"condition": 16, "money": -6},
     "event_chance": 0.1},

    # --- SOSYAL AKTİVİTELER ---
    {"catalog_id": "sos-arkadas", "title": "Arkadaş Buluşması", "group": "SOSYAL AKTİVİTELER",
     "description": "Eski dostlarınla bir araya gel. Moralini yükseltir, "
                     "sosyal çevrenle bağını canlı tutar.",
     "duration_label": "3 saat",
     "costs": {"time": 180},
     "effects": {"condition": -3, "money": -3, "attribute:charisma": 0.3},
     "event_chance": 0.35},
    {"catalog_id": "sos-kafe", "title": "Kafe", "group": "SOSYAL AKTİVİTELER",
     "description": "Sakin bir kafede kahve iç. Kısa ve zararsız bir mola, "
                     "kafan dinlenir.",
     "duration_label": "1 saat",
     "costs": {"time": 60},
     "effects": {"condition": 1, "money": -1, "attribute:empathy": 0.1},
     "event_chance": 0.3},
    {"catalog_id": "sos-aile", "title": "Aile Ziyareti", "group": "SOSYAL AKTİVİTELER",
     "description": "Ailenle vakit geçir. Kariyerin baskısını hafifletir, "
                     "aile ilişkini güçlendirir.",
     "duration_label": "Yarım gün",
     "costs": {"time": 360},
     "effects": {"condition": 4, "relationship:family": 3, "attribute:empathy": 0.3},
     "event_chance": 0.2},
    {"catalog_id": "sos-konser", "title": "Konser", "group": "SOSYAL AKTİVİTELER",
     "description": "Gece boyu sahne önünde ol. Eğlencesi bol, ertesi günkü "
                     "antrenmana bedeli ağır.",
     "duration_label": "Tüm gece",
     "costs": {"time": 540},
     "effects": {"condition": -12, "money": -8, "attribute:courage": 0.4},
     "event_chance": 0.4},
    # D35 - "Tribünün gözünde değerin artar" vaadi burada ilk kez karşılığını
    # buluyor: fame:overall AÇIK-9 kapanana kadar null (§3.2 notu).
    # D42: charisma 7 taze bir kariyerin seviyesinin TAM karşılığıdır, yani
    # bu kapı ilk günden açıktır — ve INV-22 (nitelik kendiliğinden azalmaz)
    # yüzünden bir daha da kapanmaz. Engellemek için değil, `requires`
    # şeklini bir lifestyle kaleminde sabitlemek ve FE'ye "eşik var ve
    # karşılanıyor" durumunu çizecek bir örnek vermek için burada.
    {"catalog_id": "sos-taraftar", "title": "Taraftar Etkinliği", "group": "SOSYAL AKTİVİTELER",
     "description": "Kulübün taraftar buluşmasına katıl. Tribünün gözünde "
                     "değerin artar.",
     "duration_label": "2 saat",
     "costs": {"time": 120},
     "effects": {"condition": -2, "fame:overall": None,
                 "attribute:charisma": 0.5, "attribute:courage": 0.3},
     "requires": {"charisma": 7},
     "event_chance": 0.35},
]

# §13.4/D75 - every row names its own `event_chance`. The pool a given
# activity draws from lives on the TEMPLATE side (content/activity_events.py's
# `catalog_ids`), so one template can hang off several activities without this
# file listing them; what belongs here is only how eventful the activity is.
# Home is quiet (0.02-0.08), the gym sits in between, going out is where
# things happen (0.20-0.40) — that spread is what stops "every lifestyle
# activity can spawn an event" from meaning "every activity is equally
# eventful".
assert all("event_chance" in i for i in LIFESTYLE_ITEMS)

assert len(LIFESTYLE_ITEMS) == 15
assert len({i["catalog_id"] for i in LIFESTYLE_ITEMS}) == len(LIFESTYLE_ITEMS)

from catalog import validate_catalog  # noqa: E402 (after data, INV-28)

validate_catalog(LIFESTYLE_ITEMS, "lifestyle")
