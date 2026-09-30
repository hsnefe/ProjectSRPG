"""§14.5-§14.6 D91-D94 - the design doc's 40 relationship events, plus the two
follow-ups its chains need. Each is a choice moment with a good road and a bad
one, often gated by a skill.

**Same shape as content/activity_events.py on purpose.** An event is a paragraph
and N buttons, so once a trigger has promoted it, domain/activity_events.py serves
it, T5 lists it and T6 answers it - no second answering path. What is new here is
only what makes it *arrive*: a `trigger` (when it is queued), a `priority`, an
`expires_in_days` (how long it waits in the queue, D92) and, per option, `defer`
(what comes due later, D94). `catalog_ids` is empty: no lifestyle activity spawns
these.

**The six fixed kinds (D4/D93).** `relationship` names which of the six a template
is about. The doc's management is `coach`, its agent is `family` (an agent is
the family's man in a negotiation) and its sponsors are the existing sponsorship
system (§12.7) - so a sponsor event moves `fame:overall` and `money`, or ends a deal
with the `sponsorship:end` effect, rather than touching a relationship that does
not exist.

**Skill gates** are the doc's "≥2 / ≥3" recalibrated to this game's 0-10 levels
(charisma starts at 7, empathy 5, courage 5, intelligence 6, discipline 2):
doc 2 -> 7, doc 3 -> 8. ⟦AÇIK-5⟧ owns the real scale.

**Triggers** (closed set, validated at import, evaluated by domain/triggers.py):

  {"kind": "date", "on": "birthday", "who": <relationship id>}
  {"kind": "date", "on": "anniversary"}                 # partner, only while active
  {"kind": "date", "on": "contract_left", "days": N}    # edge: exactly N days left
  {"kind": "date", "on": "derby_week"}                  # three days before a rival fixture
  {"kind": "date", "on": "special_day", "day": <SPECIAL_DAYS key>}
  {"kind": "daily", "chance": p, "needs": [...]}        # seeded roll, once a season
  {"kind": "post_match", "when": <fact>, "chance": p}   # domain/triggers.post_match_facts;
                                                        # chance defaults to 1, rolled per fixture
  {"kind": "activity", "catalog_id": ..., "on": "fail"}

In-match moments (a red card, being taken off, a goal chance) cannot fire for real -
no match_engine event reaches this service (⟦AÇIK-19⟧, §14.7) - so #2, #4 and #13
are rebuilt on what the final result does carry.

**Numbers.** Relationship deltas follow the existing scale (a missed plan is -12,
a chosen conflict side +4); every value here is ⟦AÇIK-5⟧. Money amounts stay small
because a fresh career holds 60 ₭: an option the player cannot pay for is rejected at
T6 and leaves the event open (INV-30's shape), and an ungated escape is always there.

Adding an event is an edit to THIS FILE ONLY.
"""

# D92: a candidate waits this many days by default before it is dropped unseen.
DEFAULT_EXPIRES_IN_DAYS = 3


def _opt(option_id, label, effects=None, *, requires=None, costs=None, defer=None):
    option = {"option_id": option_id, "label": label, "effects": effects or {}}
    if requires:
        option["requires"] = requires
    if costs:
        option["costs"] = costs
    if defer:
        option["defer"] = defer
    return option


def _ev(template_id, relationship, priority, trigger, title, body, options, *,
        expires_in_days=DEFAULT_EXPIRES_IN_DAYS, on_ignore=None):
    event = {
        "template_id": template_id, "relationship": relationship, "priority": priority,
        "trigger": trigger, "expires_in_days": expires_in_days,
        "catalog_ids": [], "weight": 1, "requires": {},
        "title": title, "body": body, "options": options,
    }
    if on_ignore:
        event["on_ignore"] = on_ignore
    return event


def _later(days, effects, *, followup=None, news=None):
    return {"days": days, "effects": effects, "followup": followup, "news": news}


# Fixed-calendar moments (month, day). Bayram moves with the moon and this game
# has no religious calendar, so "a holiday" is a fixed date, the same one every year.
SPECIAL_DAYS = {"gala": (12, 14), "holiday": (4, 22)}

