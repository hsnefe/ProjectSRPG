import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:project_srpg/game/scenario_progress.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/game_chrome.dart';

/// Tek bir senaryonun sınırsız denemeyle oynandığı ekran.
///
/// Antrenman ekranından ([BallTrainingScreen]) farkı üç deneme sayıp bir
/// [TrainingResult] döndürmemesi: burası bir alıştırma alanı, seans değil.
/// İstediğin kadar denersin, hiçbiri karakterine dokunmaz.
///
/// Oyun [ShotMode.free] ile kuruluyor — o mod deneme saymıyor, yani seans
/// asla bitmiyor. Notlandırma yine de çalışıyor, çünkü kademeye modun değil
/// **sahnenin** hedefi karar veriyor ([ShotScene.objective]) ve her senaryo
/// kendi hedefini taşıyor.
class ScenarioPlayScreen extends StatefulWidget {
  const ScenarioPlayScreen({
    super.key,
    required this.scenario,
    this.progress,
  });

  final ShotScenario scenario;

  /// Testler kendi kaydını geçirebilsin diye.
  final ScenarioProgress? progress;

  @override
  State<ScenarioPlayScreen> createState() => _ScenarioPlayScreenState();
}

class _ScenarioPlayScreenState extends State<ScenarioPlayScreen> {
  late final ScenarioProgress _progress =
      widget.progress ?? ScenarioProgress.instance;

  late final ShotGame _game = ShotGame(
    mode: ShotMode.free,
    scene: widget.scenario.scene,
    onStateChanged: _onGameState,
  );

  bool _rebuildScheduled = false;

  /// Duran sonucun bir kez kaydedilmesi için. Faz sonuçtan çıkınca sıfırlanır.
  bool _recorded = false;

  ShotGrade? _lastGrade;

