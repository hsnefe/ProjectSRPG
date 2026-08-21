import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:project_srpg/game/conditioning_game.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/training_result_panel.dart';

/// Kondisyon koşusu. Sol ve sağ butonlara sırayla basarak adam koşturulur;
/// süre dolmadan hedef adıma ulaşmak gerekir.
///
/// Süre hiçbir yerde saniye olarak yazmaz — üstteki bar saatin kendisi, ve
/// sona yaklaşınca kırmızıya döner.
class ConditioningTrainingScreen extends StatefulWidget {
  const ConditioningTrainingScreen({super.key});

  @override
  State<ConditioningTrainingScreen> createState() =>
      _ConditioningTrainingScreenState();
}

class _ConditioningTrainingScreenState
    extends State<ConditioningTrainingScreen> {
  late final ConditioningGame _game = ConditioningGame(
    onStateChanged: _onGameState,
    onFinished: _onFinished,
  );

  TrainingResult? _result;
  bool _rebuildScheduled = false;

  /// Oyun döngüsü Flutter'ın build fazının içinden haber verebiliyor, orada
  /// setState fırlatır. Bütün bildirimler tek bir post-frame rebuild'e
  /// toplanıyor.
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
                      _TimeBar(timeLeft: _game.timeLeft),
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
                        _StepControls(
                          game: _game,
                          stumbling: _game.stumbleLeft > 0,
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
            'Kondisyon Koşusu',
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

/// Kalan süre. Sadece bu parça her karede yeniden çiziliyor — bütün ekranı
/// saniyede 60 kez rebuild etmemek için `ValueListenableBuilder` ile sarılı.
class _TimeBar extends StatelessWidget {
  const _TimeBar({required this.timeLeft});

  final ValueListenable<double> timeLeft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ValueListenableBuilder<double>(
        valueListenable: timeLeft,
        builder: (context, left, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: left,
              minHeight: 5,
              backgroundColor: AppColors.surface1,
              color: conditioningBarColor(left),
            ),
          );
        },
      ),
    );
  }
}

class _StepControls extends StatelessWidget {
  const _StepControls({required this.game, required this.stumbling});

  final ConditioningGame game;
  final bool stumbling;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: game.stepCount,
                builder: (context, steps, _) => Text(
                  '$steps / ${ConditioningGame.targetSteps}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SideButton(
                  label: 'SOL',
                  stumbling: stumbling,
                  onPressed: () => game.step(RunSide.left),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SideButton(
                  label: 'SAĞ',
                  stumbling: stumbling,
                  onPressed: () => game.step(RunSide.right),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.stumbling,
    required this.onPressed,
  });

  final String label;
  final bool stumbling;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: stumbling
              ? AppColors.danger
              : AppColors.textPrimary,
          side: BorderSide(
            color: stumbling
                ? AppColors.danger
                : AppColors.border,
          ),
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
        child: Text(label),
      ),
    );
  }
}
