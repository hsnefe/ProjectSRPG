import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/calendar_screen.dart';
import 'package:project_srpg/screens/league_table_screen.dart';
import 'package:project_srpg/screens/lifestyle_screen.dart';
import 'package:project_srpg/screens/news_detail_screen.dart';
import 'package:project_srpg/screens/player_profile_screen.dart';
import 'package:project_srpg/screens/pre_match_screen.dart';
import 'package:project_srpg/screens/relationships_screen.dart';
import 'package:project_srpg/screens/settings_screen.dart';
import 'package:project_srpg/screens/training_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/date_labels.dart';
import 'package:project_srpg/widgets/expand_page_route.dart';
import 'package:project_srpg/widgets/lit_card.dart';
import 'package:project_srpg/widgets/month_calendar.dart';
import 'package:project_srpg/widgets/panel_states.dart';
import 'package:project_srpg/widgets/social_offer_modal.dart';
import 'package:project_srpg/widgets/news_style.dart';

class CareerCenterScreen extends StatefulWidget {
  const CareerCenterScreen({super.key, this.session});

  /// Maç sonu akışı (RequestScreen) yığında geri dönerken bu adı arar —
  /// uygulamada isimli route tablosu yok, tek tanımlayıcı `RouteSettings.name`.
  static const routeName = '/career-center';

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<CareerCenterScreen> createState() => _CareerCenterScreenState();
}

class _CareerCenterScreenState extends State<CareerCenterScreen> {
  late final CareerSession _session =
      widget.session ?? CareerSession.instance;
  late Future<api.CareerHub> _hubFuture;
  late Future<api.DayInfo> _dayFuture;
  bool _advancing = false;

  /// Akan takvimde şu an gösterilen tarih ve kaç gün ilerlendiği.
  String? _overlayDate;
  int _overlayDays = 0;

  /// Döngüyü iptal etmenin tek yolu: `await`ten dönen tur jetonun
  /// değiştiğini görür ve çıkar. Bayrak yerine jeton, çünkü kullanıcı
  /// durdurup hemen yeniden başlatabilir ve eski turun yeni koşuya
  /// karışmaması gerekir.
  int _advanceToken = 0;

  /// T1'in bildirdiği, cevap bekleyen teklifin kimliği (§6.3 D53).
  String? _pendingOfferId;

  @override
  void initState() {
    super.initState();
    _hubFuture = _loadHub();
    _dayFuture = _loadDay();
  }

  /// C3 · `GET /careers/{cid}` — tek çağrıda hub verisi (sonraki maç + puan
  /// durumu özeti + haber önizlemesi).
  Future<api.CareerHub> _loadHub() async {
    final careerId = await _session.resolve();
    return _session.client.hub(careerId);
  }

  /// T1 · `GET /careers/{cid}/day` — bugün: tarih, maç günü mü, bugünkü
  /// olaylar.
  Future<api.DayInfo> _loadDay() async {
    final careerId = await _session.resolve();
    final day = await _session.client.day(careerId);
    // T1 zaten bekleyen teklifi bildiriyor (§6.3); saklamak, "İlerle"nin
    // sunucunun 409'una yürümek yerine doğrudan teklifi açmasını sağlıyor.
    _pendingOfferId = day.pendingOfferId;
    return day;
  }