RELATIONSHIP_EVENTS = [
    # ===== 5.1 Takım arkadaşları (team) =====
    _ev("rel-dogum-gunu-takim", "team", 60,
        {"kind": "date", "on": "birthday", "who": "team"},
        "Doğum günü sürprizi",
        "Takımın kaptanı bu akşam doğum günü için soyunma odasında pasta hazırlıyor. "
        "Herkes bir şeyler getirmiş; senin elin boş.",
        [_opt("hediye", "Bir hediye alıp katıl", {"money": -15, "relationship:team": 8}),
         _opt("ugra", "Sadece uğra", {"relationship:team": 3}, costs={"time": 45.0})],
        expires_in_days=2, on_ignore={"relationship:team": -6}),

    _ev("rel-kirmizi-kart", "team", 55,
        {"kind": "post_match", "when": "red_card_loss"},
        "Kırmızı kart sonrası",
        "Takım kaybetti ve takım arkadaşlarından biri kırmızı kartla oyundan atıldı. "
        "Soyunma odası sessiz; herkes ona bakmamaya çalışıyor.",
        [_opt("teselli", "Yanına oturup teselli et", {"relationship:team": 10, "attribute:empathy": 0.2},
              requires={"empathy": 7}),
         _opt("sus", "Kimseye bir şey söyleme"),
         _opt("suclama", "Yüksek sesle suçla", {"relationship:team": -14})],
        expires_in_days=2),

    _ev("rel-forma-rekabeti", "team", 45,
        {"kind": "post_match", "when": "bench", "chance": 0.5},
        "Forma rekabeti",
        "Aynı mevkide oynayan oyuncu ilk on birde sahaya çıktı, sen yedek kulübesinde "
        "oturdun. Maçtan sonra koridorda karşılaştınız.",
        [_opt("tebrik", "Tebrik et", {"relationship:team": 6, "attribute:empathy": 0.1}),
         _opt("sikayet", "Antrenöre şikâyet et", {"relationship:coach": -8, "relationship:team": -6}),
         _opt("sessiz", "Hiçbir şey söyleme")],
        expires_in_days=2),

    _ev("rel-gol-paslasmasi", "team", 40,
        {"kind": "post_match", "when": "no_goal", "chance": 0.25},
        "Gol pozisyonu",
        "Maçtan sonra takım arkadaşın, golü sana atma şansı verdiği pozisyondan bahsetti: "
        "iki kişiydiniz, sen şutu seçmiştin.",
        [_opt("haklisin", "\"Haklısın, pas vermeliydim\"", {"relationship:team": 6}),
         _opt("sutu_savun", "\"Şut doğru karardı\"", {"relationship:team": -5}),
         _opt("guluup_gec", "Gülüp geç")],
        expires_in_days=2),

    _ev("rel-borc-istemek", "team", 35,
        {"kind": "daily", "chance": 0.012, "needs": []},
        "Borç istemek",
        "Takım arkadaşın seni kenara çekti. Bu ay sıkışmış; kirayı yatırmak için "
        "kısa süreliğine para lazım.",
        [_opt("borc_ver", "Borç ver", {"money": -40, "relationship:team": 12},
              defer=[_later(30, {"money": 40})]),
         _opt("verip_iste", "Ver ama geri iste", {"money": -40, "relationship:team": 4},
              defer=[_later(14, {"money": 40, "relationship:team": -4})]),
         _opt("reddet", "Reddet", {"relationship:team": -3})]),

    _ev("rel-sir-paylasimi", "team", 35,
        {"kind": "daily", "chance": 0.01, "needs": []},
        "Sır paylaşımı",
        "Takım arkadaşın, başka bir kulüple görüştüğünü sadece sana anlatıyor. "
        "Kimsenin bilmesini istemiyor.",
        [_opt("sir_tut", "Sır tut", {"relationship:team": 8},
              defer=[_later(35, {"relationship:team": 6})]),
         _opt("soyle", "Başkasına anlat", {},
              defer=[_later(14, {"relationship:team": -20, "fame:overall": -0.3},
                            news={"category": "Söylenti", "title": "Transfer görüşmesi sızdı",
                                  "body": "Takımdan bir oyuncunun başka bir kulüple görüştüğü "
                                          "soyunma odasından duyuldu."})]),
         _opt("dinle_gec", "Dinle ve konuyu kapat")]),

    _ev("rel-yeni-transfer-uyumu", "team", 40,
        {"kind": "daily", "chance": 0.012, "needs": ["window_open"]},
        "Yeni transfer uyumu",
        "Takıma yabancı bir oyuncu katıldı. Şehri tanımıyor, dili zor konuşuyor, "
        "yemekte tek başına oturuyor.",
        [_opt("gezdir", "Ona şehri gezdir", {"relationship:team": 8, "attribute:empathy": 0.2},
              costs={"time": 120.0, "energy": 10.0}),
         _opt("gormezden", "Görmezden gel", {},
              defer=[_later(21, {}, followup="rel-gruplasma-rakip")])]),

    _ev("rel-soyunma-gruplasmasi", "team", 40,
        {"kind": "daily", "chance": 0.008, "needs": []},
        "Soyunma odası gruplaşması",
        "Takımda iki klik oluştu. Yemekte ayrı masalar, soyunma odasında ayrı köşeler. "
        "İkisi de seni kendi tarafına çekmeye çalışıyor.",
        [_opt("arabulucu", "Arabuluculuk yap", {"relationship:team": 10, "attribute:charisma": 0.3},
              requires={"charisma": 8}),
         _opt("taraf_sec", "Bir tarafı seç", {"relationship:team": -8}),
         _opt("uzak_dur", "İkisinden de uzak dur")]),

    _ev("rel-gruplasma-rakip", "team", 40,
        {"kind": "deferred"},
        "Karşı tarafta biri",
        "Geçen haftalarda yeni gelene yüz vermedin; şimdi o, soyunma odasındaki rakip "
        "grubun en sesli oyuncularından biri ve senin hakkında konuşuyor.",
        [_opt("baris", "Gidip konuş", {"relationship:team": 6},
              requires={"empathy": 7}),
         _opt("taraf_sec", "Kendi grubunun yanında dur", {"relationship:team": -8}),
         _opt("uzak_dur", "Mesafeni koru")]),

    _ev("rel-saka-kontrolden", "team", 65,
        {"kind": "activity", "catalog_id": "kulup-soyunma-saka", "on": "fail"},
        "Şaka kontrolden çıktı",
        "Soyunma odası şakası beklediğin gibi gitmedi. Hedef aldığın oyuncu artık "
        "gülmüyor ve herkes sana bakıyor.",
        [_opt("ozur", "Özür dile", {"relationship:team": -2, "attribute:empathy": 0.2}),
         _opt("guluup_gec", "Gülüp geç", {"relationship:team": -12})],
        expires_in_days=2),

    _ev("rel-kaptanlik-secimi", "team", 45,
        {"kind": "daily", "chance": 0.006, "needs": []},
        "Kaptanlık seçimi",
        "Kaptan takımdan ayrıldı. Oylama yarın; kulüp yeni bir isim bekliyor.",
        [_opt("aday_ol", "Aday ol", {"relationship:team": 10, "relationship:fans": 4},
              requires={"charisma": 7}),
         _opt("destekle", "Seçilen kaptanı destekle", {"relationship:team": 4}),
         _opt("kenarda", "Kenarda kal")],
        on_ignore={"relationship:team": -3}),

    # ===== 5.2 Teknik ekip ve antrenör (coach) =====
    _ev("rel-taktik-itirazi", "coach", 40,
        {"kind": "daily", "chance": 0.01, "needs": []},
        "Taktik itirazı",
        "Antrenör, pozisyonuna uymayan bir rol verdi: kanatta değil, dar oynatmak "
        "istiyor. Antrenman sonrası yanına gidebilirsin.",
        [_opt("ikna_et", "Verilerle ikna etmeye çalış", {"relationship:coach": 8, "attribute:intelligence": 0.2},
              requires={"intelligence": 8}),
         _opt("itiraz", "Açıkça itiraz et", {"relationship:coach": -8}),
         _opt("uy", "Uyumlu ol", {"relationship:coach": 1})]),

    _ev("rel-antrenmana-gec", "coach", 55,
        {"kind": "daily", "chance": 0.05, "needs": ["low_condition"]},
        "Antrenmana geç kalmak",
        "Dün geceden kalan yorgunlukla antrenmana geç kaldın. Antrenör nedenini soruyor.",
        [_opt("durust", "Dürüstçe anlat", {"relationship:coach": -3}),
         _opt("yalan", "Bir bahane uydur", {},
              defer=[_later(7, {"relationship:coach": -18})])],
        expires_in_days=1),

    _ev("rel-oyundan-alinma", "coach", 50,
        {"kind": "post_match", "when": "subbed_early", "chance": 0.8},
        "Oyundan alınma",
        "Maçta erken oyundan çıkarıldın. Kulübeye doğru yürürken bütün stat seni izliyor.",
        [_opt("sakin", "Sakin kal", {"relationship:coach": 3, "attribute:discipline": 0.3}),
         _opt("tekme", "Kulübeye tekme at", {"relationship:coach": -10, "relationship:media": -8, "fame:overall": -0.5}),
         _opt("sus", "Hiçbir şey yapma")],
        expires_in_days=2),

    _ev("rel-antrenor-kotu-gun", "coach", 55,
        {"kind": "post_match", "when": "losing_streak"},
        "Antrenörün kötü günü",
        "Üst üste mağlubiyetler geldi ve antrenör baskı altında. Basın toplantısında "
        "sana onun hakkında soru soracaklar.",
        [_opt("destekle", "Basında onu destekle", {"relationship:coach": 12, "relationship:media": 2}),
         _opt("elestir", "Basında eleştir", {"relationship:coach": -20, "relationship:media": 4}),
         _opt("yorum_yok", "Yorum yapma")],
        expires_in_days=2),

    _ev("rel-fizyoterapist-uyarisi", "coach", 50,
        {"kind": "daily", "chance": 0.04, "needs": ["low_condition"]},
        "Fizyoterapist uyarısı",
        "Fizyoterapist baldırında hafif bir gerginlik fark etti. Birkaç gün dinlenmeni "
        "öneriyor.",
        [_opt("dinlen", "Uyarıya uy", {"condition": 8, "relationship:coach": 6}),
         _opt("gormezden", "Görmezden gel", {"condition": -10, "relationship:coach": -8})],
        expires_in_days=2),

    # ===== 5.3 Kulüp yönetimi (coach = yönetim, D93) =====
    _ev("rel-sozlesme-baskisi", "coach", 80,
        {"kind": "date", "on": "contract_left", "days": 182},
        "Sözleşme uzatma baskısı",
        "Sözleşmenin bitmesine altı ay kaldı. Başkan seninle yeni bir anlaşma için "
        "konuşmak istiyor ve cevabını bekliyor.",
        [_opt("imzala", "Erken imza için sözlü anlaş", {"relationship:coach": 10, "money": 40}),
         _opt("oyala", "Zaman iste", {"relationship:coach": -8})],
        expires_in_days=14),

    _ev("rel-kulup-daveti", "coach", 55,
        {"kind": "date", "on": "special_day", "day": "gala"},
        "Kulüp etkinliğine davet",
        "Kulüp, sponsorlarla bir yardım gecesi veriyor ve oyuncuların gelmesini istiyor. "
        "Kameralar ve imza bekleyen bir kalabalık olacak.",
        [_opt("katil", "Katıl", {"relationship:coach": 5, "fame:overall": 0.3, "money": 20},
              costs={"time": 180.0, "energy": 10.0}),
         _opt("katilma", "Katılma", {"relationship:coach": -3, "fame:overall": -0.1})],
        expires_in_days=2),

    _ev("rel-maas-gecikmesi", "coach", 45,
        {"kind": "daily", "chance": 0.006, "needs": []},
        "Maaş gecikmesi",
        "Kulüp maddi bir kriz yaşıyor ve bu haftaki maaşlar gecikecek. Takım arkadaşların "
        "homurdanıyor, muhabirler kapıda.",
        [_opt("sabir", "Sabırlı ol", {"relationship:coach": 8}),
         _opt("basina_konus", "Basına açıklama yap", {"relationship:coach": -18, "relationship:fans": -6, "relationship:media": 4}),
         _opt("sessiz", "Kimseyle konuşma")]),

    _ev("rel-transfer-soylentisi", "coach", 50,
        {"kind": "daily", "chance": 0.012, "needs": ["window_open"]},
        "Transfer söylentisi",
        "Gazeteler, rakip bir kulübün seninle ilgilendiğini yazıyor. Mikrofon önüne "
        "çıktığında ilk soru bu olacak.",
        [_opt("mutluyum", "\"Burada mutluyum\" de", {"relationship:coach": 6, "relationship:fans": 6}),
         _opt("kapi_acik", "Kapıyı açık bırak", {"relationship:coach": -8, "relationship:fans": -3, "relationship:media": 3}),
         _opt("yorum_yok", "Yorum yapma")]),

    # ===== 5.4 Aile ve yakın çevre (family) =====
    _ev("rel-anne-dogum-gunu", "family", 60,
        {"kind": "date", "on": "birthday", "who": "family"},
        "Annenin doğum günü",
        "Bugün annenin doğum günü. Telefonunda üç cevapsız arama var; ikisi ondan.",
        [_opt("ziyaret", "Ziyaret et", {"relationship:family": 12},
              costs={"time": 240.0, "energy": 10.0}),
         _opt("hediye", "Hediye yolla", {"money": -20, "relationship:family": 8})],
        expires_in_days=2, on_ignore={"relationship:family": -14}),

    _ev("rel-kardes-maci", "family", 45,
        {"kind": "daily", "chance": 0.01, "needs": []},
        "Kardeşin maçı",
        "Kardeşin amatör ligde oynuyor ve bu hafta sonu kritik bir maçı var. "
        "Geleceğini söylemedi ama bekliyor.",
        [_opt("izle", "Maça git", {"relationship:family": 12, "grant_item:special-signed-jersey": 1},
              costs={"time": 180.0, "energy": 10.0}),
         _opt("bahane", "Antrenman bahanesi bul", {"relationship:family": -6})]),

    _ev("rel-mahalle-arkadasi", "family", 40,
        {"kind": "daily", "chance": 0.008, "needs": []},
        "Eski mahalle arkadaşı",
        "Çocukluk arkadaşın şehre geldi ve seni görmek istiyor. Ayakkabı boyacısı "
        "sokağından beri konuşmadınız.",
        [_opt("vakit_ayir", "Vakit ayır", {"relationship:family": 6, "attribute:empathy": 0.3},
              costs={"time": 120.0}),
         _opt("reddet", "Sonra görüşürüz de", {"relationship:family": -8})]),

    _ev("rel-aileden-para", "family", 40,
        {"kind": "daily", "chance": 0.01, "needs": []},
        "Aileden para talebi",
        "Bir akraban, küçük bir iş için borç istiyor. İlk kez değil ve son olmayacak "
        "gibi görünüyor.",
        [_opt("yardim", "Yardım et", {"money": -40, "relationship:family": 10},
              defer=[_later(30, {}, followup="rel-aileden-para")]),
         _opt("kismen", "Bir kısmını ver", {"money": -15, "relationship:family": 4}),
         _opt("reddet", "Reddet", {"relationship:family": -6})]),

    _ev("rel-aile-yemegi-mac", "family", 50,
        {"kind": "post_match", "when": "special_day"},
        "Aile yemeği ile maç çakışması",
        "Bugün özel bir gün ve aile sofrası kuruldu ama sen maçtaydın. Annen sana "
        "bir tabak ayırmış.",
        [_opt("surpriz", "Yemeğe sürpriz yap", {"relationship:family": 10},
              costs={"time": 120.0, "energy": 10.0}),
         _opt("ara", "Telefonla ara", {"relationship:family": 3}),
         _opt("hicbiri", "Hiçbir şey yapma", {"relationship:family": -8})],
        expires_in_days=2),

    # ===== 5.5 Romantik ilişki (partner) =====
    _ev("rel-yil-donumu", "partner", 65,
        {"kind": "date", "on": "anniversary"},
        "Yıl dönümü",
        "Bugün ilişkinizin yıl dönümü. Takvimde bir not yok ama o unutmadı.",
        [_opt("plan", "Bir plan yap", {"money": -30, "relationship:partner": 14},
              costs={"time": 180.0}),
         _opt("mesaj", "Bir mesaj at", {"relationship:partner": 4})],
        expires_in_days=2, on_ignore={"relationship:partner": -20}),

    _ev("rel-paparazzi", "partner", 55,
        {"kind": "daily", "chance": 0.01, "needs": ["partner_active"]},
        "Paparazzi fotoğrafı",
        "Haberlerde, yanlış anlaşılmaya çok açık bir fotoğrafın dolaşıyor: bir kafede, "
        "başka biriyle ve çok yakın.",
        [_opt("acikla", "Hemen açıklama yap", {"relationship:partner": 4, "relationship:media": 3}),
         _opt("sus", "Sessiz kal", {},
              defer=[_later(3, {"relationship:partner": -16, "relationship:media": -8})])],
        expires_in_days=2),

    _ev("rel-transfer-tasinma", "partner", 70,
        {"kind": "daily", "chance": 0.04, "needs": ["offer_open", "partner_active"]},
        "Transfer ve taşınma",
        "Yurt dışından bir teklif geldi. Kabul edersen şehir değiştireceksin; partnerin "
        "henüz bundan haberdar değil.",
        [_opt("birlikte", "Birlikte karar ver", {"relationship:partner": 12},
              costs={"time": 60.0}),
         _opt("tek_basina", "Tek başına karar ver", {"relationship:partner": -16})],
        expires_in_days=5),

    _ev("rel-iliskiyi-acikla", "partner", 45,
        {"kind": "daily", "chance": 0.008, "needs": ["partner_active"]},
        "İlişkiyi açıklamak",
        "Bir muhabir, bir ilişkin olup olmadığını soruyor. Partnerin kameraların "
        "önüne çıkmak isteyip istemediğini hiç konuşmadınız.",
        [_opt("birlikte", "Birlikte karar ver", {"relationship:partner": 8, "relationship:media": 4}),
         _opt("sormadan", "Sormadan açıkla", {"relationship:partner": -12, "relationship:media": 3}),
         _opt("yorum_yok", "Yorum yapma")]),

    # ===== 5.6 Taraftarlar (fans) =====
    _ev("rel-tribun-selam", "fans", 50,
        {"kind": "post_match", "when": "win", "chance": 0.5},
        "Tribünlerle selamlaşma",
        "Galibiyetten sonra tribün ayakta. Oyuncuların bir kısmı tünele yürüyor.",
        [_opt("tribune_git", "Tribünlere git", {"relationship:fans": 6}),
         _opt("soyunma", "Doğruca soyunma odasına git", {"relationship:fans": -2})],
        expires_in_days=1),

    _ev("rel-taraftar-tepkisi", "fans", 55,
        {"kind": "post_match", "when": "loss", "chance": 0.6},
        "Taraftar tepkisi",
        "Kötü bir maçın ardından tribünden ıslıklar geliyor. Tünele doğru yürürken "
        "bir kısmı sana bağırıyor.",
        [_opt("alkisla", "Tribünü alkışla", {"relationship:fans": 6},
              requires={"charisma": 7}),
         _opt("sessiz", "Başını eğip geç", {"relationship:fans": -2}),
         _opt("el_hareketi", "El hareketi yap", {"relationship:fans": -14, "relationship:media": -8, "money": -20})],
        expires_in_days=1),

    _ev("rel-engelli-taraftar", "fans", 45,
        {"kind": "daily", "chance": 0.008, "needs": []},
        "Engelli taraftar isteği",
        "Sosyal medyada, tekerlekli sandalyedeki bir taraftar imzalı formanı istediğini "
        "yazmış. Gönderi hızla yayılıyor.",
        [_opt("karsila", "İstediğini karşıla", {"relationship:fans": 14, "relationship:media": 6, "fame:overall": 0.5}),
         _opt("gormezden", "Görmezden gel", {},
              defer=[_later(5, {"relationship:fans": -10, "relationship:media": -6},
                            news={"category": "Röportaj", "title": "Taraftarın çağrısı cevapsız kaldı",
                                  "body": "Bir taraftarın imzalı forma isteği günlerdir yanıtsız."})])]),

    _ev("rel-eski-kulube-gol", "fans", 60,
        {"kind": "post_match", "when": "former_club_goal"},
        "Eski kulübe gol",
        "Eski takımına karşı gol attın. Tribünde eski taraftarların da bir kısmı var; "
        "bütün stat sana bakıyor.",
        [_opt("saygili", "Sevinme, saygı göster", {"relationship:fans": 6, "relationship:media": 3}),
         _opt("taskin", "Taşkın sevin", {"relationship:fans": -12, "relationship:media": 4})],
        expires_in_days=1),

    _ev("rel-derbi-aciklamasi", "fans", 60,
        {"kind": "date", "on": "derby_week"},
        "Derbi öncesi açıklama",
        "Derbiye üç gün var ve şehir başka bir şeyden konuşmuyor. Basın toplantısında "
        "ağzından çıkacak ilk cümle manşet olacak.",
        [_opt("saygili_cosku", "Coşkulu ama saygılı konuş", {"relationship:fans": 8, "relationship:media": 3}),
         _opt("asagila", "Rakibi aşağıla", {"relationship:fans": 6, "relationship:media": -10, "relationship:coach": -6, "relationship:team": -4})],
        expires_in_days=2),

    # ===== 5.7 Medya (media) =====
    _ev("rel-provokatif-soru", "media", 50,
        {"kind": "daily", "chance": 0.01, "needs": []},
        "Provokatif soru",
        "Basın toplantısında bir muhabir, takım arkadaşının son formunu eleştirerek "
        "sana soruyor: \"Sizce takıma zarar veriyor mu?\"",
        [_opt("zarif", "Zarif bir cevap ver", {"relationship:media": 8, "relationship:team": 3},
              requires={"intelligence": 7}),
         _opt("elestir", "Onu eleştir", {"relationship:team": -10, "relationship:media": 4}),
         _opt("gec", "Soruyu geç")]),

    _ev("rel-eski-paylasim", "media", 45,
        {"kind": "daily", "chance": 0.006, "needs": []},
        "Eski paylaşım ortaya çıkıyor",
        "Yıllar önce attığın bir sosyal medya paylaşımı yeniden gündeme geldi. "
        "Ekran görüntüleri dolaşıyor.",
        [_opt("ozur", "Özür dile", {"relationship:media": -3, "fame:overall": -0.1}),
         _opt("savun", "Savunmaya geç", {"relationship:media": -14, "fame:overall": -0.5})]),

    _ev("rel-gazeteci-dostu", "media", 40,
        {"kind": "daily", "chance": 0.008, "needs": []},
        "Gazeteciyle dostluk",
        "Belli bir muhabir aylardır senin hakkında sürekli olumlu yazıyor ve sana "
        "özel bir röportaj teklif ediyor.",
        [_opt("ozel", "Özel röportaj ver", {"relationship:media": 10, "fame:overall": 0.3},
              costs={"time": 60.0},
              defer=[_later(7, {"relationship:media": -4})]),
         _opt("ortak", "Ortak basın açıklaması yap", {"relationship:media": 4}),
         _opt("gec", "Teşekkür edip geç")]),

    _ev("rel-yanlis-haber", "media", 50,
        {"kind": "daily", "chance": 0.008, "needs": []},
        "Yanlış haber",
        "Bir gazete, sakatlandığını ve haftalarca yok olacağını yazdı. Haber tamamen yalan "
        "ama kulüp telefonları yanıtlıyor.",
        [_opt("duzelt", "Sakince düzelt", {"relationship:media": 6, "fame:overall": 0.2}),
         _opt("saldir", "Muhabire saldır", {"relationship:media": -16, "fame:overall": -0.4}),
         _opt("umursama", "Umursama")]),

    # ===== 5.8 Menajer ve sponsorlar (agent = family, sponsor = §12.7) =====
    _ev("rel-menajer-komisyon", "family", 70,
        {"kind": "daily", "chance": 0.04, "needs": ["offer_open"]},
        "Menajerin yüksek komisyon talebi",
        "Transfer sürecinde menajerin beklenenden yüksek bir komisyon istiyor ve "
        "\"piyasa böyle\" diyor.",
        [_opt("pazarlik", "Pazarlık et", {"relationship:family": 6, "money": 25, "attribute:courage": 0.3},
              requires={"courage": 8}),
         _opt("kabul", "Kabul et", {"relationship:family": 2, "money": -25}),
         _opt("devre_disi", "Menajeri devre dışı bırak", {"relationship:family": -20})],
        expires_in_days=5),

    _ev("rel-sponsor-rakip-urun", "media", 50,
        {"kind": "daily", "chance": 0.008, "needs": ["sponsor_active"]},
        "Sponsor rakip ürün",
        "Bir fotoğrafta, sponsorunun rakibinin ürünüyle görüntülendin. Marka "
        "iletişim ekibi henüz bir şey demedi.",
        [_opt("ozur", "Hızlıca özür dile", {"relationship:media": -2, "fame:overall": -0.1}),
         _opt("umursama", "Önemseme", {},
              defer=[_later(14, {"sponsorship:end": 1, "relationship:media": -6},
                            news={"category": "Analiz", "title": "Sponsor anlaşmasını sonlandırdı",
                                  "body": "Bir marka, rakip ürünle görüntülenen oyuncuyla yollarını ayırdı."})])]),

    _ev("rel-sponsor-antrenman", "coach", 55,
        {"kind": "daily", "chance": 0.01, "needs": ["sponsor_active"]},
        "Sponsor etkinliği ile antrenman çakışması",
        "Sponsorun zorunlu bir etkinliği, antrenman saatinle çakıştı. İkisine birden "
        "yetişmen mümkün değil.",
        [_opt("konus", "Antrenörle önceden konuş", {"relationship:coach": 5, "fame:overall": 0.1},
              costs={"time": 30.0}),
         _opt("sponsoru_ekti", "Sponsoru sessizce ek", {"relationship:media": -8, "fame:overall": -0.2}),
         _opt("antrenmani_ekti", "Antrenmanı sessizce ek", {"relationship:coach": -10})]),

    # ===== Kendi başına ek: §13.12'nin "ilk gol topu" kaynağı =====
    _ev("rel-ilk-gol-topu", "family", 65,
        {"kind": "post_match", "when": "first_goal"},
        "İlk profesyonel golün",
        "İlk profesyonel golünü attın. Maçtan sonra hakem, topu sana uzattı; üstünü "
        "kimse sormadan temizledin.",
        [_opt("sakla", "Topu sakla", {"grant_item:special-first-goal-ball": 1, "relationship:family": 4}),
         _opt("ailene_ver", "Aileye götür", {"relationship:family": 10, "grant_item:special-first-goal-ball": 1})],
        expires_in_days=3),
]

