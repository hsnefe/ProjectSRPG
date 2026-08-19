"""§5.6 N3 'shop' - ports shop_screen.dart's fourteen items (four
categories) verbatim: id, title, description, price, note. `category`
uses ShopCategory's own identifiers (home/personal/realEstate/investment)
so FE needs no translation layer.

D27: only the three real-estate items carry upkeep_weekly > 0 — the other
categories are one-off purchases with no ongoing cost. Amounts are
authored, not derived from price by a fixed formula; ⟦AÇIK-5⟧ still covers
whether this scale is right.
"""

SHOP_ITEMS = [
    # --- home ---
    {"catalog_id": "home-tv", "title": "Akıllı TV", "category": "home",
     "description": "Oturma odasına 65 inç. Maç akşamları arkadaşları çağırmak için "
                     "yeterince büyük.",
     "price": 32000, "upkeep_weekly": 0, "note": "65 inç, 4K"},
    {"catalog_id": "home-espresso", "title": "Espresso makinesi", "category": "home",
     "description": "Sabah antrenmanından önce kahve kuyruğunda beklemeye son.",
     "price": 12500, "upkeep_weekly": 0, "note": "Otomatik öğütücülü"},
    {"catalog_id": "home-console", "title": "Oyun konsolu", "category": "home",
     "description": "Boş günlerin standart eğlencesi. Takım arkadaşlarıyla online "
                     "turnuvalar için de iyi bahane.",
     "price": 18900, "upkeep_weekly": 0, "note": "İki kollu"},
    {"catalog_id": "home-treadmill", "title": "Koşu bandı", "category": "home",
     "description": "Kamp dışı günlerde kondisyonu evde korumanın en kolay yolu.",
     "price": 41000, "upkeep_weekly": 0, "note": "Eğimli, 20 km/s"},

    # --- personal ---
    {"catalog_id": "personal-watch", "title": "Kol saati", "category": "personal",
     "description": "Röportajlarda ve sponsor çekimlerinde görünen tek takı.",
     "price": 27500, "upkeep_weekly": 0, "note": "Çelik kasa"},
    {"catalog_id": "personal-boots", "title": "Krampon", "category": "personal",
     "description": "Kendi ayağına göre kalıplanmış çift. Islak zeminde fark ediyor.",
     "price": 8900, "upkeep_weekly": 0, "note": "Kişiye özel kalıp"},
    {"catalog_id": "personal-suit", "title": "Takım elbise", "category": "personal",
     "description": "Deplasman yolculukları ve kulüp galaları için.",
     "price": 15400, "upkeep_weekly": 0, "note": "Ismarlama"},
    {"catalog_id": "personal-headphones", "title": "Kulaklık", "category": "personal",
     "description": "Otobüs yolculuklarında dış sesi kesiyor; maç öncesi rutinin "
                     "parçası.",
     "price": 6200, "upkeep_weekly": 0, "note": "Gürültü engelleyici"},

    # --- realEstate (D27: tek gerçek düzenli gider kaynağı) ---
    {"catalog_id": "estate-studio", "title": "Stüdyo daire", "category": "realEstate",
     "description": "Tesise on beş dakika. Küçük ama kendi başına yaşamak için yeterli.",
     "price": 1850000, "upkeep_weekly": 800, "note": "1+0, 55 m²"},
    {"catalog_id": "estate-flat", "title": "Şehir merkezi daire", "category": "realEstate",
     "description": "Merkezde geniş bir kat. Aile ziyaretleri için yer var.",
     "price": 4600000, "upkeep_weekly": 1800, "note": "3+1, 120 m²"},
    {"catalog_id": "estate-villa", "title": "Deniz manzaralı villa", "category": "realEstate",
     "description": "Sezon arasında kaçılacak yer. Bahçesinde kendi antrenman alanı "
                     "kurulabilir.",
     "price": 12750000, "upkeep_weekly": 4500, "note": "Havuzlu, 380 m²"},

    # --- investment ---
    {"catalog_id": "invest-bond", "title": "Devlet tahvili", "category": "investment",
     "description": "Sıkıcı ama öngörülebilir. Kariyerin geri kalanı için güvenli zemin.",
     "price": 25000, "upkeep_weekly": 0, "note": "Yıllık %28 getiri"},
    {"catalog_id": "invest-gold", "title": "Altın", "category": "investment",
     "description": "Kasaya girer, unutulur. Enflasyona karşı klasik siper.",
     "price": 40000, "upkeep_weekly": 0, "note": "100 gram"},
    {"catalog_id": "invest-fund", "title": "Hisse portföyü", "category": "investment",
     "description": "Menajerin önerdiği karma fon. Dalgalı ama uzun vadede iddialı.",
     "price": 120000, "upkeep_weekly": 0, "note": "Orta risk"},
]

assert len(SHOP_ITEMS) == 14
assert len({i["catalog_id"] for i in SHOP_ITEMS}) == len(SHOP_ITEMS)
