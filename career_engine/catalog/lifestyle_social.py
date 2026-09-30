"""§14.3 D83-D86 - the design doc's social-skill activities, as lifestyle rows.

Forty-seven rows, plus three the lifestyle catalog already had (`ev-meditasyon`,
`sos-kafe`, `sos-taraftar` are the doc's #4, #11 and #34 and were extended in
place rather than duplicated). They live in their own module only because 47
rows would bury the fifteen that were there; catalog/lifestyle.py appends them
to LIFESTYLE_ITEMS, so every reader (T2, N3, activity events) sees one list.

Shape, beyond the original D41 row:

  mode        'S' solo, 'B' with someone, 'S/B' either (doc's S / B / S/B).
  with        the relationship kinds a B or S/B activity may be done with. The
              six fixed kinds only (D4): the doc's captain, equipment manager or
              physio are flavour on top of `team` / `coach`, not new people.
  with_delta  the relationship score the chosen person gains (D84).
  risk        {chance, fail_effects, mitigated_by?} (D85): a seeded roll after
              the action; `fail_effects` apply ON TOP of the normal effects.
              `mitigated_by` lets a skill lower the chance: -per_level per level.
  news        {ok?, fail?} headline a media activity may publish (§14.7).

The numbers are derived, not typed: the main skill gains more the longer the
activity runs, the side skill half of that. Every figure is ⟦AÇIK-5⟧ /
⟦AÇIK-20⟧ placeholder, but deriving them keeps 47 rows from drifting apart.
"""

G_HOME = "EV VE KİŞİSEL GELİŞİM"
G_CITY = "ŞEHİRDE"
G_CLUB = "KULÜP VE FUTBOL ÇEVRESİ"
G_MEDIA = "MEDYA VE DİJİTAL"
G_NIGHT = "GECE VE SOSYAL HAYAT"

KARIZMA, CESARET, EMPATI, ZEKA, DISIPLIN = (
    "charisma", "courage", "empathy", "intelligence", "discipline",
)

# Activities that fill the day's time at different rates. ⟦AÇIK-5⟧.
_QUIET = 0.05
_CLUB = 0.15
_MEDIA = 0.12
_OUT = 0.20
_NIGHT = 0.30


def _gain(minutes: int) -> float:
    """Main-skill gain for an activity of `minutes`: 0.3 for a short one up to
    0.5 for an evening. Well below a training session (0.8), same order as the
    five `sos-*` rows it sits beside (D42/D31)."""
    return round(min(0.5, 0.2 + minutes / 600), 1)


def _act(catalog_id, title, group, description, duration_label, minutes, main, side=None, *,
         mode="S", with_=None, money=0, condition=0, chance=_QUIET, requires=None,
         risk=None, news=None, with_delta=2):
    main_gain = _gain(minutes)
    effects = {}
    if condition:
        effects["condition"] = condition
    if money:
        effects["money"] = -money
    effects[f"attribute:{main}"] = main_gain
    if side:
        effects[f"attribute:{side}"] = round(main_gain / 2, 2)
    item = {
        "catalog_id": catalog_id, "title": title, "group": group,
        "description": description, "duration_label": duration_label,
        "costs": {"time": minutes}, "effects": effects, "event_chance": chance,
        "mode": mode,
    }
    if with_:
        item["with"] = list(with_)
        item["with_delta"] = with_delta
    if requires:
        item["requires"] = requires
    if risk:
        item["risk"] = risk
    if news:
        item["news"] = news
    return item


_TEAM, _COACH, _FANS = "team", "coach", "fans"
_FAMILY, _PARTNER, _MEDIA_REL = "family", "partner", "media"

