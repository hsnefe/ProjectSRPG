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
  ShotTarget target = ShotTarget.goal;

  /// Camera facing, and the angle it is easing toward after a target switch.
  double cameraAngle = 0;
  double desiredAngle = 0;

  // Aim (phase 1)
  Offset? _dragStart;
  double aimX = 0;
  double lift = 0;

  // Strike (phase 2)
  double power = 0;
  double spin = 0;
  double ringT = 0;

  // Flight (phase 3)
  double flightT = 0;
  double _vx = 0;
  double _vy = 0;
  double _vz = 0;
  double flightDuration = 0;
  double keeperX = 0;

  String? result;

  late final BallComponent ball;

  Size get screenSize => Size(size.x, size.y);

  PitchProjector get projector =>
      PitchProjector(size: screenSize, cameraAngle: cameraAngle);

  /// Distance to the arrival plane, so a farther target genuinely takes a
  /// longer, flatter shot instead of being a reskin of the same one.
  double get targetDistance => target.distance;

  double get timeToTarget => _vy == 0 ? 0 : targetDistance / _vy;

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
    final delta = _shortestAngle(desiredAngle - cameraAngle);
    if (delta.abs() > 0.001) {
      cameraAngle += delta * math.min(1, dt * 6);
    }

    if (phase == ShotPhase.strike) {
      ringT += dt / 0.9;
      if (ringT > 1) ringT -= 1;
    }
  }

  static double _shortestAngle(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    if (r < -math.pi) r += 2 * math.pi;
    return r;
  }

  void selectTarget(ShotTarget next) {
    target = next;
    desiredAngle = next.facingAngle;
    reset();
  }

  // --- Input (driven by InputLayer) --------------------------------------

  void beginAim(Offset local) {
    if (phase != ShotPhase.aim) return;
    _dragStart = local;
  }

  void updateAim(Offset local) {
    if (phase != ShotPhase.aim || _dragStart == null) return;
    final delta = local - _dragStart!;
    aimX = (delta.dx / (size.x * 0.30)).clamp(-1.0, 1.0);
    lift = (-delta.dy / (size.y * 0.22)).clamp(0.0, 1.0);
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
  /// horizontal offset sets curve. Full power when the ring lines up with the
  /// ball's edge.
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

    _launch();
  }

  void _launch() {
    _vy = ShotWorld.baseDepthSpeed * power;
    final tg = targetDistance / _vy;
    // Solve the parabola that reaches the desired height at the arrival plane.
    final targetHeight = lift * ShotWorld.maxAimHeight;
    _vz = (targetHeight + 0.5 * ShotWorld.gravity * tg * tg) / tg;
    _vx = aimX * _vy;

    flightT = 0;
    keeperX = 0;
    flightDuration = tg + 0.55;
    phase = ShotPhase.flight;
    result = null;
    onStateChanged();
  }

  // --- Trajectory (camera space: lateral, depth, height) -----------------

  double lateralAt(double t) =>
      _vx * t + spin * ShotWorld.curveStrength * t * t;

  double depthAt(double t) => _vy * t;

  double heightAt(double t) =>
      math.max(0, _vz * t - 0.5 * ShotWorld.gravity * t * t);

  double keeperReachAt(double t) {
    final diveTime = math.max(0.0, t - ShotWorld.keeperReaction);
    final maxTravel = diveTime * ShotWorld.keeperSpeed;
    final aim = aimX.clamp(-ShotWorld.keeperMaxX, ShotWorld.keeperMaxX);
    return aim.abs() <= maxTravel ? aim : maxTravel * aim.sign;
  }

  void finishFlight() {
    phase = ShotPhase.result;
    result ??= _judge();
    add(ResultBanner(result!));
    onStateChanged();
  }

  String _judge() {
    final tg = timeToTarget;
    final x = lateralAt(tg);
    final z = heightAt(tg);

    if (!target.isGoal) {
      final caught =
          x.abs() < ShotWorld.passCatchRadius && z < ShotWorld.passCatchHeight;
      return caught ? 'PAS TUTTU' : 'PAS KAÇTI';
    }

    const r = ShotWorld.ballRadius;
    if (x.abs() > ShotWorld.goalHalfWidth + r) return 'AUT';
    if (z > ShotWorld.crossbarHeight + r) return 'ÜSTTEN AUT';
    if (x.abs() > ShotWorld.goalHalfWidth - r ||
        z > ShotWorld.crossbarHeight - r) {
      return 'DİREK';
    }

    // Keeper reach: harder to get to high balls.
    final reach = z < 0.28 ? 0.15 : (z < 0.42 ? 0.07 : 0.0);
    if ((keeperReachAt(tg) - x).abs() < reach) return 'KURTARIŞ';

    return 'GOL!';
  }

  void reset() {
    phase = ShotPhase.aim;
    aimX = 0;
    lift = 0;
    power = 0;
    spin = 0;
    flightT = 0;
    keeperX = 0;
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

/// Grass, touchlines, penalty box and the goal frame.
class PitchComponent extends Component with HasGameReference<ShotGame> {
  @override
  int get priority => 0;

  @override
  void render(Canvas canvas) {
    final p = game.projector;
    _paintGrass(canvas, p);
    _paintGoal(canvas, p);
  }

  void _paintGrass(Canvas canvas, PitchProjector p) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, p.size.width, p.size.height),
      Paint()..color = _grassDark,
    );
    // Stripes that narrow with depth. They are drawn in camera space so they
    // stay put no matter which way the camera faces.
    const bands = 7;
    for (var i = 0; i < bands; i += 2) {
      final d0 = i / bands;
      final d1 = (i + 1) / bands;
      canvas.drawPath(
        Path()
          ..moveTo(0, p.groundY(d0))
          ..lineTo(p.size.width, p.groundY(d0))
          ..lineTo(p.size.width, p.groundY(d1))
          ..lineTo(0, p.groundY(d1))
          ..close(),
        Paint()..color = _grassLight,
      );
    }
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

    // The goal line reaches wider than the frame, so it needs its own check.
    if (p.isVisible(p.depthOf(-1, 1)) && p.isVisible(p.depthOf(1, 1))) {
      canvas.drawLine(
        p.projectWorld(-1, 1, 0),
        p.projectWorld(1, 1, 0),
        Paint()
          ..color = _lineColor
          ..strokeWidth = 1.2,
      );
    }
  }
}

