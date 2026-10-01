import 'package:flutter/material.dart';

import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/skill_exam_game.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/fullscreen_game.dart';
import 'package:project_srpg/widgets/game_chrome.dart';

/// Bir yetenek sınavının oynanan hâli.
///
/// Antrenman ekranıyla ([BallTrainingScreen]) aynı mekaniği koşturur; farkı
/// sonucu ne olarak döndürdüğü: antrenman bir [TrainingResult] verir, sınav
/// katalogdaki beşli skalaya oturan bir **not** verir.
///
/// Ekran `Navigator.pop` ile `int?` döndürür: not, ya da kullanıcı sınavı
/// yarıda bıraktıysa null.
class SkillExamScreen extends StatefulWidget {
  const SkillExamScreen({super.key, required this.exam});

  static const routeName = '/skill-exam';

  final SkillExamGame exam;

  @override
  State<SkillExamScreen> createState() => _SkillExamScreenState();
}

class _SkillExamScreenState extends State<SkillExamScreen> {
  late final ShotGame _game = ShotGame(
    mode: widget.exam.mode!,
    scene: widget.exam.scene!,
    onStateChanged: _onGameState,
    onFinished: (_) => _onFinished(),
  );

  /// Seans bitince dolar. Dolu olması "sınav bitti" demek.
  int? _grade;
  bool _rebuildScheduled = false;

  /// Oyun döngüsü Flutter'ın build fazının içinden haber verebiliyor (uçuş
  /// kare ortasında bitince mesela), orada setState fırlatır. Bütün
  /// bildirimleri tek bir post-frame rebuild'e topluyoruz.
  void _onGameState() {
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  /// Yalnızca notu saklar. Pop etmez: bu geri çağrı `update()` içinden
  /// geliyor ve oradan Navigator'a dokunmak güvenli değil — ekrandan çıkışa
  /// "Notu Kaydet" karar verir.
  void _onFinished() {
    _grade = _game.examGrade;
    _onGameState();
  }

  void _retry() {
    setState(() {
      _grade = null;
      _game.restartSession();
    });
  }

  String get _hint {
    switch (_game.phase) {
      case ShotPhase.aim:
        return widget.exam.aimHint;
      case ShotPhase.strike:
        return '2) Topa vur: merkez = güç, kenar = kavis, alt = yükselt';
      case ShotPhase.flight:
        return 'Uçuşta…';
      case ShotPhase.result:
        return 'Sıradaki deneme için sahaya dokun';
    }
  }

  @override
  Widget build(BuildContext context) {
    final grade = _grade;

    return FullscreenGame(
      game: _game,
      top: [
        GameHeaderBar(title: widget.exam.title),
        GameBriefBar(text: widget.exam.brief),
      ],
      bottom: grade != null
          ? _GradePanel(
              grade: grade,
              made: _game.made,
              total: ShotGame.attemptsPerSession,
              unit: widget.exam.unit,
              onRetry: _retry,
              onSave: () => Navigator.of(context).pop(grade),
            )
          : AttemptFooter(
              log: [
                for (final attempt in _game.attemptLog)
                  AttemptMark.ofGrade(attempt.grade),
              ],
              total: ShotGame.attemptsPerSession,
              hint: _hint,
              lastLabel: _game.result,
            ),
    );
  }
}

/// Sınav bitince alt kontrollerin yerine geçen panel: kazanılan not, isabet
/// dökümü ve iki çıkış — baştan al, ya da notu sihirbaza götür.
class _GradePanel extends StatelessWidget {
  const _GradePanel({
    required this.grade,
    required this.made,
    required this.total,
    required this.unit,
    required this.onRetry,
    required this.onSave,
  });

  final int grade;
  final int made;
  final int total;
  final String unit;
  final VoidCallback onRetry;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent, width: 0.5),
            ),
            child: Text(
              '$grade',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sınav notu',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$made/$total $unit',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Tekrar'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
            child: const Text('Notu Kaydet'),
          ),
        ],
      ),
    );
  }
}
