import 'package:flutter/material.dart';

import 'package:project_srpg/game/tackle_game.dart';
import 'package:project_srpg/game/tackle_scenarios.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/widgets/fullscreen_game.dart';
import 'package:project_srpg/widgets/game_chrome.dart';
import 'package:project_srpg/widgets/tackle_controls.dart';
import 'package:project_srpg/widgets/training_result_panel.dart';

/// Müdahale: SOL/SAĞ dönüşümlü basarak rakibe koş, mesafe kapanınca açılan
/// pencerede MÜDAHALE'ye bas. Tempoyu tutturmak pencereyi genişletir — tek
/// rakip, tek deneme.
class TackleTrainingScreen extends StatefulWidget {
  const TackleTrainingScreen({super.key, this.scenario});

  /// Testlerin belirli bir durumu sabitleyebilmesi için; uygulamada boş
  /// bırakılır ve her açılışta katalogdan biri çekilir.
  final TackleScenario? scenario;

  @override
  State<TackleTrainingScreen> createState() => _TackleTrainingScreenState();
}

class _TackleTrainingScreenState extends State<TackleTrainingScreen> {
  late final TackleScenario _scenario =
      widget.scenario ?? TackleScenarios.pick();

  late final TackleGame _game = TackleGame(
    onStateChanged: _onGameState,
    onFinished: _onFinished,
    closeScale: _scenario.closeScale,
    windowScale: _scenario.windowScale,
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
      case TacklePhase.ready:
        return 'Koşmaya başlamak için SOL ya da SAĞ';
      case TacklePhase.closing:
        return 'Tempoyu tuttur · pencere o kadar genişler';
      case TacklePhase.window:
        return 'Şimdi!';
      case TacklePhase.done:
        return _game.succeeded ? 'Baskı tuttu' : 'Antrenman bitti';
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _game.phase == TacklePhase.window;

    final result = _result;
    return FullscreenGame(
      game: _game,
      top: [
        const GameHeaderBar(title: 'Müdahale'),
        GameBriefBar(
          title: '${_scenario.kind.label} · ${_scenario.title}',
          text: _scenario.brief,
        ),
        TackleGauges(game: _game),
      ],
      bottom: result != null
          ? TrainingResultPanel(
              result: result,
              onDone: () => Navigator.of(context).pop(result),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TackleControls(game: _game, windowOpen: open),
                // Tek deneme: pip dolmadan oturum biter, boş halka "bir hakkın
                // var" demenin en kısa yolu. Asıl iş ipucu satırında.
                AttemptFooter(
                  log: const [],
                  total: 1,
                  hint: _hint,
                  lastLabel: null,
                ),
              ],
            ),
    );
  }
}
