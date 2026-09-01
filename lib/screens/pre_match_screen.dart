import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/screens/match_screen.dart';
import 'package:project_srpg/state/match_controller.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/date_labels.dart';

class PreMatchScreen extends StatefulWidget {
  PreMatchScreen({super.key, this.session, MatchApiClient? matchApiClient})
      : _matchApiClient = matchApiClient ?? MatchApiClient();

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;
  final MatchApiClient _matchApiClient;

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

  /// §6.1 — M1 `409 not_match_day`: bugün maç yok. Hata değil, takvimin
  /// normal hâli; ekran maça kaç gün kaldığını gösterir.
  int? _daysUntilMatch;
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
      _daysUntilMatch = null;
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
      if (e.code == 'not_match_day') {
        // Gün sayısını mesajdan ayıklamak yerine C3'ün kendi `days_until`
        // alanından okuyoruz (§1.3: sayı BE'den, cümle FE'den).
        final days = await _daysUntilNextFixture();
        if (!mounted) return;
        setState(() => _daysUntilMatch = days ?? 0);
        return;
      }
      setState(() => _loadError = e.message ?? 'Maç bilgisi alınamadı.');
    } on MatchApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message ?? 'Maç bilgisi alınamadı.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Maç bilgisi alınamadı.');
    }
  }

  Future<int?> _daysUntilNextFixture() async {
    try {
      final careerId = await _careerSession.resolve();
      final hub = await _careerSession.client.hub(careerId);
      return hub.nextFixture?.daysUntil;
    } catch (_) {
      return null;
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
        // D38 — maç oyuncunun kendi kondisyonundan başlar, 100'den değil.
        startCondition: _preMatchCondition,
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
                  border: Border.all(color: AppColors.border, width: 0.5),
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
    if (_daysUntilMatch != null) {
      return _NotMatchDaySection(daysUntil: _daysUntilMatch!);
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
          kickoffLabel: kickoffDayLabel(next.kickoffAt),
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
        child: CircularProgressIndicator(color: AppColors.success),
      ),
    );
  }
}

/// §6.1 — bugün maç günü değil. Maç yalnızca kendi gününde oynanır; araya
/// giren günler kariyer merkezindeki "İlerle" ile geçilir.
class _NotMatchDaySection extends StatelessWidget {
  const _NotMatchDaySection({required this.daysUntil});

  final int daysUntil;

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
                Icons.event_outlined,
                size: 28,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                daysUntil <= 0
                    ? 'Bugün maçın yok.'
                    : 'Maça $daysUntil gün var.',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kalan günleri kariyer merkezinden ilerlet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Kariyer merkezine dön'),
              ),
            ],
          ),
        ),
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
                color: AppColors.danger,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
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
          bottom: BorderSide(color: AppColors.border, width: 0.5),
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
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Maça Çıkış',
              style: TextStyle(
                color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kickoffLabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
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
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.border,
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: AppColors.border),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.grid_view_outlined,
                  size: 28,
                  color: AppColors.textMuted,
                ),
                SizedBox(height: 6),
                Text(
                  'Saha dizilişi (yakında)',
                  style: TextStyle(
                    color: AppColors.textMuted,
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
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
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
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              Text(
                '$condition/100',
                style: const TextStyle(
                  color: AppColors.textSecondary,
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
              backgroundColor: AppColors.surface1,
              color: AppColors.success,
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
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
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
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
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
