import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueChanged;

import 'package:project_srpg/game/game_banner.dart';
import 'package:project_srpg/game/training_result.dart';

enum BenchPhase { ready, sweeping, lifting, done }

const _surface1 = Color(0xFF1A1D24);
const _surface2 = Color(0xFF22262F);
const _border = Color(0xFF333845);
const _steel = Color(0xFFB9BFC9);
const _skin = Color(0xFFC08A63);
const _chest = Color(0xFF9C6E4E);
const _accent = Color(0xFF1E6FD9);
const _success = Color(0xFF3DDC97);
const _warning = Color(0xFFF5A623);
const _danger = Color(0xFFE5484D);

/// The bench press drill: a marker sweeps a vertical bar, and pressing while it
/// sits in the green band is a clean rep. Three clean reps pass the session,
/// two misses end it.
///
/// Follows the training-game convention in `training_result.dart`: every rule
/// is in [advance] and [press], neither of which reads `size`.
class BenchPressGame extends FlameGame {
  BenchPressGame({required this.onStateChanged, required this.onFinished});

  final VoidCallback onStateChanged;
  final ValueChanged<TrainingResult> onFinished;

  static const neededSuccesses = 3;
  static const allowedFailures = 2;

  static const baseSweepSpeed = 0.85;

  /// The sweep speeds up and the band narrows with each attempt. Three
  /// identical reps would be one decision taken three times; ramping both makes
  /// the first rep a tutorial and the decider genuinely tight — and it reads as
  /// fatigue, which is what a bench press is.
  static const sweepAccel = 0.22;
  static const baseZoneHalf = 0.10;
  static const zoneShrink = 0.012;
  static const minZoneHalf = 0.055;

  static const liftTime = 0.55;

  /// Fixed rather than random, so a session is reproducible and the whole
  /// scoring table can be asserted — the same reasoning as the shot game's
  /// clock-free `resolve`.
  static const _zoneCenters = [0.50, 0.62, 0.40, 0.58, 0.45];

  BenchPhase phase = BenchPhase.ready;

  /// 0 at the bottom of the bar, 1 at the top.
  double markerT = 0;
  int _dir = 1;

  double liftT = 0;
  double earlyShake = 0;

  int successes = 0;
  int failures = 0;
  bool lastRepOk = false;

  final List<double> _quality = <double>[];

  int get attempts => _quality.length;

  double get zoneCenter => _zoneCenters[attempts % _zoneCenters.length];

  double get zoneHalf =>
      math.max(minZoneHalf, baseZoneHalf - zoneShrink * attempts);

  double get sweepSpeed => baseSweepSpeed + sweepAccel * attempts;

  bool get markerInZone => (markerT - zoneCenter).abs() <= zoneHalf;

  bool get succeeded => successes >= neededSuccesses;

  /// Drives the bar height, its width, its thickness and the grip spread all at
  /// once — the whole fake-perspective trick is this one scalar. A good rep
  /// goes up and locks out; a bad one is a shaky half rep that never does.
  double get liftProgress {
    if (phase != BenchPhase.lifting) return 0;
    final t = (liftT / liftTime).clamp(0.0, 1.0);
    final arc = math.sin(math.pi * t);
    return lastRepOk ? arc : 0.45 * arc * (1 + 0.15 * math.sin(liftT * 40));
  }

  TrainingResult get result => TrainingResult(
        drill: TrainingDrill.strength,
        outcome:
            succeeded ? TrainingOutcome.success : TrainingOutcome.failure,
        score: _quality.isEmpty
            ? 0
            : _quality.reduce((a, b) => a + b) / _quality.length,
        detail: '$successes başarılı tekrar / $failures kaçak',
      );

  @override
  Color backgroundColor() => _surface1;

