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
}

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
}
