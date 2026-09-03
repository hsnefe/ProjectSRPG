"""The story archetype catalog — what the game's press is capable of
writing about.

This is a DATA file (§6 red line 9): it is long on purpose and holds no
logic beyond the per-archetype `applies` predicate and `body` builder.
Everything about selection, cooldown, determinism and publication lives in
domain/news.py.

An archetype is a dict:

    story_id       kebab-case, unique, never rendered to the player. It IS
                   written to news_story_log, which is how cooldown works,
                   so renaming one resets its cooldown for existing careers.
    category       one of content.CATEGORIES — the pill FE draws.
    triggers       which events even look at this archetype.
    weight         relative pull inside one selection. 1 = rare colour,
                   5 = the story you expect to see.
    cooldown_days  how long before this exact archetype may run again.
    outlets        which publications would carry it. Narrow lists are a
                   voice decision, not an oversight — a repossession notice
                   is not something the club bulletin prints.
    applies(ctx)   bool. Reads NewsContext only; never touches the DB.
    headlines      >= 3 templates, filled with content.SLOT_KEYS via
                   str.format_map. A missing slot raises KeyError, loudly.
    body(ctx,s,r)  list of paragraphs. `s` is the same filled slot map the
                   headline used, `r` is the story's own seeded Random.
    effects        OPTIONAL static map, catalog-shaped: 'fame:overall',
                   'relationship:<rid>'. Applied via fame.apply() /
                   relationships.apply_delta() (INV-24/INV-15).

### Two authoring rules that are not obvious

**Bodies take `(ctx, slots, rng)`, not `(ctx, rng)`.** The design note this
was written from specified the latter, but a body that cannot see the same
filled slots the headline used has to re-derive the player's name, the
suitor club and the scoreline itself — three chances for the headline and
the first paragraph to disagree about who the story is about. Passing the
map through costs one parameter and removes the whole class of mismatch.

**`effects` is a static dict, not a lambda.** The design note allowed
`lambda ctx: {...}`, but a callable cannot be validated at import: an
effect key typo would only surface on the one day that story ran. A static
map is checked against catalog/__init__.py's own key predicate the moment
this file is imported (INV-28's discipline), which is worth more than
per-context scaling — and scaling can still be expressed by writing two
archetypes with different `applies` gates.

### Why relationship effects are rare here

Most triggers already price their own relationship consequence: M2 moves
coach/team/fans/media for the match itself, R3 moves the relationship the
dialogue belongs to. A news effect on top of those would double-charge the
same event and make the number the player sees in the response disagree
with the number in the database. So relationship effects live almost
entirely on `day_tick` archetypes — the ambient stories nothing else is
already paying for. Fame is the exception: it has no other producer today
(⟦AÇIK-9⟧), so the press is its main source.
"""

# --- shared phrase helpers -------------------------------------------------
#
# Small, boring, and here for one reason: a body that says "5 maçta 3
# galibiyet" should say it the same way in every archetype, and an author
# adding the 44th story should not have to re-derive Turkish number
# agreement from scratch.

def _form_line(ctx) -> str:
    f = ctx.form
    if not f["played"]:
        return "Sezon henüz başlamadı; elde karşılaştırılacak bir seri yok."
    return (
        f"Son {f['played']} maçta {f['w']} galibiyet, {f['d']} beraberlik, "
        f"{f['l']} yenilgi."
    )


def _rank_line(ctx) -> str:
    if not ctx.standings:
        return "Puan durumu tablosu bu müsabakada tutulmuyor."
    st = ctx.standings
    return (
        f"{st['competition']} sıralamasında {st['teams']} takım arasında "
        f"{st['rank']}. sırada, {st['played']} maçta {st['points']} puan."
    )


def _tally_line(ctx) -> str:
    st = ctx.season_stats
    if not st["appearances"]:
        return "Sezonun resmî maç istatistiği henüz boş."
    return (
        f"Sezon karnesi: {st['appearances']} maç, {st['goals']} gol, "
        f"{st['assists']} asist."
    )


def _money(amount) -> str:
    """₺1.250.000 for a raw number that arrived through `facts` rather than
    through a slot. domain/news._fmt_money() already does this for the slot
    map; a body that formats a fact by hand would print '1250000'."""
    try:
        return "₺" + f"{int(amount):,}".replace(",", ".")
    except (TypeError, ValueError):
        return "₺0"


def _condition_word(ctx) -> str:
    c = ctx.condition
    if c >= 85:
        return "turp gibi"
    if c >= 65:
        return "idare eder durumda"
    if c >= 45:
        return "yorgun"
    return "bitkin"


# ---------------------------------------------------------------------------
# TRANSFER — the rumour arc and its satellites
#
# The arc's stages (domain/news.ARC_STAGE_THRESHOLDS) are printed in order:
# interest -> agent talks -> bid -> agreement, with the club's refusal and
# its denial hanging off the bid as satellites.
#
# ⚠️ `ctx.arc["stage"] >= N` is NOT sufficient on its own, and getting this
# wrong is what made the arc read as random in the first playthrough. At
# stage 4 every earlier stage's predicate is still true, so the weighted
# picker would happily print "scouts are watching" a month after "the offer
# is on the table" — and then print it again once the cooldown lapsed. The
# reader cannot tell an escalating story from a shuffled one.
#
# So each stage archetype gates on `_arc_stage_due()` instead, which adds
# the two rules the stage number alone cannot express:
#   1. a stage prints AT MOST ONCE per arc — there is only one transfer arc
#      per career (its suitor is fixed by seed), so a second printing is
#      never new information;
#   2. a stage may not print once a LATER stage has printed — the press
#      cannot walk the story backwards.
# Together these make the published sequence strictly increasing, which is
# asserted in tests/test_news_generation.py.
# ---------------------------------------------------------------------------

# Which archetype narrates which stage. Ordered; the order is load-bearing.
ARC_STAGE_STORIES = (
    (1, "transfer-ilgi-dogdu"),
    (2, "transfer-temsilci-gorusuyor"),
    (3, "transfer-teklif-yapildi"),
    (4, "transfer-anlasma-yakin"),
)


def _arc_stage_due(ctx, stage: int) -> bool:
    if not ctx.arc or ctx.arc["stage"] < stage:
        return False
    for other_stage, story_id in ARC_STAGE_STORIES:
        if other_stage >= stage and story_id in ctx.published_recently:
            return False
    return True


def _arc_stage_printed(ctx, stage: int) -> bool:
    """Has the arc's stage-N article already run? Satellites (the refusal,
    the club's denial) hang off a beat the reader has actually seen, rather
    than off a number only the database knows."""
    story_id = dict((s, sid) for s, sid in ARC_STAGE_STORIES)[stage]
    return story_id in ctx.published_recently