  /// Oyun döngüsü Flutter'ın build fazının içinden haber verebiliyor (uçuş
  /// kare ortasında bitince mesela), orada setState fırlatır. Bütün
  /// bildirimleri tek bir post-frame rebuild'e topluyoruz — antrenman ve
  /// sınav ekranlarındaki aynı desen.
  void _onGameState() {
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (!mounted) return;
      setState(_recordResult);
    });
  }

  void _recordResult() {
    if (_game.phase != ShotPhase.result) {
      _recorded = false;
      return;
    }
    if (_recorded) return;
    _recorded = true;
    _lastGrade = _game.lastGrade;
    _progress.record(widget.scenario.id, _game.lastGrade);
  }

  void _retry() => setState(_game.reset);

  /// Katalog sırasındaki bir sonraki duruma geçer. `pushReplacement`, çünkü
  /// kırk iki durumu gezerken yığında kırk iki ekran birikmemeli — geri tuşu
  /// her zaman listeye dönmeli.
  void _next() {
    final all = ShotScenarios.all;
    final index = all.indexWhere((s) => s.id == widget.scenario.id);
    final next = all[(index + 1) % all.length];
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ScenarioPlayScreen(
          scenario: next,
          progress: widget.progress,
        ),
      ),
    );
  }

  String get _hint => switch (_game.phase) {
        ShotPhase.aim => widget.scenario.aimHint,
        ShotPhase.strike =>
          '2) Topa vur: merkez = güç, kenar = kavis, alt = yükselt',
        ShotPhase.flight => 'Uçuşta…',
        ShotPhase.result => 'Sahaya dokun ya da Tekrar de',
      };

  @override
  Widget build(BuildContext context) {
    final scenario = widget.scenario;
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
                  child: Column(
                    children: [
                      GameHeaderBar(
                        title: scenario.title,
                        trailing: _AttemptTally(
                          cleared: _progress.clearedOf(scenario.id),
                          attempts: _progress.attemptsOf(scenario.id),
                        ),
                      ),
                      GameBriefBar(
                        title: scenario.kind.label,
                        text: scenario.brief,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GameWidget(game: _game),
                          ),
                        ),
                      ),
                      _Footer(
                        scenario: scenario,
                        hint: _hint,
                        label: _game.result,
                        grade: _game.phase == ShotPhase.result
                            ? _lastGrade
                            : null,
                        onRetry: _retry,
                        onNext: _next,
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

/// Başlıktaki küçük sayaç: kaç denemede kaçı sayıldı.
class _AttemptTally extends StatelessWidget {
  const _AttemptTally({required this.cleared, required this.attempts});

  final int cleared;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    if (attempts == 0) {
      return const Text(
        'ilk deneme',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      );
    }
    return Text(
      '$cleared/$attempts',
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Alt panel: oynarken ipucu ve hedef tablosu, sonuçtan sonra kademe rozeti
/// ile iki çıkış.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.scenario,
    required this.hint,
    required this.label,
    required this.grade,
    required this.onRetry,
    required this.onNext,
  });

  final ShotScenario scenario;
  final String hint;
  final String? label;
  final ShotGrade? grade;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final grade = this.grade;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (grade == null) ...[
            ScenarioObjectiveLegend(scenario: scenario),
            const SizedBox(height: 10),
            Text(
              hint,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ] else ...[
            Row(
              children: [
                GradeBadge(grade: grade),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label ?? '',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Tekrar'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Sonraki'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hint,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bir kademenin rengi ve adı.
class GradeBadge extends StatelessWidget {
  const GradeBadge({super.key, required this.grade, this.compact = false});

  final ShotGrade grade;
  final bool compact;

  static Color colorOf(ShotGrade grade) => switch (grade) {
        ShotGrade.fail => AppColors.danger,
        ShotGrade.good => AppColors.success,
        ShotGrade.great => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(grade);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.5),
      ),
      child: Text(
        grade.label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Bu durumda neyin ne kadar sayıldığı, durumun kendi adamlarının adıyla.
///
/// Kademe tablosu koddan türetiliyor ([ShotObjective] + sahnenin kadrosu),
/// elle yazılmıyor: bir senaryonun hedefi ya da anahtar adamı değişince bu
/// panel kendiliğinden doğru kalıyor.
class ScenarioObjectiveLegend extends StatelessWidget {
  const ScenarioObjectiveLegend({super.key, required this.scenario});

  final ShotScenario scenario;

  /// Kademe → o kademeyi hak eden şeyin tarifi. Ulaşılamayan kademe listeye
  /// hiç girmiyor, yani iki kademeli bir durum iki satır gösteriyor.
  static List<({ShotGrade grade, String what})> rowsFor(
    ShotScenario scenario,
  ) {
    final objective = scenario.objective;
    final receivers = scenario.scene.receivers;
    final key = receivers.where((r) => r.isKey).firstOrNull;

    String join(List<String> parts) => parts.join(' · ');

    final great = <String>[
      if (objective.great.contains(ShotLabel.goal)) 'Gol at',
      if (objective.keyPassIsGreat && key != null) '${key.label} ile buluş',
    ];

    final good = <String>[
      if (objective.good.contains(ShotLabel.goal)) 'Gol at',
      if (objective.good.contains(ShotLabel.save) ||
          objective.good.contains(ShotLabel.post))
        'Kaleyi bul',
      if (objective.good.contains(ShotLabel.passCaught))
        ...(() {
          final safe = receivers
              .where((r) => !(objective.keyPassIsGreat && r.isKey))
              .map((r) => r.label);
          return safe.isEmpty ? <String>[] : [safe.join(' ya da ')];
        })(),
    ];

    return [
      if (great.isNotEmpty) (grade: ShotGrade.great, what: join(great)),
      if (good.isNotEmpty) (grade: ShotGrade.good, what: join(good)),
      (grade: ShotGrade.fail, what: 'Topu kaybet'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rowsFor(scenario))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                GradeBadge(grade: row.grade, compact: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.what,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
