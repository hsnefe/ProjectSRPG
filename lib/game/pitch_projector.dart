import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// World units: lateral (x) and height (z) are expressed in units of the
/// pitch's half-width. Ground coordinates are absolute and camera-independent:
/// +y points at the goal, +x points to the right of a player facing it.
class ShotWorld {
  static const goalHalfWidth = 0.55;
  static const crossbarHeight = 0.36;
  static const ballRadius = 0.055;
  static const gravity = 1.5;

  /// Max height the aim targets at the arrival plane.
  static const maxAimHeight = 0.52;

  /// Lateral curve offset coefficient, growing with t².
  static const curveStrength = 0.30;

  /// Depth speed at full power (units/second).
  static const baseDepthSpeed = 0.95;

  // Keeper
  static const keeperReaction = 0.28;
  static const keeperSpeed = 0.55;
  static const keeperMaxX = 0.62;

  /// A pass counts as received inside this radius of the target.
  static const passCatchRadius = 0.20;
  static const passCatchHeight = 0.38;

  // Aim reach, in world units from the ball.
  //
  // Depth is capped by what the projection can show, not by the pitch: ground
  // runs off the top of the screen at depth ~1.33 (see
  // [PitchProjector.farPlane]), and an aim you cannot see is not an aim. 1.2
  // reaches a little past the goal line, which is as far as anything worth
  // hitting gets. Lateral has a gameplay cap here and a second, depth-dependent
  // one from [PitchProjector.visibleLateral] so the reticle cannot leave frame.
  static const maxAimLateral = 1.75;
  static const minAimDepth = 0.15;
  static const maxAimDepth = 1.2;

  /// Where the reticle rests before the player drags: the goal line, when the
  /// camera is facing it.
  static const defaultAimDepth = 1.0;
}

/// Where the pitch markings sit, in the same world units.
///
/// Scale is set by [halfWidth]: 3.2 units span a 68 m pitch, so one world unit
/// is 21.25 m and the ball — at the origin, one unit out — is taking a 21 m
/// shot from 5 m outside the box. Depths follow real proportions from there.
///
/// Lateral extents cannot, because [ShotWorld.goalHalfWidth] is 0.55 = 23 m of
/// goalmouth, three times life size. It has to be, for the ball to read at this
/// zoom. Real boxes would be narrower than the goal they are supposed to
/// contain, so the two boxes are widened until they frame it. Everything else —
/// the pitch, the depths, the spot, the arc — is to scale.
class PitchLines {
  /// Half the pitch width. Wide enough that the touchlines leave the frame
  /// beside the player and only converge into view in the distance, which is
  /// what stops the pitch reading as a small lit patch in a dark void.
  static const halfWidth = 1.6;
  static const goalLineY = 1.0;

  /// Where the drawn pitch stops — the halfway line, 53 m out. It lands past
  /// the top edge of the screen at every bearing, so the pitch never shows a
  /// cut edge, and the halfway line itself is never worth drawing.
  static const backY = -1.5;

  /// Widened to clear the oversized goal rather than held to the real 0.59 and
  /// 0.27 of [halfWidth]. Depths are honest.
  static const penaltyHalfWidth = 1.10;
  static const penaltyDepth = 0.78;
  static const goalAreaHalfWidth = 0.72;
  static const goalAreaDepth = 0.26;

  static const penaltySpotDepth = 0.52;
  static const penaltyArcRadius = 0.43;
  static const cornerArcRadius = 0.05;

  /// Depth of one mowing band, about 5 m. Divides [backY]..[goalLineY] into 10.
  static const mowBandDepth = 0.25;

  static const penaltySpotY = goalLineY - penaltySpotDepth;
  static const penaltyFrontY = goalLineY - penaltyDepth;
  static const goalAreaFrontY = goalLineY - goalAreaDepth;
}

/// A point on the ground plane in absolute world coordinates. Distinct from
/// the [Offset]s the projector returns, which are screen pixels.
typedef GroundPoint = ({double x, double y});

/// Projects the three world axes onto the 2D screen.
///
/// The projection happens in two steps. First the absolute ground point is
/// rotated into camera space, so the camera can face any direction — this is
/// what makes a backward pass viewable without duplicating any geometry.
/// Then camera space is flattened with a perspective divide.
class PitchProjector {
  const PitchProjector({required this.size, this.cameraAngle = 0});

  final Size size;

