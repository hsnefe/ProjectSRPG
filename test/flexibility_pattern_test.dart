import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/flexibility_game.dart';
import 'package:project_srpg/game/training_result.dart';

/// A game with no widget behind it. Every rule lives in [FlexibilityGame
/// .advance], [FlexibilityGame.begin]/[extend]/[end], none of which read
/// `size`, so the whole session can be driven from here. `seed` makes the
/// three patterns reproducible — the app itself never passes one.
FlexibilityGame _game({void Function(TrainingResult)? onFinished, int seed = 1}) =>
    FlexibilityGame(
      onStateChanged: () {},
      onFinished: onFinished ?? (_) {},
      seed: seed,
    );

/// The first tap's position is irrelevant — it only starts the demo. Rides
/// the demo out to `recalling`.
void _start(FlexibilityGame game) {
  game.begin(nodeUnit(0));
  while (game.phase == FlexPhase.showing) {
    game.advance(0.05);
  }
}

/// Draws pattern [patternIndex] node-for-node, correctly.
void _draw(FlexibilityGame game, int patternIndex) {
  final pattern = game.patterns[patternIndex];
  game.begin(nodeUnit(pattern.first));
  for (final node in pattern.skip(1)) {
    game.extend(nodeUnit(node));
  }
  game.end();
}

/// A deliberately wrong first tap on pattern 0, then rides out the feedback
/// flash and — if a life is left — the redo demo.
void _missAndAdvance(FlexibilityGame game) {
  final wrong = (game.patterns[0].first + 1) % 9;
  game.begin(nodeUnit(wrong));
  game.advance(FlexibilityGame.feedbackTime + 0.01);
  while (game.phase == FlexPhase.showing) {
    game.advance(0.05);
  }
}

/// Independent re-derivation of the "no jumping an unvisited node" rule, so
/// the property test isn't just checking the implementation against itself.
int? _midpointBetween(int a, int b) {
  final ar = a ~/ 3, ac = a % 3;
  final br = b ~/ 3, bc = b % 3;
  final dr = br - ar, dc = bc - ac;
  if (dr == 0 && dc == 0) return null;
  if (dr % 2 != 0 || dc % 2 != 0) return null;
  return (ar + dr ~/ 2) * 3 + (ac + dc ~/ 2);
}