assert len(RELATIONSHIP_EVENTS) == 42   # the doc's 40 + two that chains and items need

# --- validation (INV-28's shape: a typo must fail at import) -----------------
from api.config import RELATIONSHIP_KINDS  # noqa: E402 (after data)
from catalog import _is_known_effect_key, validate_catalog, validate_requires  # noqa: E402

DATE_EVENTS = ("birthday", "anniversary", "contract_left", "derby_week", "special_day")
NEEDS = ("partner_active", "sponsor_active", "offer_open", "window_open", "low_condition")
POST_MATCH_FACTS = (
    "win", "loss", "red_card_loss", "bench", "no_goal", "subbed_early", "losing_streak",
    "former_club_goal", "special_day", "first_goal",
)
TRIGGER_KINDS = ("date", "daily", "post_match", "activity", "deferred")

_BY_ID = {e["template_id"]: e for e in RELATIONSHIP_EVENTS}
assert len(_BY_ID) == len(RELATIONSHIP_EVENTS), "duplicate relationship event template_id"


def _check_effects(effects: dict, where: str) -> None:
    for key in effects:
        assert _is_known_effect_key(key), f"{where} has unknown effect key {key!r}"
        if key.startswith("relationship:"):
            assert key.split(":", 1)[1] in RELATIONSHIP_KINDS, f"{where} touches unknown relationship {key!r}"


