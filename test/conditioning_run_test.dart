import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/conditioning_game.dart';
import 'package:project_srpg/game/training_result.dart';

/// A game with no widget behind it. Every rule lives in [ConditioningGame
/// .advance] and none of it reads `size`, so the whole run can be driven from
/// here.
ConditioningGame _game({void Function(TrainingResult)? onFinished}) =>
    ConditioningGame(
      onStateChanged: () {},
      onFinished: onFinished ?? (_) {},
    );

/// Alternates [count] correct steps, starting on the left.
void _run(ConditioningGame game, int count, {double gap = 0.05}) {
  for (var i = 0; i < count; i++) {
    game.step(i.isEven ? RunSide.left : RunSide.right);
    game.advance(gap);
  }
}

void main() {
  group('starting', () {
    test('the first press is accepted on either side and starts the clock', () {
      for (final side in RunSide.values) {
        final game = _game();
        expect(game.phase, ConditioningPhase.ready);
        game.step(side);
        expect(game.phase, ConditioningPhase.running);
        expect(game.steps, 1);
      }
    });

    test('the clock does not move until the first press', () {
      final game = _game();
      game.advance(5);
      expect(game.elapsed, 0);
      expect(game.timeLeft.value, 1);
    });
  });

  group('alternating', () {
    test('alternating presses count', () {
      final game = _game();
      _run(game, 6);
      expect(game.steps, 6);
    });

    test('the same side twice does not count, and costs a stumble', () {
      final game = _game();
      game.step(RunSide.left);
      game.step(RunSide.left);

      expect(game.steps, 1);
      expect(game.stumbleLeft, ConditioningGame.stumbleTime);
    });

    test('presses during a stumble are swallowed entirely', () {
      final game = _game();
      game.step(RunSide.left);
      game.step(RunSide.left);

      game.step(RunSide.right);
      expect(game.steps, 1, reason: 'even the correct foot has to wait');
    });

    test('a wrong press leaves lastSide alone, so the owed button still works',
        () {
      final game = _game();
      game.step(RunSide.left);
      game.step(RunSide.left);
      expect(game.lastSide, RunSide.left);

      game.advance(ConditioningGame.stumbleTime + 0.01);
      game.step(RunSide.right);
      expect(game.steps, 2);
    });

    test('a wrong press cuts cadence', () {
      final game = _game();
      _run(game, 4);
      final before = game.cadence;

      game.step(game.lastSide!);
      expect(game.cadence, lessThan(before * 0.5));
    });
  });

  group('outcome', () {
    test('reaching the target early succeeds', () {
      TrainingResult? finished;
      final game = _game(onFinished: (r) => finished = r);
      _run(game, ConditioningGame.targetSteps, gap: 0.02);

      expect(game.phase, ConditioningPhase.done);
      expect(finished?.outcome, TrainingOutcome.success);
      expect(finished?.drill, TrainingDrill.conditioning);
      expect(finished?.detail, '24/24 adım');
    });

    test('running out of time with too few steps fails', () {
      TrainingResult? finished;
      final game = _game(onFinished: (r) => finished = r);
      _run(game, 4);
      for (var t = 0.0; t < ConditioningGame.runDuration; t += 0.05) {
        game.advance(0.05);
      }

      expect(game.phase, ConditioningPhase.done);
      expect(finished?.outcome, TrainingOutcome.failure);
      expect(finished?.score, lessThan(1));
    });

    test('onFinished fires exactly once, however long the loop runs', () {
      var calls = 0;
      final game = _game(onFinished: (_) => calls++);
      _run(game, ConditioningGame.targetSteps, gap: 0.02);
      for (var i = 0; i < 500; i++) {
        game.advance(0.05);
      }

      expect(calls, 1);
    });

    test('presses after the run change nothing', () {
      final game = _game();
      _run(game, ConditioningGame.targetSteps, gap: 0.02);
      final steps = game.steps;

      game.step(RunSide.left);
      game.step(RunSide.right);
      expect(game.steps, steps);
    });
  });

  group('cadence and the clock', () {
    test('cadence rises with presses, decays with time, and stays in 0..1', () {
      final game = _game();
      _run(game, 12, gap: 0.01);
      expect(game.cadence, greaterThan(0.5));
      expect(game.cadence, lessThanOrEqualTo(1.0));

      game.advance(5);
      expect(game.cadence, 0);
    });

    test('timeLeft falls monotonically from 1 to 0 and never goes negative',
        () {
      final game = _game();
      game.step(RunSide.left);

      var previous = game.timeLeft.value;
      for (var i = 0; i < 400; i++) {
        game.advance(0.05);
        expect(game.timeLeft.value, lessThanOrEqualTo(previous));
        expect(game.timeLeft.value, greaterThanOrEqualTo(0));
        previous = game.timeLeft.value;
      }
      expect(previous, 0);
    });
  });

  group('the time bar never shows seconds', () {
    test('colour is the only urgency cue, and it goes green-amber-red', () {
      expect(conditioningBarColor(0.9), const Color(0xFF3DDC97));
      expect(conditioningBarColor(0.4), const Color(0xFFF5A623));
      expect(conditioningBarColor(0.1), const Color(0xFFE5484D));
    });

    test('the warning colour starts exactly at warnFraction', () {
      expect(
        conditioningBarColor(ConditioningGame.warnFraction),
        const Color(0xFFE5484D),
      );
      expect(
        conditioningBarColor(ConditioningGame.warnFraction + 0.01),
        isNot(const Color(0xFFE5484D)),
      );
    });
  });
}
