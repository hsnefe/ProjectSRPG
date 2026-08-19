import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/screens/match_screen.dart';
import 'package:project_srpg/state/match_controller.dart';
import 'package:project_srpg/state/player_scope.dart';

const _weekdayLabels = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// `DateTime.parse` bir ofset gördüğünde UTC'ye çevirir (`isUtc = true`);
/// `.hour`/`.weekday` o zaman dizedeki saat değil UTC saatini okur. Kariyer
/// dünyası tek saat dilimi kullandığı için (+03:00, career_engine CONTRACT.md
/// §5.0) `.toLocal()` cihazın kendi dilimine göre yanlış saat üretebilirdi —
/// bunun yerine UTC'den +3 saat geri eklemek dizedeki gerçek duvar saatini
/// verir, career_center_screen.dart'ın aynı sorunla aynı çözümü (bkz.
/// `_matchDayLabel`).
String _kickoffLabel(DateTime kickoffAt) {
  final local = kickoffAt.isUtc
      ? kickoffAt.add(const Duration(hours: 3))
      : kickoffAt;
  final weekday = _weekdayLabels[local.weekday - 1];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$weekday, $hh:$mm';
}

class PreMatchScreen extends StatefulWidget {
  PreMatchScreen({super.key, this.session, MatchApiClient? matchApiClient})
      : _matchApiClient = matchApiClient ?? MatchApiClient();

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;
  final MatchApiClient _matchApiClient;

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _success = Color(0xFF3DDC97);
  static const _danger = Color(0xFFE85D5D);

  @override
  State<PreMatchScreen> createState() => _PreMatchScreenState();
}

class _PreMatchScreenState extends State<PreMatchScreen> {
  MatchApiClient get _apiClient => widget._matchApiClient;
  late final CareerSession _careerSession =
      widget.session ?? CareerSession.instance;

