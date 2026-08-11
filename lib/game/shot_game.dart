import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show Colors, Curves, TextStyle, FontWeight;

import 'package:project_srpg/game/pitch_projector.dart';

enum ShotPhase { aim, strike, flight, result }

/// The four bearings the player can turn to face. Nothing in the world is
/// rebuilt when this changes — it only drives the camera angle.
enum Facing {
  forward(0),
  right(math.pi / 2),
  back(math.pi),
  left(-math.pi / 2);

  const Facing(this.angle);

  final double angle;
}

/// A selectable destination. The player picks one, the camera turns to face
/// it, and the same two-phase shot mechanic plays out toward it — including
/// targets behind the player.
class ShotTarget {
  const ShotTarget({
    required this.label,
    required this.x,
    required this.y,
    this.isGoal = false,
  });

  final String label;
  final double x;
  final double y;
  final bool isGoal;

  double get distance => math.sqrt(x * x + y * y);
  double get facingAngle => PitchProjector.angleToward(x, y);

  static const goal = ShotTarget(label: 'Kale', x: 0, y: 1, isGoal: true);
  static const leftWing = ShotTarget(label: 'Sol kanat', x: -0.9, y: 0.55);
  static const rightBack = ShotTarget(label: 'Sağ bek', x: 0.95, y: 0.15);
  static const backPass = ShotTarget(label: 'Geri pas', x: 0.05, y: -0.75);

  static const all = [goal, leftWing, rightBack, backPass];

  /// Whatever stands closest to the given bearing, if anything does. The
  /// player turns to look somewhere; what is in front of them follows from
  /// the world, rather than being picked from a menu.
  static ShotTarget? inFrontOf(Facing facing) {
    ShotTarget? best;
    var bestDiff = double.infinity;
    for (final t in all) {
      final diff = ShotGame.shortestAngle(t.facingAngle - facing.angle).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = t;
      }
    }
    return bestDiff <= math.pi / 4 ? best : null;
  }
}

/// Flame port of the shot prototype.
///
/// The pseudo-3D projection stays hand-rolled — Flame's camera is genuinely
/// 2D and cannot do the perspective divide. What Flame contributes here is
/// the structure: one component per concern, each with its own update loop,
/// plus the effects system for the result banner.
class ShotGame extends FlameGame {
  ShotGame({required this.onStateChanged});

  /// Lets the surrounding Flutter UI rebuild its readout.
  final VoidCallback onStateChanged;

  ShotPhase phase = ShotPhase.aim;

  /// The bearing the player has turned to. The world does not change with it.
  Facing facing = Facing.forward;

  /// Live camera angle, and the angle it is easing toward after a turn.
  double cameraAngle = 0;
  double desiredAngle = 0;

  /// Whatever the player is currently looking at, derived from [facing].
  ShotTarget? get target => ShotTarget.inFrontOf(facing);

  // Aim (phase 1). A ground point in camera space, free of whatever the compass
  // happens to be facing — the ball goes where you point it and the outcome
  // follows from what is actually there.
  Offset? _dragStart;
  double aimLateral = 0;
  double aimDepth = ShotWorld.defaultAimDepth;

  // Strike (phase 2)
  double power = 0;
  double spin = 0;
  double loft = 0;
  double ringT = 0;

  // Flight (phase 3)
  double flightT = 0;
  double _vx = 0;
  double _vy = 0;
  double _vz = 0;
  double flightDuration = 0;
  double keeperX = 0;

  /// Where along the goal line the keeper commits to, fixed at launch. Zero
  /// when the shot never reaches the line, so he holds his ground for a pass.
  double _keeperTarget = 0;

  String? result;

  late final BallComponent ball;

  Size get screenSize => Size(size.x, size.y);

  PitchProjector get projector =>
      PitchProjector(size: screenSize, cameraAngle: cameraAngle);

  /// Time to the aim point. A farther aim genuinely takes a longer, flatter
  /// shot instead of being a reskin of the same one.
  double get timeToTarget => _vy == 0 ? 0 : aimDepth / _vy;