_TRANSFER = [
    {
        "story_id": "transfer-ilgi-dogdu",
        "category": "Transfer",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 24,
        "outlets": ("spor-manset", "lig-ajansi", "magazin-ekspres"),
        "applies": lambda ctx: _arc_stage_due(ctx, 1),
        "headlines": [
            "{rival} scoutları {team} maçlarında",
            "{rival}, {last_name} dosyasını açtı",
            "Bir üst kademeden {player} için ilk temas",
            "{rival} radarında bir {position}: {player}",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['rival']} teknik heyetinin son haftalarda {s['team']} maçlarını "
            f"yakından izlediği öğrenildi. İzleme raporlarının merkezinde "
            f"{s['age']} yaşındaki {s['position']} {s['player']} var.",
            _form_line(ctx) + " " + _rank_line(ctx),
            rng.choice([
                f"Henüz resmî bir girişim yok. Bu aşamada konuşulan tek şey, "
                f"{s['rival_short']} kadrosunda o bölgede bir açık olup olmadığı.",
                f"{s['team']} cephesinden ses çıkmadı. Kulübün, sezon ortasında "
                f"kadro dengesini bozacak bir ayrılığa sıcak bakmadığı biliniyor.",
                f"Oyuncunun çevresi ilgiden haberdar; ancak {s['player']} tarafında "
                f"şimdilik 'sahaya odaklan' talimatı geçerli.",
            ]),
        ],
        "effects": {"fame:overall": 0.6},
    },
    {
        "story_id": "transfer-temsilci-gorusuyor",
        "category": "Transfer",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 21,
        "outlets": ("spor-manset", "magazin-ekspres", "tribun-sesi"),
        "applies": lambda ctx: _arc_stage_due(ctx, 2),
        "headlines": [
            "Temsilci {rival} ile masaya oturdu",
            "{last_name} cephesinde hareketlilik: görüşme doğrulandı",
            "{rival} ile {player}'in temsilcisi arasında ilk toplantı",
            "Kulis: {rival_short} yönetimi temsilciyi dinledi",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}'in temsilcisinin {s['rival']} yöneticileriyle bir araya "
            f"geldiği bilgisi doğrulandı. Görüşmenin gündeminde ücret değil, "
            f"öncelikle oynama süresi vardı.",
            f"Oyuncunun {s['team']} ile sözleşmesi {'bitişe yaklaşıyor' if (ctx.contract_days_left or 999) <= 200 else 'hâlâ uzun bir süre kapsıyor'}; "
            f"mevcut haftalık ücreti {s['wage']}, serbest kalma bedeli {s['clause']}.",
            rng.choice([
                "Görüşmenin bir teklife dönüşmesi için önce kulüpler arası "
                "temasın kurulması gerekiyor. O adım henüz atılmadı.",
                f"{s['team']} yönetiminin toplantıdan haberdar olduğu, ancak "
                f"resmî bir başvuru gelmediği için sessiz kalmayı tercih ettiği belirtiliyor.",
                "Temsilcinin aynı hafta içinde bir başka kulüple daha görüştüğü "
                "iddiası ise doğrulanamadı.",
            ]),
            _tally_line(ctx),
        ],
        "effects": {"fame:overall": 0.9},
    },
    {
        "story_id": "transfer-teklif-yapildi",
        "category": "Transfer",
        "triggers": ("day_tick",),
        "weight": 5,
        "cooldown_days": 30,
        "outlets": ("spor-manset", "lig-ajansi", "tribun-sesi"),
        "applies": lambda ctx: _arc_stage_due(ctx, 3),
        "headlines": [
            "{rival} resmî teklifini yaptı",
            "Teklif masada: {rival_short} {last_name} için düğmeye bastı",
            "{team}'e {rival} imzalı yazılı teklif",
            "{player} için ilk rakam telaffuz edildi",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['rival']}, {s['player']} için {s['team']} yönetimine yazılı teklif "
            f"iletti. Teklifin serbest kalma bedelinin ({s['clause']}) altında "
            f"kaldığı, bu yüzden pazarlığa açık olduğu belirtiliyor.",
            f"{s['team']} yönetimi teklifi değerlendirmeye aldı. "
            f"{s['coach']}'un bu sezon için kadro planlamasında oyuncuyu ilk on birde "
            f"görmesi, kararın yalnızca rakamla verilmeyeceğini gösteriyor.",
            rng.choice([
                f"Taraftar grupları sosyal medyada ikiye bölünmüş durumda: "
                f"bir kanat 'gitsin, kariyeri için doğru olan bu' derken, diğeri "
                f"{s['team_short']} formasının bu sezon en çok ona ihtiyacı olduğunu savunuyor.",
                "Oyuncunun kendisinin süreçle ilgili bir açıklaması olmadı. "
                "Antrenmanlara normal katıldığı öğrenildi.",
                f"Teklifin reddedilmesi hâlinde {s['rival_short']}'in rakamı bir kez "
                f"daha revize edeceği konuşuluyor.",
            ]),
        ],
        "effects": {"fame:overall": 1.4},
    },
    {
        "story_id": "transfer-kulup-reddetti",
        "category": "Transfer",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 30,
        "outlets": ("kulup-bulteni", "lig-ajansi", "tribun-sesi"),
        # The refusal answers the bid, so it waits for the bid to have been
        # PRINTED and never runs after the handshake made it moot.
        "applies": lambda ctx: (
            _arc_stage_printed(ctx, 3)
            and not _arc_stage_printed(ctx, 4)
            and "transfer-kulup-reddetti" not in ctx.published_recently
            and ctx.arc["heat"] < 78
        ),
        "headlines": [
            "{team} teklifi geri çevirdi",
            "Kapı kapandı: {rival_short} eli boş döndü",
            "{team} yönetimi: 'Satılık oyuncumuz yok'",
            "{last_name} için gelen teklife ret",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['team']}, {s['rival']} tarafından iletilen teklifi reddetti. "
            f"Kulüp kaynakları kararın sportif olduğunu, rakamın tek başına "
            f"belirleyici olmadığını ifade ediyor.",
            f"{s['player']}'in sözleşmesi bu hâliyle devam ediyor: haftalık "
            f"{s['wage']}, serbest kalma bedeli {s['clause']}.",
            rng.choice([
                "Kulübün kapıyı tamamen kapatmadığı, bedelin tamamının ödenmesi "
                "hâlinde masaya yeniden oturabileceği yorumları da yapılıyor.",
                f"{s['coach']}, konuyla ilgili soruları 'benim gündemimde cumartesi var' "
                f"diyerek geçiştirdi.",
                "Karar, soyunma odasında en azından bu hafta için rahatlama yarattı.",
            ]),
        ],
        "effects": {"relationship:fans": 1},
    },
    {
        "story_id": "transfer-anlasma-yakin",
        "category": "Transfer",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 40,
        "outlets": ("spor-manset", "magazin-ekspres"),
        "applies": lambda ctx: _arc_stage_due(ctx, 4),
        "headlines": [
            "{rival} ile {player} arasında el sıkışma iddiası",
            "Anlaşma yakın: {last_name} {rival_short} yolunda mı?",
            "Kulisler kaynıyor: {rival} son teklifini yaptı",
            "{player} için kritik 48 saat",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['rival']} ile {s['player']}'in temsilcisi arasında kişisel şartlarda "
            f"mutabakat sağlandığı öne sürülüyor. Sıra kulüpler arası rakamda.",
            f"{s['team']}'in beklentisi serbest kalma bedeline yakın bir rakam. "
            f"{s['rival_short']} cephesi bu bedeli 'sezon ortası için gerçekçi değil' "
            f"buluyor, ancak masadan kalkmış da değil.",
            rng.choice([
                f"Transferin gerçekleşmesi hâlinde {s['player']}, kariyerinde ilk kez "
                f"üst kademede forma giyecek.",
                f"{s['team']} taraftarı için bu, sezonun en zor haberi olabilir. "
                f"Tribünlerde konu bu hafta başka bir şey değil.",
                "Her iki kulüp de resmî açıklamadan kaçınıyor. Bu tür dosyalarda "
                "sessizlik genellikle iyiye işaret sayılıyor.",
            ]),
        ],
        "effects": {"fame:overall": 2.0},
    },
    {
        "story_id": "transfer-sozlesmede-son-ceyrek",
        "category": "Transfer",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 20,
        "outlets": ("spor-manset", "lig-ajansi"),
        "applies": lambda ctx: ctx.contract_days_left is not None and 0 <= ctx.contract_days_left <= 90,
        "headlines": [
            "Sözleşmede son çeyrek: {player} için sayaç işliyor",
            "{team} ile {last_name} arasında {rank}. sıra kadar önemli bir masa",
            "Sözleşme bitiyor, masa hâlâ kurulmadı",
            "{player}'in geleceği: kalan süre eriyor",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']}'in {s['team']} ile sözleşmesinin bitmesine "
                f"{ctx.contract_days_left} gün kaldı. Bu eşiğin altında kalan her gün, "
                f"oyuncunun pazarlık gücünü artırıyor.",
                f"Takvim {s['player']} lehine işliyor: {s['team']} ile sözleşmesinin "
                f"bitmesine {ctx.contract_days_left} gün var ve masa hâlâ "
                f"kurulmadı.",
                f"{ctx.contract_days_left} gün. {s['player']}'in mevcut sözleşmesinden "
                f"geriye kalan süre bu ve {s['team']} yönetimi için karar anı "
                f"yaklaşıyor.",
            ]),
            f"Mevcut şartlar: haftalık {s['wage']}, serbest kalma bedeli {s['clause']}. "
            f"Yeni bir sözleşme imzalanmazsa oyuncu sezon sonunda bedelsiz duruma gelecek.",
            rng.choice([
                "Kulüp yönetiminin uzatma için bir teklif hazırladığı, ancak henüz "
                "sunmadığı belirtiliyor.",
                f"{s['coach']}'un oyuncuyu planlamasında tuttuğu biliniyor. "
                f"Sportif tarafın onayı var; sıra mali tarafta.",
                "Bu tabloda bekleyen tek taraf kulüp değil. Oyuncu cephesi de "
                "sezon sonunu görmek istiyor olabilir.",
            ]),
        ],
    },
    {
        "story_id": "transfer-serbest-kalma-bedeli",
        "category": "Transfer",
        "triggers": ("day_tick",),
        "weight": 2,
        "cooldown_days": 35,
        "outlets": ("spor-manset", "lig-ajansi", "magazin-ekspres"),
        "applies": lambda ctx: (
            ctx.contract is not None
            and ctx.contract["release_clause"] > 0
            and (ctx.fame >= 4 or ctx.goals >= 3)
        ),
        "headlines": [
            "{clause}: {player}'in bedeli konuşuluyor",
            "Serbest kalma maddesi mercek altında",
            "{last_name}'in sözleşmesindeki o rakam: {clause}",
            "Piyasa {player}'e fiyat biçiyor",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']}'in sözleşmesindeki serbest kalma bedeli {s['clause']} olarak "
                f"biliniyor. Bu rakam, sözleşmenin imzalandığı gün için makuldü; "
                f"bugün için aynı şeyi söylemek zor.",
                f"{s['clause']}. {s['player']}'in sözleşmesindeki serbest kalma bedeli "
                f"bu ve oyuncunun bu sezonki {s['goals']} gollük performansının "
                f"yanında küçük duruyor.",
                f"Bir futbolcunun fiyatını belirleyen tek rakam serbest kalma bedelidir; "
                f"{s['player']} için bu rakam {s['clause']} olarak duruyor.",
            ]),
            _tally_line(ctx) + " " + _rank_line(ctx),
            rng.choice([
                "Bu tür maddeler genellikle kulübü korumak için konur; oyuncu "
                "beklenenden hızlı gelişince koruma tarafını değiştirir.",
                f"{s['team']} yönetiminin maddeyi güncellemek için bir uzatma "
                f"teklifi hazırladığı konuşuluyor.",
                "Rakamın bugünkü karşılığını soranlara kulüpten yanıt gelmedi.",
            ]),
        ],
        "effects": {"fame:overall": 0.4},
    },
    {
        "story_id": "transfer-kulupten-yalanlama",
        "category": "Transfer",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 18,
        "outlets": ("kulup-bulteni",),
        # Once per arc. A club that issues five identical denials in one
        # season is not a club, it is a stuck template — and the arc it
        # denies only happens once anyway.
        "applies": lambda ctx: (
            _arc_stage_printed(ctx, 1)
            and "transfer-kulupten-yalanlama" not in ctx.published_recently
        ),
        "headlines": [
            "Kulübümüzden transfer iddialarına ilişkin açıklama",
            "Basında yer alan haberler hakkında",
            "{team} basın açıklaması: spekülasyonlara nokta",
            "Kamuoyunun dikkatine: {last_name} hakkındaki iddialar",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"Son günlerde bazı yayın organlarında {s['player']} ile ilgili yer "
                f"alan transfer iddiaları kulübümüz kaynaklı değildir.",
                f"Kulübümüz, {s['player']} hakkında son günlerde ortaya atılan "
                f"transfer iddialarının hiçbirinin resmî kaynağı değildir.",
                f"{s['team']} olarak, {s['last_name']} ile ilgili basında yer alan "
                f"haberlerin tarafımızca doğrulanmadığını bildiririz.",
            ]),
            f"Futbolcumuz {s['team']} ile sözleşmesi devam eden bir oyuncumuzdur ve "
            f"teknik heyetimizin planlamasında yer almaktadır. Kadromuzdaki hiçbir "
            f"futbolcu için yürütülen bir görüşme bulunmamaktadır.",
            rng.choice([
                "Kulübümüz, futbolcularımızın konsantrasyonunu bozmaya yönelik "
                "asılsız haberler karşısında hukuki haklarını saklı tutar.",
                "Camiamızın, resmî kanallarımız dışındaki kaynaklara itibar etmemesini "
                "önemle rica ederiz.",
                "Sezonun bu döneminde gündemimiz yalnızca sahadaki performansımızdır.",
            ]),
        ],
        "effects": {"relationship:media": -1},
    },
]


# ---------------------------------------------------------------------------
# RÖPORTAJ — R3's media dialogue, printed the same evening.
#
# worlddata/relationships.py promises this in Ayça Kılıç's own bio:
# "Verdiğin her demeç ertesi sabah manşete dönüşebilir." The archetypes
# below branch on the sign of the dialogue's relationship delta, which is
# the server's own measure of how the remark landed. A neutral remark gets
# a deliberately boring three-line piece — not every quote explodes, and a
# generator that made every quote explode would stop being believable.
#
# No archetype here carries a `relationship:media` effect: R3 already
# applied the dialogue's own delta before this runs, and charging it twice
# would make the number in the response disagree with the database.
# ---------------------------------------------------------------------------

