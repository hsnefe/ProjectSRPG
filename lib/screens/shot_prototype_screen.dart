import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A two-phase shot prototype.
///
/// 1. Aim (flick): the drag vector's direction (x) and the target height
///    (lift) at the goal line.
/// 2. Strike (tap): where and when you tap the ball determines power and
///    curve. Near center + ring aligned with the ball's edge = max power.
///
/// Physics runs on 3 axes (x horizontal, y depth, z height); only the
/// rendering layer is squashed into 2D. The shadow is drawn on the ground
/// ignoring z, which is what makes the ball read as airborne.
enum _Phase { aim, strike, flight, result }

/// World units: x and z are in units of the pitch's half-width.
/// y (depth) 0 = the ball's start, 1 = the goal line.
class _World {
  static const goalHalfWidth = 0.55;
  static const crossbarHeight = 0.36;
  static const ballRadius = 0.055;
  static const gravity = 1.5;

  /// Max height the aim targets at the goal line.
  static const maxAimHeight = 0.52;

  /// Lateral curve offset coefficient, growing with t².
  static const curveStrength = 0.30;

  /// Depth speed at full power (units/second).
  static const baseDepthSpeed = 0.95;

  // Keeper
  static const keeperReaction = 0.28;
  static const keeperSpeed = 0.55;
  static const keeperMaxX = 0.62;
}

class ShotPrototypeScreen extends StatefulWidget {
  const ShotPrototypeScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _success = Color(0xFF3DDC97);
  static const _warning = Color(0xFFF5A623);

  @override
  State<ShotPrototypeScreen> createState() => _ShotPrototypeScreenState();
}