  /// T3 · `POST /careers/{cid}/advance` — günleri **tek tek** ilerletir ve
  /// arada küçük bir takvim gösterir (§6.3, D56).
  ///
  /// **Neden tek bir `next_event` çağrısı değil.** Sunucu bir çağrıda kırk
  /// gün ileri gidebilir; ekran üçüncü günü oynatırken "Durdur"a basıldığında
  /// takvim yalan söylerdi — durum çoktan ilerlemiş olurdu. Gün gün gidince
  /// ekrandaki tarih ile `career_state.game_date` her karede aynı sayıdır.
  /// Durma ölçütü yine sunucuda kalır: döngünün çıkış testi yalnızca
  /// `stopReason != 'none'`, hangi olayın durdurucu olduğuna Dart karar
  /// vermez (§6.3).
  ///
  /// İptal edildiğinde uçuştaki gün yine de commit olur; bu doğru davranış —
  /// o gün gerçekten yaşandı.
  Future<void> _advance() async {
    final player = PlayerScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // (a) Açık bir teklif varken zaman ilerlemez. BE kapıda 409 atıyor
    // zaten; buradan bakmak kullanıcıya hata yerine teklifin kendisini
    // göstermek için (§6.3 D53).
    final pending = _pendingOfferId;
    if (pending != null) {
      await _openOffer(pending);
      return;
    }

    final token = ++_advanceToken;
    setState(() {
      _advancing = true;
      _overlayDays = 0;
      _overlayDate = null;
    });

    api.AdvanceResult? last;
    var serverPendingOffer = false;
    try {
      final careerId = await _session.resolve();
      while (mounted && token == _advanceToken && _overlayDays < _maxLoopDays) {
        final result = await _session.client.advance(careerId, to: 'next_day');
        if (!mounted || token != _advanceToken) break;

        // Her gün ayrı ayrı yansıtılır — PlayerState bir ChangeNotifier,
        // yani para ve kondisyon çubuğu takvimle birlikte akar.
        player.applyServerUpdate(careerState: result.careerState);
        last = result;
        setState(() {
          _overlayDate = result.stoppedOn;
          _overlayDays++;
        });

        if (result.stopReason != 'none') break;
        await Future<void>.delayed(_advanceTick);
      }
    } on CareerApiException catch (e) {
      // Sezon sonu döngünün ortasında gelebilir; o âna kadar ilerlenen
      // günler gerçekten yaşandı, geri alınmaz.
      //
      // (c) `social_offer_pending` sunucunun arka kapısıdır: uygulama teklif
      // ekrandayken kapanmışsa T1 önbelleği bilmiyordur, ama BE bilir.
      if (mounted && token == _advanceToken) {
        if (e.code == 'social_offer_pending') {
          serverPendingOffer = true;
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(e.message ?? 'Gün ilerletilemedi.')),
          );
        }
      }
    } finally {
      if (mounted && token == _advanceToken) {
        _finishAdvance();
      }
    }

    if (!mounted || token != _advanceToken) return;
    if (serverPendingOffer) {
      await _openOffer();
      return;
    }
    if (last == null) return;

    // (b) Döngü bir teklifte durdu; `stopped_events` kimliği taşıyor, yani
    // hangi teklifin açılacağını öğrenmek için T1'i yeniden çağırmak gerekmez.
    final offerId = last.stopReason == 'social_offer' ? last.stoppedOfferId : null;
    if (offerId != null) {
      await _openOffer(offerId);
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(_advanceSummary(last))));
  }

  /// R4 ile teklifi çeker ve kapatılamayan modalı açar (§5.4, D53).
  ///
  /// [offerId] null ise **açık olan** teklif alınır. Sunucunun
  /// `social_offer_pending` arka kapısı bu biçimi kullanır: orada elimizde
  /// bir kimlik yok, yalnızca "bir teklif var" bilgisi.
  ///
  /// Kayıt bulunamazsa (teklif başka bir yerde cevaplanmış olabilir) sessizce
  /// gün verisi tazelenir — açılamayan bir modalın hatası kullanıcının
  /// çözebileceği bir şey değil.
  Future<void> _openOffer([String? offerId]) async {
    final messenger = ScaffoldMessenger.of(context);
    final player = PlayerScope.of(context);
    try {
      final careerId = await _session.resolve();
      final offers = await _session.client.socialOffers(careerId);
      final matching = offerId == null
          ? offers
          : offers.where((o) => o.offerId == offerId).toList(growable: false);
      final offer = matching.isEmpty ? null : matching.first;
      if (!mounted) return;
      if (offer == null) {
        setState(() {
          _pendingOfferId = null;
          _dayFuture = _loadDay();
        });
        return;
      }

      final result = await showSocialOfferModal(
        context,
        session: _session,
        offer: offer,
      );
      if (!mounted || result == null) return;

      player.applyServerUpdate(
        careerState: result.careerState,
        attributeChanges: result.attributeChanges,
      );
      setState(() {
        _pendingOfferId = null;
        _hubFuture = _loadHub();
        _dayFuture = _loadDay();
      });
      messenger.showSnackBar(SnackBar(content: Text(_offerSummary(result))));
    } on CareerApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Teklif açılamadı.')),
      );
    }
  }

  /// 'Antrenör +5' — BE `delta` gönderir, cümleyi ekran kurar (§1.3).
  String _offerSummary(api.SocialOfferResult result) {
    final changes = result.relationshipChanges;
    final change = changes.isEmpty ? null : changes.first;
    final name = result.offer.relationship?.category ?? 'İlişki';
    if (change == null) return 'Teklif yanıtlandı.';
    final sign = change.delta >= 0 ? '+' : '';
    return '$name $sign${change.delta}';
  }

  /// Kullanıcı akan takvimi durdurur. Döngü `await`ten döndüğünde jetonun
  /// değiştiğini görür ve çıkar; uçuştaki gün yine de commit olur.
  void _stopAdvance() {
    _advanceToken++;
    _finishAdvance();
  }

  /// Overlay'i kapatıp hub/gün verisini bir kez tazeler. Döngünün **içinde**
  /// tazelemek gün başına iki fazla çağrı demekti; geçilen günlerin toplam
  /// etkisi zaten sonda okunuyor.
  void _finishAdvance() {
    setState(() {
      _advancing = false;
      _overlayDate = null;
      _hubFuture = _loadHub();
      _dayFuture = _loadDay();
    });
  }

  String _advanceSummary(api.AdvanceResult result) {
    final base = '$_overlayDays gün ilerledi';
    final reason = _dayEventLabels[result.stopReason];
    return reason == null ? '$base.' : '$base — $reason.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      ListView(
                        children: [
                          const _HeaderSection(),
                          const _ProgressSection(),
                          FutureBuilder<api.DayInfo>(
                            future: _dayFuture,
                              builder: (context, snapshot) => _DaySection(
                              snapshot: snapshot,
                              busy: _advancing,
                              onAdvance: _advancing ? _stopAdvance : _advance,
                              onOpenOffer: _openOffer,
                            ),
                          ),
                          FutureBuilder<api.CareerHub>(
                            future: _hubFuture,
                            builder: (context, snapshot) => Column(
                              children: _hubDependentSections(snapshot),
                            ),
                          ),
                          const _ActionsSection(),
                        ],
                      ),
                      // Akan takvim, `showDialog` yerine aynı ağaçta bir
                      // katman: diyalog route'u olsaydı durdurma butonu ayrı
                      // bir yüzeyde kalırdı ve hub'ın kendi butonunu ele
                      // geçirirdi. Burada tek bir setState kapsamı var.
                      if (_advancing)
                        Positioned.fill(
                          child: _AdvanceOverlay(
                            date: _overlayDate,
                            days: _overlayDays,
                            onStop: _stopAdvance,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _hubDependentSections(AsyncSnapshot<api.CareerHub> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ];
    }
    if (snapshot.hasError) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Kariyer verisi alınamadı.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ];
    }
    final hub = snapshot.data!;
    return [
      _MatchPreviewSection(nextFixture: hub.nextFixture),
      _NewsSection(newsPreview: hub.newsPreview, session: _session),
    ];
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar + isim bloğu tek dokunulabilir birim: oyuncu profilini
          // açar. Bakiye de bu bloğun içinde olduğu için ona basmak da
          // profili açıyor — kimlik alanının parçası, kabul edilebilir.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PlayerProfileScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accentBg,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      player.initials,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                player.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              player.moneyLabel,
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${player.position} · ${player.teamName}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalendarScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: const CircleBorder(),
            ),
            icon: const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LeagueTableScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: const CircleBorder(),
            ),
            icon: const Icon(
              Icons.emoji_events_outlined,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.settings_outlined,
              size: 20,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context) {
    final condition = PlayerScope.of(context).condition;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LitCard(
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Kondisyon',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '%$condition',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: condition / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.surface1,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// T1 `events[].kind` / T3 `stop_reason` — cümle gönderilmez, ekran kendi
/// metnini kurar (§1.3, §5.5). `'none'` (T3'ün "hiçbir olay yok" durumu)
/// bilinçli olarak haritada yok — çağıran taraf onu null'a eşler.
/// `social_offer` de yok: onun kendi dokunulabilir satırı var (§6.3 D53),
/// buradan da yazılsaydı aynı şey iki kez görünürdü.
/// İki gün arasındaki bekleme — takvimin akışı okunacak kadar yavaş,
/// bir haftayı beklemek can sıkacak kadar hızlı.
const _advanceTick = Duration(milliseconds: 220);

/// Güvenlik tavanı, BE'nin `MAX_ADVANCE_DAYS`'inin FE aynası: sunucu hiç
/// durmasa bile döngü sonsuza kadar koşmaz.
const _maxLoopDays = 60;

const _dayEventLabels = {
  'match': 'maç günü',
  'cup_draw': 'kupa kurası',
  'contract_expiring': 'sözleşme bitiyor',
  'upkeep_warning': 'gider uyarısı',
  'relationship_low': 'ilişki düşük',
  'season_end': 'sezon sonu',
};

/// T1 (bugünün durumu, salt gösterim) + T3 (`İlerle` butonu) — kariyerin
/// tek zaman kaynağı burada ilerler (§6.1). Uçlar arasındaki fark: T1 hiçbir
/// şeyi değiştirmez, yalnızca okur; ilerlemeyi tek başına T3 yapar.
/// Bugünün maç dışı olayları, tekrarsız ve ekranın kendi diliyle.
List<String> _otherEventLabels(api.DayInfo? day) {
  if (day == null) return const [];
  final labels = <String>{};
  for (final event in day.events) {
    if (event.kind == 'match') continue;  // üstteki "Maç günü" satırı
    final label = _dayEventLabels[event.kind];
    if (label != null) labels.add(label);
  }
  return labels.toList(growable: false);
}

/// Akan takvim: "İlerle"ye basıldığında hub'ın üstüne binen küçük ay
/// görünümü. Günler tek tek geçtikçe vurgulanan hücre ilerler.
///
/// İşaret taşımaz — hangi günün maç olduğunu göstermek burada gereksiz;
/// akış zaten o günde duracak. Boş grid, geçen zamanın kendisini gösterir.
class _AdvanceOverlay extends StatelessWidget {
  const _AdvanceOverlay({
    required this.date,
    required this.days,
    required this.onStop,
  });

  /// Şu an işlenen gün ('YYYY-MM-DD'); ilk çağrı dönene kadar null.
  final String? date;
  final int days;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final parsed = date == null ? null : DateTime.tryParse(date!);

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: LitCard(
            borderRadius: 14,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    parsed == null ? 'Günler ilerliyor' : monthYearLabel(parsed),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (parsed != null)
                    MonthCalendar(
                      month: parsed,
                      marksByDate: const {},
                      today: date,
                      compact: true,
                    )
                  else
                    const SizedBox(
                      height: 90,
                      child: CenteredSpinner(),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    date == null ? '' : fullDateLabel(date!),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    days == 1 ? '1 gün' : '$days gün',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: onStop,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Durdur'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.snapshot,
    required this.busy,
    required this.onAdvance,
    required this.onOpenOffer,
  });

  final AsyncSnapshot<api.DayInfo> snapshot;
  final bool busy;
  final VoidCallback onAdvance;

  /// Bekleyen teklifi yeniden açar — modal kapatılamaz ama kullanıcı
  /// uygulamayı kapatıp dönmüş olabilir (§6.3 D53).
  final ValueChanged<String> onOpenOffer;

  @override
  Widget build(BuildContext context) {
    final day = snapshot.data;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LitCard(
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day == null
                          ? 'Bugün'
                          : fullDateLabel(day.careerState.currentDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (day != null && day.isMatchDay) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Maç günü',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    // T1 `events[]` — BE `kind` gönderir, cümleyi ekran
                    // kurar (§5.5). Maç zaten üstteki satırda.
                    for (final label in _otherEventLabels(day)) ...[
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (day?.pendingOfferId case final offerId?) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        key: const ValueKey('daySocialOffer'),
                        onTap: () => onOpenOffer(offerId),
                        child: const Text(
                          'Sosyal teklif bekliyor →',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              OutlinedButton(
                // Koşarken devre dışı DEĞİL: aynı buton durdurma butonudur
                // (§6.3 D56). Kullanıcının akan takvimi kesmesinin iki yolu
                // var, biri burası, diğeri overlay'in kendi butonu.
                onPressed: onAdvance,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  disabledForegroundColor: AppColors.textMuted,
                  side: const BorderSide(color: AppColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: busy
                    ? const Text('Durdur')
                    : const Text('İlerle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// C3 `next_fixture.days_until` — sayı BE'den, cümle FE'den (§1.3).
String _countdownLabel(int daysUntil) {
  if (daysUntil <= 0) return 'bugün';
  if (daysUntil == 1) return 'yarın';
  return '$daysUntil gün sonra';
}

class _MatchPreviewSection extends StatefulWidget {
  const _MatchPreviewSection({required this.nextFixture});

  final api.NextFixtureSummary? nextFixture;

  @override
  State<_MatchPreviewSection> createState() => _MatchPreviewSectionState();
}

class _MatchPreviewSectionState extends State<_MatchPreviewSection> {
  final _cardKey = GlobalKey();

  /// §6.1 — maç yalnızca kendi gününde oynanır. Maç günü değilse kart maç
  /// ekranını açmaz: kullanıcıyı "İlerle"nin durduğu yerde, kariyer
  /// merkezinde tutar.
  void _onCardTap() {
    final daysUntil = widget.nextFixture?.daysUntil ?? 0;
    if (daysUntil > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maça $daysUntil gün var — günleri ilerlet.')),
      );
      return;
    }
    _openMatchDetail();
  }

  void _openMatchDetail() {
    final renderBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;

    Navigator.of(context).push(
      ExpandPageRoute<void>(
        rect: rect,
        page: PreMatchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixture = widget.nextFixture;
    // C3'te sezon bittiyse `next_fixture` null döner (§5.1).
    if (fixture == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: LitCard(
          minHeight: 96,
          child: Center(
            child: Text(
              'Sıradaki maç bilgisi yok.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: LitCard(
        key: _cardKey,
        onTap: _onCardTap,
        minHeight: 210,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    'SONRAKİ MAÇ',
                    style: TextStyle(
                      color:
                          AppColors.accent.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    kickoffDayLabelFrom(fixture.kickoffAt),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fixture.competition.name} · ${_countdownLabel(fixture.daysUntil)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TeamBadge(team: fixture.home),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'vs',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _TeamBadge(team: fixture.away),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        AppColors.success.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppColors.success.withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Text(
                  'İlk 11',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D17: takımın kimlik renkleri BE'den ham gelir — rozet ikisini de gösterir
/// (dolgu birincil, kenarlık ikincil), league_table_screen'deki `_TeamDot`
/// ile aynı kural.
class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team});

  final api.TeamRef team;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: team.colorPrimary,
            shape: BoxShape.circle,
            border: Border.all(color: team.colorSecondary, width: 2),
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          team.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.newsPreview, required this.session});

  final List<api.NewsPreviewItem> newsPreview;
  final CareerSession session;

  @override
  Widget build(BuildContext context) {
    if (newsPreview.isEmpty) return const SizedBox.shrink();
    final item = newsPreview.first;
    final tint = tintForNewsCategory(item.category);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LitCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NewsDetailScreen(
                newsIds: [for (final n in newsPreview) n.newsId],
                initialIndex: 0,
                session: session,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: Stack(
                children: [
                  // Detay ekranındaki hero ile aynı ton ve ikon: liste kartı ile
                  // açılan haber aynı şeye benziyor.
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                tint.withValues(alpha: 0.55),
                                tint.withValues(alpha: 0.22),
                                AppColors.surface0.withValues(alpha: 0.92),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          right: -12,
                          top: -12,
                          child: Icon(
                            iconForNewsCategory(item.category),
                            size: 96,
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: tint.withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          color: tint,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.source} · ${newsTimeAgo(item.publishedAt)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.people_outline,
                  label: 'İlişkiler',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RelationshipsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.fitness_center,
                  label: 'Antrenman',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TrainingScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              icon: Icons.home_outlined,
              label: 'Yaşam tarzı',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LifestyleScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LitCard(
      onTap: onPressed,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