_ROPORTAJ = [
    {
        "story_id": "roportaj-olumlu-demec",
        "category": "Röportaj",
        "triggers": ("interview",),
        "weight": 5,
        "cooldown_days": 5,
        "outlets": ("spor-manset", "tribun-sesi"),
        "applies": lambda ctx: ctx.fact("delta", 0) > 0,
        "headlines": [
            "{player}: 'Bu takımın parçası olmak beni büyütüyor'",
            "{last_name}'den olgun açıklama: 'Cevabı sahada vereceğiz'",
            "{reporter}'a konuşan {player}: 'Hedefim {team} ile yükselmek'",
            "Soyunma odasının sesi: {player} konuştu",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['outlet']} mikrofonuna konuşan {s['player']}, sezonun gidişatına "
            f"dair sakin bir tablo çizdi. {s['age']} yaşındaki {s['position']}, "
            f"soruların hepsine yanıt verdi ve hiçbirinden kaçmadı.",
            rng.choice([
                f"\"{s['coach']} bizden ne istediğini çok net söylüyor. Benim işim "
                f"onu sahada uygulamak,\" dedi.",
                f"\"Tribünlerin sabrını hak etmek zorundayız. Bunu laf ile değil, "
                f"koşarak yapacağız,\" ifadelerini kullandı.",
                f"\"{s['team_short']} forması benim için bir basamak değil, bir sorumluluk,\" "
                f"diyerek transfer sorularını kapattı.",
            ]),
            _form_line(ctx) + " " + _rank_line(ctx),
            "Röportajın tamamı yayın organının hafta sonu ekinde yer alacak.",
        ],
        "effects": {"fame:overall": 1.0},
    },
    {
        "story_id": "roportaj-tepki-ceken",
        "category": "Röportaj",
        "triggers": ("interview",),
        "weight": 5,
        "cooldown_days": 5,
        "outlets": ("magazin-ekspres", "tribun-sesi", "spor-manset"),
        "applies": lambda ctx: ctx.fact("delta", 0) < 0,
        "headlines": [
            "{player}'in sözleri tepki çekti",
            "'Bunu söylememeliydi': {last_name}'in demeci tartışma yarattı",
            "Mikrofon açıktı: {player}'den camiayı karıştıran cümle",
            "{team} camiasında {last_name} rahatsızlığı",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}'in dün verdiği demeç, {s['team']} çevresinde beklenmedik "
            f"bir tartışma başlattı. Sorun cümlenin kendisinden çok, söylendiği "
            f"zamanlama gibi görünüyor.",
            rng.choice([
                "Kulübe yakın bir kaynak, açıklamanın teknik heyetle önceden "
                "paylaşılmadığını doğruladı.",
                f"{s['captain']}'in soyunma odasında konuyu kapatmak için devreye "
                f"girdiği öne sürülüyor.",
                "Taraftar gruplarının sosyal medya hesaplarında sabaha kadar "
                "süren bir tartışma yaşandı.",
            ]),
            f"{_condition_word(ctx).capitalize()} bir dönemde verilen bu demecin, "
            f"basın toplantılarında bir süre daha sorulacağı kesin.",
        ],
        "effects": {"fame:overall": 0.7},
    },
    {
        "story_id": "roportaj-notr-kisa",
        "category": "Röportaj",
        "triggers": ("interview",),
        "weight": 4,
        "cooldown_days": 3,
        "outlets": ("lig-ajansi", "kulup-bulteni"),
        "applies": lambda ctx: ctx.fact("delta", 0) == 0,
        "headlines": [
            "{player} basın mensuplarının sorularını yanıtladı",
            "{team}'den {last_name} açıklaması",
            "Kısa bülten: {player} konuştu",
            "Basın toplantısı notları: {last_name}",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}, tesislerde düzenlenen basın toplantısında soruları "
            f"yanıtladı. Açıklamada yeni bir bilgi paylaşılmadı.",
            rng.choice([
                "Oyuncu, sezon hedefleri ve kendi formuyla ilgili genel "
                "ifadeler kullandı.",
                "Toplantı on iki dakika sürdü.",
                "Transfer sorularına yanıt verilmedi.",
            ]),
            _tally_line(ctx),
        ],
    },
    {
        "story_id": "roportaj-transfer-sorusu",
        "category": "Röportaj",
        "triggers": ("interview",),
        "weight": 3,
        "cooldown_days": 12,
        "outlets": ("spor-manset", "magazin-ekspres"),
        "applies": lambda ctx: bool(ctx.arc) and ctx.arc["stage"] >= 1,
        "headlines": [
            "{last_name}'e {rival} soruldu",
            "'{rival_short} mu?' — {player} o soruya böyle yanıt verdi",
            "Röportajın en kritik dakikası: {rival} sorusu",
            "{player}: 'Şu an {team} oyuncusuyum'",
        ],
        "body": lambda ctx, s, rng: [
            f"Röportajın en çok konuşulacak bölümü, {s['rival']} iddialarının "
            f"sorulduğu dakikaydı. {s['player']} soruyu geçiştirmedi ama "
            f"doğrulamadı da.",
            rng.choice([
                f"\"Şu an {s['team_short']} oyuncusuyum. Gerisi benim değil, "
                f"yöneticilerin işi,\" dedi.",
                "\"Her futbolcu ilgi duyulmasından memnun olur. Ama ben "
                "haftaya oynanacak maçı düşünüyorum,\" ifadesini kullandı.",
                "\"Bu konuları temsilcim takip ediyor. Ben antrenmana "
                "gidiyorum,\" diyerek gülümsedi.",
            ]),
            f"{s['team']} yönetiminin bu yanıttan memnun kaldığı, "
            f"ancak konunun kapanmadığı ortada.",
        ],
        "effects": {"fame:overall": 0.8},
    },
    {
        "story_id": "roportaj-hocaya-destek",
        "category": "Röportaj",
        "triggers": ("interview",),
        "weight": 3,
        "cooldown_days": 20,
        "outlets": ("spor-manset", "kulup-bulteni", "tribun-sesi"),
        "applies": lambda ctx: ctx.rel("coach") >= 60 and ctx.fact("delta", 0) >= 0,
        "headlines": [
            "{player}'den {coach}'a açık destek",
            "'Hocamızın arkasındayız': {last_name} konuştu",
            "{last_name}, {coach} tartışmasına nokta koydu",
            "Soyunma odasından tek ses: {coach}",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}, teknik direktör {s['coach']} etrafındaki tartışmalara "
            f"soyunma odası adına yanıt verdi.",
            f"\"Bu takım {s['coach']} ile ne yaptığını biliyor. Sonuç alamadığımız "
            f"haftalarda ilk sorumluluk bizim, sahaya çıkanların,\" dedi.",
            _rank_line(ctx),
        ],
        "effects": {"fame:overall": 0.5},
    },
    {
        "story_id": "roportaj-taraftara-mesaj",
        "category": "Röportaj",
        "triggers": ("interview",),
        "weight": 3,
        "cooldown_days": 20,
        "outlets": ("tribun-sesi", "kulup-bulteni"),
        "applies": lambda ctx: ctx.rel("fans") <= 45,
        "headlines": [
            "{player}'den tribüne çağrı",
            "'Bize sahip çıkın': {last_name} taraftara seslendi",
            "{last_name} tribünle arasını düzeltmeye çalışıyor",
            "{player}: 'Islık da alkış da bizim payımıza'",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}, son haftalarda tribünlerde hissedilen soğukluğa "
            f"doğrudan değindi. \"Islığı hak ettiğimiz maçlar oldu, bunu "
            f"biliyoruz,\" dedi.",
            rng.choice([
                f"\"Ama {s['team_short']} tribünü bize küsmesin. Cumartesi günü "
                f"sesinizi duyunca oyun değişiyor, bunu sahadan görüyoruz,\" diye ekledi.",
                "\"Kimseden sabır istemiyorum. Sadece sahada koştuğumuzu "
                "görmenizi istiyorum,\" ifadesini kullandı.",
                f"\"Deplasmanda bizimle yolculuk eden insanlara bir şey borçluyuz,\" dedi.",
            ]),
            _form_line(ctx),
        ],
        "effects": {"relationship:fans": 1, "fame:overall": 0.3},
    },
]


# ---------------------------------------------------------------------------
# MAGAZİN — the tabloid layer. New category (§3).
#
# This is the part of the design note that asked for "gossip": nightlife,
# the partner, the family, expensive purchases, and the eternal tabloid
# question of whether a footballer was out the night before training.
# Almost all of these are day_tick or lifestyle-triggered, so they read as
# something the press noticed rather than something the player submitted.
# ---------------------------------------------------------------------------