def _check_trigger(trigger: dict, where: str) -> None:
    kind = trigger["kind"]
    assert kind in TRIGGER_KINDS, f"{where} has trigger kind {kind!r}"
    if kind == "date":
        assert trigger["on"] in DATE_EVENTS, f"{where} has date trigger {trigger['on']!r}"
        if trigger["on"] == "birthday":
            assert trigger["who"] in RELATIONSHIP_KINDS, f"{where} birthday of {trigger['who']!r}"
        if trigger["on"] == "special_day":
            assert trigger["day"] in SPECIAL_DAYS, f"{where} unknown special day {trigger['day']!r}"
        if trigger["on"] == "contract_left":
            assert trigger["days"] > 0, f"{where} contract_left needs days"
    elif kind == "daily":
        assert 0 < trigger["chance"] < 1, f"{where} has chance {trigger['chance']!r}"
        for need in trigger["needs"]:
            assert need in NEEDS, f"{where} needs unknown {need!r}"
    elif kind == "post_match":
        assert trigger["when"] in POST_MATCH_FACTS, f"{where} post_match on {trigger['when']!r}"
        assert 0 < trigger.get("chance", 1.0) <= 1, f"{where} has chance {trigger['chance']!r}"
    elif kind == "activity":
        assert trigger["on"] == "fail" and trigger["catalog_id"], f"{where} malformed activity trigger"