  @override
  Future<void> onLoad() async {
    addAll([BenchSceneComponent(), PowerBarComponent(), PressInputLayer()]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    advance(dt);
  }

  void advance(double dt) {
    earlyShake = math.max(0, earlyShake - dt);

    switch (phase) {
      case BenchPhase.sweeping:
        markerT += _dir * sweepSpeed * dt;
        // Reflect rather than clamp: clamping would park the marker on an end
        // for a frame at high dt and make the endpoints a free target.
        if (markerT > 1) {
          markerT = 2 - markerT;
          _dir = -1;
        } else if (markerT < 0) {
          markerT = -markerT;
          _dir = 1;
        }
      case BenchPhase.lifting:
        liftT += dt;
        if (liftT >= liftTime) _nextRep();
      case BenchPhase.ready:
      case BenchPhase.done:
        break;
    }
  }

  /// One press. Position is irrelevant — only the moment counts.
  void press() {
    switch (phase) {
      case BenchPhase.ready:
        // The first press starts the session, so the marker cannot run away
        // while the screen animates in.
        phase = BenchPhase.sweeping;
        markerT = 0;
        _dir = 1;
        onStateChanged();
      case BenchPhase.sweeping:
        _judge();
      case BenchPhase.lifting:
        earlyShake = 0.15;
      case BenchPhase.done:
        break;
    }
  }

  void _judge() {
    final off = (markerT - zoneCenter).abs();
    lastRepOk = off <= zoneHalf;
    if (lastRepOk) {
      successes++;
      _quality.add(1 - off / zoneHalf);
    } else {
      failures++;
      _quality.add(0);
    }

    phase = BenchPhase.lifting;
    liftT = 0;
    onStateChanged();
  }

  void _nextRep() {
    if (succeeded || failures >= allowedFailures) {
      _finish();
      return;
    }
    // The marker carries on from where it is, at the new speed.
    phase = BenchPhase.sweeping;
    onStateChanged();
  }

  void _finish() {
    phase = BenchPhase.done;
    if (isMounted) {
      add(GameBanner(succeeded ? 'BAŞARILI' : 'YETERSİZ', highlight: succeeded));
    }
    onFinished(result);
    onStateChanged();
  }
}

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

/// The first-person scene: ceiling, rack, barbell, hands and chest, all driven
/// off [BenchPressGame.liftProgress].
class BenchSceneComponent extends Component
    with HasGameReference<BenchPressGame> {
  @override
  int get priority => 0;

  double _breath = 0;

  @override
  void update(double dt) {
    _breath += dt;
  }

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;
    final lift = game.liftProgress;

    canvas.save();
    if (game.phase == BenchPhase.lifting && !game.lastRepOk) {
      canvas.translate(math.sin(game.liftT * 60) * 2, 0);
    }

    _paintCeiling(canvas, u, v);
    _paintRack(canvas, u, v);
    _paintChest(canvas, u, v);
    _paintBarbell(canvas, u, v, lift);
    _paintArms(canvas, u, v, lift);
    _paintStrain(canvas, u, v);

    canvas.restore();
  }