_MAGAZIN = [
    {
        "story_id": "magazin-gece-hayati",
        "category": "Magazin",
        "triggers": ("lifestyle",),
        "weight": 5,
        "cooldown_days": 9,
        "outlets": ("magazin-ekspres", "tribun-sesi"),
        "applies": lambda ctx: ctx.fact("catalog_id") in ("sos-konser", "sos-arkadas"),
        "headlines": [
            "{player} sabaha karşı o mekândan çıkarken görüntülendi",
            "Gece {player}, sabah antrenman: peki bu tempo sürer mi?",
            "{last_name}'in gecesi uzun sürdü",
            "Objektifler {player}'i yakaladı",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}, dün gece şehrin merkezindeki bir mekânda görüntülendi. "
            f"Görgü tanıklarına göre oyuncu kalabalık bir masadaydı ve keyfi "
            f"yerindeydi.",
            rng.choice([
                f"{s['team']} tesislerinden konuyla ilgili bir açıklama gelmedi. "
                f"Kulübün gece izni konusunda yazılı bir kuralı olduğu biliniyor.",
                f"Aynı gece mekânda bulunan başka isimler de olduğu, ancak "
                f"{s['last_name']}'in masadan ilk kalkanlardan olmadığı iddia ediliyor.",
                "Fotoğrafları çeken kişi, oyuncunun kendilerine el salladığını "
                "söylüyor. Biz de bunu bir cevap sayıyoruz.",
            ]),
            f"Oyuncunun kondisyonu bugün itibarıyla {ctx.condition}/100 — "
            f"yani {_condition_word(ctx)}. " + _form_line(ctx),
        ],
        "effects": {"fame:overall": 0.8, "relationship:coach": -1},
    },
    {
        "story_id": "magazin-antrenman-oncesi-gece",
        "category": "Magazin",
        "triggers": ("lifestyle",),
        "weight": 4,
        "cooldown_days": 14,
        "outlets": ("magazin-ekspres", "tribun-sesi"),
        "applies": lambda ctx: (
            ctx.condition <= 55 and str(ctx.fact("catalog_id", "")).startswith("sos-")
        ),
        "headlines": [
            "Yorgun {player}, yine dışarıda",
            "Kondisyon {rank}. sıradaki takımın sorunu mu, {last_name}'in mi?",
            "'Önce dinlensin' diyenler haklı çıkar mı?",
            "{last_name}'in programı tartışılıyor",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}'in kondisyon değeri {ctx.condition}/100 seviyesine "
            f"gerilemişken sosyal programını sürdürmesi, kulüp çevresinde "
            f"kaş kaldırtıyor.",
            f"{s['coach']}'un oyuncularının dinlenme düzenine önem verdiği biliniyor. "
            f"Teknik ekibin bu konuyu bireysel görüşmede gündeme getirip "
            f"getirmediği bilinmiyor.",
            rng.choice([
                "Bir futbolcunun boş gününü nasıl geçireceği kendi bileceği iştir. "
                "Cumartesi günü sahadaki hâli ise herkesin bileceği iş.",
                "Kondisyon düşüşünün tek sebebinin sosyal program olmadığını, "
                "maç yükünün de payı olduğunu ekleyelim.",
                f"{s['team_short']} taraftarının bu konuda sabrı, sonuçlarla "
                f"doğru orantılı ilerliyor.",
            ]),
        ],
        "effects": {"relationship:coach": -1, "relationship:media": -1},
    },
    {
        "story_id": "magazin-partner-birlikte",
        "category": "Magazin",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 16,
        "outlets": ("magazin-ekspres",),
        "applies": lambda ctx: ctx.rel("partner") >= 55,
        "headlines": [
            "{player} ve {partner} el ele görüntülendi",
            "{partner} ile {last_name}: mutluluk pozu",
            "Sezonun en huzurlu çifti mi?",
            "{player}'in yanındaki isim: {partner}",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']} ve {s['partner']}, dün akşam sahildeki bir restoranda "
                f"birlikte görüntülendi. Çift, objektifleri fark ettiğinde "
                f"rahatsız olmadı.",
                f"{s['partner']} ile {s['player']}, dün akşam şehir merkezindeki bir "
                f"mekândan el ele çıkarken görüntülendi.",
                f"Maç haftasının ortasında {s['player']}'i sahada değil, {s['partner']} "
                f"ile bir kafe terasında gördük. İkilinin keyfi yerindeydi.",
            ]),
            rng.choice([
                f"{s['partner']}'in {s['player']}'in maçlarını tribünden takip ettiği, "
                f"deplasmanlara da zaman zaman eşlik ettiği biliniyor.",
                "Yakın çevrelerinden edindiğimiz bilgiye göre ilişki gayet yolunda.",
                "Akşam yemeği yaklaşık iki saat sürdü. Hesabı kimin ödediğini "
                "sormadık, ama bir tahminimiz var.",
            ]),
            f"{s['player']} için sezonun bu bölümü sahada da fena gitmiyor. "
            + _tally_line(ctx),
        ],
        "effects": {"fame:overall": 0.5},
    },
    {
        "story_id": "magazin-partner-yalniz-aksam",
        "category": "Magazin",
        "triggers": ("day_tick",),
        "weight": 3,
        # 45, not 18: `partner` sits at 0 for as long as the player never
        # talks to them, so this is the one Magazin story a career can be
        # permanently eligible for. At 18 days it printed four times in a
        # season — "he had dinner alone" is not a fortnightly headline.
        "cooldown_days": 45,
        "outlets": ("magazin-ekspres",),
        # The "nobody in the picture" story, NOT a break-up: it runs while
        # the partner score has never been meaningfully high. A career opens
        # at partner 0 by design (§4 — "you haven't called home yet"), so
        # this is the state a fresh player is actually in.
        "applies": lambda ctx: ctx.rel("partner") <= 25 and ctx.peak("partner") < 40,
        "headlines": [
            "{player} yalnız akşam yemeğinde",
            "{last_name} tek başına görüntülendi",
            "Sessiz masa: {player}'in akşamı",
            "{last_name}'in yanında bu kez kimse yoktu",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']} dün akşam şehirdeki bir restoranda tek başına "
                f"görüntülendi. Oyuncunun telefonuyla uzun süre ilgilendiği, "
                f"masaya kimsenin katılmadığı gözlendi.",
                f"{s['age']} yaşındaki {s['position']}, dün akşamı da yalnız "
                f"geçirdi. {s['player']}'in özel hayatına dair elimizde "
                f"yıllardır tek bir fotoğraf yok.",
                f"{s['player']}'in sosyal hayatı, kariyerinin bu döneminde "
                f"sahayla tesis arasına sıkışmış görünüyor. Dün akşamki masada "
                f"da yanında kimse yoktu.",
            ]),
            rng.choice([
                "Oyuncunun çevresine yakın isimler, gündeminde şu an yalnızca "
                "futbol olduğunu söylüyor.",
                "Bir açıklama beklemiyoruz; zaten açıklanacak bir şey de "
                "olmadığı anlaşılıyor.",
                f"{s['player']}'in yoğun maç takvimi göz önüne alındığında bunun "
                f"olağan bir akşam olduğu da söylenebilir. Söylenebilir.",
            ]),
        ],
    },
    {
        "story_id": "magazin-ayrilik-soylentisi",
        "category": "Magazin",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 30,
        "outlets": ("magazin-ekspres",),
        # A break-up needs something to break. `partner` starts at 0 for
        # every career (§4), so keying on the current score alone printed
        # the end of a relationship the player never had — the single most
        # obviously wrong thing this layer was doing. `peak()` is the
        # relationship's own audit trail (relationship_event, replayed):
        # the story runs only where the rapport was REAL and then fell.
        "applies": lambda ctx: ctx.peak("partner") >= 40 and ctx.rel("partner") <= 10,
        "headlines": [
            "{player} cephesinde ayrılık iddiası",
            "{partner} sosyal medyadan fotoğrafları kaldırdı",
            "O ilişki bitti mi?",
            "{last_name}'in özel hayatında sessizlik",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']} ile {s['partner']} arasındaki ilişkinin bir süredir "
                f"sürmediği iddia ediliyor. İddianın kaynağı, iki tarafın da "
                f"aylardır birlikte görüntülenmemiş olması.",
                f"Bir dönem birlikte görüntülenmedikleri hafta olmayan "
                f"{s['player']} ile {s['partner']}'in yollarını ayırdığı "
                f"konuşuluyor. İki taraf da sessiz.",
                f"{s['partner']} cephesindeki sessizlik uzadıkça, "
                f"{s['player']} ile ilişkilerinin bittiği iddiası güçleniyor. "
                f"Ortak fotoğrafların kaybolması da bu yönde okunuyor.",
            ]),
            rng.choice([
                "Yakın çevre 'yorum yok' demekle yetindi. Bu tür dosyalarda "
                "'yorum yok' genellikle bir yorumdur.",
                f"{s['player']}'in sezon içinde yoğun bir tempoya girdiği, "
                f"özel hayatına vakit ayıramadığı da söyleniyor.",
                "Bir futbolcunun kalbi bizi ilgilendirmez. Ama okurumuz merak "
                "ediyorsa biz de merak ederiz.",
            ]),
            "Konuya ilişkin doğrulanmış tek bir bilgi bulunmuyor.",
        ],
    },
    {
        "story_id": "magazin-aileden-sitem",
        "category": "Magazin",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 25,
        "outlets": ("magazin-ekspres", "tribun-sesi"),
        # "He drifted away from home" only makes sense if he was ever close
        # to it. `family` also starts at 0, so the same peak gate applies —
        # otherwise a career that never called home once got a reproach
        # story on its second week, about a bond it never had.
        "applies": lambda ctx: (
            ctx.rel("family") <= 10 and ctx.peak("family") >= 30 and not ctx.did("sos-aile")
        ),
        "headlines": [
            "Memleketten sitem: '{first_name} aramıyor'",
            "{mother}'den {player}'e sitem",
            "Ailesi {last_name}'i televizyondan izliyor",
            "'Biz onu maçlarda görüyoruz'",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']}'in ailesinin, oyuncunun son dönemde memleketiyle "
                f"bağını zayıflattığından yakındığı öğrenildi.",
                f"Bir zamanlar her maç sonrası aranan {s['mother']}, "
                f"{s['player']}'den haber alamadığını yakın çevresine "
                f"anlatıyor.",
                f"{s['player']}'in memleketiyle arasına giren mesafe, "
                f"ailesinin çevresinde açıkça konuşulur oldu.",
            ]),
            rng.choice([
                f"\"{s['first_name']}'i televizyondan izliyoruz. Kızmıyoruz, "
                f"işi zor. Ama bir telefon bir dakika sürer,\" ifadeleri aktarılıyor.",
                "Aile çevresi, oyuncunun sezon başından bu yana memlekete "
                "uğramadığını belirtiyor.",
                f"{s['mother']}'in her maçı ekran başında takip ettiği biliniyor.",
            ]),
            "Futbolcunun kendisinden bu konuda bir açıklama gelmedi.",
        ],
        "effects": {"relationship:family": -1},
    },
    {
        "story_id": "magazin-luks-alisveris",
        "category": "Magazin",
        "triggers": ("purchase",),
        "weight": 5,
        "cooldown_days": 10,
        "outlets": ("magazin-ekspres", "tribun-sesi"),
        "applies": lambda ctx: (ctx.fact("price", 0) or 0) >= 500000,
        "headlines": [
            "{player}'in yeni adresi: {item}",
            "{last_name} {item} aldı, rakam konuşuluyor",
            "Bu kadarı da fazla mı? {player}'in son alışverişi",
            "{item}: {player} imzayı attı",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}'in {s['item']} satın aldığı öğrenildi. "
            f"Ödenen rakamın piyasa değerinin üzerinde olmadığı belirtiliyor, "
            f"ancak bir {s['position']} için iddialı bir tercih olduğu kesin.",
            rng.choice([
                f"Oyuncunun haftalık ücretinin {s['wage']} olduğu düşünüldüğünde, "
                f"bu alışverişin uzun vadeli bir taahhüt olduğu ortada.",
                "Yakın çevresi, kararın uzun süredir düşünüldüğünü ve bir "
                "yatırım olarak görüldüğünü aktarıyor.",
                "Kulüpten bir açıklama beklemiyoruz; bu, tamamen oyuncunun "
                "kendi bileceği bir iş. Yine de yazıyoruz.",
            ]),
            f"Kasa durumu: {s['money']}.",
        ],
        "effects": {"fame:overall": 0.6},
    },
    {
        "story_id": "magazin-mutevazi-alisveris",
        "category": "Magazin",
        "triggers": ("purchase",),
        "weight": 3,
        "cooldown_days": 14,
        "outlets": ("magazin-ekspres", "lig-ajansi"),
        "applies": lambda ctx: 0 < (ctx.fact("price", 0) or 0) < 500000,
        "headlines": [
            "{player} kendine {item} aldı",
            "Küçük ödül: {last_name}'in yeni {item}'i",
            "{player}'in alışveriş listesi merak konusu",
            "{item} — ve o kadar",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}, {s['item']} satın aldı. Alışverişin ne büyüklüğü ne "
            f"de zamanlaması olağandışı; buna rağmen sosyal medyada "
            f"konuşuldu.",
            rng.choice([
                "Genç futbolcuların ilk kazançlarını nasıl harcadığı, "
                "her sezon aynı tartışmayı doğuruyor.",
                f"{s['player']}'in bu sezon kasasında {s['money']} bulunuyor.",
                "Bu haberi yazmamızın sebebi haberin kendisi değil, "
                "okurun merakı. Şeffaf olalım.",
            ]),
        ],
    },
    {
        "story_id": "magazin-objektiflerden-kaciyor",
        "category": "Magazin",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 22,
        "outlets": ("magazin-ekspres", "spor-manset"),
        "applies": lambda ctx: ctx.fame >= 8 and ctx.rel("media") <= 25,
        "headlines": [
            "{player} objektiflerden kaçıyor",
            "Ünlü ama uzak: {last_name} basınla arasına mesafe koydu",
            "Bir sezondur konuşan yok: {player} neden susuyor?",
            "{last_name}'in basınla imtihanı",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']} tanınırlığını hızla artırırken basınla arasındaki "
                f"mesafeyi de büyütüyor. Oyuncu son dönemde röportaj taleplerinin "
                f"neredeyse tamamını geri çevirdi.",
                f"Herkes {s['player']}'i tanıyor ama kimse onunla konuşamıyor. "
                f"Oyuncunun basın mensuplarıyla arasına koyduğu mesafe "
                f"büyümeye devam ediyor.",
                f"{s['player']}, mixed zone'dan geçen ama durmayan futbolcular "
                f"kategorisine yerleşti. Tanınırlığı artarken erişilebilirliği "
                f"tam tersi yönde ilerliyor.",
            ]),
            rng.choice([
                "Bu tavrın bilinçli bir tercih mi yoksa geçmiş bir kırgınlığın "
                "sonucu mu olduğu bilinmiyor.",
                f"{s['team']} basın biriminin oyuncuyu ikna etmek için "
                f"çalıştığı belirtiliyor.",
                "Konuşmayan futbolcunun haberi de yazılır. Sadece daha az "
                "cümlesiyle.",
            ]),
            "Sessizlik uzun sürerse, boşluğu başkalarının doldurduğu bir "
            "meslektir bu.",
        ],
        "effects": {"relationship:media": -1},
    },
    {
        "story_id": "magazin-taraftar-etkinligi",
        "category": "Magazin",
        "triggers": ("lifestyle",),
        "weight": 5,
        "cooldown_days": 12,
        "outlets": ("tribun-sesi", "kulup-bulteni", "magazin-ekspres"),
        "applies": lambda ctx: ctx.fact("catalog_id") == "sos-taraftar",
        "headlines": [
            "{player} taraftar buluşmasında",
            "Tribünle yüz yüze: {last_name} sözünü tuttu",
            "{team} taraftarı {player}'i bağrına bastı",
            "Bir futbolcu, iki yüz taraftar, bir salon",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}, kulübün taraftar derneğinin düzenlediği buluşmaya "
            f"katıldı. Oyuncu, salondaki herkesle tek tek fotoğraf çektirdi "
            f"ve programı planlanandan uzun sürdü.",
            rng.choice([
                "Bu tür etkinliklere katılan futbolcu sayısı her yıl azalıyor. "
                "Bu yüzden yazıyoruz.",
                f"{s['team_short']} tribünü, sahada mücadele eden ve tribüne "
                f"selam veren oyuncuyu unutmaz. Bunu herkes bilir.",
                f"Etkinlikte en çok sorulan soru, tahmin edileceği üzere, "
                f"{s['player']}'in geleceğiyle ilgiliydi.",
            ]),
            _rank_line(ctx),
        ],
        "effects": {"relationship:fans": 2, "fame:overall": 0.7},
    },
    {
        "story_id": "magazin-kafe-goruntusu",
        "category": "Magazin",
        "triggers": ("lifestyle",),
        "weight": 2,
        "cooldown_days": 15,
        "outlets": ("magazin-ekspres",),
        "applies": lambda ctx: ctx.fact("catalog_id") in ("sos-kafe", "ev-film", "ev-oyun"),
        "headlines": [
            "{player}'in sıradan günü de haber oluyor",
            "Kahve, telefon, {last_name}",
            "Bugün {player} hakkında yazacak pek bir şey yoktu",
            "{last_name} kendi hâlinde",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']} dün şehirde sakin bir gün geçirdi. Oyuncunun "
            f"kimseyle tartışmadığını, kimseye bağırmadığını ve hiçbir mekândan "
            f"sabaha karşı çıkmadığını üzülerek bildiririz.",
            rng.choice([
                "Bazı günler böyledir. Yazacak bir şey yoksa, olmadığını yazarız.",
                f"{s['player']}'in bu haftaki tek dikkat çeken hareketi, "
                f"telefonuna uzun süre bakması oldu.",
                "Fotoğrafçımız iki saat bekledi. Elde ettiği tek kare bu.",
            ]),
        ],
    },
    {
        "story_id": "magazin-soyunma-odasi-gerginlik",
        "category": "Magazin",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 16,
        "outlets": ("magazin-ekspres", "spor-manset", "tribun-sesi"),
        "applies": lambda ctx: ctx.rel("team") <= 30,
        "headlines": [
            "{team} soyunma odasında gerginlik iddiası",
            "'{captain} devreye girdi': {team}'de huzursuzluk",
            "Soyunma odasında sesler yükseldi",
            "{team} içinde çatlak mı var?",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['team']} soyunma odasında son haftalarda gerginlik yaşandığı "
                f"öne sürülüyor. İddiaya göre tartışmanın merkezinde oyun içi "
                f"sorumluluk paylaşımı var.",
                f"{s['team']} soyunma odasından yükselen sesler tesis duvarlarını "
                f"aştı. Tartışmanın {s['captain']} ile bir grup oyuncu "
                f"arasında geçtiği iddia ediliyor.",
                f"Bir takımın iç dengesi bozulduğunda ilk belirti antrenman "
                f"sahasında görülür; {s['team']}'te bu hafta tam olarak bu "
                f"yaşandı.",
            ]),
            rng.choice([
                f"Kaptan {s['captain']}'in konuyu büyümeden kapatmak için "
                f"devreye girdiği belirtiliyor.",
                f"{s['coach']}, antrenman sonrası olağan dışı uzunlukta bir "
                f"toplantı yaptı.",
                "Kulüp içinden kimse konuşmuyor. Konuşmayınca da yazılıyor.",
            ]),
            _form_line(ctx),
        ],
        "effects": {"relationship:team": -1},
    },
]


# ---------------------------------------------------------------------------
# İLİŞKİ / SOYUNMA ODASI — §2.4. Filed as Analiz when the angle is tactical
# and Magazin when the angle is human; the split is what keeps the Analiz
# feed from turning into a gossip column.
# ---------------------------------------------------------------------------

