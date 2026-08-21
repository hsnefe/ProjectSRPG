import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:project_srpg/game/bench_press_game.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/training_result_panel.dart';

/// Güç antrenmanı: POV bench press. Sağdaki dikey barda ok git-gel yapar,
/// yeşil bölgedeyken basmak temiz bir tekrar demektir.
class StrengthTrainingScreen extends StatefulWidget {
  const StrengthTrainingScreen({super.key});

  @override
  State<StrengthTrainingScreen> createState() => _StrengthTrainingScreenState();
}

class _StrengthTrainingScreenState extends State<StrengthTrainingScreen> {
  late final BenchPressGame _game = BenchPressGame(
    onStateChanged: _onGameState,
    onFinished: _onFinished,
  );

  TrainingResult? _result;
  bool _rebuildScheduled = false;

  /// Oyun döngüsü build fazının içinden haber verebiliyor; bütün bildirimler
  /// tek bir post-frame rebuild'e toplanıyor.
  void _onGameState() {
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _onFinished(TrainingResult result) {
    _result = result;
    _onGameState();
  }

  String get _hint {
    switch (_game.phase) {
      case BenchPhase.ready:
        return 'Başlamak için bas';
      case BenchPhase.sweeping:
        return 'Ok yeşil bölgedeyken bas';
      case BenchPhase.lifting:
        return _game.lastRepOk ? 'Temiz tekrar' : 'Kaçtı';
      case BenchPhase.done:
        return 'Antrenman bitti';
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
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      const _HeaderSection(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GameWidget(game: _game),
                          ),
                        ),
                      ),
                      if (_result case final result?)
                        TrainingResultPanel(
                          result: result,
                          onDone: () => Navigator.of(context).pop(result),
                        )
                      else
                        _PressControls(hint: _hint, onPress: _game.press),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          const SizedBox(width: 8),
          const Text(
            'Güç Antrenmanı',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sahneye dokunmak da aynı işi görüyor; bu buton hem tek elle oynamak için
/// hem de isimli bir hedef olduğu için duruyor.
class _PressControls extends StatelessWidget {
  const _PressControls({required this.hint, required this.onPress});

  final String hint;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: onPress,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('BAS'),
            ),
          ),
        ],
      ),
    );
  }
}