/// Every option the player can pick, drawn wherever it actually is. Options
/// behind the camera are culled rather than hidden, so turning around reveals
/// them naturally.
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

      final selected = t == game.target;
      final feet = p.projectWorld(t.x, t.y, 0);
      final s = p.scale(depth);
      final h = 0.26 * p.zScale * s;
      final w = 0.16 * p.halfWidth * s;

      canvas.drawOval(
        Rect.fromCenter(center: feet, width: w * 1.6, height: w * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h),
          const Radius.circular(3),
        ),
        Paint()
          ..color = selected
              ? _success.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.55),
      );
    }
  }
}

/// Only guards the goal, and only when the camera is facing it.
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
    if (!game.target.isGoal) return;
    final p = game.projector;

    // The keeper stands on the goal line, so his absolute position follows
    // the lateral offset the dive has taken him to.
    const depthOnPitch = 0.97;
    final wx = game.keeperX;
    final wy = depthOnPitch;
    final depth = p.depthOf(wx, wy);
    if (!p.isPointVisible(depth)) return;

    final s = p.scale(depth);
    final feet = p.projectWorld(wx, wy, 0);
    final w = 0.20 * p.halfWidth * s;
    final h = 0.30 * p.zScale * s;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h),
        const Radius.circular(3),
      ),
      Paint()..color = _warning.withValues(alpha: 0.85),
    );
  }
}

/// Reticle plus the curve-free preview trajectory, shown while aiming.
class AimComponent extends Component with HasGameReference<ShotGame> {
  @override
  int get priority => 3;

  @override
  void render(Canvas canvas) {
    if (game.phase != ShotPhase.aim) return;
    if (game.aimX == 0 && game.lift == 0) return;

    final p = game.projector;
    final dist = game.targetDistance;
    final height = game.lift * ShotWorld.maxAimHeight;

    // Aim reticle: where the ball would cross the arrival plane.
    final target = p.projectCamera(game.aimX, dist, height);
    final reticle = Paint()
      ..color = _warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(target, 7, reticle);
    canvas.drawLine(target.translate(-11, 0), target.translate(11, 0), reticle);
    canvas.drawLine(target.translate(0, -11), target.translate(0, 11), reticle);

    final vy = ShotWorld.baseDepthSpeed;
    final tg = dist / vy;
    final vz = (height + 0.5 * ShotWorld.gravity * tg * tg) / tg;
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (var i = 1; i <= 16; i++) {
      final ts = tg * i / 16;
      final z = math.max(0.0, vz * ts - 0.5 * ShotWorld.gravity * ts * ts);
      canvas.drawCircle(
        p.projectCamera(game.aimX * vy * ts, vy * ts, z),
        1.8,
        dot,
      );
    }
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