_ILISKI = [
    {
        "story_id": "iliski-teknik-direktorle-mesafe",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 18,
        "outlets": ("spor-manset", "tribun-sesi"),
        "applies": lambda ctx: ctx.rel("coach") <= 30,
        "headlines": [
            "{coach} ile {last_name} arasında mesafe",
            "Kadro dışı sinyali mi? {player} için tehlike çanları",
            "{team}'de teknik heyet–oyuncu gerilimi",
            "{coach}'un planında {last_name} nerede?",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['coach']} ile {s['player']} arasındaki ilişkinin son haftalarda "
                f"soğuduğu değerlendiriliyor. Teknik heyetin oyuncudan beklediği "
                f"savunma katkısını yeterli bulmadığı konuşuluyor.",
                f"{s['team']}'te teknik direktör {s['coach']} ile {s['player']} arasında "
                f"bir mesafe oluştuğu konuşuluyor. Antrenman sahasındaki "
                f"görüntü de bu yorumu besliyor.",
                f"{s['coach']}'un {s['player']} ile ilgili beklentileri ile oyuncunun "
                f"sahadaki tercihleri son haftalarda örtüşmüyor.",
            ]),
            f"Bu tür durumlarda ilk göstergesi oynama süresidir. "
            + _tally_line(ctx),
            rng.choice([
                "Sezonun bu döneminde kadro dışı bırakmak, hem oyuncuya hem "
                "kulübe pahalıya patlar. İki taraf da bunu biliyor.",
                f"{s['coach']}'un veriye güvenen bir isim olduğu düşünülürse, "
                f"tartışmanın çözümü de veride aranacak.",
                "Bir hafta içinde ilk on birde görülmesi, tartışmayı tek başına "
                "bitirir.",
            ]),
        ],
    },
    {
        "story_id": "iliski-hoca-guveni",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 22,
        "outlets": ("spor-manset", "kulup-bulteni"),
        "applies": lambda ctx: ctx.rel("coach") >= 80,
        "headlines": [
            "{coach}'un vazgeçilmezi: {player}",
            "Teknik heyetin güveni tam",
            "{last_name}, {coach}'un planının merkezinde",
            "{team}'de bir oyuncu öne çıkıyor",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['coach']}'un {s['player']}'e duyduğu güven, kadro tercihlerine "
                f"açıkça yansıyor. Teknik heyetin oyuncuyu sistemin sabit "
                f"parçalarından biri olarak gördüğü belirtiliyor.",
                f"{s['team']}'te ilk on bir tartışması yapılırken bir isim hiç "
                f"konuşulmuyor: {s['player']}. {s['coach']}'un tercihi bu "
                f"konuda nettir.",
                f"{s['coach']}, {s['player']}'i sezon başından bu yana neredeyse hiç "
                f"kadro dışı bırakmadı. {_tally_line(ctx)}",
            ]),
            _tally_line(ctx) + " " + _rank_line(ctx),
            rng.choice([
                "Bu güvenin sözleşme masasına da yansıması bekleniyor.",
                f"{s['position']} bölgesinde alternatif arayışının rafa "
                f"kaldırıldığı öğrenildi.",
                "Genç bir oyuncu için teknik direktörün güveni, transfer "
                "teklifinden daha değerlidir.",
            ]),
        ],
        "effects": {"fame:overall": 0.3},
    },
    {
        "story_id": "iliski-tribunden-islik",
        "category": "Magazin",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 15,
        "outlets": ("tribun-sesi", "magazin-ekspres"),
        "applies": lambda ctx: ctx.rel("fans") <= 20,
        "headlines": [
            "Tribünden {last_name}'e ıslık",
            "{team} tribünü sabrını tüketti",
            "O ıslık kime? {player}'e",
            "Kendi sahamızda kendi oyuncumuzu ıslıklıyoruz",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['team']} tribünlerinin {s['player']}'e tepkisi son maçta "
                f"duyulur hâle geldi. Oyuncu topla buluştuğunda kale arkasından "
                f"gelen sesler, kameralara da yansıdı.",
                f"Kale arkası {s['player']}'e sırtını döndü. {s['team']} tribünü "
                f"sabrının sınırına geldiğini son maçta açıkça gösterdi.",
                f"{s['player']} topla her buluştuğunda tribünden yükselen ses, artık "
                f"{s['team']} camiasında konuşulan bir başlık.",
            ]),
            rng.choice([
                "Bunu yazmak hoşumuza gitmiyor. Kendi oyuncumuzu ıslıklamak "
                "kimseye bir şey kazandırmaz. Ama yaşandı.",
                "Tribünün beklentisi gol değil, mücadele. Fark burada.",
                f"{s['captain']}'in maç sonunda kale arkasına gidip konuştuğu "
                f"görüldü.",
            ]),
            _form_line(ctx),
        ],
        "effects": {"relationship:fans": -1},
    },
    {
        "story_id": "iliski-soyunma-odasi-uyum",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 24,
        "outlets": ("kulup-bulteni", "tribun-sesi", "lig-ajansi"),
        "applies": lambda ctx: ctx.rel("team") >= 78 and ctx.rel("fans") >= 55,
        "headlines": [
            "{team}'de soyunma odası uyumu dikkat çekiyor",
            "İyi haber: {team} kenetlendi",
            "{captain} ve {last_name}: işleyen bir ikili",
            "Bu takımın en güçlü tarafı kadro değil",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['team']} kadrosundaki uyumun sahaya yansıdığı görülüyor. "
                f"{s['captain']} liderliğindeki grubun, yeni gelenleri hızlıca "
                f"içine aldığı belirtiliyor.",
                f"{s['team']} soyunma odasından yansıyan tablo olumlu: {s['captain']} "
                f"etrafında toplanan grup, sahadaki dayanışmayı da "
                f"koruyor.",
                f"Bir takımın en zor ölçülen özelliği uyumdur; {s['team']}'te bu "
                f"özellik son haftalarda gözle görülür hâle geldi.",
            ]),
            _rank_line(ctx) + " " + _form_line(ctx),
            rng.choice([
                "Bu tür dönemler uzun sürmez; bu yüzden değerlidir.",
                f"{s['player']} de bu ortamın kazananlarından: "
                f"{s['appearances']} maçta forma giydi.",
                "Kulüp içinde herkesin aynı şeyi söylediği haftalar, "
                "genellikle sonuç alınan haftalardır.",
            ]),
        ],
    },
]


# ---------------------------------------------------------------------------
# YAŞAM — new category (§3). Money, upkeep, and the consequences of D27/D29.
#
# The two existing hard-coded news items (`Bütçe zorlaması` and
# `Bütçe uyarısı`, previously filed under Analiz with a single sentence of
# body) are replaced by the first two archetypes here.
# ---------------------------------------------------------------------------

_YASAM = [
    {
        "story_id": "yasam-butce-zorlamasi",
        "category": "Yaşam",
        "triggers": ("money_trouble",),
        "weight": 5,
        "cooldown_days": 0,   # her el değiştiren eşya kendi haberini hak eder
        "outlets": ("magazin-ekspres", "lig-ajansi", "spor-manset"),
        "applies": lambda ctx: True,
        "headlines": [
            "{player} {item}'i elden çıkardı",
            "Kasa konuştu: {item} satıldı",
            "{last_name}'in düzenli gideri {item}'e mal oldu",
            "Zorunlu satış: {item}",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}, haftalık düzenli giderlerini karşılayamadığı için "
            f"{s['item']} elden çıkarmak zorunda kaldı. Satış, piyasa "
            f"değerinin altında gerçekleşti.",
            f"Oyuncunun haftalık geliri {s['wage']}; alışverişlerinin getirdiği "
            f"düzenli yük ise bu geliri aşmış durumda. Kasada kalan: {s['money']}.",
            rng.choice([
                "Genç futbolcuların ilk sözleşmelerinde en sık düştüğü tuzak, "
                "gelirin değil giderin sabit olduğunu geç fark etmek.",
                "Bu tür kararlar sahada değil, muhasebede alınır. Ama sahada "
                "hissedilir.",
                f"{s['player']}'in çevresinin mali danışmanlık konusunda "
                f"harekete geçtiği belirtiliyor.",
            ]),
        ],
    },
    {
        "story_id": "yasam-gider-uyarisi",
        "category": "Yaşam",
        "triggers": ("upkeep_warning",),
        "weight": 5,
        "cooldown_days": 0,
        "outlets": ("lig-ajansi", "spor-manset", "magazin-ekspres"),
        "applies": lambda ctx: True,
        "headlines": [
            "Kasada alarm: {player}'in bütçesi zorlanıyor",
            "Bu hafta gider gelirden büyük",
            "{last_name} için mali uyarı",
            "{money}: {player}'in kasasındaki tablo",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}'in bu haftaki düzenli giderleri, kasadaki para ve "
            f"haftalık ücretin toplamıyla karşılanamıyor. Açık "
            f"{_money(ctx.fact('shortfall', 0))} seviyesinde.",
            f"Mevcut durumda kasada {s['money']} bulunuyor, haftalık gelir "
            f"{s['wage']}. Açık kapanmazsa sahip olunan kalemlerden biri "
            f"elden çıkarılacak.",
            rng.choice([
                "Uyarı, kararı vermeden önce bir hafta tanıyor. O hafta "
                "genellikle yeterli olur.",
                "Bir maç primi tabloyu tamamen değiştirebilir.",
                "Gider kalemlerinin gönüllü olarak azaltılması da bir seçenek.",
            ]),
        ],
    },
    {
        "story_id": "yasam-kasada-delik",
        "category": "Yaşam",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 20,
        "outlets": ("magazin-ekspres", "spor-manset"),
        "applies": lambda ctx: ctx.money < 2000 and bool(ctx.inventory),
        "headlines": [
            "{player}'in kasasında delik: {money}",
            "Alışveriş bitti, hesap başladı",
            "{last_name} ay sonunu nasıl getirecek?",
            "Gelir sabit, gider değil",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']}'in kasasındaki para {s['money']} seviyesine geriledi. "
                f"Oyuncunun sahip olduğu kalemlerin haftalık yükü sürüyor.",
                f"{s['money']}. {s['player']}'in kasasında kalan tutar bu ve haftalık "
                f"düzenli giderler işlemeye devam ediyor.",
                f"Sahadaki tablo iyi, kasadaki tablo değil: {s['player']}'in birikimi "
                f"{s['money']} seviyesine indi.",
            ]),
            f"Haftalık ücret {s['wage']}. Bir sonraki maaş gününe kadar "
            f"kasadaki paranın bu yükü karşılaması gerekiyor.",
            rng.choice([
                "Futbolcuların kariyerlerinin ilk yıllarında en çok "
                "zorlandıkları konu, kazancın düzenli gidere dönüşme hızı.",
                "Prim maddeleri devreye girerse tablo hızla düzelir.",
                f"{s['team']} yönetiminden bir avans talebi olup olmadığı "
                f"bilinmiyor.",
            ]),
        ],
    },
    {
        "story_id": "yasam-prim-kazanci",
        "category": "Yaşam",
        "triggers": ("day_tick",),
        "weight": 2,
        "cooldown_days": 25,
        "outlets": ("lig-ajansi", "spor-manset"),
        "applies": lambda ctx: (
            ctx.contract is not None and ctx.contract["goal_bonus"] > 0 and ctx.goals >= 3
        ),
        "headlines": [
            "{player}'in prim hanesi kabarıyor",
            "{goals} gol, {goals} prim",
            "Sözleşmedeki gol maddesi işliyor",
            "{last_name} sahada kazanıyor",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']}'in sözleşmesindeki gol primi maddesi bu sezon "
                f"düzenli olarak işliyor. Oyuncu {s['goals']} golle prim hanesini "
                f"kabartmış durumda.",
                f"{s['goals']} gol, {s['goals']} prim. {s['player']}'in sözleşmesindeki "
                f"gol maddesi bu sezon en çok çalışan madde oldu.",
                f"Taban ücreti mütevazı, primleri değil: {s['player']} bu sezon attığı "
                f"{s['goals']} golle kazancını sözleşme üzerinden ikiye "
                f"katlıyor.",
            ]),
            f"Haftalık ücreti {s['wage']} olan futbolcunun kasasında hâlihazırda "
            f"{s['money']} bulunuyor.",
            rng.choice([
                "Prim yapısı, düşük taban ücretli genç oyuncular için "
                "kulüplerin tercih ettiği model.",
                "Bu tempoda sezon sonunda prim geliri, taban ücreti "
                "geçebilir.",
                "Sözleşme yenilenirse ilk tartışılacak kalem bu olacak.",
            ]),
        ],
    },
    {
        "story_id": "yasam-mutevazi-duzen",
        "category": "Yaşam",
        "triggers": ("day_tick",),
        "weight": 2,
        "cooldown_days": 30,
        "outlets": ("spor-manset", "kulup-bulteni"),
        "applies": lambda ctx: ctx.money >= 250000 and not ctx.owns_any("estate-"),
        "headlines": [
            "{player} hâlâ aynı evde",
            "Kasada {money}, hayatta değişen yok",
            "{last_name}'in mütevazı düzeni",
            "Kazanıyor ama harcamıyor",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']}'in kasasında {s['money']} birikmiş olmasına rağmen "
                f"yaşam düzeninde bir değişiklik olmadığı belirtiliyor. Oyuncu "
                f"hâlâ sezon başındaki evinde oturuyor.",
                f"{s['money']} birikime rağmen {s['player']}'in adresi değişmedi. "
                f"Oyuncu sezon başındaki evinde oturmaya devam ediyor.",
                f"Kazanç arttıkça harcamanın da artması beklenirdi; {s['player']} "
                f"örneğinde bu olmadı. Kasada {s['money']} var, hayatta "
                f"değişen yok.",
            ]),
            rng.choice([
                "Bu tercihin bilinçli olduğu, oyuncunun çevresinin ilk "
                "yatırımın doğru zamanda yapılmasını beklediği söyleniyor.",
                "Kariyerinin başındaki bir futbolcu için bu, nadir görülen "
                "bir olgunluk.",
                f"{s['team']} yönetiminin de bu tabloyu memnuniyetle "
                f"karşıladığı belirtiliyor.",
            ]),
        ],
    },
]