  /// Direction the camera faces, in radians, measured from the +y axis
  /// (0 = looking at the goal, pi = looking back at your own half).
  final double cameraAngle;

  /// Perspective strength: the higher it is, the more distant objects shrink.
  static const k = 1.25;

  double get halfWidth => size.width * 0.46;
  double get baseY => size.height * 0.90;
  double get horizonY => size.height * 0.10;

  /// Deliberately exaggerating height: a 1:1 projection leaves the goal only
  /// ~26px tall and vertical motion unreadable. The standard pseudo-3D trick.
  double get zScale => halfWidth * 1.5;

  /// Depth of an absolute ground point along the camera's forward axis.
  double depthOf(double wx, double wy) =>
      wx * math.sin(cameraAngle) + wy * math.cos(cameraAngle);

  /// Lateral offset of an absolute ground point along the camera's right axis.
  double lateralOf(double wx, double wy) =>
      wx * math.cos(cameraAngle) - wy * math.sin(cameraAngle);

  /// The camera-facing angle that puts an absolute ground point dead ahead.
  static double angleToward(double wx, double wy) => math.atan2(wx, wy);

  /// A camera-space ground point back in absolute world coordinates.
  ///
  /// [depthOf] and [lateralOf] are a rotation, so this is its transpose. It is
  /// static and takes the angle because the shot decides its outcome from where
  /// the ball really ends up, and that question has nothing to do with a screen.
  static GroundPoint cameraToWorld(
    double lateral,
    double depth,
    double angle,
  ) =>
      (
        x: lateral * math.cos(angle) + depth * math.sin(angle),
        y: depth * math.cos(angle) - lateral * math.sin(angle),
      );

  double scale(double depth) => 1 / (1 + k * depth);

  /// depth (0..1) → depth compressed to 0..1 on screen.
  double _depthT(double depth) => depth * (1 + k) / (1 + k * depth);

  double groundY(double depth) =>
      baseY - (baseY - horizonY) * _depthT(depth);

  /// Projects a point already expressed in camera space.
  Offset projectCamera(double lateral, double depth, double z) {
    final s = scale(depth);
    return Offset(
      size.width / 2 + lateral * halfWidth * s,
      groundY(depth) - z * zScale * s,
    );
  }

  /// Projects an absolute ground point, rotating it into camera space first.
  Offset projectWorld(double wx, double wy, double z) =>
      projectCamera(lateralOf(wx, wy), depthOf(wx, wy), z);

  /// The widest lateral offset still inside the viewport at this depth.
  ///
  /// Close to the camera the ground fans out fast, so a fixed lateral cap would
  /// push the aim reticle off the side of the screen near the player while
  /// leaving most of the visible pitch unreachable further out.
  double visibleLateral(double depth) =>
      (size.width / 2) / (halfWidth * scale(depth));

  /// Near plane. Geometry closer than this is culled rather than drawn:
  /// as depth approaches zero, `groundY` races to the bottom of the screen
  /// while the far end of the same object sits near the horizon, smearing it
  /// across the whole viewport. Culling early is cheaper than clipping, and
  /// anything this close is swinging out of frame anyway.
  static const nearPlane = 0.2;

  /// For extended geometry (the goal frame, the goal line) — anything whose
  /// two ends can land at very different depths and smear between them.
  bool isVisible(double depth) => depth > nearPlane;

  /// For point-like objects (a player, the ball). A single small sprite has
  /// no far end to smear toward, so it only has to be in front of the camera.
  bool isPointVisible(double depth) => depth > 0.02;

  /// Depth at which a point-like object reaches full opacity.
  static const pointFadeDepth = 0.4;

  /// How solid a point-like object at this depth should be.
  ///
  /// There is no field of view to carry a player out of frame as the camera
  /// swings past them: `scale(depth)` tends to 1 and the lateral offset tends
  /// to the object's distance, so screen x converges on
  /// `width / 2 ± distance * halfWidth` — bounded. The back-pass marker ends
  /// up 60 px inside the left edge of a phone and the keeper 24 px, so culling
  /// them at [isPointVisible] blinked them out mid-screen. Fading over the last
  /// stretch of the swing reads as leaving instead.
  double pointOpacity(double depth) =>
      (depth / pointFadeDepth).clamp(0.0, 1.0);