  NextMatchResponse? _next;
  String? _fixtureId;
  int? _preMatchCondition;
  String? _loadError;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  /// M1 (career_engine) → E11 (match_engine) köprüsü (D7, D33). Kariyerin
  /// gerçek fikstürü career_engine'den alınır, `engine_payload` olduğu gibi
  /// motora POST'lanır — FE ikisini birbirine bağlayan tek taraf (D3/D33).
  Future<void> _loadNext() async {
    setState(() {
      _loadError = null;
      _next = null;
    });
    try {
      final careerId = await _careerSession.resolve();
      final careerMatch = await _fetchNextWithRecovery(careerId);
      final created = await _apiClient.createMatch(careerMatch.enginePayload);
      if (!mounted) return;
      setState(() {
        _fixtureId = careerMatch.fixtureId;
        _preMatchCondition =
            careerMatch.enginePayload['user_condition'] as int?;
        // E11'in kendi kickoff_at'i motorun dolgu değeri (§8.1a) — gösterimde
        // career_engine'in gerçek fikstür saatini kullanıyoruz.
        _next = NextMatchResponse(
          matchId: created.matchId,
          kickoffAt: DateTime.parse(careerMatch.kickoffAt),
          userSide: created.userSide,
          teams: created.teams,
          teamTactic: created.teamTactic,
          stamina: created.stamina,
          directiveOptions: created.directiveOptions,
          defaults: created.defaults,
        );
      });
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message ?? 'Maç bilgisi alınamadı.');
    } on MatchApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message ?? 'Maç bilgisi alınamadı.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Maç bilgisi alınamadı.');
    }
  }

  /// §6.4 — M1 `409 match_in_progress` dönerse motor oturumu muhtemelen
  /// kaybolmuştur (uygulama maç bitmeden kapanmış olabilir). FE'nin bilmediği
  /// bir sonucu var-mış gibi davranamayacağı için tek güvenli yol M3 ile
  /// fikstürü `scheduled`'a döndürüp yeniden istemek.
  Future<NextCareerMatch> _fetchNextWithRecovery(String careerId) async {
    try {
      return await _careerSession.client.nextMatch(careerId);
    } on CareerApiException catch (e) {
      if (e.code != 'match_in_progress') rethrow;
      // errors.match_in_progress() (career_engine/api/errors.py) yalnızca
      // insan-okur bir cümle döner, ayrı bir `fixture_id` alanı yok — id'yi
      // "fixture '<id>' has an unfinished match" kalıbından çıkarıyoruz.
      final match = RegExp(r"fixture '([^']+)'").firstMatch(e.message ?? '');
      final staleFixtureId = match?.group(1);
      if (staleFixtureId == null) rethrow;
      await _careerSession.client.abandonMatch(careerId, staleFixtureId);
      return _careerSession.client.nextMatch(careerId);
    }
  }

  Future<void> _startMatch() async {
    final next = _next;
    final fixtureId = _fixtureId;
    if (next == null || fixtureId == null || _starting) return;
    setState(() => _starting = true);
    try {
      final start = await _apiClient.startMatch(
        next.matchId,
        userSide: next.userSide,
        effort: next.defaults.effort,
        aggression: next.defaults.aggression,
        focus: next.defaults.focus,
      );
      if (!mounted) return;
      final controller = MatchController(
        matchId: start.matchId,
        streamUrl: start.streamUrl,
        userSide: next.userSide,
        teams: next.teams,
        staminaCatalog: next.stamina,
        directiveOptions: next.directiveOptions,
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MatchScreen(
            controller: controller,
            careerSession: _careerSession,
            fixtureId: fixtureId,
            preMatchCondition: _preMatchCondition ?? next.stamina.current,
          ),
        ),
      );
      // career_engine M1 fikstürü 'in_progress' işaretledi, M2 onu 'played'
      // yapar — geri dönüldüğünde bir sonraki maç için tazesini iste.
      if (mounted) _loadNext();
    } on MatchApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Maç başlatılamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PreMatchScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PreMatchScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PreMatchScreen._border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildBody(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final next = _next;
    if (_loadError != null) {
      return _ErrorSection(message: _loadError!, onRetry: _loadNext);
    }
    if (next == null) {
      return const _LoadingSection();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderSection(
          home: next.teams.home.name,
          away: next.teams.away.name,
          kickoffLabel: _kickoffLabel(next.kickoffAt),
        ),
        const _FieldPlaceholder(),
        _TacticsRow(tacticLabel: next.teamTactic.label),
        const _ConditionBar(),
        _ActionRow(starting: _starting, onPlay: _startMatch),
      ],
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(
        child: CircularProgressIndicator(color: PreMatchScreen._success),
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 28,
                color: PreMatchScreen._danger,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PreMatchScreen._textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PreMatchScreen._textPrimary,
                  side: const BorderSide(color: PreMatchScreen._border),
                ),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.home,
    required this.away,
    required this.kickoffLabel,
  });

  final String home;
  final String away;
  final String kickoffLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PreMatchScreen._border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_left,
              size: 24,
              color: PreMatchScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Maça Çıkış',
              style: TextStyle(
                color: PreMatchScreen._textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$home - $away',
                style: const TextStyle(
                  color: PreMatchScreen._textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kickoffLabel,
                style: const TextStyle(
                  color: PreMatchScreen._textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldPlaceholder extends StatelessWidget {
  const _FieldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 260),
        width: double.infinity,
        decoration: BoxDecoration(
          color: PreMatchScreen._surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: PreMatchScreen._border,
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: PreMatchScreen._border),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.grid_view_outlined,
                  size: 28,
                  color: PreMatchScreen._textMuted,
                ),
                SizedBox(height: 6),
                Text(
                  'Saha dizilişi (yakında)',
                  style: TextStyle(
                    color: PreMatchScreen._textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(8),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TacticsRow extends StatelessWidget {
  const _TacticsRow({required this.tacticLabel});

  final String tacticLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _InfoTile(label: 'Takım taktiği', value: tacticLabel),
          ),
          const SizedBox(width: 12),
          // Bireysel rol: contract'ta karşılığı yok (§1.2, bireysel oyuncu
          // katmanı yok) — sabit kalır.
          const Expanded(
            child: _InfoTile(label: 'Bireysel rol', value: 'Oyun Kurucu'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PreMatchScreen._surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PreMatchScreen._textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: PreMatchScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionBar extends StatelessWidget {
  const _ConditionBar();

  @override
  Widget build(BuildContext context) {
    final condition = PlayerScope.of(context).condition;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kondisyon',
                style: TextStyle(
                  color: PreMatchScreen._textMuted,
                  fontSize: 12,
                ),
              ),
              Text(
                '$condition/100',
                style: const TextStyle(
                  color: PreMatchScreen._textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: condition / 100,
              minHeight: 6,
              backgroundColor: PreMatchScreen._surface1,
              color: PreMatchScreen._success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.starting, required this.onPlay});

  final bool starting;
  final VoidCallback onPlay;

  void _showStubMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showStubMessage(context, 'Antrenörle konuşma yakında'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PreMatchScreen._textPrimary,
                side: const BorderSide(color: PreMatchScreen._border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 13),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Antrenörle konuş'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            height: 64,
            child: OutlinedButton(
              onPressed: starting ? null : onPlay,
              style: OutlinedButton.styleFrom(
                foregroundColor: PreMatchScreen._textPrimary,
                side: const BorderSide(color: PreMatchScreen._border),
                padding: EdgeInsets.zero,
              ),
              child: starting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