SOCIAL_ACTIVITIES = [
    # --- 2.1 Ev ve kişisel gelişim (#4 is ev-meditasyon, extended in lifestyle.py) ---
    _act("ev-kitap", "Kitap Okumak", G_HOME,
         "Bir roman ya da bir biyografi. Sakin bir akşamın en kalıcı kazancı.",
         "1,5 saat", 90, ZEKA, DISIPLIN),
    _act("ev-mac-analizi", "Rakip Videolarını Analiz Et", G_HOME,
         "Bir sonraki rakibin son maçlarını dakika dakika izle. Yalnız ya da hocayla, notlar tutarak.",
         "2 saat", 120, ZEKA, mode="S/B", with_=(_COACH, _TEAM), condition=-1),
    _act("ev-roportaj-provasi", "Ayna Karşısında Röportaj Provası", G_HOME,
         "Zor soruları yüksek sesle cevapla. Kameranın önünde ilk kez konuşuyormuş gibi olmaktan kurtarır.",
         "45 dakika", 45, KARIZMA, CESARET),
    _act("ev-yemek-tarifi", "Yeni Bir Tarif Dene", G_HOME,
         "Mutfakta denenmemiş bir yemek. Tek başına sakin, birileriyle daha eğlenceli.",
         "1,5 saat", 90, DISIPLIN, EMPATI, mode="S/B",
         with_=(_FAMILY, _PARTNER, _TEAM), money=2, condition=2),
    _act("ev-dil-ogrenme", "Dil Öğrenme Uygulaması", G_HOME,
         "Yurt dışı bir transfere hazırlık: günde yarım saat, her gün.",
         "30 dakika", 30, ZEKA, DISIPLIN),
    _act("ev-gunluk", "Günlük Tutmak", G_HOME,
         "Günün maçlarını ve insanlarını yaz. Kendini dışarıdan okumanın en ucuz yolu.",
         "30 dakika", 30, EMPATI, DISIPLIN),
    _act("ev-aile-arama", "Aileyle Görüntülü Görüşme", G_HOME,
         "Sofradakileri ekranda gör, hâlini anlat. Uzaktayken bile bağı koruyor.",
         "1 saat", 60, EMPATI, mode="B", with_=(_FAMILY,), with_delta=3),
    _act("ev-online-satranc", "Online Satranç", G_HOME,
         "Dakikalık maçlar, aynı anda birkaç hamle ilerisini görmek.",
         "1 saat", 60, ZEKA, DISIPLIN),
    _act("ev-evcil-hayvan", "Köpek Gezdirmek", G_HOME,
         "Mahallede uzun bir tur. Sorumluluğun ve şefkatin küçük bir egzersizi.",
         "45 dakika", 45, EMPATI, DISIPLIN, condition=1),

    # --- 2.2 Şehirde (#11 is sos-kafe) ---
    _act("sehir-muze", "Müze ya da Sergi Gez", G_CITY,
         "Sessiz salonlar, merak edilen bir konu. Yalnız ya da biriyle.",
         "2 saat", 120, ZEKA, KARIZMA, mode="S/B",
         with_=(_PARTNER, _FAMILY, _TEAM), money=2, chance=_OUT),
    _act("sehir-sokak-lezzeti", "Sokak Lezzetleri Turu", G_CITY,
         "Acı biber challenge'ı dahil. Cesaret isteyen tek yemek turu.",
         "2 saat", 120, CESARET, mode="S/B",
         with_=(_TEAM, _PARTNER, _FAMILY), money=2, condition=-1, chance=_OUT),
    _act("sehir-standup", "Stand-up Gösterisi İzle", G_CITY,
         "Salondaki kahkahayı dinlemek sahne bilgisi öğretir.",
         "2 saat", 120, KARIZMA, mode="S/B", with_=(_TEAM, _PARTNER), money=3, chance=_OUT),
    _act("sehir-acik-mikrofon", "Açık Mikrofon Gecesi", G_CITY,
         "Sahneye çık ve beş dakika konuş. Yeterince cesaretin yoksa kapı kapalı.",
         "2 saat", 120, CESARET, KARIZMA, condition=-2, chance=_OUT,
         requires={"courage": 6}),
    _act("sehir-karaoke", "Karaoke", G_CITY,
         "Yanlış notalar, yüksek sesle. Utancı birlikte atmanın yolu.",
         "2,5 saat", 150, CESARET, KARIZMA, mode="B", with_=(_TEAM, _PARTNER),
         money=3, condition=-2, chance=_NIGHT),
    _act("sehir-bit-pazari", "Bit Pazarında Pazarlık", G_CITY,
         "Fiyatı düşürmeyi öğren. İleride bir sözleşme masasında işe yarar.",
         "1,5 saat", 90, ZEKA, CESARET, money=2, chance=_OUT),
    _act("sehir-sac-stili", "Yeni Bir Saç Stili", G_CITY,
         "Berberde yeni bir kesim. Aynaya bakışın da değişir.",
         "1 saat", 60, KARIZMA, money=4, chance=_OUT),
    _act("sehir-stilist", "Stilistle Kıyafet Alışverişi", G_CITY,
         "Bir stilistin gözüyle dolap yenile. Yalnız ya da yakınınla.",
         "3 saat", 180, KARIZMA, mode="B", with_=(_PARTNER, _FAMILY), money=8,
         chance=_OUT),
    _act("sehir-sahil-yuruyusu", "Sahilde Yürüyüş ve Sohbet", G_CITY,
         "Dalgaları dinleyerek yürü, konuşmak için acele etme.",
         "1,5 saat", 90, EMPATI, mode="B", with_=(_PARTNER, _FAMILY), condition=1,
         chance=_OUT, with_delta=3),
    _act("sehir-sinema", "Sinemaya Git", G_CITY,
         "Bir film, sonra dışarıda onun üzerine konuşmak.",
         "3 saat", 180, EMPATI, ZEKA, mode="B", with_=(_PARTNER, _FAMILY, _TEAM),
         money=2, chance=_OUT),
    _act("sehir-escape-room", "Escape Room", G_CITY,
         "Kilitli bir odada altmış dakika. Panik etmeyeni ve fikir üretmeyeni ayırır.",
         "1,5 saat", 90, ZEKA, CESARET, mode="B", with_=(_TEAM, _PARTNER),
         money=4, chance=_OUT),
    _act("sehir-lunapark", "Lunaparkta Ekstrem Oyuncaklar", G_CITY,
         "Yüksekten düşen vagonlar. Korkuyu paylaşmak.",
         "3 saat", 180, CESARET, mode="B", with_=(_TEAM, _PARTNER, _FAMILY),
         money=4, condition=-2, chance=_NIGHT),
    _act("sehir-barinak", "Hayvan Barınağında Gönüllülük", G_CITY,
         "Kafesleri temizle, yeni gelenlerle ilgilen.",
         "2 saat", 120, EMPATI, mode="S/B", with_=(_FAMILY, _PARTNER, _FANS),
         condition=-1, chance=_OUT),
    _act("sehir-huzurevi", "Huzurevi Ziyareti", G_CITY,
         "Anlatacak çok şeyi olan insanları dinlemek.",
         "2 saat", 120, EMPATI, KARIZMA, mode="S/B", with_=(_FAMILY, _PARTNER, _FANS),
         chance=_OUT),

    # --- 2.3 Kulüp ve futbol çevresi (#34 is sos-taraftar) ---
    _act("kulup-ekstra-calisma", "Antrenman Sonrası Ekstra Çalışma", G_CLUB,
         "Herkes gittikten sonra sahada bir saat daha. Kimse görmese de.",
         "1 saat", 60, DISIPLIN, condition=-4, chance=_CLUB),
    _act("kulup-altyapi-mentor", "Altyapı Oyuncularına Mentorluk", G_CLUB,
         "Sana bakan gençlere ne yaptığını anlat, nasıl yaptığını göster.",
         "1,5 saat", 90, EMPATI, KARIZMA, mode="B", with_=(_TEAM,), chance=_CLUB),
    _act("kulup-malzemeci", "Malzemeciyle Çay", G_CLUB,
         "Kulübün her şeyini bilen adamla küçük bir sohbet.",
         "45 dakika", 45, EMPATI, mode="B", with_=(_TEAM,), chance=_CLUB),
    _act("kulup-konsol-turnuvasi", "Konsol Turnuvası", G_CLUB,
         "Takım arkadaşlarıyla bir akşam, kazananın hakkı tartışılmaz.",
         "3 saat", 180, KARIZMA, ZEKA, mode="B", with_=(_TEAM,), condition=-3,
         chance=_CLUB),
    _act("kulup-kaptan-yemegi", "Kaptanla Akşam Yemeği", G_CLUB,
         "Soyunma odasının konuşulmayanlarını masada konuş.",
         "2 saat", 120, CESARET, ZEKA, mode="B", with_=(_TEAM,), money=4, chance=_CLUB),
    _act("kulup-taktik-tahtasi", "Taktik Tahtası Çalışması", G_CLUB,
         "Yardımcı antrenörle bir pozisyonu baştan sona çizmek.",
         "1,5 saat", 90, ZEKA, mode="B", with_=(_COACH,), chance=_CLUB),
    _act("kulup-fizyoterapist", "Fizyoterapistle Beslenme Sohbeti", G_CLUB,
         "Ne yediğin ne zaman yediğin, sahada bir ayrıntı olarak döner.",
         "45 dakika", 45, DISIPLIN, mode="B", with_=(_COACH,), chance=_CLUB),
    _act("kulup-soyunma-saka", "Soyunma Odasında Şaka Planla", G_CLUB,
         "Kurbanı bilmiyor. Plan tutarsa efsane, tutmazsa ciddi bir hesaplaşma.",
         "1 saat", 60, CESARET, KARIZMA, mode="B", with_=(_TEAM,), chance=_CLUB,
         risk={"chance": 0.35,
               "fail_effects": {"relationship:team": -6, "attribute:discipline": -0.2},
               "mitigated_by": {"attribute": KARIZMA, "per_level": 0.03}}),

    # --- 2.4 Medya ve dijital (#35-#41) ---
    _act("medya-paylasim", "Sosyal Medyada Paylaşım Yap", G_MEDIA,
         "Bir kare, iki cümle. Doğru tonu tutturursan konuşulursun; tutturamazsan da konuşulursun.",
         "30 dakika", 30, KARIZMA, chance=_MEDIA,
         risk={"chance": 0.30,
               "fail_effects": {"relationship:media": -4, "relationship:fans": -2},
               "mitigated_by": {"attribute": ZEKA, "per_level": 0.03}},
         news={"ok": {"category": "Röportaj", "source": "Sosyal Medya",
                      "title": "Paylaşımı beğeni topladı",
                      "body": "Genç oyuncunun son paylaşımı kısa sürede yüz binlerce kişiye ulaştı; "
                              "taraftarlar sade ve samimi tonu öne çıkarıyor."},
               "fail": {"category": "Röportaj", "source": "Sosyal Medya",
                        "title": "Paylaşım tepki çekti",
                        "body": "Oyuncunun son paylaşımı sosyal medyada eleştirildi; kulüp "
                                "çevresinde 'bir daha düşünmesi' gerektiği konuşuluyor."}}),
    _act("medya-canli-yayin", "Taraftarlarla Canlı Yayın", G_MEDIA,
         "Soruları gerçek zamanlı cevapla. Kimi sorar kimse bilmez.",
         "1 saat", 60, KARIZMA, CESARET, chance=_MEDIA,
         news={"ok": {"category": "Röportaj", "source": "Sosyal Medya",
                      "title": "Canlı yayında taraftarlarla buluştu",
                      "body": "Yayın boyunca yüzlerce soruyu cevaplayan oyuncu, taraftarlardan "
                              "olumlu tepki aldı."}}),
    _act("medya-podcast", "Podcast'e Konuk Ol", G_MEDIA,
         "Uzun bir sohbet, kesinti yok. Ne söylediğin kadar nasıl söylediğin.",
         "2 saat", 120, KARIZMA, ZEKA, mode="B", with_=(_MEDIA_REL,), chance=_MEDIA,
         news={"ok": {"category": "Röportaj", "source": "Podcast",
                      "title": "Podcast konuğu olarak açık sözlü konuştu",
                      "body": "Kariyerini ve hedeflerini anlatan oyuncu, sohbetiyle dinleyicilerin "
                              "beğenisini topladı."}}),
    _act("medya-kotu-yorumlar", "Kötü Yorumları Okuyup Cevap Vermemek", G_MEDIA,
         "Ekrandaki her şeye cevap vermek zorunda olmadığını öğrenmek.",
         "30 dakika", 30, DISIPLIN, CESARET, chance=_MEDIA),
    _act("medya-egitimi", "Medya Eğitimi Kursu", G_MEDIA,
         "Kamera önünde konuşma, zor soruya cevap, cümle kurma.",
         "3 saat", 180, KARIZMA, ZEKA, money=6, chance=_MEDIA),
    _act("medya-imza-gunu", "İmza Günü", G_MEDIA,
         "Saatlerce sıra, her birine bir cümle, bir gülümseme.",
         "2 saat", 120, KARIZMA, EMPATI, condition=-2, chance=_MEDIA,
         news={"ok": {"category": "Röportaj", "source": "Kulüp Bülteni",
                      "title": "İmza gününde uzun kuyruk",
                      "body": "Taraftarlar oyuncuyu görmek için saatlerce sıra bekledi."}}),
    _act("medya-cocuk-hastanesi", "Çocuk Hastanesi Ziyareti", G_MEDIA,
         "Formanı getirdin, onlar gülümsemeyi. Bundan fazlası gerekmiyor.",
         "2 saat", 120, EMPATI, mode="S/B", with_=(_FANS, _FAMILY, _PARTNER),
         chance=_MEDIA, with_delta=3),

    # --- 2.5 Gece ve sosyal hayat ---
    _act("gece-ev-partisi", "Arkadaşlarla Ev Partisi", G_NIGHT,
         "Çalan müzik, dolu salon. Evin ev sahibi olmak.",
         "4 saat", 240, KARIZMA, mode="B", with_=(_TEAM, _PARTNER, _FAMILY),
         money=6, condition=-6, chance=_NIGHT),
    _act("gece-dans-kursu", "Dans Kursu", G_NIGHT,
         "İlk derste herkes beceriksiz. Öğrenmenin tek yolu.",
         "1,5 saat", 90, CESARET, KARIZMA, mode="S/B", with_=(_PARTNER, _TEAM),
         money=4, condition=-2, chance=_NIGHT),
    _act("gece-pub-quiz", "Pub Quiz", G_NIGHT,
         "Takım olarak bilgi yarışması. Ekibini seçmek sorudan önemli.",
         "2,5 saat", 150, ZEKA, mode="B", with_=(_TEAM, _PARTNER), money=3, chance=_NIGHT),
    _act("gece-satranc-turnuvasi", "Satranç Kafede Turnuva", G_NIGHT,
         "Saatlerce masada, rakibin gözünü okuyarak.",
         "3 saat", 180, ZEKA, DISIPLIN, mode="B", with_=(_TEAM, _PARTNER), money=2,
         chance=_NIGHT),
    _act("gece-masa-oyunu", "Masa Oyunu Gecesi", G_NIGHT,
         "Vampir Köylü, Tabu. Kimin yalan söylediğini anlamak.",
         "3 saat", 180, KARIZMA, EMPATI, mode="B", with_=(_TEAM, _PARTNER, _FAMILY),
         money=1, chance=_NIGHT),
    _act("gece-poker", "Poker Gecesi", G_NIGHT,
         "Blöf yapmak cesaret ister, kaybetmemek zeka. Bazen ikisi de yetmez.",
         "4 saat", 240, CESARET, ZEKA, mode="B", with_=(_TEAM,), money=3,
         condition=-3, chance=_NIGHT,
         risk={"chance": 0.40,
               "fail_effects": {"money": -10, "attribute:discipline": -0.3},
               "mitigated_by": {"attribute": ZEKA, "per_level": 0.03}}),
    _act("gece-kamp", "Hafta Sonu Kamp ya da Trekking", G_NIGHT,
         "Çadır, yürüyüş, sabaha kadar ateş. Rahatlıktan uzak, insana yakın.",
         "Yarım gün", 360, CESARET, DISIPLIN, mode="B", with_=(_TEAM, _PARTNER, _FAMILY),
         money=3, condition=-6, chance=_NIGHT),
    _act("gece-gitar", "Gitar ya da Bağlama Dersi", G_NIGHT,
         "Her gün on beş dakika bir şey bir ay sonra müzik olur.",
         "1 saat", 60, DISIPLIN, KARIZMA, money=3, chance=_NIGHT),
    _act("gece-sokak-futbolu", "Mahalle Çocuklarıyla Sokak Futbolu", G_NIGHT,
         "Kale direği iki ceket. İlk kez sadece eğlenmek için oyna.",
         "1,5 saat", 90, EMPATI, KARIZMA, mode="B", with_=(_FAMILY, _FANS),
         condition=-4, chance=_NIGHT),
]