  double get strikeRadius => math.min(size.x * 0.17, 62.0);

  double get ringRadius => strikeRadius * (1.9 + (0.28 - 1.9) * ringT);

  @override
  Future<void> onLoad() async {
    addAll([
      PitchComponent(),
      TargetsComponent(),
      KeeperComponent(),
      AimComponent(),
      ball = BallComponent(),
      StrikeComponent(),
      InputLayer(),
    ]);
  }

  @override
  Color backgroundColor() => const Color(0xFF15251B);

  @override
  void update(double dt) {
    super.update(dt);

    // Ease the camera toward the selected target's bearing, normalising the
    // angle so the turn always takes the short way around. This is purely
    // visual, so it deliberately does not notify Flutter — Flame already
    // redraws every frame and the readout never shows the angle.
    final delta = shortestAngle(desiredAngle - cameraAngle);
    if (delta.abs() > 0.001) {
      cameraAngle += delta * math.min(1, dt * 6);
    }

    if (phase == ShotPhase.strike) {
      ringT += dt / 0.9;
      if (ringT > 1) ringT -= 1;
    }
  }

  static double shortestAngle(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    if (r < -math.pi) r += 2 * math.pi;
    return r;
  }

  /// Turn to a new bearing. Only the camera moves — the goal, the keeper and
  /// the teammates are the same objects they were before the turn.
  void turnTo(Facing next) {
    facing = next;
    desiredAngle = next.angle;
    reset();
  }

  // --- Input (driven by InputLayer) --------------------------------------

  void beginAim(Offset local) {
    if (phase != ShotPhase.aim) return;
    _dragStart = local;
  }

  /// Carries the reticle across the ground: sideways for direction, up and down
  /// for distance. Height is no longer set here — it comes out of where the boot
  /// meets the ball, in [_strike].
  void updateAim(Offset local) {
    if (phase != ShotPhase.aim || _dragStart == null) return;
    final delta = local - _dragStart!;

    final reach = ShotWorld.maxAimDepth - ShotWorld.minAimDepth;
    aimDepth = (ShotWorld.defaultAimDepth - delta.dy / (size.y * 0.34) * reach)
        .clamp(ShotWorld.minAimDepth, ShotWorld.maxAimDepth);

    // Two caps: the gameplay one, and whatever is still on screen at this
    // depth, kept just inside the edge.
    final limit = math.min(
      ShotWorld.maxAimLateral,
      projector.visibleLateral(aimDepth) * 0.97,
    );
    aimLateral =
        (delta.dx / (size.x * 0.32) * ShotWorld.maxAimLateral).clamp(-limit, limit);

    onStateChanged();
  }

  void endAim() {
    if (phase != ShotPhase.aim || _dragStart == null) return;
    _dragStart = null;
    phase = ShotPhase.strike;
    ringT = 0;
    onStateChanged();
  }

  void handleTap(Offset local) {
    if (phase == ShotPhase.strike) {
      _strike(local);
    } else if (phase == ShotPhase.result) {
      reset();
    }
  }

  /// Striking the ball: distance from the tap point to center reduces power,
  /// horizontal offset sets curve, and getting under it lifts it. Full power
  /// when the ring lines up with the ball's edge.
  void _strike(Offset local) {
    final center = projector.projectCamera(0, 0, 0);
    final offset = local - center;
    if (offset.distance > strikeRadius * 1.45) return;

    final timing = 1 -
        ((ringRadius - strikeRadius).abs() / (strikeRadius * 0.9))
            .clamp(0.0, 1.0);

    final normX = (offset.dx / strikeRadius).clamp(-1.0, 1.0);
    final normY = (offset.dy / strikeRadius).clamp(-1.0, 1.0);
    final offCenter = math.min(1.0, math.sqrt(normX * normX + normY * normY));

    power = (0.62 + 0.38 * timing) * (1 - 0.25 * offCenter);
    // Striking the right side of the ball curves it left.
    spin = -normX;
    // Under the ball lifts it; over the top keeps it driven. The power the loft
    // costs you is already priced in by offCenter.
    loft = normY.clamp(0.0, 1.0);

    launch();
  }