# ---------------------------------------------------------------------------
# MAÇ — replaces the old one-line "Maç sonuçlandı." report.
#
# ⚠️ Every headline in this block MUST carry {score} or {scoreline}. It is
# asserted at the bottom of this file, and the reason is not cosmetic: M2's
# response hands FE a single news_id and that item IS the match report — a
# headline without the result would be the one place the feed fails to
# answer the only question the reader has. (tests/test_content_router.py's
# end-to-end read asserts exactly this.)
# ---------------------------------------------------------------------------

_MAC = [
    {
        "story_id": "mac-hat-trick",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 9,
        "cooldown_days": 0,
        "outlets": ("spor-manset", "tribun-sesi", "magazin-ekspres"),
        "applies": lambda ctx: ctx.fact("goals", 0) >= 3,
        "headlines": [
            "{scoreline}: {player}'in gecesi",
            "Hat-trick! {scoreline}",
            "{last_name} üç attı: {scoreline}",
            "{score} — ve sahada tek isim vardı",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['player']} {ctx.fact('goals')} gol attı ve "
                f"maçın tartışmasız adamı oldu. {s['competition']} bu akşam "
                f"başka hiçbir şeyi konuşmayacak.",
                f"{s['scoreline']}. Bu akşamın tek bir başlığı var: {s['player']}. "
                f"Doksan dakika, {ctx.fact('goals')} gol, tek isim.",
                f"{s['player']}, {s['opponent']} filelerini bir maçta {ctx.fact('goals')} "
                f"kez havalandırdı. {s['scoreline']} biten karşılaşmada sahanın "
                f"en çok konuşulacak ismi daha ilk yarıda belli olmuştu.",
            ]),
            rng.choice([
                "Üç golün üçü de farklı biçimde geldi; bu, bir forvetin "
                "cephaneliğini gösteren en iyi işarettir.",
                f"{s['opponent']} savunması ikinci golden sonra toparlanamadı.",
                "Maç topunu alıp soyunma odasına giden oyuncuyu, "
                "takım arkadaşları koridorda karşıladı.",
            ]),
            _tally_line(ctx) + " " + _rank_line(ctx),
        ],
        "effects": {"fame:overall": 3.0},
    },
    {
        "story_id": "mac-golle-galibiyet",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 8,
        "cooldown_days": 0,
        "outlets": ("spor-manset", "tribun-sesi", "lig-ajansi"),
        "applies": lambda ctx: ctx.fact("result") == "win" and 1 <= ctx.fact("goals", 0) <= 2,
        "headlines": [
            "{scoreline}: {last_name} yine sahnede",
            "{score} — {player}'in golüyle üç puan",
            "{team} kazandı, {last_name} attı: {scoreline}",
            "{scoreline}: kazandıran isim {last_name}",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['player']} {ctx.fact('goals')} golle skora "
                f"doğrudan katkı verdi ve {s['team']} sahadan üç puanla ayrıldı.",
                f"{s['team']}, {s['opponent']} karşısında {s['score']} kazandı. Skorun "
                f"altında {s['player']}'in {ctx.fact('goals')} gollük imzası var.",
                f"{s['scoreline']}. Üç puanı getiren isimlerin başında {ctx.fact('goals')} "
                f"golle {s['player']} geliyor; maçın kırılma anları da onun "
                f"ayağından çıktı.",
            ]),
            rng.choice([
                f"{s['coach']}'un maç planı işledi: rakibi kendi yarı sahasında "
                f"karşılamak, topu kazandıktan sonra hızlı çıkmak.",
                f"{s['opponent']} maçın kontrolünü ilk yarım saat elinde tuttu, "
                f"ancak pozisyona dönüştüremedi.",
                "Kazanılan maçın kahramanı belli; kazandıran emek ise "
                "on bir kişiye ait.",
            ]),
            _rank_line(ctx) + " " + _form_line(ctx),
        ],
        "effects": {"fame:overall": 1.5},
    },
    {
        "story_id": "mac-asist",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 6,
        "cooldown_days": 0,
        "outlets": ("spor-manset", "lig-ajansi", "tribun-sesi"),
        "applies": lambda ctx: ctx.fact("assists", 0) >= 1 and ctx.fact("goals", 0) == 0,
        "headlines": [
            "{scoreline}: asisti {last_name} yaptı",
            "{score} — golü atan değil, pası veren konuşuldu",
            "{player}'in ara pası maça damga vurdu: {scoreline}",
            "{scoreline}: {last_name} hazırladı",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['player']} skor tabelasına adını yazdıramadı "
                f"ama maçın en kritik anını o üretti: "
                f"{ctx.fact('assists')} asistle golün hazırlayıcısı oldu.",
                f"{s['scoreline']}. {s['player']}'in adı gol listesinde yok; asist "
                f"hanesinde ise {ctx.fact('assists')} rakamı duruyor.",
                f"Golü atan başkasıydı, hazırlayan {s['player']}. {s['scoreline']} biten "
                f"karşılaşmada oyuncunun hanesine {ctx.fact('assists')} asist yazıldı.",
            ]),
            rng.choice([
                "Asist istatistiği tribünde alkış toplamaz; teknik heyetin "
                "defterinde ise en çok yer kaplayan sütunlardan biridir.",
                f"{s['position']} bölgesinde topla oynama yüzdesi maç boyunca "
                f"yüksek kaldı.",
                f"{s['opponent']} savunması o tek pasa kadar hatasızdı.",
            ]),
            _tally_line(ctx),
        ],
        "effects": {"fame:overall": 0.9},
    },
    {
        "story_id": "mac-fark-galibiyeti",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 7,
        "cooldown_days": 0,
        "outlets": ("tribun-sesi", "spor-manset", "kulup-bulteni"),
        "applies": lambda ctx: ctx.fact("result") == "win" and ctx.fact("goal_diff", 0) >= 3,
        "headlines": [
            "{scoreline}: farklı ve net",
            "{score} — {team} rakibini geçti",
            "{scoreline}: bu bir mesajdı",
            "Fark galibiyeti: {scoreline}",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['team']}, {s['opponent']} karşısında maçı "
                f"erken kopardı ve farkı sonuna kadar korudu.",
                f"{s['scoreline']}. {s['team']} için rahat bir doksan dakikaydı: fark "
                f"erken açıldı, bir daha da kapanmadı.",
                f"{s['team']}, {s['opponent']} karşısında {s['score']} kazandı. Skorun bu "
                f"kadar açık olması, maçın hiçbir bölümünde tartışmalı "
                f"olmadığını gösteriyor.",
            ]),
            rng.choice([
                "Böyle skorlar bir maçın değil, bir dönemin özetidir.",
                f"{s['coach']}'un son yirmi dakikada kadroyu dinlendirmesi, "
                f"maçın erken bittiğinin en açık göstergesiydi.",
                "Deplasman tribününün son çeyrekte boşalması, skorun "
                "ağırlığını anlatıyor.",
            ]),
            _rank_line(ctx),
        ],
        "effects": {"fame:overall": 1.0},
    },
    {
        "story_id": "mac-golsuz-sonuc",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 6,
        "cooldown_days": 0,
        "outlets": ("lig-ajansi", "spor-manset"),
        "applies": lambda ctx: ctx.fact("goals", 0) == 0 and ctx.fact("assists", 0) == 0
        and ctx.fact("result") in ("win", "draw"),
        "headlines": [
            "{scoreline}: sessiz bir akşam",
            "{score} — skora katkı yok, mücadele var",
            "{scoreline}: {last_name} bu kez suskun",
            "{team} ve {opponent} arasında: {score}",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['player']} maç boyunca sahadaydı ancak "
                f"skor tabelasına katkı veremedi.",
                f"{s['scoreline']}. {s['player']} için sessiz bir akşamdı: ne gol, "
                f"ne asist, ama doksan dakika mücadele.",
                f"{s['team']} ile {s['opponent']} arasındaki maç {s['score']} bitti. "
                f"{s['player']}'in istatistik satırı bu akşam boş kaldı.",
            ]),
            rng.choice([
                f"{s['opponent']} savunması bölgeyi kalabalık tuttu; "
                f"alan bulmak kolay olmadı.",
                "Her maç gol atılmaz. Önemli olan pozisyona girmeye "
                "devam etmek.",
                f"{s['coach']}'un maç sonu değerlendirmesinde bireysel "
                f"performanslara girmemesi dikkat çekti.",
            ]),
            _form_line(ctx),
        ],
    },
    {
        # Coverage archetype, not colour. Without it a DRAW in which the
        # player scored one or two goals matches nothing here — hat-trick
        # needs three, `mac-golle-galibiyet` needs the win, `mac-asist`
        # needs goals == 0, `mac-golsuz-sonuc` needs no contribution at all
        # — and M2 would return an empty `news_created` for a response whose
        # contract promises the match report. tests/test_news_generation.py
        # walks the whole (result × goals × assists × goal_diff) grid to keep
        # that hole from reopening.
        "story_id": "mac-beraberlik-golu",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 7,
        "cooldown_days": 0,
        "outlets": ("spor-manset", "tribun-sesi", "lig-ajansi"),
        "applies": lambda ctx: ctx.fact("result") == "draw" and ctx.fact("goals", 0) >= 1,
        "headlines": [
            "{scoreline}: {last_name} attı, yetmedi",
            "{score} — bir puan, bir gol",
            "{player}'in golü {team}'i kurtardı: {scoreline}",
            "{scoreline}: paylaşılan puan, paylaşılmayan gol",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['player']} skora katkı verdi ancak "
                f"{s['team']} sahadan bir puanla ayrıldı.",
                f"{s['scoreline']}. {s['player']}'in golü {s['team']}'e bir puan "
                f"getirdi; üç puana yetmedi.",
                f"{s['team']} ile {s['opponent']} puanları paylaştı: {s['score']}. "
                f"{s['player']} skora katkı veren taraftaydı.",
            ]),
            rng.choice([
                f"{s['opponent']} karşısında alınan beraberlik, tabloya "
                f"bakıldığında kayıp mı kazanç mı, önümüzdeki haftalar "
                f"gösterecek.",
                "Gol atan bir futbolcu için beraberlik, kazanılmış bir "
                "maçtan çok kaçırılmış bir maç gibi hissedilir.",
                f"{s['coach']}'un maç sonunda oyuncularını uzun süre "
                f"sahada tuttuğu görüldü.",
            ]),
            _rank_line(ctx),
            _tally_line(ctx),
        ],
        "effects": {"fame:overall": 0.8},
    },
    {
        "story_id": "mac-agir-yenilgi",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 8,
        "cooldown_days": 0,
        "outlets": ("tribun-sesi", "magazin-ekspres", "spor-manset"),
        "applies": lambda ctx: ctx.fact("result") == "loss" and ctx.fact("goal_diff", 0) <= -3,
        "headlines": [
            "{scoreline}: ağır yenilgi",
            "{score} — bu akşam konuşulacak bir şey yok",
            "{team} dağıldı: {scoreline}",
            "{scoreline}: sorular yarın sabah başlıyor",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['team']}, {s['opponent']} karşısında sahada "
                f"neredeyse hiç var olamadı. Skorun büyüklüğü, oyunun "
                f"tamamını özetliyor.",
                f"{s['scoreline']}. {s['team']} adına anlatılacak pek bir şey yok: "
                f"maç ilk yarıda bitti, kalanı sadece oynandı.",
                f"{s['opponent']} karşısında alınan {s['score']} sonucu, {s['team']} "
                f"için sezonun en ağır akşamlarından biri oldu.",
            ]),
            rng.choice([
                "Böyle akşamlarda bireysel performans aramak anlamsız; "
                "kırılan şey takımın kendisi.",
                f"{s['coach']}'un maç sonu soyunma odasında uzun süre kaldığı "
                f"öğrenildi.",
                "Tribün, düdükle birlikte sahaya sırtını döndü.",
            ]),
            _rank_line(ctx) + " " + _form_line(ctx),
        ],
    },
    {
        "story_id": "mac-yenilgi-normal",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 6,
        "cooldown_days": 0,
        "outlets": ("lig-ajansi", "spor-manset", "tribun-sesi"),
        "applies": lambda ctx: ctx.fact("result") == "loss" and ctx.fact("goal_diff", 0) > -3,
        "headlines": [
            "{scoreline}: puan kaybı",
            "{score} — {team} eli boş döndü",
            "{scoreline}: kritik anlarda fark",
            "{team} {opponent} deplasmanından puansız: {score}",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['team']} maçın büyük bölümünde dengeyi "
                f"kurdu ancak sonucu değiştiremedi.",
                f"{s['scoreline']}. Aradaki fark tek bir pozisyondu ve {s['team']} onu "
                f"bulamayan taraf oldu.",
                f"{s['team']}, {s['opponent']} karşısında oyunda değil detayda kaybetti: "
                f"{s['score']}.",
            ]),
            rng.choice([
                "Bu skorlar genellikle tek bir anda belirlenir. Bu akşam da "
                "öyle oldu.",
                f"{s['player']} mücadelesini sürdürdü; "
                + _tally_line(ctx).lower(),
                f"{s['opponent']} kazandığı tek pozisyonu değerlendirdi. "
                f"Fark buydu.",
            ]),
            _rank_line(ctx),
        ],
    },
    {
        "story_id": "mac-kupa-turu",
        "category": "Maç",
        "triggers": ("match_played",),
        "weight": 7,
        "cooldown_days": 0,
        "outlets": ("spor-manset", "kulup-bulteni", "tribun-sesi"),
        "applies": lambda ctx: bool(ctx.fact("is_cup")),
        "headlines": [
            "Kupada {scoreline}",
            "{competition}: {scoreline}",
            "Eleme usulü affetmez: {score}",
            "{scoreline} — kupa gecesi",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['competition']} karşılaşmasında {s['scoreline']}. "
                f"Eleme usulü müsabakada geri dönüş şansı olmadığı için "
                f"her dakika ayrı ağırlık taşıdı.",
                f"{s['scoreline']}. {s['competition']} akşamında tur hesabı yapıldı; "
                f"tabloya değil, bir sonraki maça bakıldı.",
                f"Kupada {s['team']} ile {s['opponent']} karşı karşıya geldi ve maç "
                f"{s['score']} sonuçlandı. Eleme usulü hatayı affetmiyor.",
            ]),
            rng.choice([
                "Kupa maçları lig maçlarına benzemez: burada tabloya değil, "
                "bir sonraki tura bakılır.",
                f"{s['coach']}'un kadroda rotasyona gitmemesi, kupaya verilen "
                f"önemi gösteriyor.",
                f"{s['team']} taraftarı için kupa, ligden daha kısa ve daha "
                f"acımasız bir yol.",
            ]),
            _tally_line(ctx),
        ],
    },
    {
        "story_id": "mac-kadroda-yoktun",
        "category": "Maç",
        "triggers": ("match_missed",),
        "weight": 5,
        "cooldown_days": 0,
        "outlets": ("lig-ajansi", "spor-manset", "tribun-sesi"),
        "applies": lambda ctx: True,
        "headlines": [
            "{scoreline}: {last_name} kadroda yoktu",
            "{score} — {player} sahada değildi",
            "{team} {last_name}'siz oynadı: {scoreline}",
            "{scoreline}: bu maç onsuz geçti",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['scoreline']}. {s['player']} bu karşılaşmada forma giymedi; "
                f"maç sonucu puan durumuna işlendi ancak oyuncunun sezon "
                f"istatistiklerine hiçbir katkı yazılmadı.",
                f"{s['team']} bu maçı {s['player']}'siz oynadı ve karşılaşma "
                f"{s['score']} bitti. Oyuncunun karnesine bu akşamdan hiçbir "
                f"satır düşmedi.",
                f"{s['scoreline']}. {s['player']} tribündeydi. Puan tabloya yazıldı, "
                f"oyuncunun istatistiğine yazılmadı.",
            ]),
            rng.choice([
                "Kadroda yer almayan bir futbolcu için en zor an, "
                "maçı dışarıdan izlemek değil, ertesi günkü antrenmandır.",
                f"{s['coach']}'un tercihinin gerekçesi açıklanmadı.",
                "Bu tür maçlar sezon karnesinde görünmez; hafızada kalır.",
            ]),
            _rank_line(ctx),
        ],
    },
]