  void _paintCeiling(Canvas canvas, double u, double v) {
    canvas.drawRect(Rect.fromLTWH(0, 0, u, v), Paint()..color = _surface1);

    // One light, faked with three ovals. Looking up is the whole point of the
    // shot, so it has to be the first thing the eye lands on.
    const alphas = [0.04, 0.07, 0.11];
    const radii = [0.34, 0.24, 0.15];
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(u * 0.5, v * 0.10),
          width: u * radii[i] * 2,
          height: v * radii[i] * 0.9,
        ),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alphas[i]),
      );
    }

    // Panel seams converging toward the top centre.
    final seam = Paint()
      ..color = _border.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(u * 0.10, v * 0.42), Offset(u * 0.34, 0), seam);
    canvas.drawLine(Offset(u * 0.90, v * 0.42), Offset(u * 0.66, 0), seam);
  }

  void _paintRack(Canvas canvas, double u, double v) {
    final fill = Paint()..color = _surface2;
    final line = Paint()
      ..color = _border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final left in [true, false]) {
      final outer = left ? 0.0 : u;
      final inner = left ? u * 0.10 : u * 0.90;
      final path = Path()
        ..moveTo(outer, 0)
        ..lineTo(inner, 0)
        ..lineTo(left ? u * 0.075 : u * 0.925, v * 0.30)
        ..lineTo(left ? u * 0.025 : u * 0.975, v * 0.30)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, line);

      // J-hook.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left ? u * 0.055 : u * 0.885,
            v * 0.20,
            u * 0.06,
            v * 0.018,
          ),
          const Radius.circular(3),
        ),
        fill,
      );
    }
  }

  void _paintChest(Canvas canvas, double u, double v) {
    final rise = math.sin(_breath * 2.2) * v * 0.006;
    final rect = Rect.fromLTRB(
      u * 0.16,
      v * 0.86 + rise,
      u * 0.84,
      v * 1.06,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(u * 0.10)),
      Paint()..color = _chest,
    );
    canvas.drawLine(
      Offset(u * 0.5, rect.top + v * 0.02),
      Offset(u * 0.5, rect.top + v * 0.10),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.07)
        ..strokeWidth = 1,
    );
  }

  void _paintBarbell(Canvas canvas, double u, double v, double lift) {
    final scale = lerpDouble(1.0, 0.72, lift)!;
    final y = lerpDouble(v * 0.62, v * 0.30, lift)!;
    final half = u * 0.44 * scale;
    final thickness = v * 0.022 * scale;

    final shaft = Rect.fromCenter(
      center: Offset(u * 0.5, y),
      width: half * 2,
      height: thickness,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shaft, Radius.circular(thickness / 2)),
      Paint()..color = _steel,
    );
    canvas.drawLine(
      Offset(shaft.left, shaft.top + 1),
      Offset(shaft.right, shaft.top + 1),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(shaft.left, shaft.bottom - 1),
      Offset(shaft.right, shaft.bottom - 1),
      Paint()
        ..color = _border
        ..strokeWidth = 1,
    );

    // Knurling, either side of centre.
    final knurl = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final dx = u * (0.10 + i * 0.012) * scale;
      canvas.drawLine(
        Offset(u * 0.5 - dx, shaft.top + 2),
        Offset(u * 0.5 - dx, shaft.bottom - 2),
        knurl,
      );
      canvas.drawLine(
        Offset(u * 0.5 + dx, shaft.top + 2),
        Offset(u * 0.5 + dx, shaft.bottom - 2),
        knurl,
      );
    }

    // Plates. Ellipses rather than circles: the foreshortening is what sells
    // the point of view.
    const plateColors = [Color(0xFF2A2F3A), Color(0xFF20242C), _border];
    for (final sign in [-1, 1]) {
      for (var i = 0; i < 3; i++) {
        final cx = u * 0.5 + sign * (half - u * 0.02 - i * u * 0.028 * scale);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, y),
            width: u * 0.035 * scale * 2,
            height: v * 0.16 * scale * 2 * (1 - i * 0.12),
          ),
          Paint()..color = plateColors[i],
        );
      }
      // Collar.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(u * 0.5 + sign * (half - u * 0.13 * scale), y),
            width: u * 0.022 * scale,
            height: v * 0.045 * scale,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = _steel,
      );
    }
  }

  void _paintArms(Canvas canvas, double u, double v, double lift) {
    final y = lerpDouble(v * 0.62, v * 0.30, lift)!;
    // The grip narrows and the elbows tuck as the bar rises — what a press
    // looks like from underneath.
    final spread = lerpDouble(u * 0.24, u * 0.185, lift)!;

    for (final sign in [-1, 1]) {
      final hand = Offset(u * 0.5 + sign * spread, y);

      final forearm = Path()
        ..moveTo(u * 0.5 + sign * u * 0.24, v * 1.04)
        ..lineTo(u * 0.5 + sign * u * 0.38, v * 1.04)
        ..lineTo(hand.dx + sign * u * 0.030, hand.dy)
        ..lineTo(hand.dx - sign * u * 0.026, hand.dy)
        ..close();
      canvas.drawPath(forearm, Paint()..color = _skin);
      canvas.drawPath(
        forearm,
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: hand,
            width: u * 0.070,
            height: v * 0.040,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = _skin,
      );
      for (var f = 0; f < 4; f++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(
                hand.dx - u * 0.024 + f * u * 0.016,
                hand.dy - v * 0.020,
              ),
              width: u * 0.012,
              height: v * 0.016,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = _skin,
        );
      }
    }
  }

  void _paintStrain(Canvas canvas, double u, double v) {
    final lifting = game.phase == BenchPhase.lifting;
    if (!lifting && game.earlyShake == 0) return;

    final pulse = lifting
        ? math.sin(math.pi * (game.liftT / BenchPressGame.liftTime))
        : 1.0;
    final color = (lifting && game.lastRepOk) ? _success : _danger;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, u, v).deflate(u * 0.025),
      Paint()
        ..color = color.withValues(alpha: 0.22 * pulse.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.05,
    );
  }
}

