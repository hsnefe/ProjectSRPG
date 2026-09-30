import 'package:flutter/material.dart';

import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/widgets/fullscreen_game.dart';
import 'package:project_srpg/widgets/game_chrome.dart';
import 'package:project_srpg/widgets/training_result_panel.dart';

/// Şut ve pas antrenmanları. İkisi de aynı [ShotGame]; fark yalnızca
/// seansa hangi durumların dizildiği.
///
/// Prototip ekranı (FlameShotDemoScreen) mekaniği *göstermek* için var:
/// pusulası ve dört tanı barı orada kalır. Burası onu gizler, üç deneme sayar
/// ve sonucu geri döndürür.
///
/// Üç deneme artık aynı yerde geçmiyor: seans [ShotScenarios]'tan bir durum
/// listesi çekiyor ve her deneme sahanın başka bir noktasında, başka bir
/// kadroyla, kendi hedefiyle oynanıyor (bkz. [ShotGame.playlist]).
class BallTrainingScreen extends StatefulWidget {
  const BallTrainingScreen({super.key, required this.mode, this.playlist});

  final ShotMode mode;

  /// Seansın durumları. Testler sabit bir liste verebilsin diye dışarıdan
  /// alınabiliyor; normalde katalogdan rastgele geliyor.
  final List<ShotScenario>? playlist;

  @override
  State<BallTrainingScreen> createState() => _BallTrainingScreenState();
}

class _BallTrainingScreenState extends State<BallTrainingScreen> {
  late final List<ShotScenario> _playlist =
      widget.playlist ??
      (widget.mode == ShotMode.pass
          ? ShotScenarios.passSession()
          : ShotScenarios.shotSession());

  late final ShotGame _game = ShotGame(
    mode: widget.mode,
    playlist: _playlist,
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
        return _game.scenario?.aimHint ??
            (_isPass
                ? '1) Sürükle: arkadaşını hedefle, bırak'
                : '1) Sürükle: kalede bir nokta seç, bırak');
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
    final result = _result;
    return FullscreenGame(
      game: _game,
      top: [
        GameHeaderBar(title: _isPass ? 'Pas Antrenmanı' : 'Şut Antrenmanı'),
        if (_game.scenario case final scenario?)
          GameBriefBar(
            // Durum ilerledikçe başlık da ilerlesin: hangi denemede olduğun,
            // nerede durduğunla aynı şey.
            title: '${scenario.kind.label} · ${scenario.title}',
            text: scenario.brief,
          ),
      ],
      bottom: result != null
          ? TrainingResultPanel(
              result: result,
              onDone: () => Navigator.of(context).pop(result),
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