  /// Far limit for clipped ground geometry, and deliberately generous.
  ///
  /// [horizonY] is not a horizon: it is merely where depth 1 lands. [groundY]
  /// keeps climbing past it, asymptoting at 1.8x the baseY–horizonY span, so
  /// ground stays on screen out to depth ~1.33. Clipping at 1.0 — as a first
  /// pass here did — deleted the whole far corner of the pitch and left the
  /// markings vanishing as the camera turned. This sits well past the top edge
  /// so the viewport does the cutting and nothing is visibly truncated; it only
  /// bounds the coordinates handed to the canvas.
  static const farPlane = 2.0;

  /// Near limit for *clipped* ground geometry, and deliberately not [nearPlane].
  ///
  /// [nearPlane] is 0.2 because it culls whole objects, and 0.2 already sits
  /// 60% of the way up the screen — clipping the pitch there leaves it floating
  /// above an empty strip. Exact clipping has nothing to smear, and the
  /// perspective divide only degenerates at depth `-1/k` (-0.8), so the ground
  /// can safely run a little past the camera line. It has to: the ball stands
  /// at depth 0, and the grass should reach under it rather than stop dead.
  static const groundNearPlane = -0.15;

  /// Clips a ground segment to the visible depth band and projects both ends,
  /// or returns null when none of it is visible.
  ///
  /// Culling whole segments the way [isVisible] does is not enough for pitch
  /// markings: a touchline runs past the camera, so one end is always behind
  /// it. Clipping is exact — depth is a dot product, hence affine along the
  /// segment — and the projection is projective, so a clipped straight line is
  /// still straight on screen and a single [Canvas.drawLine] is correct.
  (Offset, Offset)? projectGroundSegment(GroundPoint a, GroundPoint b) {
    final span = _visibleSpan(depthOf(a.x, a.y), depthOf(b.x, b.y));
    if (span == null) return null;
    final near = _lerpGround(a, b, span.t0);
    final far = _lerpGround(a, b, span.t1);
    return (
      projectWorld(near.x, near.y, 0),
      projectWorld(far.x, far.y, 0),
    );
  }

  /// Clips a convex ground polygon to the same band and projects it. Fewer
  /// than three points back means nothing of it is visible.
  List<Offset> projectGroundPolygon(List<GroundPoint> polygon) {
    var clipped = _clipToDepth(polygon, groundNearPlane, keepFarSide: true);
    clipped = _clipToDepth(clipped, farPlane, keepFarSide: false);
    if (clipped.length < 3) return const [];
    return [for (final p in clipped) projectWorld(p.x, p.y, 0)];
  }

  /// The sub-range of `[0, 1]` where a segment with endpoint depths [da]/[db]
  /// stays inside the band, or null when it never does.
  static ({double t0, double t1})? _visibleSpan(double da, double db) {
    final delta = db - da;
    if (delta.abs() < 1e-12) {
      final inside = da >= groundNearPlane && da <= farPlane;
      return inside ? (t0: 0.0, t1: 1.0) : null;
    }

    final tNear = (groundNearPlane - da) / delta;
    final tFar = (farPlane - da) / delta;
    final t0 = math.max(0.0, delta > 0 ? tNear : tFar);
    final t1 = math.min(1.0, delta > 0 ? tFar : tNear);
    return t0 <= t1 ? (t0: t0, t1: t1) : null;
  }

  /// Sutherland–Hodgman against one depth plane. One plane at a time keeps it
  /// to a dozen lines; a quad comes back with at most six corners.
  List<GroundPoint> _clipToDepth(
    List<GroundPoint> polygon,
    double limit, {
    required bool keepFarSide,
  }) {
    if (polygon.isEmpty) return const [];

    double side(GroundPoint p) {
      final d = depthOf(p.x, p.y) - limit;
      return keepFarSide ? d : -d;
    }

    final out = <GroundPoint>[];
    var previous = polygon.last;
    var previousSide = side(previous);
    for (final current in polygon) {
      final currentSide = side(current);
      final crosses = (currentSide >= 0) != (previousSide >= 0);
      if (crosses) {
        out.add(_lerpGround(
          previous,
          current,
          previousSide / (previousSide - currentSide),
        ));
      }
      if (currentSide >= 0) out.add(current);
      previous = current;
      previousSide = currentSide;
    }
    return out;
  }

  static GroundPoint _lerpGround(GroundPoint a, GroundPoint b, double t) =>
      (x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t);
}