/// The vertical bar and its sweeping marker — the part you actually play
/// against. On the right so the barbell keeps the centre.
class PowerBarComponent extends Component
    with HasGameReference<BenchPressGame> {
  @override
  int get priority => 6;

  double _hitFlash = 0;
  int _seenAttempts = 0;

  @override
  void update(double dt) {
    if (game.attempts != _seenAttempts) {
      _seenAttempts = game.attempts;
      _hitFlash = 0.25;
    }
    _hitFlash = math.max(0, _hitFlash - dt);
  }

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;

    final track = Rect.fromLTWH(u * 0.855, v * 0.18, u * 0.055, v * 0.64);
    final radius = Radius.circular(u * 0.028);

    canvas.drawRRect(
      RRect.fromRectAndRadius(track, radius),
      Paint()..color = _surface1.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, radius),
      Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    double yAt(double t) => track.bottom - t * track.height;

    final zoneTop = yAt(game.zoneCenter + game.zoneHalf);
    final zoneBottom = yAt(game.zoneCenter - game.zoneHalf);
    final missed = game.phase == BenchPhase.lifting && !game.lastRepOk;
    final zoneColor = _hitFlash > 0 ? (missed ? _danger : _success) : _success;

    canvas.drawRect(
      Rect.fromLTRB(track.left, zoneTop, track.right, zoneBottom),
      Paint()
        ..color = zoneColor.withValues(alpha: _hitFlash > 0 ? 0.55 : 0.30),
    );
    final edge = Paint()
      ..color = zoneColor
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(track.left, zoneTop),
      Offset(track.right, zoneTop),
      edge,
    );
    canvas.drawLine(
      Offset(track.left, zoneBottom),
      Offset(track.right, zoneBottom),
      edge,
    );

    _paintMarker(canvas, track, yAt(game.markerT), u);
    _paintPips(canvas, track, u, v);

    // On a miss, show *how far* off it was — that is the information you need
    // to correct, and a bare red flash does not carry it.
    if (missed && _hitFlash > 0) {
      final nearest = game.markerT > game.zoneCenter ? zoneTop : zoneBottom;
      canvas.drawLine(
        Offset(track.center.dx, yAt(game.markerT)),
        Offset(track.center.dx, nearest),
        Paint()
          ..color = _danger
          ..strokeWidth = 4,
      );
    }
  }

  void _paintMarker(Canvas canvas, Rect track, double y, double u) {
    final color = game.markerInZone ? _warning : _accent;

    canvas.drawLine(
      Offset(track.left, y),
      Offset(track.right, y),
      Paint()
        ..color = color
        ..strokeWidth = 3,
    );

    final tip = track.right + u * 0.012;
    canvas.drawPath(
      Path()
        ..moveTo(tip, y)
        ..lineTo(tip + u * 0.045, y - u * 0.026)
        ..lineTo(tip + u * 0.045, y + u * 0.026)
        ..close(),
      Paint()..color = color,
    );

    if (_hitFlash > 0) {
      canvas.drawCircle(
        Offset(track.center.dx, y),
        u * 0.05 * (1 - _hitFlash / 0.25),
        Paint()
          ..color = (game.lastRepOk ? _success : _danger)
              .withValues(alpha: _hitFlash / 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _paintPips(Canvas canvas, Rect track, double u, double v) {
    for (var i = 0; i < BenchPressGame.neededSuccesses; i++) {
      final filled = i < game.successes;
      final center = Offset(
        track.center.dx,
        track.top - v * 0.045 - i * v * 0.032,
      );
      canvas.drawCircle(
        center,
        u * 0.013,
        Paint()
          ..color = filled ? _success : _border
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    for (var i = 0; i < BenchPressGame.allowedFailures; i++) {
      final filled = i < game.failures;
      final center = Offset(
        track.center.dx,
        track.bottom + v * 0.040 + i * v * 0.028,
      );
      canvas.drawCircle(
        center,
        u * 0.010,
        Paint()
          ..color = filled ? _danger : _border
          ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }
}

/// Full-bleed tap surface. Copies [PositionComponent.onGameResize] from the
/// shot game's input layer for a reason: a tappable component only receives
/// taps inside its own size, so without this the canvas silently ignores them.
class PressInputLayer extends PositionComponent
    with HasGameReference<BenchPressGame>, TapCallbacks {
  @override
  int get priority => 20;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.press();
  }
}
