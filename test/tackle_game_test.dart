import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/conditioning_game.dart' show RunSide;
import 'package:project_srpg/game/shot_objective.dart';
import 'package:project_srpg/game/tackle_game.dart';
import 'package:project_srpg/game/training_result.dart';

/// Kural katmanı `size` okumadığı için oyun widget'sız kurulabiliyor: aşağıda
/// hiçbir test `pumpWidget` çağırmıyor, hepsi [TackleGame.step],
/// [TackleGame.commit] ve [TackleGame.advance]'ı doğrudan sürüyor
/// (`dribble_game_test.dart` / `conditioning_run_test.dart` ile aynı politika).
TackleGame _game({
  void Function(TrainingResult)? onFinished,
  double closeScale = 1,
  double windowScale = 1,
}) =>
    TackleGame(
      onStateChanged: () {},
      onFinished: onFinished ?? (_) {},
      closeScale: closeScale,
      windowScale: windowScale,
    );

/// [beats] adım, aralarında tam [gap] saniye.
void _run(TackleGame game, int beats, {double gap = TackleGame.targetGap}) {
  for (var i = 0; i < beats; i++) {
    game.step(i.isEven ? RunSide.left : RunSide.right);
    game.advance(gap);
  }
}

/// Pencere açılana kadar [gap] temposunda koşar.
void _runToWindow(TackleGame game, {double gap = TackleGame.targetGap}) {
  var i = 0;
  while (game.phase != TacklePhase.window && !game.finished && i < 600) {
    game.step(i.isEven ? RunSide.left : RunSide.right);
    game.advance(gap);
    i++;
  }
}

/// Pencereyi açar, içinde [at] oranına konumlanıp dalar ve dereceyi döner.
/// Konumu doğrudan kurmak `bench_press_test.dart`'ın `_rep` kalıbı: kaba
/// `advance` adımlarıyla pencerenin merkezine nişan alınamaz.
ShotGrade _commitAt(
  TackleGame game,
  double at, {
  double gap = TackleGame.targetGap,
}) {
  _runToWindow(game, gap: gap);
  game.windowElapsed = game.windowDuration * at;
  game.commit();
  return game.grade!;
}

