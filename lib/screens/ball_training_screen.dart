import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/training_result_panel.dart';

/// Şut ve pas antrenmanları. İkisi de aynı [ShotGame]; fark yalnızca
/// [ShotMode] — hangi sonucun sayıldığı ve hangi yöne dönük başlanacağı.
///
/// Prototip ekranı (FlameShotDemoScreen) mekaniği *göstermek* için var:
/// pusulası ve dört tanı barı orada kalır. Burası onu gizler, üç deneme sayar
/// ve sonucu geri döndürür.
class BallTrainingScreen extends StatefulWidget {
  const BallTrainingScreen({super.key, required this.mode});

  final ShotMode mode;

  @override
  State<BallTrainingScreen> createState() => _BallTrainingScreenState();
}

class _BallTrainingScreenState extends State<BallTrainingScreen> {
  late final ShotGame _game = ShotGame(
    mode: widget.mode,
    onStateChanged: _onGameState,
    onFinished: _onFinished,
  );

  TrainingResult? _result;
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

  /// Seans bittiğinde yalnızca sonucu saklar. Pop etmez: bu geri çağrı
  /// `update()` içinden geliyor ve oradan Navigator'a dokunmak güvenli değil —
  /// ekrandan çıkışa `Bitir` karar verir.
  void _onFinished(TrainingResult result) {
    _result = result;
    _onGameState();
  }

  bool get _isPass => widget.mode == ShotMode.pass;

  String get _hint {
    if (_result != null) return 'Antrenman bitti';
    switch (_game.phase) {
      case ShotPhase.aim:
        return _isPass
            ? '1) Sürükle: arkadaşını hedefle, bırak'
            : '1) Sürükle: kalede bir nokta seç, bırak';
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
                      _HeaderSection(
                        title: _isPass ? 'Pas Antrenmanı' : 'Şut Antrenmanı',
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
                      if (_result case final result?)
                        TrainingResultPanel(
                          result: result,
                          onDone: () => Navigator.of(context).pop(result),
                        )
                      else
                        _AttemptFooter(
                          log: _game.attemptLog,
                          total: ShotGame.attemptsPerSession,
                          hint: _hint,
                          lastLabel: _game.result,
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
  const _HeaderSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
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

/// Üç deneme göstergesi, faz ipucu ve son uçuşun sonucu.
class _AttemptFooter extends StatelessWidget {
  const _AttemptFooter({
    required this.log,
    required this.total,
    required this.hint,
    required this.lastLabel,
  });

  final List<bool> log;
  final int total;
  final String hint;
  final String? lastLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _Pip(made: i < log.length ? log[i] : null),
                ),
              const Spacer(),
              if (lastLabel != null)
                Text(
                  lastLabel!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({required this.made});

  /// null = henüz atılmadı.
  final bool? made;

  @override
  Widget build(BuildContext context) {
    final made = this.made;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: made == null
            ? Colors.transparent
            : (made
                ? AppColors.success
                : AppColors.danger),
        border: Border.all(
          color: made == null
              ? AppColors.border
              : Colors.transparent,
          width: 1.5,
        ),
      ),
    );
  }
}