_option_items = []
for _tpl in RELATIONSHIP_EVENTS:
    _id = _tpl["template_id"]
    assert _tpl["relationship"] in RELATIONSHIP_KINDS, f"{_id} is about {_tpl['relationship']!r}"
    _check_trigger(_tpl["trigger"], _id)
    validate_requires(_tpl.get("requires"), f"relationship_event:{_id}")
    _check_effects(_tpl.get("on_ignore", {}), f"{_id}:on_ignore")
    assert any(not _o.get("requires") for _o in _tpl["options"]), f"{_id} has no ungated option"
    _seen = set()
    for _opt_row in _tpl["options"]:
        _where = f"relationship_event:{_id}:{_opt_row['option_id']}"
        assert _opt_row["option_id"] not in _seen, f"{_where} is a duplicate option_id"
        _seen.add(_opt_row["option_id"])
        _check_effects(_opt_row.get("effects", {}), _where)
        _option_items.append({
            "catalog_id": _where, "costs": _opt_row.get("costs", {}),
            "effects": _opt_row.get("effects", {}), "requires": _opt_row.get("requires", {}),
        })
        for _later_row in _opt_row.get("defer", []):
            _check_effects(_later_row["effects"], f"{_where}:defer")
            assert _later_row["days"] > 0, f"{_where} defers by {_later_row['days']!r} days"
            assert _later_row["followup"] is None or _later_row["followup"] in _BY_ID, (
                f"{_where} follows up with unknown {_later_row['followup']!r}"
            )

validate_catalog(_option_items, "relationship_event")