void main() {
  group('koşu', () {
    test('ilk basışa kadar saat işlemez', () {
      final game = _game();
      game.advance(5);

      expect(game.phase, TacklePhase.ready);
      expect(game.elapsed, 0);
      expect(game.timeLeft.value, 1);
      expect(game.approach.value, 0);
    });

    test('dönüşümlü basmak mesafeyi kapatır', () {
      final game = _game();
      _run(game, 8);

      expect(game.phase, TacklePhase.closing);
      expect(game.approach.value, greaterThan(0));
      expect(game.steps, 8);
    });

    test('aynı ayağa iki kez basmak tökezletir', () {
      final game = _game();
      game.step(RunSide.left);
      game.advance(TackleGame.targetGap);
      final before = game.steps;

      game.step(RunSide.left);

      expect(game.steps, before);
      expect(game.stumbleLeft, TackleGame.stumbleTime);
    });

    test('tökezlerken doğru ayak bile saymaz', () {
      final game = _game();
      game.step(RunSide.left);
      game.advance(TackleGame.targetGap);
      game.step(RunSide.left);
      final before = game.steps;

      game.step(RunSide.right);

      expect(game.steps, before);
    });

    test('tökezleme borçlu tuşu değiştirmez', () {
      final game = _game();
      game.step(RunSide.left);
      game.advance(TackleGame.targetGap);
      game.step(RunSide.left);
      final before = game.steps;

      game.advance(TackleGame.stumbleTime + 0.01);
      game.step(RunSide.right);

      expect(game.steps, before + 1);
    });
  });

  group('ritim', () {
    test('hedef tempoda basmak ritmi yükseltir', () {
      final game = _game();
      _run(game, 20);

      expect(game.rhythm, greaterThan(0.9));
    });

    // D'nin can alıcı noktası: hız ile isabet ayrı iki beceri. Mash etmek
    // cadence'i tavana çıkarır (çabuk yetişirsin) ama ritmi sıfırda bırakır
    // (pencere dar kalır).
    test('mash cadence\'i tavana çıkarır ama ritmi sıfırda bırakır', () {
      final game = _game();
      _run(game, 30, gap: 0.05);

      expect(game.cadence, greaterThan(0.9));
      expect(game.rhythm, lessThan(0.05));
    });

    test('hedeften çok yavaş basmak da ritmi yükseltmez', () {
      final game = _game();
      _run(game, 15, gap: 0.55);

      expect(game.rhythm, lessThan(0.05));
    });

    test('yanlış ayak ritmi yarıya düşürür', () {
      final game = _game();
      _run(game, 16);
      final before = game.rhythm;

      game.step(game.lastSide!);

      expect(game.rhythm, closeTo(before / 2, 1e-9));
    });
  });

  group('pencere', () {
    test('yüksek ritim geniş, sıfır ritim dar pencere açar', () {
      final steady = _game();
      _runToWindow(steady);

      final mashed = _game();
      _runToWindow(mashed, gap: 0.05);

      expect(steady.phase, TacklePhase.window);
      expect(mashed.phase, TacklePhase.window);
      expect(steady.windowDuration, greaterThan(mashed.windowDuration));
      expect(steady.windowDuration, closeTo(TackleGame.maxWindow, 0.05));
      expect(mashed.windowDuration, closeTo(TackleGame.minWindow, 0.05));
    });

    test('pencere genişliği açılışta donar', () {
      final game = _game();
      _runToWindow(game);
      final frozen = game.windowDuration;

      // Ritmi sonradan yıkmak açık pencereyi daraltmamalı: derece tek bir ana
      // bağlı kalsın.
      game.step(game.lastSide!);
      game.advance(0.05);

      expect(game.windowDuration, frozen);
    });

    test('pencerenin merkezi great, kenarı good', () {
      expect(_commitAt(_game(), 0.5), ShotGrade.great);
      expect(_commitAt(_game(), 0.9), ShotGrade.good);
      expect(_commitAt(_game(), 0.0), ShotGrade.good);
    });

    test('pencerenin dolması fail', () {
      final game = _game();
      _runToWindow(game);
      game.advance(game.windowDuration + 0.01);

      expect(game.grade, ShotGrade.fail);
      expect(game.phase, TacklePhase.done);
    });

    test('yaklaşırken dalmak erken dalıştır, fail', () {
      final game = _game();
      _run(game, 4);
      expect(game.phase, TacklePhase.closing);

      game.commit();

      expect(game.grade, ShotGrade.fail);
    });
  });

  group('durum çarpanları', () {
    test('windowScale pencereyi orantılı ölçekler', () {
      final normal = _game();
      _runToWindow(normal);

      final narrow = _game(windowScale: 0.5);
      _runToWindow(narrow);

      expect(narrow.windowDuration, closeTo(normal.windowDuration * 0.5, 1e-9));
    });

    test('closeScale kovalama süresini değiştirir', () {
      final normal = _game();
      _runToWindow(normal);

      final slow = _game(closeScale: 0.5);
      _runToWindow(slow);

      expect(slow.phase, TacklePhase.window);
      expect(slow.elapsed, greaterThan(normal.elapsed));
      // Çarpan yalnızca kovalamaya dokunur; pencere ritimden gelmeye devam eder.
      expect(slow.windowDuration, closeTo(normal.windowDuration, 0.05));
    });
  });

  group('sonuç', () {
    test('pencerede dalmak oturumu bitirir', () {
      final game = _game();
      final grade = _commitAt(game, 0.5);

      expect(grade, ShotGrade.great);
      expect(game.phase, TacklePhase.done);
      expect(game.result.drill, TrainingDrill.tackling);
    });

    test('tutan müdahale başarı sayılır', () {
      final game = _game();
      _commitAt(game, 0.9);

      expect(game.succeeded, isTrue);
      expect(game.result.outcome, TrainingOutcome.success);
      expect(game.result.detail, ShotGrade.good.label);
    });

    test('kaçan müdahale başarısızlık sayılır', () {
      final game = _game();
      _runToWindow(game);
      game.advance(game.windowDuration + 0.01);

      expect(game.succeeded, isFalse);
      expect(game.result.outcome, TrainingOutcome.failure);
      expect(game.result.detail, ShotGrade.fail.label);
    });

    test('skor derecenin ağırlığı', () {
      final great = _game();
      _commitAt(great, 0.5);
      expect(great.result.score, closeTo(1.0, 1e-9));

      final good = _game();
      _commitAt(good, 0.9);
      expect(good.result.score, closeTo(0.6, 1e-9));

      final early = _game();
      _run(early, 4);
      early.commit();
      expect(early.result.score, 0);
    });

    test('koşmayı bırakınca süre dolar ve adam kaçar', () {
      final game = _game();
      game.step(RunSide.left);

      // Tek adımdan sonra basmayı bırak: cadence sönüyor, mesafe kapanmıyor.
      for (var i = 0; i < 60 * 20 && !game.finished; i++) {
        game.advance(1 / 60);
      }

      expect(game.finished, isTrue);
      expect(game.timedOut, isTrue);
      expect(game.grade, ShotGrade.fail);
      expect(game.result.detail, 'Süre doldu');
      expect(game.result.score, 0);
    });

    test('onFinished tam bir kez çağrılır', () {
      var calls = 0;
      final game = _game(onFinished: (_) => calls++);
      _commitAt(game, 0.5);

      for (var i = 0; i < 500; i++) {
        game.advance(1 / 60);
      }

      expect(calls, 1);
    });

    test('bitişten sonra basışlar hiçbir şeyi değiştirmez', () {
      final game = _game();
      _commitAt(game, 0.5);
      final grade = game.grade;
      final steps = game.steps;

      game.step(RunSide.left);
      game.step(RunSide.right);
      game.commit();
      game.advance(1);

      expect(game.grade, grade);
      expect(game.steps, steps);
      expect(game.phase, TacklePhase.done);
    });
  });
}