  /// Fires the ball at the aim point. Internal rather than private so the
  /// outcome table can be exercised without a game loop — nothing here reads
  /// [size].
  void launch() {
    _vy = ShotWorld.baseDepthSpeed * power;
    final tg = aimDepth / _vy;
    // Solve the parabola that reaches the desired height at the aim point.
    final targetHeight = loft * ShotWorld.maxAimHeight;
    _vz = (targetHeight + 0.5 * ShotWorld.gravity * tg * tg) / tg;
    // Without spin the ball lands exactly on the aim point; spin bends it off.
    _vx = (aimLateral / aimDepth) * _vy;

    flightT = 0;
    keeperX = 0;
    flightDuration = tg + 0.55;

    // The keeper reads your body shape, not the curve you put on it, so he
    // commits to the unspun line. Bending the ball away from where he goes is
    // the whole counterplay — send him to the real crossing point and he is
    // unbeatable, because he always leaves exactly when you do.
    _keeperTarget = _shotAtGoal() == null
        ? 0
        : _goalLineCrossing(withSpin: false)?.x.clamp(
              -ShotWorld.keeperMaxX,
              ShotWorld.keeperMaxX,
            ) ??
            0;

    phase = ShotPhase.flight;
    result = null;
    onStateChanged();
  }

  // --- Trajectory (camera space: lateral, depth, height) -----------------

  double lateralAt(double t) => _lateralAt(t, withSpin: true);

  /// The unspun line is what the keeper gets to read, so it needs a name.
  double _lateralAt(double t, {required bool withSpin}) =>
      _vx * t + (withSpin ? spin * ShotWorld.curveStrength * t * t : 0);

  double depthAt(double t) => _vy * t;

  double heightAt(double t) =>
      math.max(0, _vz * t - 0.5 * ShotWorld.gravity * t * t);

  double keeperReachAt(double t) {
    final diveTime = math.max(0.0, t - ShotWorld.keeperReaction);
    final maxTravel = diveTime * ShotWorld.keeperSpeed;
    final aim = _keeperTarget;
    return aim.abs() <= maxTravel ? aim : maxTravel * aim.sign;
  }

  /// Where the ball is in absolute world coordinates at time [t].
  GroundPoint worldAt(double t) =>
      PitchProjector.cameraToWorld(lateralAt(t), depthAt(t), cameraAngle);

  /// The first moment the ball crosses the goal line, or null if it never does.
  ///
  /// The path is not straight in world terms — spin adds a t² term and the
  /// camera can face anywhere — so it is sampled and then narrowed between the
  /// two samples that bracket the crossing, the same way the pitch arcs are
  /// drawn.
  ({double t, double x, double z})? _goalLineCrossing({bool withSpin = true}) {
    if (flightDuration <= 0) return null;

    GroundPoint at(double t) => PitchProjector.cameraToWorld(
          _lateralAt(t, withSpin: withSpin),
          depthAt(t),
          cameraAngle,
        );

    const samples = 180;
    var previousT = 0.0;
    var previousY = at(0).y;

    for (var i = 1; i <= samples; i++) {
      final t = flightDuration * i / samples;
      final y = at(t).y;
      if (y >= PitchLines.goalLineY) {
        final span = y - previousY;
        final f = span.abs() < 1e-12
            ? 0.0
            : (PitchLines.goalLineY - previousY) / span;
        final hit = previousT + (t - previousT) * f;
        return (t: hit, x: at(hit).x, z: heightAt(hit));
      }
      previousT = t;
      previousY = y;
    }
    return null;
  }

