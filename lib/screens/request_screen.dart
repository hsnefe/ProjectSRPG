import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/screens/career_center_screen.dart';

/// Maç sonrası ekran. M2'nin (career_engine) sonucu varsa gerçek özet
/// gösterilir — skor, puan durumu değişimi, gol katkısı; talep sistemi
/// (röportaj vb.) henüz yok, yer tutucu olarak kalıyor.
class RequestScreen extends StatelessWidget {
  const RequestScreen({
    super.key,
    this.result,
    this.homeTeamName,
    this.awayTeamName,
  });

  /// M2 · `POST /careers/{cid}/matches/{fid}/result` yanıtı. Sonuç yazımı
  /// başarısız olduysa null — bu durumda özet bölümü hiç çizilmez (§6.4:
  /// fikstür 'in_progress' kalır, bir sonraki M1 çağrısı kurtarır).
  final MatchResultResponse? result;

  final String? homeTeamName;
  final String? awayTeamName;

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _success = Color(0xFF3DDC97);
  static const _danger = Color(0xFFE85D5D);

  /// Yığındaki mevcut kariyer merkezine döner; maç öncesi/maç ekranları atılır.
  /// `route.isFirst` güvenlik ağı: kariyer merkezi yığında yoksa (izole test,
  /// ileride farklı bir giriş noktası) tüm yığın boşaltılmasın.
  void _openCareerCenter(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == CareerCenterScreen.routeName || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return Scaffold(
      backgroundColor: _surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _HeaderSection(),
                      // `result` null olabilir: ya bu maç bir kariyer
                      // fikstürüne hiç bağlı değildi, ya da M2 başarısız oldu
                      // (o durumda kullanıcı hatayı zaten MatchScreen'in
                      // SnackBar'ında gördü — burada tekrar etmiyoruz).
                      if (result != null)
                        _MatchResultSection(
                          result: result,
                          homeTeamName: homeTeamName,
                          awayTeamName: awayTeamName,
                        ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
                        child: Text(
                          'Maç sonrası talepler yakında.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textMuted, fontSize: 12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openCareerCenter(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textPrimary,
                              side: const BorderSide(color: _border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            icon: const Icon(Icons.home_outlined, size: 16),
                            label: const Text('Kariyer Merkezi'),
                          ),
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
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: RequestScreen._border,
            width: 0.5,
          ),
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
              color: RequestScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Talepler',
            style: TextStyle(
              color: RequestScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// M2'nin döndürdüğü gerçek maç özeti: skor, puan durumu değişimi, katkı.
class _MatchResultSection extends StatelessWidget {
  const _MatchResultSection({
    required this.result,
    this.homeTeamName,
    this.awayTeamName,
  });

  final MatchResultResponse result;
  final String? homeTeamName;
  final String? awayTeamName;

  @override
  Widget build(BuildContext context) {
    final fixture = result.fixture;
    final delta = result.standingDelta;
    final stat = result.playerStatDelta;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Text(
            '${homeTeamName ?? 'Ev sahibi'} '
            '${fixture.homeScore ?? '–'} - ${fixture.awayScore ?? '–'} '
            '${awayTeamName ?? 'Deplasman'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RequestScreen._textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (delta.rankBefore != null && delta.rankAfter != null)
                _StatPill(
                  icon: delta.rankAfter! < delta.rankBefore!
                      ? Icons.trending_up
                      : delta.rankAfter! > delta.rankBefore!
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  label: '${delta.rankBefore}. → ${delta.rankAfter}.',
                  color: delta.rankAfter! < delta.rankBefore!
                      ? RequestScreen._success
                      : delta.rankAfter! > delta.rankBefore!
                          ? RequestScreen._danger
                          : RequestScreen._textSecondary,
                ),
              _StatPill(
                icon: Icons.sports_soccer,
                label: '${stat.goals} gol',
                color: RequestScreen._textSecondary,
              ),
              _StatPill(
                icon: Icons.timer_outlined,
                label: '${stat.minutes} dk',
                color: RequestScreen._textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
