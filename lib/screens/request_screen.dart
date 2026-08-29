import 'package:flutter/material.dart';
import 'package:project_srpg/game/intervention_stats.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Maç sonrası ekran. M2'nin (career_engine) sonucu varsa gerçek özet
/// gösterilir — skor, puan durumu değişimi, istatistik tablosu, ilişki
/// delta'ları; röportaj/talep akışı henüz yok, medya satırındaki mikrofon
/// şimdilik pasif bir "yakında" göstergesi.
class RequestScreen extends StatelessWidget {
  const RequestScreen({
    super.key,
    this.result,
    this.userStats,
    this.homeTeamName,
    this.awayTeamName,
  });

  /// M2 · `POST /careers/{cid}/matches/{fid}/result` yanıtı. Sonuç yazımı
  /// başarısız olduysa null — bu durumda özet bölümü hiç çizilmez (§6.4:
  /// fikstür 'in_progress' kalır, bir sonraki M1 çağrısı kurtarır).
  final MatchResultResponse? result;

  /// Oyuncunun kendi maç istatistikleri — `MatchController`'ın müdahale
  /// defterinden türetilir (`game/intervention_stats.dart`). E9 özetinin
  /// `stats[userSide]`'ı **kullanılmaz**: o, 11 kişilik takımın maç geneli
  /// sayacıdır; kullanıcının kaç fırsata çıkıp kaç şut çektiğiyle ilgisi
  /// yoktur. Maç ekranı dışından açılan bir özet için null olabilir; o
  /// zaman tablo hiç çizilmez.
  final UserMatchStats? userStats;

  final String? homeTeamName;
  final String? awayTeamName;

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
                  // İstatistik tablosu + ilişki bar'ları eklenince içerik
                  // her zaman tek ekrana sığmayabiliyor (kısa ekranlar,
                  // çok satırlı özet) — kart artık kayan bir gövde,
                  // header/buton sabit kalıyor.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _HeaderSection(),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // `result` null olabilir: ya bu maç bir
                              // kariyer fikstürüne hiç bağlı değildi, ya da
                              // M2 başarısız oldu (o durumda kullanıcı
                              // hatayı zaten MatchScreen'in SnackBar'ında
                              // gördü — burada tekrar etmiyoruz).
                              if (result != null)
                                _MatchResultSection(
                                  result: result,
                                  homeTeamName: homeTeamName,
                                  awayTeamName: awayTeamName,
                                ),
                              if (result != null && userStats != null)
                                _StatsTable(
                                  stats: userStats!,
                                  playerStatDelta: result.playerStatDelta,
                                ),
                              if (result != null &&
                                  result.relationshipChanges.isNotEmpty)
                                _RelationshipSection(
                                  changes: result.relationshipChanges,
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openCareerCenter(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            icon: const Icon(Icons.home_outlined, size: 16),
                            label: const Text('İlerle'),
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
            color: AppColors.border,
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
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Talepler',
            style: TextStyle(
              color: AppColors.textPrimary,
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
              color: AppColors.textPrimary,
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
                      ? AppColors.success
                      : delta.rankAfter! > delta.rankBefore!
                          ? AppColors.danger
                          : AppColors.textSecondary,
                ),
              _StatPill(
                icon: Icons.sports_soccer,
                label: '${stat.goals} gol',
                color: AppColors.textSecondary,
              ),
              _StatPill(
                icon: Icons.timer_outlined,
                label: '${stat.minutes} dk',
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 7 satırlık maç istatistik tablosu — **oyuncunun kendi** rakamları,
/// takımın maç geneli değil. Fırsat/şut satırları müdahale defterinden
/// gelir (`stats`), gol/asist M2'nin oyuncu delta'sından; motorda karşılığı
/// olmayan pas/dribling/başarılı müdahale sayıları **dürüst 0** olarak
/// gösterilir, uydurulmaz.
class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.stats, required this.playerStatDelta});

  final UserMatchStats stats;
  final PlayerStatDelta playerStatDelta;

  @override
  Widget build(BuildContext context) {
    final rows = <_StatRow>[
      _StatRow('Fırsat sayısı', '${stats.opportunities}'),
      _StatRow('Başarılı pas / Pas denemesi', '0/0'),
      _StatRow(
        'İsabetli şut / Şut',
        '${stats.shotsOnTarget}/${stats.shots}',
      ),
      _StatRow('Başarılı dribling / Dribling', '0/0'),
      _StatRow('Başarılı müdahale', '0'),
      _StatRow('Gol', '${playerStatDelta.goals}'),
      _StatRow('Asist', '${playerStatDelta.assists}'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(height: 13, color: AppColors.border, thickness: 0.5),
                Row(
                  children: [
                    // Uzun etiketler (ör. "Başarılı pas / Pas denemesi")
                    // dar ekranlarda taşabiliyordu - `Expanded` kalan
                    // genişliği alır, sığmazsa satır kırar.
                    Expanded(
                      child: Text(
                        rows[i].label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rows[i].value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;
}

/// Antrenör/Takım/Taraftarlar/Medya ilişki bar'ları — sabit sırayla, M2'nin
/// `relationship_changes` listesinden `relationshipId`'ye göre haritalanır.
/// Medya satırının yanında pasif (dokununca hiçbir şey yapmayan) mikrofon
/// ikonu var — röportaj akışı bu turda yok.
class _RelationshipSection extends StatelessWidget {
  const _RelationshipSection({required this.changes});

  final List<RelationshipChange> changes;

  static const _order = ['coach', 'team', 'fans', 'media'];
  static const _labels = {
    'coach': 'Antrenör',
    'team': 'Takım',
    'fans': 'Taraftarlar',
    'media': 'Medya',
  };

  @override
  Widget build(BuildContext context) {
    final byId = {for (final c in changes) c.relationshipId: c};
    final rows = [
      for (final id in _order)
        if (byId.containsKey(id)) MapEntry(id, byId[id]!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          for (final entry in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RelationshipDeltaBar(
                label: _labels[entry.key] ?? entry.key,
                delta: entry.value.delta,
                trailing: entry.key == 'media'
                    ? const IconButton(
                        onPressed: null,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        icon: Icon(
                          Icons.mic_none_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _RelationshipDeltaBar extends StatelessWidget {
  const _RelationshipDeltaBar({
    required this.label,
    required this.delta,
    this.trailing,
  });

  final String label;
  final int delta;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = delta > 0
        ? AppColors.success
        : delta < 0
            ? AppColors.danger
            : AppColors.textSecondary;
    final sign = delta > 0 ? '+$delta' : '$delta';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
            ),
            child: Text(
              sign,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
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