  /// Whoever the ball is aimed at, if anyone. Past two and a half catch radii
  /// it was not aimed at a person at all.
  ({ShotTarget player, double gap})? _receiver() {
    final landing = worldAt(timeToTarget);

    ShotTarget? nearest;
    var nearestGap = double.infinity;
    for (final t in ShotTarget.all) {
      if (t.isGoal) continue;
      final dx = t.x - landing.x;
      final dy = t.y - landing.y;
      final gap = math.sqrt(dx * dx + dy * dy);
      if (gap < nearestGap) {
        nearestGap = gap;
        nearest = t;
      }
    }

    if (nearest == null || nearestGap > ShotWorld.passCatchRadius * 2.5) {
      return null;
    }
    return (player: nearest, gap: nearestGap);
  }

  /// The crossing that counts, or null when this was not a shot at goal.
  ///
  /// The flight deliberately runs on past the aim point for the look of it, so a
  /// pass to a team mate would otherwise trundle across the goal line and be
  /// scored as a shot. Whoever gets to the ball first wins: a receiver standing
  /// on the aim point takes it before it can run on.
  ({double t, double x, double z})? _shotAtGoal() {
    final crossing = _goalLineCrossing();
    if (crossing == null) return null;
    if (crossing.t > timeToTarget && _receiver() != null) return null;
    return crossing;
  }

  void finishFlight() {
    phase = ShotPhase.result;
    result ??= judge();
    add(ResultBanner(result!));
    onStateChanged();
  }

  /// Reads the outcome off the ball's actual world path rather than off
  /// whichever target the compass had selected. That is what makes a pass to a
  /// team mate possible from a shooting position: aim at them and the ball never
  /// reaches the goal line, so it is judged as a pass.
  ///
  /// Internal rather than private so the outcome table can be tested directly.
  String judge() {
    const r = ShotWorld.ballRadius;

    final atGoal = _shotAtGoal();
    if (atGoal != null) {
      final x = atGoal.x;
      final z = atGoal.z;

      if (x.abs() > ShotWorld.goalHalfWidth + r) return 'AUT';
      if (z > ShotWorld.crossbarHeight + r) return 'ÜSTTEN AUT';
      if (x.abs() > ShotWorld.goalHalfWidth - r ||
          z > ShotWorld.crossbarHeight - r) {
        return 'DİREK';
      }

      // Keeper reach: harder to get to high balls.
      final reach = z < 0.28 ? 0.15 : (z < 0.42 ? 0.07 : 0.0);
      if ((keeperReachAt(atGoal.t) - x).abs() < reach) return 'KURTARIŞ';

      return 'GOL!';
    }

    final tg = timeToTarget;
    final receiver = _receiver();
    if (receiver != null) {
      final caught = receiver.gap < ShotWorld.passCatchRadius &&
          heightAt(tg) < ShotWorld.passCatchHeight;
      return caught ? 'PAS TUTTU' : 'PAS KAÇTI';
    }

    final landing = worldAt(tg);
    final inPlay = landing.x.abs() <= PitchLines.halfWidth &&
        landing.y <= PitchLines.goalLineY &&
        landing.y >= PitchLines.backY;
    return inPlay ? 'BOŞLUĞA' : 'AUT';
  }

  void reset() {
    phase = ShotPhase.aim;
    aimLateral = 0;
    aimDepth = ShotWorld.defaultAimDepth;
    power = 0;
    spin = 0;
    loft = 0;
    flightT = 0;
    keeperX = 0;
    _keeperTarget = 0;
    ringT = 0;
    result = null;
    _dragStart = null;
    children.whereType<ResultBanner>().forEach((c) => c.removeFromParent());
    onStateChanged();
  }
}

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

const _grassDark = Color(0xFF15251B);
const _grassLight = Color(0xFF1A2D20);
const _lineColor = Color(0x55FFFFFF);
const _accent = Color(0xFF1E6FD9);
const _success = Color(0xFF3DDC97);
const _warning = Color(0xFFF5A623);

