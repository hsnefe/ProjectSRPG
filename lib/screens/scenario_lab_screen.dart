import 'package:flutter/material.dart';

import 'package:project_srpg/game/scenario_progress.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';
import 'package:project_srpg/screens/scenario_play_screen.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/game_chrome.dart';

/// Senaryo sahası: kataloğun kırk iki durumunu tek tek seçip oynadığın yer.
///
/// Antrenman ekranı seansı kendisi diziyor — üç durum çekiyor, sayıyor ve
/// karakterin niteliklerine yazıyor. Burası onun tersi: hangi durumu
/// oynayacağına sen karar veriyorsun, istediğin kadar tekrar ediyorsun ve
/// hiçbiri kariyerine dokunmuyor. Bir durumun nasıl hissettirdiğini görmenin
/// tek yolu bu, çünkü seans onu rastgele ve bir kez veriyor.
class ScenarioLabScreen extends StatefulWidget {
  const ScenarioLabScreen({super.key, this.progress});

  static const routeName = '/scenario-lab';

  /// Testler kendi kaydını geçirebilsin diye.
  final ScenarioProgress? progress;

  @override
  State<ScenarioLabScreen> createState() => _ScenarioLabScreenState();
}

class _ScenarioLabScreenState extends State<ScenarioLabScreen> {
  late final ScenarioProgress _progress =
      widget.progress ?? ScenarioProgress.instance;

  /// null = tümü.
  ShotScenarioKind? _filter;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_onProgress);
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    if (mounted) setState(() {});
  }

  List<ShotScenario> get _visible {
    final filter = _filter;
    return filter == null ? ShotScenarios.all : ShotScenarios.of(filter);
  }

  Future<void> _open(ShotScenario scenario) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScenarioPlayScreen(
          scenario: scenario,
          progress: widget.progress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    // Aileler yalnızca "tümü" görünümünde başlıklanıyor; tek aile seçiliyken
    // her kartın üstünde aynı başlığı tekrarlamak gürültü olurdu.
    final grouped = _filter == null;

    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                GameHeaderBar(
                  title: 'Senaryo Sahası',
                  trailing: _Tally(progress: _progress),
                ),
                _FilterBar(
                  selected: _filter,
                  onSelect: (kind) => setState(() => _filter = kind),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final scenario = visible[i];
                      final startsFamily = grouped &&
                          (i == 0 || visible[i - 1].kind != scenario.kind);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (startsFamily)
                            _FamilyHeading(
                              kind: scenario.kind,
                              count: ShotScenarios.of(scenario.kind).length,
                            ),
                          _ScenarioCard(
                            scenario: scenario,
                            best: _progress.bestOf(scenario.id),
                            attempts: _progress.attemptsOf(scenario.id),
                            onTap: () => _open(scenario),
                          ),
                        ],
                      );
                    },
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

/// Sunum kararları: her ailenin ikonu ve rengi. Oyun tarafında bunların
/// karşılığı yok — [ShotScenarioKind] kurallara hiç karışmıyor.
({IconData icon, Color color}) _styleOf(ShotScenarioKind kind) =>
    switch (kind) {
      ShotScenarioKind.shot => (
          icon: Icons.sports_soccer,
          color: AppColors.warning
        ),
      ShotScenarioKind.buildUp => (
          icon: Icons.shield_outlined,
          color: AppColors.accent
        ),
      ShotScenarioKind.transition => (
          icon: Icons.bolt_outlined,
          color: AppColors.success
        ),
      ShotScenarioKind.finalThird => (
          icon: Icons.gps_fixed,
          color: AppColors.dangerBright
        ),
    };

/// Başlıktaki toplam: kaç durum geçildi, kaçında tavan yapıldı.
class _Tally extends StatelessWidget {
  const _Tally({required this.progress});

  final ScenarioProgress progress;

  @override
  Widget build(BuildContext context) {
    final total = ShotScenarios.all.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${progress.cleared}/$total',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (progress.mastered > 0) ...[
          const SizedBox(width: 8),
          Icon(Icons.star_rounded,
              size: 14, color: GradeBadge.colorOf(ShotGrade.great)),
          const SizedBox(width: 2),
          Text(
            '${progress.mastered}',
            style: TextStyle(
              color: GradeBadge.colorOf(ShotGrade.great),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});

  final ShotScenarioKind? selected;
  final ValueChanged<ShotScenarioKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Chip(
            label: 'Tümü',
            count: ShotScenarios.all.length,
            color: AppColors.textSecondary,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final kind in ShotScenarioKind.values)
            _Chip(
              label: kind.label,
              count: ShotScenarios.of(kind).length,
              color: _styleOf(kind).color,
              selected: selected == kind,
              onTap: () => onSelect(kind),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.6)
                    : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Text(
              '$label · $count',
              style: TextStyle(
                color: selected ? color : AppColors.textMuted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyHeading extends StatelessWidget {
  const _FamilyHeading({required this.kind, required this.count});

  final ShotScenarioKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(kind);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Icon(style.icon, size: 15, color: style.color),
          const SizedBox(width: 7),
          Text(
            kind.label.toUpperCase(),
            style: TextStyle(
              color: style.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$count durum',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.best,
    required this.attempts,
    required this.onTap,
  });

  final ShotScenario scenario;
  final ShotGrade? best;
  final int attempts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(scenario.kind);
    final best = this.best;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                // Geçilmiş bir durumun çerçevesi kendi kademesinin rengini
                // alıyor: listeye bakınca nerede kaldığın tek bakışta belli.
                color: best == null
                    ? AppColors.border
                    : GradeBadge.colorOf(best).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(style.icon, size: 16, color: style.color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        scenario.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        scenario.brief,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _TierPips(tiers: scenario.objective.tiers),
                          const SizedBox(width: 8),
                          Text(
                            scenario.objective.tiers == 3
                                ? 'üç sonuç'
                                : 'iki sonuç',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                          if (attempts > 0) ...[
                            const SizedBox(width: 10),
                            Text(
                              '$attempts deneme',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (best == null)
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textMuted)
                else
                  GradeBadge(grade: best, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Durumun kaç sonucu olduğunu gösteren küçük çentikler.
class _TierPips extends StatelessWidget {
  const _TierPips({required this.tiers});

  final int tiers;

  @override
  Widget build(BuildContext context) {
    const order = [ShotGrade.fail, ShotGrade.good, ShotGrade.great];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tiers; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GradeBadge.colorOf(order[i]).withValues(alpha: 0.75),
              ),
            ),
          ),
      ],
    );
  }
}
