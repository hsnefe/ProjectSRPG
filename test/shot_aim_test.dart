import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';

const _size = Size(360, 600);

/// A game with no widget behind it. Nothing the aim or the outcome touches
/// reads `size`, so the whole outcome table can be driven from here.
ShotGame _game({
  required double cameraAngle,
  required double aimLateral,
  required double aimDepth,
  double power = 1.0,
  double spin = 0,
  double loft = 0,
}) {
  return ShotGame(onStateChanged: () {})
    ..cameraAngle = cameraAngle
    ..aimLateral = aimLateral
    ..aimDepth = aimDepth
    ..power = power
    ..spin = spin
    ..loft = loft;
}

/// Aims at an absolute world point from wherever the camera happens to face.
ShotGame _aimingAt(
  double wx,
  double wy, {
  required double cameraAngle,
  double power = 1.0,
  double spin = 0,
  double loft = 0,
}) {
  final p = PitchProjector(size: _size, cameraAngle: cameraAngle);
  return _game(
    cameraAngle: cameraAngle,
    aimLateral: p.lateralOf(wx, wy),
    aimDepth: p.depthOf(wx, wy),
    power: power,
    spin: spin,
    loft: loft,
  );
}

void main() {
  group('camera space to world', () {
    test('is the inverse of the forward rotation', () {
      for (final angle in [0.0, 0.6, -1.2, math.pi, 2.4]) {
        final p = PitchProjector(size: _size, cameraAngle: angle);
        for (final w in [(x: 0.4, y: 0.9), (x: -1.5, y: -0.3), (x: 1.6, y: 1.0)]) {
          final back = PitchProjector.cameraToWorld(
            p.lateralOf(w.x, w.y),
            p.depthOf(w.x, w.y),
            angle,
          );

          expect(back.x, closeTo(w.x, 1e-9), reason: 'angle $angle, point $w');
          expect(back.y, closeTo(w.y, 1e-9), reason: 'angle $angle, point $w');
        }
      }
    });
  });

  group('aim reach', () {
    test('every player can be aimed at from the bearing facing them', () {
      for (final t in ShotTarget.all) {
        final angle = PitchProjector.angleToward(t.x, t.y);
        final p = PitchProjector(size: _size, cameraAngle: angle);

        expect(
          p.lateralOf(t.x, t.y).abs(),
          lessThanOrEqualTo(ShotWorld.maxAimLateral),
          reason: t.label,
        );
        expect(
          p.depthOf(t.x, t.y),
          inInclusiveRange(ShotWorld.minAimDepth, ShotWorld.maxAimDepth),
          reason: t.label,
        );
      }
    });

    test('the reticle cannot be carried off the screen', () {
      // An aim you cannot see is not an aim, so the reach has to stay inside
      // what the projection shows.
      const p = PitchProjector(size: _size);

      expect(p.groundY(ShotWorld.maxAimDepth), greaterThan(0));
      expect(p.groundY(ShotWorld.minAimDepth), lessThan(_size.height));

      for (var d = ShotWorld.minAimDepth;
          d <= ShotWorld.maxAimDepth;
          d += 0.05) {
        final limit = math.min(
          ShotWorld.maxAimLateral,
          p.visibleLateral(d) * 0.97,
        );
        final edge = p.projectCamera(limit, d, 0);

        expect(edge.dx, greaterThan(0), reason: 'depth $d');
        expect(edge.dx, lessThan(_size.width), reason: 'depth $d');
      }
    });

    test('the reach beats the old one-unit cap across the pitch', () {
      // The complaint: the reticle used to be pinned to lateral = aimX * depth
      // with |aimX| <= 1, so at the goal line it could not get past one unit —
      // under a third of a 3.2-unit pitch.
      const p = PitchProjector(size: _size);
      const atGoalLine = 1.0;
      final limit = math.min(
        ShotWorld.maxAimLateral,
        p.visibleLateral(atGoalLine) * 0.97,
      );

      expect(limit, greaterThan(1.5));
      expect(limit, greaterThan(PitchLines.penaltyHalfWidth));
    });

    test('a team mate off to the side is out of the old one-unit cap', () {
      // Facing the goal, the left wing sits 0.9 units sideways at 0.55 depth.
      // The old model could only place the reticle at lateral = aimX * depth,
      // with |aimX| <= 1, so it could never get further out than 0.55 there.
      const p = PitchProjector(size: _size);
      final lateral = p.lateralOf(ShotTarget.leftWing.x, ShotTarget.leftWing.y);
      final depth = p.depthOf(ShotTarget.leftWing.x, ShotTarget.leftWing.y);

      expect(lateral.abs(), greaterThan(depth));
      expect(lateral.abs(), lessThanOrEqualTo(ShotWorld.maxAimLateral));
    });
  });

  group('outcome comes from where the ball actually goes', () {
    test('curling it away from where the keeper commits scores', () {
      // The keeper leaves exactly when the ball does and dives to the line he
      // can read, so beating him means bending it off that line.
      final game = _aimingAt(
        0.30,
        PitchLines.goalLineY,
        cameraAngle: 0,
        spin: 0.5,
      )..launch();

      expect(game.judge(), 'GOL!');
    });

    test('the same shot without the curve is saved', () {
      final game = _aimingAt(0.30, PitchLines.goalLineY, cameraAngle: 0)
        ..launch();

      expect(game.judge(), 'KURTARIŞ');
    });

    test('a shot down the middle is saved', () {
      final game = _aimingAt(0, PitchLines.goalLineY, cameraAngle: 0)..launch();

      expect(game.judge(), 'KURTARIŞ');
    });

    test('aiming outside the post puts it out', () {
      final game = _aimingAt(
        ShotWorld.goalHalfWidth + 0.3,
        PitchLines.goalLineY,
        cameraAngle: 0,
      )..launch();

      expect(game.judge(), 'AUT');
    });

    test('a lofted shot clears the bar', () {
      final game = _aimingAt(
        0.30,
        PitchLines.goalLineY,
        cameraAngle: 0,
        loft: 1,
      )..launch();

      expect(game.judge(), 'ÜSTTEN AUT');
    });

    test('facing the goal, a pass to the wing is a pass', () {
      // The regression the whole change exists for: standing in a shooting
      // position used to mean every ball was judged against the goal.
      final game = _aimingAt(
        ShotTarget.leftWing.x,
        ShotTarget.leftWing.y,
        cameraAngle: 0,
      )..launch();

      expect(game.judge(), 'PAS TUTTU');
    });

    test('facing the goal, a pass to the full back is a pass', () {
      final game = _aimingAt(
        ShotTarget.rightBack.x,
        ShotTarget.rightBack.y,
        cameraAngle: 0,
      )..launch();

      expect(game.judge(), 'PAS TUTTU');
    });

    test('turned around, the back pass still works', () {
      final game = _aimingAt(
        ShotTarget.backPass.x,
        ShotTarget.backPass.y,
        cameraAngle: math.pi,
      )..launch();

      expect(game.judge(), 'PAS TUTTU');
    });

    test('a ball into open space reaches nobody', () {
      // Clear of everyone, and short enough that the overshoot cannot carry it
      // over the goal line either — blast it wide and far and it is out, not
      // into space.
      final game = _aimingAt(-1.5, 0.3, cameraAngle: 0)..launch();

      expect(game.judge(), 'BOŞLUĞA');
    });

    test('a wide blast that runs over the line is out, not into space', () {
      final game = _aimingAt(-1.5, 0.9, cameraAngle: 0)..launch();

      expect(game.judge(), 'AUT');
    });

    test('the keeper only commits when the ball is coming at him', () {
      final pass = _aimingAt(
        ShotTarget.leftWing.x,
        ShotTarget.leftWing.y,
        cameraAngle: 0,
      )..launch();
      final shot = _aimingAt(0.30, PitchLines.goalLineY, cameraAngle: 0)
        ..launch();

      expect(pass.keeperReachAt(pass.timeToTarget), 0);
      expect(shot.keeperReachAt(shot.timeToTarget).abs(), greaterThan(0));
    });
  });

  group('flight', () {
    test('the ball arrives on the aim point when nothing bends it', () {
      const target = (x: -0.7, y: 0.8);
      final game = _aimingAt(target.x, target.y, cameraAngle: 0.5)..launch();

      final landing = game.worldAt(game.timeToTarget);

      expect(landing.x, closeTo(target.x, 1e-9));
      expect(landing.y, closeTo(target.y, 1e-9));
    });

    test('spin bends it off the aim point', () {
      const target = (x: 0.0, y: 0.9);
      final straight = _aimingAt(target.x, target.y, cameraAngle: 0)..launch();
      final curled = _aimingAt(target.x, target.y, cameraAngle: 0, spin: 1)
        ..launch();

      final a = straight.worldAt(straight.timeToTarget);
      final b = curled.worldAt(curled.timeToTarget);

      expect((b.x - a.x).abs(), greaterThan(0.05));
    });

    test('getting under the ball lifts it', () {
      const target = (x: 0.0, y: 0.9);
      final driven = _aimingAt(target.x, target.y, cameraAngle: 0)..launch();
      final lofted = _aimingAt(target.x, target.y, cameraAngle: 0, loft: 1)
        ..launch();

      expect(driven.heightAt(driven.timeToTarget), closeTo(0, 1e-9));
      expect(
        lofted.heightAt(lofted.timeToTarget),
        closeTo(ShotWorld.maxAimHeight, 1e-9),
      );
    });
  });
}