# ---------------------------------------------------------------------------
# ANALİZ — milestones, attribute jumps, streaks, table movement.
# ---------------------------------------------------------------------------

_ANALIZ = [
    {
        "story_id": "analiz-gol-kilometre-tasi",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 5,
        "cooldown_days": 14,
        "outlets": ("spor-manset", "lig-ajansi", "tribun-sesi"),
        "applies": lambda ctx: ctx.goals in (5, 10, 15, 20, 25),
        "headlines": [
            "{player} sezonun {goals}. golüne ulaştı",
            "{goals} gol: {last_name} için bir eşik",
            "Sayılar konuşuyor: {goals} gol, {appearances} maç",
            "{last_name}'in {goals} golü ne anlatıyor?",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']}, sezonun {s['goals']}. golüne ulaştı. "
                f"{s['appearances']} maçlık örneklemde bu, bir "
                f"{s['position']} için dikkat çekici bir oran.",
                f"{s['goals']} gol: {s['player']} sezonu {s['appearances']} maçta bu "
                f"rakama taşıdı ve {s['team']}'in en golcü ismi hâline geldi.",
                f"{s['team']} formasıyla {s['goals']}. golünü atan {s['player']}, "
                f"{s['league']}'de bu yaş grubundaki oyuncular arasında öne "
                f"çıkıyor.",
            ]),
            _rank_line(ctx) + " " + _form_line(ctx),
            rng.choice([
                "Bu tempoda sezon sonunda ulaşılacak rakam, kulübün son "
                "yıllardaki en iyi bireysel üretimlerinden biri olur.",
                "Gol sayısı tek başına bir oyuncuyu anlatmaz; ama "
                "anlatmadığını da kimse iddia edemez.",
                f"{s['coach']}'un oyuncuyu ceza sahasına daha yakın "
                f"konumlandırdığı gözleniyor.",
            ]),
        ],
        "effects": {"fame:overall": 1.2},
    },
    {
        "story_id": "analiz-mac-kilometre-tasi",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 14,
        "outlets": ("kulup-bulteni", "lig-ajansi", "spor-manset"),
        "applies": lambda ctx: ctx.appearances in (10, 20, 30, 50),
        "headlines": [
            "{player} {appearances}. maçına çıktı",
            "{appearances} maç: {last_name} için bir dönüm noktası",
            "{team} formasıyla {appearances}. kez",
            "Sayılarla {player}: {appearances} maç, {goals} gol",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['player']}, {s['team']} formasıyla {s['appearances']}. maçına "
                f"çıktı. Bu, {s['age']} yaşındaki oyuncunun profesyonel "
                f"kariyerinde önemli bir eşik.",
                f"{s['appearances']} maç: {s['player']}'in {s['team']} formasıyla "
                f"geldiği nokta bu. Rakamın kendisinden çok, kesintisiz "
                f"olması önemli.",
                f"{s['age']} yaşında {s['appearances']} profesyonel maç. {s['player']}'in "
                f"karnesi bu eşikte şöyle okunuyor: " + _tally_line(ctx).lower(),
            ]),
            _tally_line(ctx),
            rng.choice([
                "Süreklilik, genç oyuncularda yetenekten daha nadir bir "
                "özelliktir.",
                f"{s['coach']}'un rotasyonda oyuncuyu sabit tutması, "
                f"güvenin en somut göstergesi.",
                "Bir sonraki eşiğe kadar formu korumak, asıl sınav olacak.",
            ]),
        ],
        "effects": {"fame:overall": 0.5},
    },
    {
        "story_id": "analiz-nitelik-sicramasi",
        "category": "Analiz",
        "triggers": ("training",),
        "weight": 6,
        "cooldown_days": 8,
        "outlets": ("spor-manset", "lig-ajansi"),
        "applies": lambda ctx: ctx.fact("level_after", 0) > ctx.fact("level_before", 0),
        "headlines": [
            "Scout raporu: {player}'de gözle görülür sıçrama",
            "{last_name} bir kademe atladı",
            "Antrenman sahasından haber: {player} gelişiyor",
            "{team}'in gelişim raporunda {last_name}",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}'in gelişim eğrisinde belirgin bir sıçrama "
            f"kaydedildi. Kulübün performans birimi, oyuncunun "
            # `attribute_label` is the training item's own Turkish title
            # ("Şut"), not the raw attribute key ("shooting") — there is no
            # key->Turkish map on this side and a headline is the last place
            # to leak an English identifier.
            f"{ctx.fact('attribute_label') or 'ilgili'} başlığındaki seviyesinin "
            f"{ctx.fact('level_before', 0)}'den {ctx.fact('level_after', 0)}'e "
            f"yükseldiğini raporladı.",
            rng.choice([
                "Bu tür sıçramalar genellikle tek bir antrenmanın değil, "
                "haftalarca süren tekrarın sonucudur.",
                f"{s['coach']}'un bireysel çalışma programına verdiği önem, "
                f"karşılığını buluyor.",
                "Rakamın kendisi kadar, hangi yaşta elde edildiği önemli: "
                f"{s['age']}.",
            ]),
            _tally_line(ctx),
        ],
        "effects": {"fame:overall": 0.3},
    },
    {
        "story_id": "analiz-galibiyet-serisi",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 5,
        "cooldown_days": 12,
        "outlets": ("spor-manset", "tribun-sesi", "lig-ajansi"),
        "applies": lambda ctx: ctx.form["streak_kind"] == "W" and ctx.form["streak_len"] >= 3,
        "headlines": [
            "{team} üst üste kazanıyor",
            "Seri sürüyor: {team} yükselişte",
            "{rank}. sıra yetmez: {team}'in çıkışı",
            "{team}'in serisi nereye kadar?",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['team']} üst üste {ctx.form['streak_len']} maç kazandı. "
                f"Sezonun bu bölümünde yakalanan bu seri, tabloyu doğrudan "
                f"etkiliyor.",
                f"{s['team']} cephesinde {ctx.form['streak_len']} maçlık bir galibiyet "
                f"serisi var ve tabloda {s['rank']}. sıraya kadar yükselmiş "
                f"durumdalar.",
                f"Üst üste {ctx.form['streak_len']} galibiyet: {s['team']} sezonun en iyi "
                f"dönemini yaşıyor. Seriyi ayakta tutan şey skorlar değil, "
                f"skorların geliş biçimi.",
            ]),
            _rank_line(ctx),
            rng.choice([
                f"{s['player']} de bu dönemin öne çıkan isimlerinden: "
                + _tally_line(ctx).lower(),
                "Seriler biterken değil, sürerken yazılır. Biz de "
                "bunu yapıyoruz.",
                f"{s['coach']}'un ilk on birde değişikliğe gitmemesi, "
                f"kazanan takımın bozulmadığı klasik yaklaşımının sonucu.",
            ]),
        ],
    },
    {
        "story_id": "analiz-yenilgi-serisi",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 5,
        "cooldown_days": 12,
        "outlets": ("tribun-sesi", "spor-manset", "magazin-ekspres"),
        "applies": lambda ctx: ctx.form["streak_kind"] == "L" and ctx.form["streak_len"] >= 3,
        "headlines": [
            "{team}'de kötü gidiş sürüyor",
            "Üst üste yenilgi: {team} için alarm",
            "{rank}. sıra ve düşen grafik",
            "{team} nerede hata yapıyor?",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['team']} üst üste {ctx.form['streak_len']} maç kaybetti. "
                f"Kötü gidişin sebebi tek bir başlıkta toplanamıyor; "
                f"hem üretim hem savunma tarafında düşüş var.",
                f"{ctx.form['streak_len']} maçtır kazanamayan {s['team']}, tabloda "
                f"{s['rank']}. sıraya kadar geriledi. Seri kendi kendini "
                f"besleyen bir hâl aldı.",
                f"{s['team']} için üst üste {ctx.form['streak_len']}. yenilgi. Bu "
                f"uzunlukta bir seride mesele artık taktik değil, güven.",
            ]),
            _rank_line(ctx),
            rng.choice([
                f"{s['coach']}'un koltuğuyla ilgili sorular henüz "
                f"yüksek sesle sorulmuyor. Henüz.",
                f"{s['player']}'in bu dönemdeki katkısı da beklentinin "
                f"altında kaldı.",
                "Bu tür serileri kıran şey genellikle taktik değil, "
                "bir maçın son on dakikasıdır.",
            ]),
        ],
    },
    {
        "story_id": "analiz-siralama-yukselisi",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 4,
        "cooldown_days": 18,
        "outlets": ("spor-manset", "lig-ajansi", "tribun-sesi"),
        "applies": lambda ctx: (
            ctx.standings is not None
            and ctx.standings["played"] >= 4
            and ctx.rank <= max(3, ctx.standings["teams"] // 5)
        ),
        "headlines": [
            "{team} zirveye oynuyor: {rank}. sıra",
            "{league}'de {rank}. sıra ve yükselen beklenti",
            "Sezonun sürprizi {team}",
            "{rank}. sıra: artık tesadüf denemez",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['team']}, {s['league']} sıralamasında {s['rank']}. basamağa "
                f"yerleşti. Sezon başında bu tabloyu bekleyen çok azdı.",
                f"{ctx.standings['played']} maç sonunda {ctx.standings['points']} puan: "
                f"{s['team']} {s['league']} tablosunda {s['rank']}. sırada.",
                f"{s['league']}'in ilk sıralarında bu sezon alışılmadık bir isim var: "
                f"{s['team']}, {s['rank']}. basamakta.",
            ]),
            _rank_line(ctx) + " " + _form_line(ctx),
            rng.choice([
                f"{s['player']}'in katkısı bu tablonun görünen yüzlerinden: "
                + _tally_line(ctx).lower(),
                "Asıl soru, bu tempoyu sezonun ikinci yarısında "
                "sürdürüp sürdüremeyecekleri.",
                "Küçük bütçeli kadrolarda böyle dönemler, transfer "
                "dönemine kadar sürer.",
            ]),
        ],
    },
    {
        "story_id": "analiz-genc-oyuncu-raporu",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 3,
        "cooldown_days": 28,
        "outlets": ("spor-manset", "lig-ajansi"),
        "applies": lambda ctx: ctx.player["age"] <= 23 and ctx.appearances >= 5,
        "headlines": [
            "Genç oyuncu raporu: {player}",
            "{age} yaşında {appearances} maç: {last_name} dosyası",
            "{team}'in altyapıdan gelen değeri",
            "{player} nereye kadar gider?",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['age']} yaşındaki {s['player']}, bu sezon {s['appearances']} maçta "
                f"forma giydi. Bu yaş grubunda düzenli süre alan oyuncu sayısı "
                f"{s['league']}'de sanıldığından az.",
                f"{s['league']}'in genç oyuncu tablosunda {s['player']} dikkat çekiyor: "
                f"{s['age']} yaşında {s['appearances']} maç, {s['goals']} gol.",
                f"Bir {s['position']} için {s['age']} yaş, kariyerin hangi noktası? "
                f"{s['player']}'in bu sezonki {s['appearances']} maçlık dosyası "
                f"bu soruya cevap veriyor.",
            ]),
            _tally_line(ctx) + " " + _rank_line(ctx),
            rng.choice([
                "Gelişim eğrisinin en kritik dönemi, ilk düzenli sezondur. "
                "Bu sezon o sezon.",
                f"{s['coach']}'un genç oyuncularla çalışma konusundaki "
                f"sicili, bu dosyanın en güçlü tarafı.",
                "Üst kademeden gelen ilginin de bu rapordan bağımsız "
                "olmadığı açık.",
            ]),
        ],
        "effects": {"fame:overall": 0.4},
    },
    {
        # This used to be `analiz-sessiz-hafta`: `applies: True`, the
        # last-resort filler whose lede was the constant sentence "nothing
        # unusual happened". It printed 10 times in a 91-item feed — 11% of
        # everything the player read was an article announcing that there
        # was no article. An empty day is a better outcome than that, and
        # day_tick's own 0.45 chance gate already makes empty days legal.
        #
        # Kept rather than deleted, but rebuilt as a real weekly bulletin:
        # it now needs an actual table to report (`standings`) and at least
        # one played fixture, every paragraph is drawn from the day's own
        # numbers, and the cooldown tripled. It is the quietest voice in the
        # catalog, not its most frequent one.
        "story_id": "analiz-haftalik-bulten",
        "category": "Analiz",
        "triggers": ("day_tick",),
        "weight": 1,
        "cooldown_days": 30,
        "outlets": ("lig-ajansi", "spor-manset"),
        "applies": lambda ctx: ctx.standings is not None and ctx.form["played"] >= 1,
        "headlines": [
            "{league}'de {rank}. sıra: {team} tablosu",
            "Haftanın bülteni: {team}",
            "{team} {rank}. sırada, {goals} gollük katkı",
            "{team} için hafta ortası notları",
        ],
        "body": lambda ctx, s, rng: [
            rng.choice([
                f"{s['team']}, {s['league']} tablosunda {ctx.standings['played']} "
                f"maç sonunda {ctx.standings['points']} puanla {s['rank']}. sırada "
                f"bulunuyor.",
                f"{s['team']}'in son {ctx.form['played']} maçlık serisi "
                f"{'-'.join(ctx.form['results'])} şeklinde okunuyor; tabloda "
                f"{s['rank']}. sıradalar.",
                f"{s['league']} tablosunda {s['rank']}. basamakta bulunan "
                f"{s['team']}'te haftanın öne çıkan ismi yine {s['player']}: "
                + _tally_line(ctx).lower(),
                f"{s['player']}'in sezon karnesi bu hafta itibarıyla "
                f"{s['appearances']} maç, {s['goals']} gol, {s['assists']} asist. "
                f"{s['team']} ise {s['rank']}. sırada.",
            ]),
            rng.choice([
                _form_line(ctx) + " " + _rank_line(ctx),
                _rank_line(ctx) + " " + _tally_line(ctx),
                _form_line(ctx) + f" Oyuncunun kondisyonu {ctx.condition}/100.",
            ]),
        ],
    },
]