/// A full-bleed component that receives gestures. Component-level input is
/// the modern Flame API — the deprecated game-level detectors would work too,
/// but this keeps input as just another node in the tree.
class InputLayer extends PositionComponent
    with HasGameReference<ShotGame>, TapCallbacks, DragCallbacks {
  Offset? _origin;

  @override
  int get priority => 20;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.handleTap(event.canvasPosition.toOffset());
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _origin = event.canvasPosition.toOffset();
    game.beginAim(_origin!);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game.updateAim(event.canvasEndPosition.toOffset());
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _origin = null;
    game.endAim();
  }
}

/// Grass, the markings and the goal frame.
///
/// Everything here is pinned to absolute world coordinates, so turning the
/// camera slides the pitch past you instead of dragging it along. That is what
/// makes the compass mean anything: without markings the only cue was the
/// grass, and the grass used to be painted in camera space.
class PitchComponent extends Component with HasGameReference<ShotGame> {
  @override
  int get priority => 0;

  @override
  void render(Canvas canvas) {
    final p = game.projector;
    _paintGrass(canvas, p);
    _paintMarkings(canvas, p);
    _paintGoal(canvas, p);
  }

  void _paintGrass(Canvas canvas, PitchProjector p) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, p.size.width, p.size.height),
      Paint()..color = _grassDark,
    );

    // Mowing bands, as world-space strips rather than screen-space stripes, so
    // they turn with the markings. Outside the touchlines the darker base
    // shows through, which is what makes the pitch read as a rectangle.
    const back = PitchLines.backY;
    const front = PitchLines.goalLineY;
    const w = PitchLines.halfWidth;
    final bands = ((front - back) / PitchLines.mowBandDepth).round();
    final paint = Paint()..color = _grassLight;

    for (var i = 0; i < bands; i += 2) {
      final y0 = back + (front - back) * i / bands;
      final y1 = back + (front - back) * (i + 1) / bands;
      final corners = p.projectGroundPolygon([
        (x: -w, y: y0),
        (x: w, y: y0),
        (x: w, y: y1),
        (x: -w, y: y1),
      ]);
      if (corners.length < 3) continue;

      final path = Path()..moveTo(corners.first.dx, corners.first.dy);
      for (final corner in corners.skip(1)) {
        path.lineTo(corner.dx, corner.dy);
      }
      canvas.drawPath(path..close(), paint);
    }
  }

  void _paintMarkings(Canvas canvas, PitchProjector p) {
    final paint = Paint()
      ..color = _lineColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const w = PitchLines.halfWidth;
    const front = PitchLines.goalLineY;
    const back = PitchLines.backY;

    // Touchlines and the goal line. There is no halfway line to draw: at this
    // scale it sits at [PitchLines.backY], past the top of the screen.
    _seg(canvas, p, paint, (x: -w, y: back), (x: -w, y: front));
    _seg(canvas, p, paint, (x: w, y: back), (x: w, y: front));
    _seg(canvas, p, paint, (x: -w, y: front), (x: w, y: front));

    _box(canvas, p, paint, PitchLines.penaltyHalfWidth, PitchLines.penaltyDepth);
    _box(
      canvas,
      p,
      paint,
      PitchLines.goalAreaHalfWidth,
      PitchLines.goalAreaDepth,
    );

    _paintPenaltySpot(canvas, p);
    _paintPenaltyArc(canvas, p, paint);

    // Corner arcs curl into the pitch, so each one starts a quarter turn back
    // from the corner it sits on.
    for (final side in [-1, 1]) {
      _arc(
        canvas,
        p,
        paint,
        centre: (x: w * side, y: front),
        radius: PitchLines.cornerArcRadius,
        from: side > 0 ? math.pi : -math.pi / 2,
        sweep: math.pi / 2,
        samples: 8,
      );
    }
  }

  /// A goal-side box: two sides running back from the goal line and the front
  /// line joining them. The fourth edge *is* the goal line, already drawn.
  void _box(
    Canvas canvas,
    PitchProjector p,
    Paint paint,
    double halfWidth,
    double depth,
  ) {
    final y = PitchLines.goalLineY - depth;
    for (final side in [-1, 1]) {
      _seg(
        canvas,
        p,
        paint,
        (x: halfWidth * side, y: PitchLines.goalLineY),
        (x: halfWidth * side, y: y),
      );
    }
    _seg(canvas, p, paint, (x: -halfWidth, y: y), (x: halfWidth, y: y));
  }

  void _paintPenaltySpot(Canvas canvas, PitchProjector p) {
    const spot = (x: 0.0, y: PitchLines.penaltySpotY);
    final depth = p.depthOf(spot.x, spot.y);
    if (!p.isPointVisible(depth)) return;

    canvas.drawCircle(
      p.projectWorld(spot.x, spot.y, 0),
      0.02 * p.halfWidth * p.scale(depth),
      Paint()
        ..color = _lineColor.withValues(
          alpha: _lineColor.a * p.pointOpacity(depth),
        ),
    );
  }

  /// Only the sliver of the arc that pokes out in front of the penalty area —
  /// the rest is inside the box and never drawn.
  void _paintPenaltyArc(Canvas canvas, PitchProjector p, Paint paint) {
    const radius = PitchLines.penaltyArcRadius;
    const reach = PitchLines.penaltySpotY - PitchLines.penaltyFrontY;
    if (radius <= reach) return;

    final half = math.acos(reach / radius);
    _arc(
      canvas,
      p,
      paint,
      centre: (x: 0.0, y: PitchLines.penaltySpotY),
      radius: radius,
      from: -math.pi / 2 - half,
      sweep: half * 2,
      samples: 16,
    );
  }

  /// Curves are the one thing the projection cannot draw exactly, so they get
  /// sampled. Pushing every sample pair through [_seg] means near and far
  /// clipping come for free, and the round cap hides the joins.
  void _arc(
    Canvas canvas,
    PitchProjector p,
    Paint paint, {
    required GroundPoint centre,
    required double radius,
    required double from,
    required double sweep,
    required int samples,
  }) {
    GroundPoint at(int i) {
      final a = from + sweep * i / samples;
      return (
        x: centre.x + radius * math.cos(a),
        y: centre.y + radius * math.sin(a),
      );
    }

    var previous = at(0);
    for (var i = 1; i <= samples; i++) {
      final current = at(i);
      _seg(canvas, p, paint, previous, current);
      previous = current;
    }
  }

  void _seg(
    Canvas canvas,
    PitchProjector p,
    Paint paint,
    GroundPoint a,
    GroundPoint b,
  ) {
    final segment = p.projectGroundSegment(a, b);
    if (segment == null) return;
    canvas.drawLine(segment.$1, segment.$2, paint);
  }

  void _paintGoal(Canvas canvas, PitchProjector p) {
    const gh = ShotWorld.goalHalfWidth;
    const cb = ShotWorld.crossbarHeight;

    // The goal is anchored in absolute world coordinates, so turning the
    // camera slides it off-screen instead of dragging it along.
    final depthL = p.depthOf(-gh, 1);
    final depthR = p.depthOf(gh, 1);
    if (!p.isVisible(depthL) || !p.isVisible(depthR)) return;

    final tl = p.projectWorld(-gh, 1, cb);
    final tr = p.projectWorld(gh, 1, cb);
    final bl = p.projectWorld(-gh, 1, 0);
    final br = p.projectWorld(gh, 1, 0);

    canvas.drawPath(
      Path()
        ..moveTo(tl.dx, tl.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(br.dx, br.dy)
        ..lineTo(bl.dx, bl.dy)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    final mesh = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 0.6;
    for (var i = 1; i < 8; i++) {
      final f = i / 8;
      canvas.drawLine(Offset.lerp(tl, tr, f)!, Offset.lerp(bl, br, f)!, mesh);
    }
    for (var i = 1; i < 4; i++) {
      final f = i / 4;
      canvas.drawLine(Offset.lerp(tl, bl, f)!, Offset.lerp(tr, br, f)!, mesh);
    }

    // Posts and crossbar
    final frame = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(bl, tl, frame);
    canvas.drawLine(br, tr, frame);
    canvas.drawLine(tl, tr, frame);
  }
}

/// Everyone on the pitch, drawn wherever they actually are. Players behind the
/// camera are culled rather than hidden, so turning around reveals them
/// naturally.
///
/// Nobody is highlighted: with the aim free of the compass there is no
/// "selected" player to mark, and any of them can be picked out by pointing the
/// reticle at them.
class TargetsComponent extends Component with HasGameReference<ShotGame> {
  @override
  int get priority => 1;

  @override
  void render(Canvas canvas) {
    final p = game.projector;
    for (final t in ShotTarget.all) {
      if (t.isGoal) continue;
      final depth = p.depthOf(t.x, t.y);
      if (!p.isPointVisible(depth)) continue;

      final o = p.pointOpacity(depth);
      final feet = p.projectWorld(t.x, t.y, 0);
      final s = p.scale(depth);
      final h = 0.26 * p.zScale * s;
      final w = 0.16 * p.halfWidth * s;

      canvas.drawOval(
        Rect.fromCenter(center: feet, width: w * 1.6, height: w * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.35 * o),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.55 * o),
      );
    }
  }
}