class _ShotPrototypeScreenState extends State<ShotPrototypeScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.aim;

  // --- Phase 1: aim ---
  Offset? _dragStart;
  double _aimX = 0;
  double _lift = 0;

  // --- Phase 2: strike ---
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  double _power = 0;
  double _spin = 0;

  // --- Phase 3: flight ---
  Ticker? _flight;
  double _t = 0;
  double _vx = 0;
  double _vy = 0;
  double _vz = 0;
  double _keeperX = 0;
  double _flightDuration = 0;

  String? _result;

  @override
  void dispose() {
    _ring.dispose();
    _flight?.dispose();
    super.dispose();
  }

  double get _timeToGoal => _vy == 0 ? 0 : 1 / _vy;

  // The keeper's guess: the straight-flight landing point, ignoring curve.
  // That's why curve is what fools the keeper.
  double get _keeperTarget => _aimX.clamp(-_World.keeperMaxX, _World.keeperMaxX);

  void _onPanStart(DragStartDetails d) {
    if (_phase != _Phase.aim) return;
    _dragStart = d.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (_phase != _Phase.aim || _dragStart == null) return;
    final delta = d.localPosition - _dragStart!;
    setState(() {
      _aimX = (delta.dx / (size.width * 0.30)).clamp(-1.0, 1.0);
      _lift = (-delta.dy / (size.height * 0.22)).clamp(0.0, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_phase != _Phase.aim || _dragStart == null) return;
    setState(() {
      _dragStart = null;
      _phase = _Phase.strike;
    });
    _ring.repeat();
  }

  /// Striking the ball: distance from the tap point to center reduces
  /// power, horizontal offset sets curve. Full power when the ring lines
  /// up with the ball's edge.
  void _onStrike(Offset local, Offset ballCenter, double ballRadius) {
    final offset = local - ballCenter;
    if (offset.distance > ballRadius * 1.45) return;

    final ringRadius = _ringRadius(ballRadius);
    final timing =
        1 - ((ringRadius - ballRadius).abs() / (ballRadius * 0.9)).clamp(0.0, 1.0);

    final normX = (offset.dx / ballRadius).clamp(-1.0, 1.0);
    final normY = (offset.dy / ballRadius).clamp(-1.0, 1.0);
    final offCenter = math.min(1.0, math.sqrt(normX * normX + normY * normY));

    _ring.stop();

    final power = (0.62 + 0.38 * timing) * (1 - 0.25 * offCenter);
    // Striking the right side of the ball curves it left.
    final spin = -normX;

    _launch(power: power, spin: spin);
  }

  void _launch({required double power, required double spin}) {
    final vy = _World.baseDepthSpeed * power;
    final tg = 1 / vy;
    // Solve the parabola that reaches the desired height at the goal line.
    final targetHeight = _lift * _World.maxAimHeight;
    final vz = (targetHeight + 0.5 * _World.gravity * tg * tg) / tg;

    setState(() {
      _power = power;
      _spin = spin;
      _vy = vy;
      _vx = _aimX * vy;
      _vz = vz;
      _t = 0;
      _keeperX = 0;
      _flightDuration = tg + 0.55;
      _phase = _Phase.flight;
      _result = null;
    });

    _flight?.dispose();
    _flight = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;

    // Keeper: after the reaction delay, slides toward the target at a capped speed.
    final diveTime = math.max(0.0, t - _World.keeperReaction);
    final maxTravel = diveTime * _World.keeperSpeed;
    final target = _keeperTarget;
    final keeperX = target.abs() <= maxTravel
        ? target
        : maxTravel * target.sign;

    if (t >= _flightDuration) {
      _flight?.stop();
      setState(() {
        _t = _flightDuration;
        _keeperX = keeperX;
        _phase = _Phase.result;
        _result ??= _judge();
      });
      return;
    }

    setState(() {
      _t = t;
      _keeperX = keeperX;
    });
  }

  double _xAt(double t) => _vx * t + _spin * _World.curveStrength * t * t;
  double _yAt(double t) => _vy * t;
  double _zAt(double t) =>
      math.max(0, _vz * t - 0.5 * _World.gravity * t * t);

  String _judge() {
    final tg = _timeToGoal;
    final x = _xAt(tg);
    final z = _zAt(tg);
    const r = _World.ballRadius;

    if (x.abs() > _World.goalHalfWidth + r) return 'AUT';
    if (z > _World.crossbarHeight + r) return 'ÜSTTEN AUT';
    if (x.abs() > _World.goalHalfWidth - r || z > _World.crossbarHeight - r) {
      return 'DİREK';
    }

    // Keeper reach: harder to get to high balls.
    final keeperXAtGoal = _keeperReachAt(tg);
    final reach = z < 0.28 ? 0.15 : (z < 0.42 ? 0.07 : 0.0);
    if ((keeperXAtGoal - x).abs() < reach) return 'KURTARIŞ';

    return 'GOL!';
  }

  double _keeperReachAt(double t) {
    final diveTime = math.max(0.0, t - _World.keeperReaction);
    final maxTravel = diveTime * _World.keeperSpeed;
    final target = _keeperTarget;
    return target.abs() <= maxTravel ? target : maxTravel * target.sign;
  }

  double _ringRadius(double ballRadius) =>
      ballRadius * (1.9 + (0.28 - 1.9) * _ring.value);

  void _reset() {
    _flight?.stop();
    _ring.stop();
    _ring.value = 0;
    setState(() {
      _phase = _Phase.aim;
      _aimX = 0;
      _lift = 0;
      _t = 0;
      _power = 0;
      _spin = 0;
      _keeperX = 0;
      _result = null;
      _dragStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShotPrototypeScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ShotPrototypeScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ShotPrototypeScreen._border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _Header(onReset: _reset),
                      Expanded(child: _buildPitch()),
                      _Readout(
                        phase: _phase,
                        aimX: _aimX,
                        lift: _lift,
                        power: _power,
                        spin: _spin,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPitch() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final projector = _Projector(size);
          final ballCenter = projector.project(0, 0, 0);
          final strikeRadius = math.min(size.width * 0.17, 62.0);

          return GestureDetector(
            key: const ValueKey('pitch'),
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: (d) => _onPanUpdate(d, size),
            onPanEnd: _onPanEnd,
            onTapDown: (d) {
              if (_phase == _Phase.strike) {
                _onStrike(d.localPosition, ballCenter, strikeRadius);
              } else if (_phase == _Phase.result) {
                _reset();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AnimatedBuilder(
                animation: _ring,
                builder: (context, _) {
                  return CustomPaint(
                    size: size,
                    painter: _PitchPainter(
                      phase: _phase,
                      aimX: _aimX,
                      lift: _lift,
                      spin: _spin,
                      t: _t,
                      xAt: _xAt,
                      yAt: _yAt,
                      zAt: _zAt,
                      timeToGoal: _timeToGoal,
                      keeperX: _keeperX,
                      strikeRadius: strikeRadius,
                      ringRadius: _ringRadius(strikeRadius),
                      result: _result,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Projects the 3 world axes onto the 2D screen.
class _Projector {
  const _Projector(this.size);

  final Size size;

  /// Perspective strength: the higher it is, the more distant objects shrink.
  static const k = 1.25;

  double get halfWidth => size.width * 0.46;
  double get baseY => size.height * 0.90;
  double get horizonY => size.height * 0.10;

  /// Deliberately exaggerating height: a 1:1 projection leaves the goal
  /// only ~26px tall and vertical motion unreadable. The standard trick
  /// in pseudo-3D games.
  double get zScale => halfWidth * 1.5;

  double scale(double y) => 1 / (1 + k * y);

  /// y (0..1) → depth compressed to 0..1 on screen.
  double _depthT(double y) => y * (1 + k) / (1 + k * y);

  double groundY(double y) => baseY - (baseY - horizonY) * _depthT(y);

  Offset project(double x, double y, double z) {
    final s = scale(y);
    return Offset(
      size.width / 2 + x * halfWidth * s,
      groundY(y) - z * zScale * s,
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter({
    required this.phase,
    required this.aimX,
    required this.lift,
    required this.spin,
    required this.t,
    required this.xAt,
    required this.yAt,
    required this.zAt,
    required this.timeToGoal,
    required this.keeperX,
    required this.strikeRadius,
    required this.ringRadius,
    required this.result,
  });

  final _Phase phase;
  final double aimX;
  final double lift;
  final double spin;
  final double t;
  final double Function(double) xAt;
  final double Function(double) yAt;
  final double Function(double) zAt;
  final double timeToGoal;
  final double keeperX;
  final double strikeRadius;
  final double ringRadius;
  final String? result;

  static const _grass1 = Color(0xFF15251B);
  static const _grass2 = Color(0xFF1A2D20);
  static const _line = Color(0x55FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final p = _Projector(size);
    _paintGrass(canvas, size, p);
    _paintLines(canvas, size, p);
    _paintGoal(canvas, p);

    if (phase == _Phase.aim) {
      _paintAim(canvas, p);
    }

    _paintKeeper(canvas, p);

    if (phase == _Phase.flight || phase == _Phase.result) {
      _paintBallInFlight(canvas, p);
    } else {
      _paintBallAtRest(canvas, p, size);
    }

    if (phase == _Phase.result && result != null) {
      _paintResult(canvas, size);
    }
  }

  void _paintResult(Canvas canvas, Size size) {
    final isGoal = result == 'GOL!';
    final painter = TextPainter(
      text: TextSpan(
        text: result,
        style: TextStyle(
          color: isGoal
              ? ShotPrototypeScreen._success
              : ShotPrototypeScreen._textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final center = Offset(
      (size.width - painter.width) / 2,
      size.height * 0.42 - painter.height / 2,
    );

    final backdrop = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - 18,
        center.dy - 10,
        painter.width + 36,
        painter.height + 20,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      backdrop,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    painter.paint(canvas, center);
  }

  void _paintGrass(Canvas canvas, Size size, _Projector p) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _grass1);
    // Stripes that narrow with depth.
    const bands = 7;
    for (var i = 0; i < bands; i += 2) {
      final y0 = i / bands;
      final y1 = (i + 1) / bands;
      final path = Path()
        ..moveTo(0, p.groundY(y0))
        ..lineTo(size.width, p.groundY(y0))
        ..lineTo(size.width, p.groundY(y1))
        ..lineTo(0, p.groundY(y1))
        ..close();
      canvas.drawPath(path, Paint()..color = _grass2);
    }
  }

  void _paintLines(Canvas canvas, Size size, _Projector p) {
    final paint = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Touchlines
    canvas.drawLine(p.project(-1, 0, 0), p.project(-1, 1, 0), paint);
    canvas.drawLine(p.project(1, 0, 0), p.project(1, 1, 0), paint);

    // Penalty box
    const boxHalf = 0.85;
    const boxDepth = 0.72;
    canvas.drawLine(
      p.project(-boxHalf, boxDepth, 0),
      p.project(boxHalf, boxDepth, 0),
      paint,
    );
    canvas.drawLine(
      p.project(-boxHalf, boxDepth, 0),
      p.project(-boxHalf, 1, 0),
      paint,
    );
    canvas.drawLine(
      p.project(boxHalf, boxDepth, 0),
      p.project(boxHalf, 1, 0),
      paint,
    );

    // Goal line
    canvas.drawLine(p.project(-1, 1, 0), p.project(1, 1, 0), paint);
  }

  void _paintGoal(Canvas canvas, _Projector p) {
    const gh = _World.goalHalfWidth;
    const cb = _World.crossbarHeight;

    final tl = p.project(-gh, 1, cb);
    final tr = p.project(gh, 1, cb);
    final bl = p.project(-gh, 1, 0);
    final br = p.project(gh, 1, 0);

    // Net
    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(tl.dx, tl.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(br.dx, br.dy)
        ..lineTo(bl.dx, bl.dy)
        ..close(),
      netPaint,
    );

    final mesh = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 0.6;
    for (var i = 1; i < 8; i++) {
      final f = i / 8;
      canvas.drawLine(
        Offset.lerp(tl, tr, f)!,
        Offset.lerp(bl, br, f)!,
        mesh,
      );
    }
    for (var i = 1; i < 4; i++) {
      final f = i / 4;
      canvas.drawLine(
        Offset.lerp(tl, bl, f)!,
        Offset.lerp(tr, br, f)!,
        mesh,
      );
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

  void _paintAim(Canvas canvas, _Projector p) {
    if (aimX == 0 && lift == 0) return;

    // Aim reticle: the point where the ball would cross the goal line.
    final target = p.project(aimX, 1, lift * _World.maxAimHeight);
    final reticle = Paint()
      ..color = ShotPrototypeScreen._warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(target, 7, reticle);
    canvas.drawLine(
      target.translate(-11, 0),
      target.translate(11, 0),
      reticle,
    );
    canvas.drawLine(
      target.translate(0, -11),
      target.translate(0, 11),
      reticle,
    );

    // Curve-free preview trajectory (spin will bend this on the actual shot).
    final vy = _World.baseDepthSpeed;
    final tg = 1 / vy;
    final vz =
        (lift * _World.maxAimHeight + 0.5 * _World.gravity * tg * tg) / tg;
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (var i = 1; i <= 16; i++) {
      final ts = tg * i / 16;
      final x = aimX * vy * ts;
      final y = vy * ts;
      final z = math.max(0.0, vz * ts - 0.5 * _World.gravity * ts * ts);
      canvas.drawCircle(p.project(x, y, z), 1.8, dot);
    }
  }

  void _paintKeeper(Canvas canvas, _Projector p) {
    const keeperHeight = 0.30;
    const keeperHalf = 0.10;
    final s = p.scale(0.97);

    final feet = p.project(keeperX, 0.97, 0);
    final w = keeperHalf * 2 * p.halfWidth * s;
    final h = keeperHeight * p.zScale * s;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h),
        const Radius.circular(3),
      ),
      Paint()..color = ShotPrototypeScreen._warning.withValues(alpha: 0.85),
    );
  }

  void _paintBallAtRest(Canvas canvas, _Projector p, Size size) {
    final center = p.project(0, 0, 0);

    if (phase == _Phase.strike) {
      // Strike phase: enlarged ball + shrinking timing ring.
      canvas.drawCircle(
        center,
        strikeRadius,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        center,
        strikeRadius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Center mark: full-power zone.
      canvas.drawCircle(
        center,
        strikeRadius * 0.22,
        Paint()
          ..color = ShotPrototypeScreen._accent.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill,
      );
      // Curve axis
      canvas.drawLine(
        center.translate(-strikeRadius * 0.8, 0),
        center.translate(strikeRadius * 0.8, 0),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );

      final sweet = (ringRadius - strikeRadius).abs() < strikeRadius * 0.18;
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..color = sweet
              ? ShotPrototypeScreen._success
              : ShotPrototypeScreen._accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = sweet ? 3 : 2,
      );
      return;
    }

    final r = _World.ballRadius * p.halfWidth;
    _paintShadow(canvas, p, 0, 0, 0);
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
  }

  void _paintBallInFlight(Canvas canvas, _Projector p) {
    final x = xAt(t);
    final y = yAt(t);
    final z = zAt(t);

    _paintShadow(canvas, p, x, y, z);

    final s = p.scale(y);
    final center = p.project(x, y, z);
    final r = _World.ballRadius * p.halfWidth * s;

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

  /// The shadow is drawn on the ground ignoring z — the real depth cue in pseudo-3D.
  void _paintShadow(Canvas canvas, _Projector p, double x, double y, double z) {
    final s = p.scale(y);
    final ground = Offset(
      p.size.width / 2 + x * p.halfWidth * s,
      p.groundY(y),
    );
    final r = _World.ballRadius * p.halfWidth * s;
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

  @override
  bool shouldRepaint(covariant _PitchPainter old) => true;
}

class _Header extends StatelessWidget {
  const _Header({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ShotPrototypeScreen._border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_left,
              size: 24,
              color: ShotPrototypeScreen._textMuted,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Şut Prototipi',
            style: TextStyle(
              color: ShotPrototypeScreen._textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onReset,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Sıfırla',
            icon: const Icon(
              Icons.refresh,
              size: 20,
              color: ShotPrototypeScreen._textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.phase,
    required this.aimX,
    required this.lift,
    required this.power,
    required this.spin,
  });

  final _Phase phase;
  final double aimX;
  final double lift;
  final double power;
  final double spin;

  String get _hint {
    switch (phase) {
      case _Phase.aim:
        return '1) Sürükle: yön ve yükseklik seç, bırak';
      case _Phase.strike:
        return '2) Topa vur: merkez = güç, kenar = kavis';
      case _Phase.flight:
        return 'Uçuşta…';
      case _Phase.result:
        return 'Tekrar denemek için sahaya dokun';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: ShotPrototypeScreen._border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _hint,
            style: const TextStyle(
              color: ShotPrototypeScreen._textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Yön', value: aimX, signed: true),
              _Stat(label: 'Yükseklik', value: lift),
              _Stat(label: 'Güç', value: power),
              _Stat(label: 'Kavis', value: spin, signed: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.signed = false,
  });

  final String label;
  final double value;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final magnitude = value.abs().clamp(0.0, 1.0);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ShotPrototypeScreen._textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  signed && value > 0
                      ? '+${value.toStringAsFixed(2)}'
                      : value.toStringAsFixed(2),
                  style: const TextStyle(
                    color: ShotPrototypeScreen._textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: magnitude,
                minHeight: 4,
                backgroundColor: ShotPrototypeScreen._surface1,
                color: magnitude > 0.75
                    ? ShotPrototypeScreen._success
                    : ShotPrototypeScreen._accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
