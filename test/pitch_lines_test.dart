import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';

const _size = Size(360, 600);

void main() {
  group('segment clipping', () {
    test('a segment entirely behind the camera is dropped', () {
      const p = PitchProjector(size: _size);

      expect(
        p.projectGroundSegment((x: -1, y: -0.5), (x: 1, y: -0.5)),
        isNull,
      );
    });

    test('a segment inside the band is projected untouched', () {
      const p = PitchProjector(size: _size);
      const a = (x: -0.5, y: 0.4);
      const b = (x: 0.5, y: 0.9);

      final segment = p.projectGroundSegment(a, b);
      final expected = (p.projectWorld(a.x, a.y, 0), p.projectWorld(b.x, b.y, 0));

      expect(segment, isNotNull);
      expect(segment!.$1.dx, closeTo(expected.$1.dx, 1e-9));
      expect(segment.$1.dy, closeTo(expected.$1.dy, 1e-9));
      expect(segment.$2.dx, closeTo(expected.$2.dx, 1e-9));
      expect(segment.$2.dy, closeTo(expected.$2.dy, 1e-9));
    });

    test('a segment running past the camera starts at the ground near plane', () {
      const p = PitchProjector(size: _size);

      // A touchline: it reaches from behind the camera to the goal line.
      final segment = p.projectGroundSegment(
        (x: 1, y: PitchLines.backY),
        (x: 1, y: PitchLines.goalLineY),
      );

      expect(segment, isNotNull);
      expect(
        segment!.$1.dy,
        closeTo(p.groundY(PitchProjector.groundNearPlane), 1e-9),
      );
      // The grass has to reach under the ball, which stands at depth 0.
      expect(segment.$1.dy, greaterThan(p.baseY));
    });

    test('the far corner survives a diagonal camera', () {
      // Regression: clipping at depth 1 deleted this corner, so the markings
      // vanished from whichever corner the camera turned toward. horizonY is
      // only where depth 1 lands — ground past it is still on screen.
      final p = PitchProjector(size: _size, cameraAngle: math.pi / 4);
      const corner = (x: PitchLines.halfWidth, y: PitchLines.goalLineY);
      expect(p.depthOf(corner.x, corner.y), greaterThan(1));

      final segment = p.projectGroundSegment(
        (x: -PitchLines.halfWidth, y: PitchLines.goalLineY),
        corner,
      );

      expect(segment, isNotNull);
      expect(segment!.$2.dy, lessThan(p.horizonY));
      expect(p.projectWorld(corner.x, corner.y, 0).dy, closeTo(segment.$2.dy, 1e-9));
    });

    test('a segment reaching past the far plane is cut off screen', () {
      const p = PitchProjector(size: _size);
      // Straight along the camera axis, so depth runs the full length.
      final segment = p.projectGroundSegment((x: 0, y: 0), (x: 0, y: 4));

      expect(segment, isNotNull);
      expect(segment!.$2.dy, closeTo(p.groundY(PitchProjector.farPlane), 1e-9));
      // Whatever it cuts is above the top edge, so nothing visible is lost.
      expect(segment.$2.dy, lessThan(0));
    });

    test('clipped ends always land inside the depth band', () {
      for (final angle in [0.0, -0.8, 0.9, math.pi, 2.5]) {
        final p = PitchProjector(size: _size, cameraAngle: angle);
        for (final side in [-1.0, 1.0]) {
          final segment = p.projectGroundSegment(
            (x: PitchLines.halfWidth * side, y: PitchLines.backY),
            (x: PitchLines.halfWidth * side, y: PitchLines.goalLineY),
          );
          if (segment == null) continue;

          // groundY falls as depth grows, so the band inverts into a dy range.
          for (final end in [segment.$1, segment.$2]) {
            expect(
              end.dy,
              lessThanOrEqualTo(
                p.groundY(PitchProjector.groundNearPlane) + 1e-9,
              ),
              reason: 'angle $angle, side $side',
            );
            expect(
              end.dy,
              greaterThanOrEqualTo(p.groundY(PitchProjector.farPlane) - 1e-9),
              reason: 'angle $angle, side $side',
            );
          }
        }
      }
    });
  });

  group('projection is projective', () {
    test('collinear ground points stay collinear on screen', () {
      // Why drawing a clipped segment with a single straight drawLine is
      // correct: the perspective divide shares one affine denominator between
      // both screen axes, so lines map to lines. Midpoints do not survive,
      // which is why this checks collinearity rather than the midpoint.
      final p = PitchProjector(size: _size, cameraAngle: 0.55);
      const a = (x: -0.5, y: 0.6);
      const b = (x: 0.9, y: 0.95);

      final pa = p.projectWorld(a.x, a.y, 0);
      final pb = p.projectWorld(b.x, b.y, 0);

      for (final t in [0.1, 0.37, 0.5, 0.82]) {
        final mid = p.projectWorld(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          0,
        );
        final cross = (pb.dx - pa.dx) * (mid.dy - pa.dy) -
            (pb.dy - pa.dy) * (mid.dx - pa.dx);
        expect(cross, closeTo(0, 1e-6), reason: 'bent at t=$t');
      }
    });
  });

  group('polygon clipping', () {
    test('a band straddling the near plane keeps a drawable polygon', () {
      const p = PitchProjector(size: _size);
      const w = PitchLines.halfWidth;

      final corners = p.projectGroundPolygon([
        (x: -w, y: -0.6),
        (x: w, y: -0.6),
        (x: w, y: 0.5),
        (x: -w, y: 0.5),
      ]);

      expect(corners, hasLength(4));
      for (final corner in corners) {
        expect(
          corner.dy,
          lessThanOrEqualTo(p.groundY(PitchProjector.groundNearPlane) + 1e-9),
        );
      }
    });

    test('a band fully behind the camera yields nothing', () {
      final p = PitchProjector(size: _size, cameraAngle: math.pi);
      const w = PitchLines.halfWidth;

      final corners = p.projectGroundPolygon([
        (x: -w, y: 0.7),
        (x: w, y: 0.7),
        (x: w, y: 1.0),
        (x: -w, y: 1.0),
      ]);

      expect(corners, isEmpty);
    });

    test('an untouched band keeps its four corners', () {
      const p = PitchProjector(size: _size);
      const w = PitchLines.halfWidth;

      final corners = p.projectGroundPolygon([
        (x: -w, y: 0.3),
        (x: w, y: 0.3),
        (x: w, y: 0.6),
        (x: -w, y: 0.6),
      ]);

      expect(corners, hasLength(4));
    });
  });

  group('marking geometry', () {
    test('the boxes nest inside each other and inside the touchlines', () {
      expect(ShotWorld.goalHalfWidth, lessThan(PitchLines.goalAreaHalfWidth));
      expect(
        PitchLines.goalAreaHalfWidth,
        lessThan(PitchLines.penaltyHalfWidth),
      );
      expect(PitchLines.penaltyHalfWidth, lessThan(PitchLines.halfWidth));

      expect(PitchLines.goalAreaDepth, lessThan(PitchLines.penaltySpotDepth));
      expect(PitchLines.penaltySpotDepth, lessThan(PitchLines.penaltyDepth));
    });

    test('the penalty arc pokes out in front of the box', () {
      const reach = PitchLines.penaltySpotY - PitchLines.penaltyFrontY;

      expect(reach, greaterThan(0));
      expect(PitchLines.penaltyArcRadius, greaterThan(reach));

      // ...but not so far that it reaches back behind the ball, where the
      // ground clip would cut it open.
      const nearest = PitchLines.penaltySpotY - PitchLines.penaltyArcRadius;
      expect(nearest, greaterThan(0));
    });

    test('the touchlines leave the frame beside the player', () {
      // The whole point of the pitch being 3.2 units wide: seeing both
      // touchlines converge to a point makes it read as a toy.
      const p = PitchProjector(size: _size);
      final edge = p.projectWorld(PitchLines.halfWidth, 0, 0);

      expect(edge.dx, greaterThan(_size.width));
    });

    test('the mowing bands divide the pitch evenly', () {
      const length = PitchLines.goalLineY - PitchLines.backY;
      final bands = length / PitchLines.mowBandDepth;

      expect(bands, closeTo(bands.roundToDouble(), 1e-9));
      expect(bands.round().isEven, isTrue);
    });

    test('the pitch shows no cut edge at any bearing', () {
      // Every corner has to land either inside the band or off the top of the
      // screen — a corner clipped mid-screen is a visible truncation.
      for (final angle in [0.0, 0.7, math.pi / 4, 2.0, math.pi, -1.2]) {
        final p = PitchProjector(size: _size, cameraAngle: angle);
        for (final x in [-PitchLines.halfWidth, PitchLines.halfWidth]) {
          for (final y in [PitchLines.backY, PitchLines.goalLineY]) {
            final depth = p.depthOf(x, y);
            if (depth <= PitchProjector.farPlane) continue;
            expect(
              p.groundY(PitchProjector.farPlane),
              lessThan(0),
              reason: 'corner ($x, $y) at angle $angle is cut on screen',
            );
          }
        }
      }
    });
  });

  group('point objects fade out of frame', () {
    test('opacity ramps from nothing to solid', () {
      const p = PitchProjector(size: _size);

      expect(p.pointOpacity(-0.3), 0);
      expect(p.pointOpacity(0), 0);
      expect(p.pointOpacity(PitchProjector.pointFadeDepth), 1);
      expect(p.pointOpacity(3), 1);

      var previous = 0.0;
      for (var d = 0.0; d <= PitchProjector.pointFadeDepth; d += 0.02) {
        final o = p.pointOpacity(d);
        expect(o, greaterThanOrEqualTo(previous));
        previous = o;
      }
    });

    test('a player culled at the near plane is still inside the viewport', () {
      // Why the fade exists. There is no field of view, so as the camera swings
      // past a player their screen x converges on a bounded offset instead of
      // running off the edge — culling at isPointVisible blinks them out in
      // plain sight. Every target and the keeper hit that.
      // The goal is not one of these — TargetsComponent skips it and draws the
      // frame instead.
      final standing = [
        for (final t in ShotTarget.all)
          if (!t.isGoal) (label: t.label, x: t.x, y: t.y),
        (label: 'keeper', x: 0.0, y: 0.97),
      ];

      const barelyVisible = 0.021;
      for (final o in standing) {
        // Turn until the object sits just inside the cull threshold.
        final distance = math.sqrt(o.x * o.x + o.y * o.y);
        final offAxis = math.acos((barelyVisible / distance).clamp(-1.0, 1.0));
        final p = PitchProjector(
          size: _size,
          cameraAngle: PitchProjector.angleToward(o.x, o.y) + offAxis,
        );

        final depth = p.depthOf(o.x, o.y);
        expect(depth, closeTo(barelyVisible, 1e-9), reason: o.label);
        expect(p.isPointVisible(depth), isTrue, reason: o.label);

        final screenX = p.projectWorld(o.x, o.y, 0).dx;
        expect(screenX, greaterThan(0), reason: o.label);
        expect(screenX, lessThan(_size.width), reason: o.label);

        // ...and it is nearly transparent there, so the cull cannot be seen.
        expect(p.pointOpacity(depth), lessThan(0.06), reason: o.label);
      }
    });

    test('the keeper is culled by geometry, not by which target is picked', () {
      const keeper = (x: 0.0, y: 0.97);

      for (final facing in Facing.values) {
        final p = PitchProjector(size: _size, cameraAngle: facing.angle);
        final depth = p.depthOf(keeper.x, keeper.y);
        final guarding = ShotTarget.inFrontOf(facing)?.isGoal ?? false;

        expect(
          p.isPointVisible(depth),
          guarding,
          reason: 'facing ${facing.name}: the goal is either in view or not, '
              'and the keeper follows the camera either way',
        );
      }
    });
  });
}