void main() {
  group('geometry', () {
    test('gridRectFor is centered and square', () {
      final rect = gridRectFor(Vector2(400, 800));
      expect(rect.width, rect.height);
      expect(rect.center.dx, closeTo(200, 0.001));
      expect(rect.center.dy, closeTo(400, 0.001));
    });

    test('nodeAt finds the nearest node within hitRadius, else null', () {
      final game = _game();
      for (var i = 0; i < 9; i++) {
        expect(game.nodeAt(nodeUnit(i)), i);
      }
      expect(game.nodeAt(const Offset(0.22, 0.22)), isNull);
    });
  });

  group('the demo', () {
    test('shows all three patterns before recalling starts', () {
      final game = _game();
      game.begin(nodeUnit(0));
      expect(game.phase, FlexPhase.showing);
      expect(game.demoIndex, 0);

      while (game.phase == FlexPhase.showing) {
        game.advance(0.05);
      }

      expect(game.phase, FlexPhase.recalling);
      expect(game.recallIndex, 0);
      expect(game.stroke, isEmpty);
    });
  });

  group('judging a stroke', () {
    test('a wrong node ends the attempt immediately', () {
      final game = _game();
      _start(game);
      final wrong = (game.patterns[0].first + 1) % 9;

      game.begin(nodeUnit(wrong));

      expect(game.phase, FlexPhase.feedback);
      expect(game.lastAttemptOk, isFalse);
      expect(game.mistakes, 1);
    });

    test('lifting the finger before the pattern is complete is a miss', () {
      final game = _game();
      _start(game);
      final pattern = game.patterns[0];

      game.begin(nodeUnit(pattern[0]));
      game.extend(nodeUnit(pattern[1]));
      game.end();

      expect(game.phase, FlexPhase.feedback);
      expect(game.lastAttemptOk, isFalse);
      expect(game.mistakes, 1);
    });

    test('a mistake restarts from pattern one with the same three patterns',
        () {
      final game = _game();
      _start(game);
      final before = game.patterns.map(List<int>.from).toList();

      _missAndAdvance(game);

      expect(game.mistakes, 1);
      expect(game.phase, FlexPhase.recalling);
      expect(game.recallIndex, 0);
      expect(game.patterns, before);
    });
  });

  group('the session', () {
    test('drawing all three patterns correctly succeeds', () {
      TrainingResult? finished;
      final game = _game(onFinished: (r) => finished = r);
      _start(game);

      for (var i = 0; i < FlexibilityGame.patternCount; i++) {
        expect(game.phase, FlexPhase.recalling, reason: 'pattern $i');
        _draw(game, i);
        expect(game.lastAttemptOk, isTrue, reason: 'pattern $i');
        game.advance(FlexibilityGame.feedbackTime + 0.01);
      }

      expect(game.phase, FlexPhase.done);
      expect(finished?.drill, TrainingDrill.flexibility);
      expect(finished?.outcome, TrainingOutcome.success);
      expect(finished?.score, 1.0);
      expect(finished?.detail, '3/3 desen · 0 hata');
    });

    test('one mistake still succeeds, at a lower score', () {
      TrainingResult? finished;
      final game = _game(onFinished: (r) => finished = r);
      _start(game);

      _missAndAdvance(game);
      for (var i = 0; i < FlexibilityGame.patternCount; i++) {
        _draw(game, i);
        game.advance(FlexibilityGame.feedbackTime + 0.01);
      }

      expect(finished?.outcome, TrainingOutcome.success);
      expect(finished?.score, 0.75);
      expect(finished?.detail, '3/3 desen · 1 hata');
    });

    test('three mistakes end the session as a failure', () {
      TrainingResult? finished;
      final game = _game(onFinished: (r) => finished = r);
      _start(game);

      for (var i = 0; i < FlexibilityGame.allowedMistakes; i++) {
        expect(game.phase, FlexPhase.recalling, reason: 'attempt $i');
        _missAndAdvance(game);
      }

      expect(game.phase, FlexPhase.done);
      expect(finished?.outcome, TrainingOutcome.failure);
      expect(finished?.score, 0);
    });

    test('onFinished fires exactly once', () {
      var calls = 0;
      final game = _game(onFinished: (_) => calls++);
      _start(game);
      for (var i = 0; i < FlexibilityGame.patternCount; i++) {
        _draw(game, i);
        game.advance(FlexibilityGame.feedbackTime + 0.01);
      }
      for (var i = 0; i < 200; i++) {
        game.advance(0.05);
      }

      expect(calls, 1);
    });

    test('input after the session is over changes nothing', () {
      final game = _game();
      _start(game);
      for (var i = 0; i < FlexibilityGame.patternCount; i++) {
        _draw(game, i);
        game.advance(FlexibilityGame.feedbackTime + 0.01);
      }
      expect(game.phase, FlexPhase.done);

      game.begin(nodeUnit(0));
      game.extend(nodeUnit(1));
      game.end();
      game.advance(1);

      expect(game.phase, FlexPhase.done);
    });
  });

  group('pattern generation', () {
    test(
        'patterns have the expected lengths, no repeated node, and never '
        'jump an unvisited midpoint', () {
      for (var seed = 0; seed < 200; seed++) {
        final game = _game(seed: seed);
        expect(game.patterns.length, FlexibilityGame.patternCount,
            reason: 'seed $seed');

        for (var i = 0; i < game.patterns.length; i++) {
          final pattern = game.patterns[i];
          expect(pattern.length, FlexibilityGame.patternLengths[i],
              reason: 'seed $seed pattern $i');
          expect(pattern.toSet().length, pattern.length,
              reason: 'seed $seed pattern $i repeats a node');

          final visited = <int>{pattern.first};
          for (var k = 1; k < pattern.length; k++) {
            final mid = _midpointBetween(pattern[k - 1], pattern[k]);
            if (mid != null) {
              expect(visited.contains(mid), isTrue,
                  reason:
                      'seed $seed pattern $i jumps ${pattern[k - 1]}→${pattern[k]} over unvisited $mid');
            }
            visited.add(pattern[k]);
          }
        }
      }
    });
  });
}