# ---------------------------------------------------------------------------
# DİYALOG — non-media R3 interactions. Rare and light on purpose: a
# conversation with your mother is not front-page news, and the trigger's
# own chance gate (domain/news.TRIGGER_CHANCE) already keeps most of them
# out of the paper.
# ---------------------------------------------------------------------------

_DIYALOG = [
    {
        "story_id": "diyalog-partner-goruntusu",
        "category": "Magazin",
        "triggers": ("dialogue",),
        "weight": 4,
        "cooldown_days": 14,
        "outlets": ("magazin-ekspres",),
        "applies": lambda ctx: ctx.fact("relationship_id") == "partner",
        "headlines": [
            "{player} ve {partner}: uzun bir telefon",
            "{partner} cephesinde hareketlilik",
            "{last_name}'in özel hayatı yine gündemde",
            "O konuşma ne hakkındaydı?",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']} ile {s['partner']} arasındaki ilişkinin seyri, "
            f"magazin gündeminin sabit maddelerinden biri olmayı sürdürüyor.",
            rng.choice([
                "Çiftin yakın çevresi konuya dair konuşmuyor. Biz de "
                "ısrar etmiyoruz — çok fazla.",
                f"{s['player']}'in maç temposu düşünüldüğünde, ilişkiyi "
                f"ayakta tutmanın kolay olmadığı ortada.",
                "Bu haberin kaynağı bir görgü tanığı. Kim olduğunu "
                "sormayın.",
            ]),
        ],
    },
    {
        "story_id": "diyalog-aile-ziyareti",
        "category": "Magazin",
        "triggers": ("dialogue",),
        "weight": 3,
        "cooldown_days": 20,
        "outlets": ("magazin-ekspres", "tribun-sesi"),
        "applies": lambda ctx: ctx.fact("relationship_id") == "family",
        "headlines": [
            "{player} memleketiyle bağını koruyor",
            "{mother} ile uzun bir görüşme",
            "{last_name}'in ailesi konuştu",
            "Kökler: {player}'in memleket bağı",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['player']}'in ailesiyle düzenli görüştüğü, memleketiyle "
            f"bağını sezon içinde de sürdürdüğü öğrenildi.",
            rng.choice([
                f"{s['mother']}'in oyuncunun her maçını takip ettiği biliniyor.",
                "Genç futbolcularda aile desteğinin performansa etkisi, "
                "kulüplerin psikolog raporlarında sık geçen bir başlık.",
                "Bu, magazin sayfalarında nadiren gördüğümüz türden "
                "sıkıcı ve güzel bir haber.",
            ]),
        ],
    },
    {
        "story_id": "diyalog-soyunma-odasi-sohbeti",
        "category": "Analiz",
        "triggers": ("dialogue",),
        "weight": 3,
        "cooldown_days": 18,
        "outlets": ("spor-manset", "tribun-sesi", "lig-ajansi"),
        "applies": lambda ctx: ctx.fact("relationship_id") in ("team", "coach"),
        "headlines": [
            "{team} tesislerinde uzun bir gün",
            "{coach} ve oyuncular: kapalı kapı ardında",
            "{captain} liderliğinde takım toplantısı",
            "Tesislerden yansıyanlar",
        ],
        "body": lambda ctx, s, rng: [
            f"{s['team']} tesislerinde antrenman sonrası yapılan görüşmelerin, "
            f"takımın son dönemdeki gidişatını masaya yatırdığı belirtiliyor.",
            rng.choice([
                f"{s['coach']}'un oyuncularla bireysel görüşme yapmayı "
                f"tercih ettiği biliniyor.",
                f"Kaptan {s['captain']}'in grup içindeki rolü, bu tür "
                f"dönemlerde daha görünür hâle geliyor.",
                "Toplantının içeriğine dair kulüpten bir bilgi paylaşılmadı.",
            ]),
            _form_line(ctx) + " " + _rank_line(ctx),
        ],
    },
]


STORIES = _TRANSFER + _ROPORTAJ + _MAGAZIN + _ILISKI + _YASAM + _MAC + _ANALIZ + _DIYALOG


# --- import-time validation (INV-28's discipline, applied to content) ------

from content import validate_stories  # noqa: E402 (after data, deliberate)

validate_stories(STORIES)

# The match-report rule from this file's _MAC header: FE opens exactly one
# item from M2's response, and that item has to answer "what was the
# score?" in its headline. Enforced here rather than in content/__init__.py
# because it is a rule about THESE archetypes, not about archetypes in
# general.
for _story in STORIES:
    if "match_played" in _story["triggers"] or "match_missed" in _story["triggers"]:
        for _headline in _story["headlines"]:
            assert "{score}" in _headline or "{scoreline}" in _headline, (
                f"{_story['story_id']}: a match headline must carry the result "
                f"({_headline!r} does not)"
            )

# A generator that can produce nothing on a given trigger is a silent
# feature outage. Every trigger needs at least one archetype pointing at it.
from content import TRIGGERS as _TRIGGERS  # noqa: E402

_covered = {t for s in STORIES for t in s["triggers"]}
assert _covered == _TRIGGERS, f"triggers with no story: {sorted(_TRIGGERS - _covered)}"

assert len(STORIES) >= 35, f"only {len(STORIES)} archetypes; the catalog needs at least 35"
