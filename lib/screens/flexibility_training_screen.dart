import 'package:flutter/material.dart';

import 'package:project_srpg/game/flexibility_game.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/widgets/fullscreen_game.dart';
import 'package:project_srpg/widgets/game_chrome.dart';
import 'package:project_srpg/widgets/training_result_panel.dart';

/// Esneklik & Toparlanma: ekranda sırayla üç desen gösterilir, sonra oyuncu
/// onları aynı sırayla çizer. Yanlış bir desen baştan başlatır; üçüncü hata
/// antrenmanı başarısız sayar.
class FlexibilityTrainingScreen extends StatefulWidget {
  const FlexibilityTrainingScreen({super.key});

  @override
  State<FlexibilityTrainingScreen> createState() =>
      _FlexibilityTrainingScreenState();
}

class _FlexibilityTrainingScreenState extends State<FlexibilityTrainingScreen> {
  late final FlexibilityGame _game = FlexibilityGame(
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
    final step = _game.phase == FlexPhase.showing
        ? _game.demoIndex + 1
        : _game.recallIndex + 1;
    switch (_game.phase) {
      case FlexPhase.ready:
        return 'Başlamak için ekrana dokun';
      case FlexPhase.showing:
        return 'Deseni izle · $step/${FlexibilityGame.patternCount}';
      case FlexPhase.recalling:
        return 'Deseni çiz · $step/${FlexibilityGame.patternCount}';
      case FlexPhase.feedback:
        return _game.lastAttemptOk ? 'Doğru' : 'Yanlış desen';
      case FlexPhase.done:
        return 'Antrenman bitti';
    }
  }

  /// Bu turda tamamlanan desenlerin başarı günlüğü — `AttemptFooter`'ın pip
  /// sırası. Yalnızca doğrular burada; bir yanlış zaten baştan başlatıyor.
  List<AttemptMark> get _log =>
      List<AttemptMark>.filled(_game.recallIndex, AttemptMark.good);

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return FullscreenGame(
      game: _game,
      top: const [GameHeaderBar(title: 'Esneklik & Toparlanma')],
      bottom: result != null
          ? TrainingResultPanel(
              result: result,
              onDone: () => Navigator.of(context).pop(result),
            )
          : AttemptFooter(
              log: _log,
              total: FlexibilityGame.patternCount,
              hint: _hint,
              lastLabel: _game.mistakes > 0 ? '${_game.mistakes} hata' : null,
            ),
    );
  }
}