/// Stands on the goal line whenever the goal is in view.
///
/// Visibility comes from geometry, never from which target is selected.
/// [ShotGame.turnTo] flips `facing` in one frame while the camera eases over
/// the next half second, so gating the keeper on `target.isGoal` deleted him
/// from a shot the camera was still pointing at.
class KeeperComponent extends Component with HasGameReference<ShotGame> {
  @override
  int get priority => 2;

  @override
  void update(double dt) {
    if (game.phase == ShotPhase.flight) {
      game.keeperX = game.keeperReachAt(game.flightT);
    }
  }

  @override
  void render(Canvas canvas) {
    final p = game.projector;

    // The keeper stands on the goal line, so his absolute position follows
    // the lateral offset the dive has taken him to.
    const depthOnPitch = 0.97;
    final wx = game.keeperX;
    final wy = depthOnPitch;
    final depth = p.depthOf(wx, wy);
    if (!p.isPointVisible(depth)) return;

    final o = p.pointOpacity(depth);
    final s = p.scale(depth);
    final feet = p.projectWorld(wx, wy, 0);
    final w = 0.20 * p.halfWidth * s;
    final h = 0.30 * p.zScale * s;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h),
        const Radius.circular(3),
      ),
      Paint()..color = _warning.withValues(alpha: 0.85 * o),
    );
  }
}

