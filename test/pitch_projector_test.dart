import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/pitch_projector.dart';

const _size = Size(360, 600);

void main() {
  group('camera rotation', () {
    test('facing the goal leaves world coordinates untouched', () {
      const p = PitchProjector(size: _size);

      expect(p.depthOf(0, 1), closeTo(1, 1e-9));
      expect(p.lateralOf(0.4, 1), closeTo(0.4, 1e-9));
    });

    test('turning fully around puts the goal behind the camera', () {
      final p = PitchProjector(size: _size, cameraAngle: math.pi);

      expect(p.depthOf(0, 1), closeTo(-1, 1e-9));
      expect(p.isPointVisible(p.depthOf(0, 1)), isFalse);
    });

    test('a backward target comes into view once the camera turns', () {
      const back = (x: 0.05, y: -0.75);

      const facingGoal = PitchProjector(size: _size);
      expect(facingGoal.isPointVisible(facingGoal.depthOf(back.x, back.y)),
          isFalse);

      final turned = PitchProjector(
        size: _size,
        cameraAngle: PitchProjector.angleToward(back.x, back.y),
      );
      expect(turned.isPointVisible(turned.depthOf(back.x, back.y)), isTrue);
    });

    test('facing a target puts it dead ahead at its true distance', () {
      for (final t in [
        (x: 0.0, y: 1.0),
        (x: -0.9, y: 0.55),
        (x: 0.95, y: 0.15),
        (x: 0.05, y: -0.75),
      ]) {
        final angle = PitchProjector.angleToward(t.x, t.y);
        final p = PitchProjector(size: _size, cameraAngle: angle);
        final distance = math.sqrt(t.x * t.x + t.y * t.y);

        expect(p.lateralOf(t.x, t.y), closeTo(0, 1e-9),
            reason: 'target ($t) should be centred');
        expect(p.depthOf(t.x, t.y), closeTo(distance, 1e-9),
            reason: 'target ($t) should sit at its real distance');
      }
    });

    test('rotation preserves distance from the camera', () {
      const wx = 0.7;
      const wy = 0.3;
      final expected = math.sqrt(wx * wx + wy * wy);

      for (final angle in [0.0, 0.6, 1.9, math.pi, 4.4]) {
        final p = PitchProjector(size: _size, cameraAngle: angle);
        final d = p.depthOf(wx, wy);
        final l = p.lateralOf(wx, wy);
        expect(math.sqrt(d * d + l * l), closeTo(expected, 1e-9));
      }
    });
  });

  group('projection', () {
    test('height moves the point up the screen, never down', () {
      const p = PitchProjector(size: _size);

      final ground = p.projectCamera(0, 1, 0);
      final lofted = p.projectCamera(0, 1, ShotWorld.crossbarHeight);

      expect(lofted.dy, lessThan(ground.dy));
      expect(lofted.dx, closeTo(ground.dx, 1e-9));
    });

    test('distant points render smaller and nearer the horizon', () {
      const p = PitchProjector(size: _size);

      expect(p.scale(1), lessThan(p.scale(0)));
      expect(p.groundY(1), lessThan(p.groundY(0)));
      expect(p.groundY(0), closeTo(p.baseY, 1e-9));
      expect(p.groundY(1), closeTo(p.horizonY, 1e-9));
    });

    test('extended geometry is culled earlier than point objects', () {
      const p = PitchProjector(size: _size);
      const between = (PitchProjector.nearPlane + 0.02) / 2;

      expect(p.isVisible(between), isFalse);
      expect(p.isPointVisible(between), isTrue);
    });
  });
}
