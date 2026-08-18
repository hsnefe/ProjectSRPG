import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/training_result.dart';

const _size = Size(360, 600);

/// A scored game with no widget behind it. `finishFlight` is safe to call
/// headlessly — the banner it would add is skipped when nothing is mounted.
ShotGame _game(
  ShotMode mode, {
  void Function(TrainingResult)? onFinished,
}) =>
    ShotGame(
      mode: mode,
      onStateChanged: () {},
      onFinished: onFinished,
    );

/// Takes one attempt at an absolute world point and resolves it.
void _attempt(
  ShotGame game,
  double wx,
  double wy, {
  double spin = 0,
  double loft = 0,
}) {
  if (game.phase == ShotPhase.result) game.reset();

  final p = PitchProjector(size: _size, cameraAngle: game.cameraAngle);
  game
    ..aimLateral = p.lateralOf(wx, wy)
    ..aimDepth = p.depthOf(wx, wy)
    ..power = 1.0
    ..spin = spin
    ..loft = loft
    ..launch();
  game.finishFlight();
}

/// A goal. The keeper leaves when the ball does, so beating him takes curve —
/// a ball struck flat at the same spot is saved.
void _goalAttempt(ShotGame game) =>
    _attempt(game, 0.30, PitchLines.goalLineY, spin: 0.5);

/// Wide of the post: a resolved attempt that scores nothing in either mode.
void _missAttempt(ShotGame game) =>
    _attempt(game, ShotWorld.goalHalfWidth + 0.5, PitchLines.goalLineY);

/// A caught pass to the left wing, which is what a pass drill faces. It needs
/// height — flat along the ground a rival reads it and steps in.
void _catchableAttempt(ShotGame game) => _attempt(
      game,
      ShotTarget.leftWing.x,
      ShotTarget.leftWing.y,
      loft: 0.6,
    );

void main() {
  group('the mode only picks a success criterion', () {
    test('each mode scores exactly one outcome label', () {
      expect(ShotMode.shot.successLabel, 'GOL!');
      expect(ShotMode.pass.successLabel, 'PAS TUTTU');
      expect(ShotMode.free.successLabel, isNull);
    });

    test('a pass drill starts facing a team mate, not the goal', () {
      final game = _game(ShotMode.pass);
      expect(game.facing, Facing.left);
      expect(ShotTarget.inFrontOf(game.facing), ShotTarget.leftWing);
    });

    test('a shot drill starts facing the goal', () {
      expect(_game(ShotMode.shot).facing, Facing.forward);
    });

    test('a goal scores in a shot drill', () {
      final game = _game(ShotMode.shot);
      _goalAttempt(game);

      expect(game.result, 'GOL!');
      expect(game.made, 1);
    });

    test('a caught pass scores in a pass drill', () {
      final game = _game(ShotMode.pass);
      _catchableAttempt(game);

      expect(game.result, 'PAS TUTTU');
      expect(game.made, 1);
    });

    test('a caught pass is still just a pass in a shot drill', () {
      // Reachable without turning: from a shooting position you can put the
      // ball into a team mate instead. It resolves as a pass, and a shot drill
      // does not pay for it.
      final game = _game(ShotMode.shot);
      _attempt(game, ShotTarget.rightBack.x, ShotTarget.rightBack.y);

      expect(game.result, 'PAS TUTTU');
      expect(game.made, 0);
      expect(game.attempts, 1, reason: 'it still burns an attempt');
    });

    test('a goal would not pay in a pass drill', () {
      final game = _game(ShotMode.pass);
      game.result = 'GOL!';

      expect(game.lastAttemptSucceeded, isFalse);
    });
  });

  group('the session', () {
    test('two of three passes the drill', () {
      TrainingResult? finished;
      final game = _game(ShotMode.shot, onFinished: (r) => finished = r);

      _goalAttempt(game);
      _goalAttempt(game);
      _missAttempt(game);

      expect(game.attempts, ShotGame.attemptsPerSession);
      expect(finished?.outcome, TrainingOutcome.success);
      expect(finished?.drill, TrainingDrill.shot);
      expect(finished?.detail, '2/3 gol');
    });

    test('one of three fails it', () {
      TrainingResult? finished;
      final game = _game(ShotMode.shot, onFinished: (r) => finished = r);

      _goalAttempt(game);
      _missAttempt(game);
      _missAttempt(game);

      expect(finished?.outcome, TrainingOutcome.failure);
      expect(finished?.detail, '1/3 gol');
    });

    test('a pass session reports itself as one', () {
      TrainingResult? finished;
      final game = _game(ShotMode.pass, onFinished: (r) => finished = r);
      for (var i = 0; i < ShotGame.attemptsPerSession; i++) {
        _catchableAttempt(game);
      }

      expect(finished?.drill, TrainingDrill.pass);
      expect(finished?.detail, '3/3 isabetli pas');
    });

    test('onFinished fires once, on the last attempt', () {
      var calls = 0;
      final game = _game(ShotMode.shot, onFinished: (_) => calls++);

      _goalAttempt(game);
      expect(calls, 0);
      _goalAttempt(game);
      expect(calls, 0);
      _goalAttempt(game);
      expect(calls, 1);
    });

    test('free mode never finishes, however many flights resolve', () {
      var calls = 0;
      final game = ShotGame(onStateChanged: () {}, onFinished: (_) => calls++);
      for (var i = 0; i < 8; i++) {
        _goalAttempt(game);
      }

      expect(calls, 0);
      expect(game.attempts, 0);
    });
  });

  group('reset versus restart', () {
    test('reset lines up the next attempt without clearing the tally', () {
      final game = _game(ShotMode.shot);
      _goalAttempt(game);
      expect(game.attempts, 1);

      game.reset();
      expect(game.attempts, 1, reason: 'otherwise a session never ends');
      expect(game.phase, ShotPhase.aim);
    });

    test('handleTap in the result phase keeps the tally too', () {
      final game = _game(ShotMode.shot);
      _goalAttempt(game);
      game.handleTap(Offset.zero);

      expect(game.phase, ShotPhase.aim);
      expect(game.attempts, 1);
    });

    test('restartSession zeroes it', () {
      final game = _game(ShotMode.shot);
      _goalAttempt(game);
      game.restartSession();

      expect(game.attempts, 0);
      expect(game.made, 0);
    });
  });

  group('turning', () {
    test('a drill cannot be turned away from its bearing', () {
      for (final mode in [ShotMode.shot, ShotMode.pass]) {
        final game = _game(mode);
        final facing = game.facing;

        game.turnTo(Facing.back);
        expect(game.facing, facing, reason: '$mode should ignore the compass');
      }
    });

    test('the prototype still turns', () {
      final game = ShotGame(onStateChanged: () {});
      game.turnTo(Facing.back);
      expect(game.facing, Facing.back);
    });
  });
}