/// The spot on the pitch the ball is aimed at, plus the line it will run along
/// to get there.
///
/// The reticle sits on the ground rather than hanging in the air, because
/// height is not decided until the strike — the player picks a place, then picks
/// how to hit it. It is drawn for the whole aim phase so the shot is legible
/// before the first drag.
class AimComponent extends Component with HasGameReference<ShotGame> {
  @override
  int get priority => 3;

  @override
  void render(Canvas canvas) {
    if (game.phase != ShotPhase.aim) return;

    final p = game.projector;
    final spot = p.projectCamera(game.aimLateral, game.aimDepth, 0);

    // Dotted run-up along the ground. Height would be a guess at this point.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 1; i < 16; i++) {
      final f = i / 16;
      canvas.drawCircle(
        p.projectCamera(game.aimLateral * f, game.aimDepth * f, 0),
        1.6,
        dot,
      );
    }

    // The reticle is flattened to sit on the grass, and shrinks with distance
    // the same way every other ground object does.
    final s = p.scale(game.aimDepth);
    final radius = math.max(4.0, 0.09 * p.halfWidth * s);
    final reticle = Paint()
      ..color = _warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawOval(
      Rect.fromCenter(
        center: spot,
        width: radius * 2,
        height: radius * 0.7,
      ),
      reticle,
    );
    canvas.drawLine(
      spot.translate(-radius * 1.5, 0),
      spot.translate(radius * 1.5, 0),
      reticle,
    );
    canvas.drawLine(
      spot.translate(0, -radius * 0.9),
      spot.translate(0, radius * 0.9),
      reticle,
    );
  }
}

