import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/bench_press_game.dart';
import 'package:project_srpg/game/training_result.dart';

/// No widget behind it: every rule lives in [BenchPressGame.advance] and
/// [BenchPressGame.press], neither of which reads `size`.
BenchPressGame _game({void Function(TrainingResult)? onFinished}) =>
    BenchPressGame(
      onStateChanged: () {},
      onFinished: onFinished ?? (_) {},
    );

/// Starts the session and takes one rep at [at] on the bar.
void _rep(BenchPressGame game, double at) {
  if (game.phase == BenchPhase.ready) game.press();
  game.markerT = at;
  game.press();
  // Ride out the lift animation so the next rep is live.
  game.advance(BenchPressGame.liftTime + 0.01);
}

void main() {
  group('sweep', () {
    test('the marker stays on the bar and reverses at both ends', () {
      final game = _game();
      game.press();

      var sawTop = false;
      var sawBottom = false;
      for (var i = 0; i < 5000; i++) {
        game.advance(0.001);
        expect(game.markerT, inInclusiveRange(0, 1));
        if (game.markerT > 0.98) sawTop = true;
        if (sawTop && game.markerT < 0.02) sawBottom = true;
      }

      expect(sawTop, isTrue);
      expect(sawBottom, isTrue, reason: 'it reflects rather than clamping');
    });

    test('the sweep speeds up and the zone narrows with each attempt', () {
      final game = _game();
      final speeds = <double>[];
      final halves = <double>[];

      for (var i = 0; i < 3; i++) {
        speeds.add(game.sweepSpeed);
        halves.add(game.zoneHalf);
        _rep(game, game.zoneCenter);
      }

      expect(speeds[1], greaterThan(speeds[0]));
      expect(speeds[2], greaterThan(speeds[1]));
      expect(halves[1], lessThan(halves[0]));
      expect(halves[2], lessThan(halves[1]));
    });

    test('the zone never shrinks past its floor', () {
      final game = _game();
      for (var i = 0; i < 40; i++) {
        expect(
          game.zoneHalf,
          greaterThanOrEqualTo(BenchPressGame.minZoneHalf),
        );
        game.markerT = 0.0;
        game.advance(0.001);
      }
    });

    test('two fresh games sweep the same zones', () {
      final a = _game();
      final b = _game();
      for (var i = 0; i < 4; i++) {
        expect(a.zoneCenter, b.zoneCenter);
        _rep(a, a.zoneCenter);
        _rep(b, b.zoneCenter);
      }
    });
  });

  group('judging a rep', () {
    test('pressing inside the zone is a clean rep', () {
      final game = _game();
      _rep(game, game.zoneCenter);

      expect(game.successes, 1);
      expect(game.failures, 0);
    });

    test('pressing outside the zone is a miss', () {
      final game = _game();
      _rep(game, game.zoneCenter + game.zoneHalf + 0.05);

      expect(game.successes, 0);
      expect(game.failures, 1);
    });

    test('presses during the lift are ignored', () {
      final game = _game();
      game.press();
      game.markerT = game.zoneCenter;
      game.press();

      expect(game.phase, BenchPhase.lifting);
      final attempts = game.attempts;
      game.press();
      expect(game.attempts, attempts);
      expect(game.earlyShake, greaterThan(0));
    });
  });

  group('the session', () {
    test('three clean reps pass', () {
      TrainingResult? finished;
      final game = _game(onFinished: (r) => finished = r);
      for (var i = 0; i < 3; i++) {
        _rep(game, game.zoneCenter);
      }

      expect(game.phase, BenchPhase.done);
      expect(finished?.outcome, TrainingOutcome.success);
      expect(finished?.drill, TrainingDrill.strength);
      expect(finished?.detail, '3 başarılı tekrar / 0 kaçak');
    });

    test('two misses end it as a failure', () {
      TrainingResult? finished;
      final game = _game(onFinished: (r) => finished = r);
      for (var i = 0; i < 2; i++) {
        _rep(game, (game.zoneCenter + 0.5) % 1);
      }

      expect(game.phase, BenchPhase.done);
      expect(finished?.outcome, TrainingOutcome.failure);
      expect(finished?.score, 0);
    });

    test('a session never runs past four reps', () {
      for (final pattern in [
        [true, true, true],
        [false, false],
        [true, false, true, false],
        [false, true, true, true],
      ]) {
        final game = _game();
        for (final ok in pattern) {
          if (game.phase == BenchPhase.done) break;
          _rep(game, ok ? game.zoneCenter : (game.zoneCenter + 0.5) % 1);
        }
        expect(game.attempts, lessThanOrEqualTo(4));
      }
    });

    test('presses after the session change nothing', () {
      final game = _game();
      for (var i = 0; i < 3; i++) {
        _rep(game, game.zoneCenter);
      }
      final attempts = game.attempts;

      game.press();
      game.advance(1);
      expect(game.attempts, attempts);
      expect(game.phase, BenchPhase.done);
    });

    test('onFinished fires exactly once', () {
      var calls = 0;
      final game = _game(onFinished: (_) => calls++);
      for (var i = 0; i < 3; i++) {
        _rep(game, game.zoneCenter);
      }
      for (var i = 0; i < 200; i++) {
        game.advance(0.05);
      }

      expect(calls, 1);
    });

    test('score rewards how close to the middle of the zone you pressed', () {
      final sharp = _game();
      final scrappy = _game();
      for (var i = 0; i < 3; i++) {
        _rep(sharp, sharp.zoneCenter);
        _rep(scrappy, scrappy.zoneCenter + scrappy.zoneHalf * 0.95);
      }

      expect(sharp.result.score, greaterThan(scrappy.result.score));
    });
  });
}
