import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/league_table_screen.dart';
import 'package:project_srpg/screens/lifestyle_screen.dart';
import 'package:project_srpg/screens/news_detail_screen.dart';
import 'package:project_srpg/screens/player_profile_screen.dart';
import 'package:project_srpg/screens/pre_match_screen.dart';
import 'package:project_srpg/screens/relationships_screen.dart';
import 'package:project_srpg/screens/settings_screen.dart';
import 'package:project_srpg/screens/training_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/expand_page_route.dart';
import 'package:project_srpg/widgets/news_style.dart';

class CareerCenterScreen extends StatefulWidget {
  const CareerCenterScreen({super.key, this.session});

  /// Maç sonu akışı (RequestScreen) yığında geri dönerken bu adı arar —
  /// uygulamada isimli route tablosu yok, tek tanımlayıcı `RouteSettings.name`.
  static const routeName = '/career-center';

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _accentBg = Color(0x33228BFF);
  static const _success = Color(0xFF3DDC97);
  static const _successBg = Color(0x333DDC97);

  @override
  State<CareerCenterScreen> createState() => _CareerCenterScreenState();
}

class _CareerCenterScreenState extends State<CareerCenterScreen> {
  late final CareerSession _session =
      widget.session ?? CareerSession.instance;
  late Future<api.CareerHub> _hubFuture;
  late Future<api.DayInfo> _dayFuture;
  bool _advancing = false;

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
    return _session.client.day(careerId);
  }

  /// T3 · `POST /careers/{cid}/advance` — bir sonraki olaylı güne kadar
  /// ilerler (§6.3). Gün ve hub verisi bu yüzden birlikte tazelenir: yeni
  /// fikstürler koşmuş, haberler oluşmuş olabilir.
  Future<void> _advance() async {
    setState(() => _advancing = true);
    final player = PlayerScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final careerId = await _session.resolve();
      final result =
          await _session.client.advance(careerId, to: 'next_event');
      player.applyServerUpdate(careerState: result.careerState);
      if (!mounted) return;
      setState(() {
        _hubFuture = _loadHub();
        _dayFuture = _loadDay();
        _advancing = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(_advanceSummary(result))));
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() => _advancing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Gün ilerletilemedi.')),
      );
    }
  }

  String _advanceSummary(api.AdvanceResult result) {
    final base = '${result.daysAdvanced} gün ilerledi';
    final reason = _dayEventLabels[result.stopReason];
    return reason == null ? '$base.' : '$base — $reason.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareerCenterScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CareerCenterScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CareerCenterScreen._border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView(
                    children: [
                      const _HeaderSection(),
                      const _ProgressSection(),
                      FutureBuilder<api.DayInfo>(
                        future: _dayFuture,
                        builder: (context, snapshot) => _DaySection(
                          snapshot: snapshot,
                          busy: _advancing,
                          onAdvance: _advance,
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
                color: CareerCenterScreen._textMuted,
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
                color: CareerCenterScreen._textMuted,
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
            color: CareerCenterScreen._border,
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
                      color: CareerCenterScreen._accentBg,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      player.initials,
                      style: const TextStyle(
                        color: CareerCenterScreen._accent,
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
                                  color: CareerCenterScreen._textPrimary,
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
                                color: CareerCenterScreen._success,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${player.position} · ${player.teamName}',
                          style: const TextStyle(
                            color: CareerCenterScreen._textSecondary,
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
                  builder: (_) => const LeagueTableScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              side: const BorderSide(color: CareerCenterScreen._border),
              shape: const CircleBorder(),
            ),
            icon: const Icon(
              Icons.emoji_events_outlined,
              size: 18,
              color: CareerCenterScreen._textPrimary,
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
              color: CareerCenterScreen._textMuted,
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
      child: _LitCard(
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
                      color: CareerCenterScreen._textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '%$condition',
                    style: const TextStyle(
                      color: CareerCenterScreen._textPrimary,
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
                  backgroundColor: CareerCenterScreen._surface1,
                  color: CareerCenterScreen._success,
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
const _dayEventLabels = {
  'match': 'maç günü',
  'cup_draw': 'kupa kurası',
  'contract_expiring': 'sözleşme bitiyor',
  'upkeep_warning': 'gider uyarısı',
  'relationship_low': 'ilişki düşük',
  'season_end': 'sezon sonu',
};

const _dayMonths = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

/// 'YYYY-MM-DD' → '19 Ağustos 2026' — tarih bileşeni yalnız (saat yok), bu
/// yüzden `career_center_screen.dart`'ın kickoff yardımcısındaki UTC
/// dönüşümü sorunu burada yok (§1.3).
String _fullDateLabel(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  return '${date.day} ${_dayMonths[date.month - 1]} ${date.year}';
}

/// T1 (bugünün durumu, salt gösterim) + T3 (`İlerle` butonu) — kariyerin
/// tek zaman kaynağı burada ilerler (§6.1). Uçlar arasındaki fark: T1 hiçbir
/// şeyi değiştirmez, yalnızca okur; ilerlemeyi tek başına T3 yapar.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.snapshot,
    required this.busy,
    required this.onAdvance,
  });

  final AsyncSnapshot<api.DayInfo> snapshot;
  final bool busy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final day = snapshot.data;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _LitCard(
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
                          : _fullDateLabel(day.careerState.currentDate),
                      style: const TextStyle(
                        color: CareerCenterScreen._textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (day != null && day.isMatchDay) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Maç günü',
                        style: TextStyle(
                          color: CareerCenterScreen._success,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: busy ? null : onAdvance,
                style: OutlinedButton.styleFrom(
                  foregroundColor: CareerCenterScreen._textPrimary,
                  disabledForegroundColor: CareerCenterScreen._textMuted,
                  side: const BorderSide(color: CareerCenterScreen._border),
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
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CareerCenterScreen._textMuted,
                        ),
                      )
                    : const Text('İlerle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LitCard extends StatelessWidget {
  const _LitCard({
    super.key,
    required this.child,
    this.onTap,
    this.minHeight,
    this.borderRadius = 16,
  });

  static const _cardTop = Color(0xFF2E3440);
  static const _cardMid = Color(0xFF252932);
  static const _cardBottom = Color(0xFF181C23);

  final Widget child;
  final VoidCallback? onTap;
  final double? minHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final innerRadius = borderRadius - 1;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: CareerCenterScreen._accent.withValues(alpha: 0.22),
            blurRadius: 48,
            spreadRadius: -10,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.06),
              Colors.black.withValues(alpha: 0.35),
            ],
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: Container(
          constraints:
              minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_cardTop, _cardMid, _cardBottom],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.42),
                        Colors.white.withValues(alpha: 0.42),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                bottom: 14,
                left: 0,
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(innerRadius),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return card;

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

const _matchWeekdays = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

/// '2026-03-16T20:00:00+03:00' → 'Pazartesi, 20:00' — §1.3: BE `kickoff_at`
/// verir, gösterime hazır cümleyi ekran kurar.
///
/// `DateTime.parse` bir ofset gördüğünde UTC'ye çevirir ve `isUtc = true`
/// işaretler (§9.2 `.hour`/`.weekday` artık UTC alanlarıdır, dizedeki saat
/// değil). Sözleşme tek saat dilimi kullandığı için (+03:00, §5.0) UTC'den
/// geri +3 saat eklemek dizedeki gerçek duvar saatini verir — cihazın kendi
/// yerel dilimi hiç devreye girmez.
String _matchDayLabel(String isoDateTime) {
  final parsed = DateTime.tryParse(isoDateTime);
  if (parsed == null) return isoDateTime;
  final kickoff = parsed.isUtc ? parsed.add(const Duration(hours: 3)) : parsed;
  final weekday = _matchWeekdays[kickoff.weekday - 1];
  final hh = kickoff.hour.toString().padLeft(2, '0');
  final mm = kickoff.minute.toString().padLeft(2, '0');
  return '$weekday, $hh:$mm';
}

class _MatchPreviewSection extends StatefulWidget {
  const _MatchPreviewSection({required this.nextFixture});

  final api.NextFixtureSummary? nextFixture;

  @override
  State<_MatchPreviewSection> createState() => _MatchPreviewSectionState();
}

class _MatchPreviewSectionState extends State<_MatchPreviewSection> {
  final _cardKey = GlobalKey();

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
        child: _LitCard(
          minHeight: 96,
          child: Center(
            child: Text(
              'Sıradaki maç bilgisi yok.',
              style: TextStyle(
                color: CareerCenterScreen._textMuted,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: _LitCard(
        key: _cardKey,
        onTap: _openMatchDetail,
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
                          CareerCenterScreen._accent.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _matchDayLabel(fixture.kickoffAt),
                    style: const TextStyle(
                      color: CareerCenterScreen._textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fixture.competition.name,
                    style: const TextStyle(
                      color: CareerCenterScreen._textSecondary,
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
                        color: CareerCenterScreen._textMuted,
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
                  color: CareerCenterScreen._successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        CareerCenterScreen._success.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          CareerCenterScreen._success.withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Text(
                  'İlk 11',
                  style: TextStyle(
                    color: CareerCenterScreen._success,
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
            color: CareerCenterScreen._textPrimary,
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
      child: _LitCard(
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
                                const Color(0xFF12151B).withValues(alpha: 0.92),
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
                      color: CareerCenterScreen._textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.source} · ${newsTimeAgo(item.publishedAt)}',
                    style: const TextStyle(
                      color: CareerCenterScreen._textMuted,
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
    return _LitCard(
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
              color: CareerCenterScreen._textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: CareerCenterScreen._textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