/// The ball and its shadow. Owns the flight integration in its own update.
class BallComponent extends Component with HasGameReference<ShotGame> {
  @override
  int get priority => 4;

  @override
  void update(double dt) {
    if (game.phase != ShotPhase.flight) return;
    game.flightT += dt;
    if (game.flightT >= game.flightDuration) {
      game.flightT = game.flightDuration;
      game.finishFlight();
    }
  }

  @override
  void render(Canvas canvas) {
    final p = game.projector;

    if (game.phase == ShotPhase.strike) return;

    final flying =
        game.phase == ShotPhase.flight || game.phase == ShotPhase.result;
    final lateral = flying ? game.lateralAt(game.flightT) : 0.0;
    final depth = flying ? game.depthAt(game.flightT) : 0.0;
    final z = flying ? game.heightAt(game.flightT) : 0.0;

    _paintShadow(canvas, p, lateral, depth, z);

    final s = p.scale(depth);
    final center = p.projectCamera(lateral, depth, z);
    final r = ShotWorld.ballRadius * p.halfWidth * s;

    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// The shadow is drawn on the ground ignoring z — the real depth cue.
  void _paintShadow(
    Canvas canvas,
    PitchProjector p,
    double lateral,
    double depth,
    double z,
  ) {
    final s = p.scale(depth);
    final ground = Offset(
      p.size.width / 2 + lateral * p.halfWidth * s,
      p.groundY(depth),
    );
    final r = ShotWorld.ballRadius * p.halfWidth * s;
    // The shadow grows and fades as the ball rises.
    final spread = 1 + z * 1.2;
    final alpha = (0.45 / (1 + z * 3.5)).clamp(0.05, 0.45);

    canvas.drawOval(
      Rect.fromCenter(
        center: ground,
        width: r * 2 * spread,
        height: r * 0.85 * spread,
      ),
      Paint()..color = Colors.black.withValues(alpha: alpha),
    );
  }
}

/// Enlarged ball plus the shrinking timing ring, shown during the strike.
class StrikeComponent extends Component with HasGameReference<ShotGame> {
  @override
  int get priority => 5;

  @override
  void render(Canvas canvas) {
    if (game.phase != ShotPhase.strike) return;

    final p = game.projector;
    final center = p.projectCamera(0, 0, 0);
    final r = game.strikeRadius;

    canvas.drawCircle(
      center,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Center mark: full-power zone.
    canvas.drawCircle(
      center,
      r * 0.22,
      Paint()..color = _accent.withValues(alpha: 0.35),
    );
    // Curve axis
    canvas.drawLine(
      center.translate(-r * 0.8, 0),
      center.translate(r * 0.8, 0),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );

    final ring = game.ringRadius;
    final sweet = (ring - r).abs() < r * 0.18;
    canvas.drawCircle(
      center,
      ring,
      Paint()
        ..color = sweet ? _success : _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = sweet ? 3 : 2,
    );
  }
}

/// The result banner — the one place a Flame effect genuinely pays off,
/// since the pop-in is declarative instead of another hand-rolled tween.
class ResultBanner extends PositionComponent
    with HasGameReference<ShotGame> {
  ResultBanner(this.text) : super(anchor: Anchor.center, scale: Vector2.all(0.6));

  final String text;

  late final TextPaint _painter = TextPaint(
    style: TextStyle(
      color: text == 'GOL!' || text == 'PAS TUTTU'
          ? _success
          : const Color(0xFFE8EAED),
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
    ),
  );

  @override
  int get priority => 10;

  @override
  Future<void> onLoad() async {
    position = Vector2(game.size.x / 2, game.size.y * 0.42);
    add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.25, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final metrics = _painter.getLineMetrics(text);
    final w = metrics.width;
    final h = metrics.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w / 2 - 18, -h / 2 - 10, w + 36, h + 20),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    _painter.render(canvas, text, Vector2(-w / 2, -h / 2));
  }
}
