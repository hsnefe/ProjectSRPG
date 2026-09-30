import 'package:flutter/material.dart';

import 'package:project_srpg/game/dribble_courses.dart';
import 'package:project_srpg/game/dribble_game.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/fullscreen_game.dart';
import 'package:project_srpg/widgets/game_chrome.dart';
import 'package:project_srpg/widgets/training_result_panel.dart';

/// Dribling: koridorda yukarı kaydırarak topu sür. Aynı yöne devam etmek
/// hızlandırır, ters yöne kaydırmak frenler, yana kaydırmak çevirir —
/// konilere ve duvara çarpmadan bitişe var.
class DribbleTrainingScreen extends StatefulWidget {
  const DribbleTrainingScreen({super.key, this.course});

  /// Oynanacak kurs. Verilmezse katalogdan rastgele biri — testler kendi
  /// kursunu geçirebilsin diye açık.
  final DribbleCourse? course;

  @override
  State<DribbleTrainingScreen> createState() => _DribbleTrainingScreenState();
}

class _DribbleTrainingScreenState extends State<DribbleTrainingScreen> {
  late final DribbleCourse _course = widget.course ?? DribbleCourses.pick();

  late final DribbleGame _game = DribbleGame(
    onStateChanged: _onGameState,
    onFinished: _onFinished,
    course: _course,
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
      case DribblePhase.ready:
        return 'Topu sürmek için yukarı kaydır';
      case DribblePhase.running:
        return 'Aynı yöne kaydırdıkça hızlan · ters yön frenler';
      case DribblePhase.done:
        return _game.succeeded ? 'Bitişe vardın' : 'Antrenman bitti';
    }
  }

  /// `AttemptFooter`'ın pip sırası burada **temas hakkı** anlamına geliyor:
  /// harcanmamış haklar iyi, harcananlar kötü. Diğer antrenmanlarda pip bir
  /// denemeyi gösteriyor ama diribling tek uzun koşu — sayılacak tek şey
  /// kaç kez çarptığın.
  List<AttemptMark> get _log => List<AttemptMark>.generate(
    _game.hits.clamp(0, DribbleGame.maxHits),
    (_) => AttemptMark.fail,
  );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return FullscreenGame(
      game: _game,
      top: [
        const GameHeaderBar(title: 'Dribling'),
        GameBriefBar(title: _course.name, text: _course.brief),
        _ProgressBar(game: _game),
      ],
      bottom: result != null
          ? TrainingResultPanel(
              result: result,
              onDone: () => Navigator.of(context).pop(result),
            )
          : AttemptFooter(
              log: _log,
              total: DribbleGame.maxHits,
              hint: _hint,
              lastLabel: _game.hits > 0 ? '${_game.hits} temas' : null,
            ),
    );
  }
}

/// Mesafe ve süre — ikisi de her karede değişiyor, o yüzden `setState` yerine
/// oyunun notifier'larını dinler.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.game});

  final DribbleGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: game.progress,
            builder: (_, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.surface1,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          ValueListenableBuilder<double>(
            valueListenable: game.timeLeft,
            builder: (_, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: AppColors.surface1,
                valueColor: AlwaysStoppedAnimation<Color>(
                  value <= 0.25 ? AppColors.dangerBright : AppColors.warning,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
