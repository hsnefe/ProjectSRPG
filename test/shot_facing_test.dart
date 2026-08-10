import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/shot_game.dart';

void main() {
  group('facing', () {
    test('each bearing has exactly one thing in front of it', () {
      expect(ShotTarget.inFrontOf(Facing.forward), ShotTarget.goal);
      expect(ShotTarget.inFrontOf(Facing.left), ShotTarget.leftWing);
      expect(ShotTarget.inFrontOf(Facing.right), ShotTarget.rightBack);
      expect(ShotTarget.inFrontOf(Facing.back), ShotTarget.backPass);
    });

    test('every target is reachable from some bearing', () {
      final reached = Facing.values.map(ShotTarget.inFrontOf).toSet();
      expect(reached, containsAll(ShotTarget.all));
    });

    test('only the goal is guarded', () {
      expect(ShotTarget.inFrontOf(Facing.forward)?.isGoal, isTrue);
      for (final f in [Facing.left, Facing.right, Facing.back]) {
        expect(ShotTarget.inFrontOf(f)?.isGoal, isFalse);
      }
    });

    test('distance differs per bearing, so flight time does too', () {
      final goal = ShotTarget.inFrontOf(Facing.forward)!.distance;
      final back = ShotTarget.inFrontOf(Facing.back)!.distance;

      expect(goal, closeTo(1.0, 1e-9));
      expect(back, lessThan(goal));
    });

    test('a bearing with nothing within 45 degrees sees empty space', () {
      // Every real target sits near a cardinal, so a target list containing
      // only the goal must leave the other three bearings empty.
      for (final f in [Facing.left, Facing.right, Facing.back]) {
        final diff =
            ShotGame.shortestAngle(ShotTarget.goal.facingAngle - f.angle).abs();
        expect(diff, greaterThan(math.pi / 4));
      }
    });
  });

  group('shortestAngle', () {
    test('always takes the short way around', () {
      expect(ShotGame.shortestAngle(0), closeTo(0, 1e-9));
      expect(ShotGame.shortestAngle(math.pi / 2), closeTo(math.pi / 2, 1e-9));
      // Turning 350 degrees one way is really 10 degrees the other.
      expect(
        ShotGame.shortestAngle(2 * math.pi - 0.1),
        closeTo(-0.1, 1e-9),
      );
      expect(ShotGame.shortestAngle(3 * math.pi), closeTo(math.pi, 1e-9));
    });

    test('result never exceeds half a turn', () {
      for (var a = -10.0; a <= 10.0; a += 0.37) {
        expect(ShotGame.shortestAngle(a).abs(), lessThanOrEqualTo(math.pi));
      }
    });
  });
}
