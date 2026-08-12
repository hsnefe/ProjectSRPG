import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors, ValueChanged;

import 'package:project_srpg/game/game_banner.dart';
import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/training_result.dart';

enum ShotPhase { aim, strike, flight, result }

/// What a finished flight is being judged *for*.
///
/// The world is identical in every mode — the pitch, the targets and [ShotGame
/// .resolve] do not know the mode exists. Only the success criterion, the
/// starting bearing and the surrounding chrome differ, which is what keeps the
/// demo and the two drills one game.
enum ShotMode {
  /// The prototype: turn anywhere, shoot forever, nothing is scored.
  free(null),
  shot('GOL!'),
  pass('PAS TUTTU');

  const ShotMode(this.successLabel);

  /// The one label out of [ShotGame.resolve] that counts as a made attempt.
  final String? successLabel;
}

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
///
/// Rivals ride in the same class because the ball does not care whose shirt a
/// body is wearing, but they are kept out of [all]: that list means "things you
/// can pick out", and nobody passes to the opposition.
class ShotTarget {
  const ShotTarget({
    required this.label,
    required this.x,
    required this.y,
    this.isGoal = false,
    this.isRival = false,
  });

  final String label;
  final double x;
  final double y;
  final bool isGoal;
  final bool isRival;

  double get distance => math.sqrt(x * x + y * y);
  double get facingAngle => PitchProjector.angleToward(x, y);

  static const goal = ShotTarget(label: 'Kale', x: 0, y: 1, isGoal: true);
  static const leftWing = ShotTarget(label: 'Sol kanat', x: -0.9, y: 0.55);
  static const rightBack = ShotTarget(label: 'Sağ bek', x: 0.95, y: 0.15);
  static const backPass = ShotTarget(label: 'Geri pas', x: 0.05, y: -0.75);

  /// The opposition. They stand off the obvious lines rather than on them —
  /// a defender parked on the shot you are about to take is not a decision —
  /// and close the ball down once it is struck.
  static const rivalCentreBack =
      ShotTarget(label: 'Rakip stoper', x: -0.45, y: 0.80, isRival: true);
  static const rivalMidfielder =
      ShotTarget(label: 'Rakip orta saha', x: -0.50, y: 0.66, isRival: true);
  static const rivalFullBack =
      ShotTarget(label: 'Rakip bek', x: 0.85, y: 0.40, isRival: true);

  static const all = [goal, leftWing, rightBack, backPass];

  static const rivals = [rivalCentreBack, rivalMidfielder, rivalFullBack];

  /// Everyone with a body on the pitch: what the ball can run into, and what
  /// gets drawn. The goal has no body and the keeper is his own component.
  static const players = [leftWing, rightBack, backPass, ...rivals];

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
  ShotGame({
    required this.onStateChanged,
    this.mode = ShotMode.free,
    this.onFinished,
  }) {
    // A pass drill starts looking at a team mate rather than at the goal. The
    // bearing is the only thing the mode moves — [ShotTarget.all] is the same
    // list it always was.
    if (mode == ShotMode.pass) {
      facing = Facing.left;
      desiredAngle = Facing.left.angle;
      cameraAngle = Facing.left.angle;
    }
  }

  /// Lets the surrounding Flutter UI rebuild its readout.
  final VoidCallback onStateChanged;

  /// Defaulted so the prototype screen and the existing tests construct this
  /// game exactly as they always did.
  final ShotMode mode;

  /// Fired once, when a scored session runs out of attempts. Never in
  /// [ShotMode.free].
  final ValueChanged<TrainingResult>? onFinished;

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

  /// How long the ball is animated for. Shorter than [_flightSpan] whenever
  /// somebody gets a touch on it, because that is where it stops.
  double flightDuration = 0;

  /// The full flight the strike would produce if the pitch were empty. Every
  /// sweep reads this rather than [flightDuration], so shortening the animation
  /// cannot feed back into the outcome.
  double _flightSpan = 0;

  /// Where along the goal line the keeper commits to, fixed at launch. Zero
  /// when the shot never reaches the line, so he holds his ground for a pass.
  double _keeperTarget = 0;

  /// Where each rival has decided to go, also fixed at launch. Empty outside a
  /// flight, which is what leaves everyone standing on their post.
  final Map<ShotTarget, GroundPoint> _rivalRuns = {};

  /// The first body the ball runs into, if it runs into one.
  ({double t, ShotTarget player})? _contact;

  /// When the ball stopped because somebody touched it. Null when nobody did.
  double? _stopT;

  String? result;

  // --- Session accounting (every mode but [ShotMode.free]) -----------------

  static const attemptsPerSession = 3;

  /// Best of three. Two out of three is a session you can be pleased with.
  static const madeToPass = 2;

  /// One entry per resolved flight, in order — the footer draws a pip from
  /// each. Deliberately survives [reset], which is how you take the *next*
  /// attempt.
  final List<bool> attemptLog = <bool>[];

  int get attempts => attemptLog.length;

  int get made => attemptLog.where((made) => made).length;

  bool get lastAttemptSucceeded =>
      mode.successLabel != null && result == mode.successLabel;

  TrainingResult get sessionResult => TrainingResult(
        drill: mode == ShotMode.pass ? TrainingDrill.pass : TrainingDrill.shot,
        outcome: made >= madeToPass
            ? TrainingOutcome.success
            : TrainingOutcome.failure,
        score: made / attemptsPerSession,
        detail: mode == ShotMode.pass
            ? '$made/$attemptsPerSession isabetli pas'
            : '$made/$attemptsPerSession gol',
      );

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
      AimComponent(),
      ActorsComponent(),
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
    // A drill fixes the bearing, so a stray turn cannot quietly reset the
    // attempt. The compass is hidden in those modes anyway; the guard is what
    // makes that an invariant rather than a UI accident.
    if (mode != ShotMode.free) return;
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
    // Deliberately running on past the aim point, for the look of it.
    _flightSpan = tg + 0.55;

    // Order matters here, and only in one direction: the rivals read a path
    // that knows nothing about them, the contact sweep needs to know where they
    // went, and both the keeper and the outcome need to know whether the ball
    // ever gets through.
    _readRivalRuns();
    _contact = _firstContact();

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

    final outcome = resolve();
    result = outcome.label;
    // A touched ball stops where it was touched and is given a moment to drop;
    // everything else plays out the whole flight.
    _stopT = outcome.touched ? outcome.t : null;
    flightDuration =
        outcome.touched ? outcome.t + ShotWorld.settleTime : _flightSpan;

    phase = ShotPhase.flight;
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

  // --- Rivals -------------------------------------------------------------

  /// Where a rival is at time [t]: on his post until he reacts, then walking
  /// the straight line to the spot he committed to at launch.
  GroundPoint rivalAt(ShotTarget rival, double t) {
    final aim = _rivalRuns[rival];
    if (aim == null) return (x: rival.x, y: rival.y);

    final dx = aim.x - rival.x;
    final dy = aim.y - rival.y;
    final gap = math.sqrt(dx * dx + dy * dy);
    if (gap < 1e-9) return (x: rival.x, y: rival.y);

    final travel = math.min(
      gap,
      math.max(0.0, t - ShotWorld.rivalReaction) * ShotWorld.rivalSpeed,
    );
    return (x: rival.x + dx / gap * travel, y: rival.y + dy / gap * travel);
  }

  /// Each rival picks the point on the ball's path he wants to be standing on.
  ///
  /// Like the keeper he reads the unspun line, so the counterplay is the same
  /// one: bend it round him, lift it over him, or hit it hard enough that he is
  /// still turning when it goes past. He stays on his post for a ball he could
  /// never get to, and never strays further than [ShotWorld.rivalRange].
  void _readRivalRuns() {
    _rivalRuns.clear();
    for (final rival in ShotTarget.rivals) {
      final spot = _closestApproach((x: rival.x, y: rival.y));
      if (spot == null || spot.t <= ShotWorld.rivalReaction) continue;
      if (spot.gap < 1e-9) continue;

      final reach = math.min(spot.gap, ShotWorld.rivalRange);
      _rivalRuns[rival] = (
        x: rival.x + (spot.point.x - rival.x) / spot.gap * reach,
        y: rival.y + (spot.point.y - rival.y) / spot.gap * reach,
      );
    }
  }

  /// The closest the unspun path ever comes to a standing player, and when.
  ({double t, GroundPoint point, double gap})? _closestApproach(
    GroundPoint post,
  ) {
    if (_flightSpan <= 0) return null;

    ({double t, GroundPoint point, double gap})? best;
    for (var i = 0; i <= _sweepSamples; i++) {
      final t = _flightSpan * i / _sweepSamples;
      final point = PitchProjector.cameraToWorld(
        _lateralAt(t, withSpin: false),
        depthAt(t),
        cameraAngle,
      );
      final gap = _gap(point, post);
      if (best == null || gap < best.gap) {
        best = (t: t, point: point, gap: gap);
      }
    }
    return best;
  }

  // --- Contact ------------------------------------------------------------

  /// How the flight is sampled. At a typical span the step is about 6 ms, or
  /// a hundredth of a world unit — well inside [ShotWorld.blockRadius], so
  /// nothing tunnels through anybody.
  static const _sweepSamples = 180;

  /// The first body the ball runs into.
  ///
  /// The keeper is not in here: he keeps his own reach test at the goal line,
  /// which is graded by height in a way a plain cylinder is not.
  ({double t, ShotTarget player})? _firstContact() {
    if (_flightSpan <= 0) return null;

    for (var i = 1; i <= _sweepSamples; i++) {
      final t = _flightSpan * i / _sweepSamples;
      // Over everyone's head there is nothing to hit.
      if (heightAt(t) >= ShotWorld.blockHeight) continue;

      final ball = worldAt(t);
      for (final player in ShotTarget.players) {
        final at = playerAt(player, t);
        if (_gap(ball, at) < ShotWorld.blockRadius) {
          return (t: t, player: player);
        }
      }
    }
    return null;
  }

  /// Where a player is standing at time [t]. Only rivals ever move.
  GroundPoint playerAt(ShotTarget player, double t) =>
      player.isRival ? rivalAt(player, t) : (x: player.x, y: player.y);

  static double _gap(GroundPoint a, GroundPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Where to draw the ball at time [t]. Once somebody has touched it, it stops
  /// dead there and drops out of the air.
  ({double lateral, double depth, double z}) ballAt(double t) {
    final stop = _stopT;
    if (stop == null || t <= stop) {
      return (lateral: lateralAt(t), depth: depthAt(t), z: heightAt(t));
    }

    final fall = t - stop;
    return (
      lateral: lateralAt(stop),
      depth: depthAt(stop),
      z: math.max(
        0,
        heightAt(stop) - 0.5 * ShotWorld.gravity * fall * fall,
      ),
    );
  }

  /// The first moment the ball crosses the goal line, or null if it never does.
  ///
  /// The path is not straight in world terms — spin adds a t² term and the
  /// camera can face anywhere — so it is sampled and then narrowed between the
  /// two samples that bracket the crossing, the same way the pitch arcs are
  /// drawn.
  ({double t, double x, double z})? _goalLineCrossing({bool withSpin = true}) {
    if (_flightSpan <= 0) return null;

    GroundPoint at(double t) => PitchProjector.cameraToWorld(
          _lateralAt(t, withSpin: withSpin),
          depthAt(t),
          cameraAngle,
        );

    const samples = _sweepSamples;
    var previousT = 0.0;
    var previousY = at(0).y;

    for (var i = 1; i <= samples; i++) {
      final t = _flightSpan * i / samples;
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
      final gap = _gap(landing, (x: t.x, y: t.y));
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
  /// scored as a shot. Whoever gets to the ball first wins: anybody it runs into
  /// takes it before it can run on, and so does a receiver it merely arrives at
  /// — [ShotWorld.passCatchRadius] is more generous than a body is wide, and a
  /// pass that only just misses its man is still a pass.
  ({double t, double x, double z})? _shotAtGoal() {
    final crossing = _goalLineCrossing();
    if (crossing == null) return null;

    final contact = _contact;
    if (contact != null && contact.t <= crossing.t) return null;
    if (crossing.t > timeToTarget && _receiver() != null) return null;
    return crossing;
  }

  void finishFlight() {
    phase = ShotPhase.result;
    result ??= judge();
    // Purely visual, and there is no view in a headless test — which is where
    // the session accounting below gets driven from.
    if (isMounted) {
      add(GameBanner(result!, highlight: _isGoodOutcome(result!)));
    }

    if (mode != ShotMode.free) {
      attemptLog.add(lastAttemptSucceeded);
      if (attempts >= attemptsPerSession) onFinished?.call(sessionResult);
    }

    onStateChanged();
  }

  /// Which labels the banner paints green. Broader than the mode's success
  /// criterion on purpose: a caught pass reads as a good ball even in a
  /// shooting drill, it just does not score.
  static bool _isGoodOutcome(String label) =>
      label == 'GOL!' || label == 'PAS TUTTU';

  /// Reads the outcome off the ball's actual world path rather than off
  /// whichever target the compass had selected. That is what makes a pass to a
  /// team mate possible from a shooting position: aim at them and the ball never
  /// reaches the goal line, so it is judged as a pass.
  ///
  /// Internal rather than private so the outcome table can be tested directly.
  String judge() => resolve().label;

  /// The outcome, the moment it happens, and whether anybody got a touch on the
  /// ball — which is what decides where the flight stops.
  ///
  /// Nothing in here reads the clock, so it says the same thing at launch as it
  /// does when the ball lands.
  ({String label, double t, bool touched}) resolve() {
    const r = ShotWorld.ballRadius;

    final atGoal = _shotAtGoal();
    if (atGoal != null) {
      final x = atGoal.x;
      final z = atGoal.z;
      // Anything that beats the keeper keeps flying; only a save stops here.
      ({String label, double t, bool touched}) past(String label) =>
          (label: label, t: _flightSpan, touched: false);

      if (x.abs() > ShotWorld.goalHalfWidth + r) return past('AUT');
      if (z > ShotWorld.crossbarHeight + r) return past('ÜSTTEN AUT');
      if (x.abs() > ShotWorld.goalHalfWidth - r ||
          z > ShotWorld.crossbarHeight - r) {
        return past('DİREK');
      }

      // Keeper reach: harder to get to high balls.
      final reach = z < 0.28 ? 0.15 : (z < 0.42 ? 0.07 : 0.0);
      if ((keeperReachAt(atGoal.t) - x).abs() < reach) {
        return (label: 'KURTARIŞ', t: atGoal.t, touched: true);
      }

      return past('GOL!');
    }

    // Nobody in your shirt gets it now: a rival got there first.
    final contact = _contact;
    if (contact != null && contact.player.isRival) {
      return (label: 'RAKİP KESTİ', t: contact.t, touched: true);
    }

    final tg = timeToTarget;
    final receiver = _receiver();
    if (receiver != null) {
      final caught = receiver.gap < ShotWorld.passCatchRadius &&
          heightAt(tg) < ShotWorld.passCatchHeight;
      return (
        label: caught ? 'PAS TUTTU' : 'PAS KAÇTI',
        t: contact?.t ?? tg,
        touched: contact != null,
      );
    }

    // It ran into one of your own without having been meant for him: still a
    // ball you gave away, just not one you meant to give.
    if (contact != null) {
      return (label: 'PAS KAÇTI', t: contact.t, touched: true);
    }

    final landing = worldAt(tg);
    final inPlay = landing.x.abs() <= PitchLines.halfWidth &&
        landing.y <= PitchLines.goalLineY &&
        landing.y >= PitchLines.backY;
    return (label: inPlay ? 'BOŞLUĞA' : 'AUT', t: _flightSpan, touched: false);
  }

  /// Clears the shot, not the session. [handleTap] calls this in the result
  /// phase to line up the next attempt, so zeroing [attempts] here would mean a
  /// scored session never ends — use [restartSession] for that.
  void reset() {
    phase = ShotPhase.aim;
    aimLateral = 0;
    aimDepth = ShotWorld.defaultAimDepth;
    power = 0;
    spin = 0;
    loft = 0;
    flightT = 0;
    flightDuration = 0;
    _flightSpan = 0;
    _keeperTarget = 0;
    _rivalRuns.clear();
    _contact = null;
    _stopT = null;
    ringT = 0;
    result = null;
    _dragStart = null;
    children.whereType<GameBanner>().forEach((c) => c.removeFromParent());
    onStateChanged();
  }

  /// Starts the drill over: the shot *and* the tally.
  void restartSession() {
    attemptLog.clear();
    reset();
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
const _rival = Color(0xFFE5484D);

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

/// Everyone on the pitch and the ball, painted back to front.
///
/// They share one component because they share one ground plane and there is no
/// depth buffer to sort them out: with a component each, Flame's priority
/// decides who covers whom, and the ball — drawn last — went straight through
/// the bodies it was supposed to be behind. Painting the whole cast in depth
/// order is the only thing that puts the ball behind a defender it has yet to
/// reach.
///
/// Players behind the camera are culled rather than hidden, so turning around
/// reveals them naturally. Nobody is highlighted: with the aim free of the
/// compass there is no "selected" player to mark, and any of them can be picked
/// out by pointing the reticle at them.
class ActorsComponent extends Component with HasGameReference<ShotGame> {
  /// Where the keeper stands: on the line, a stride in front of it.
  static const keeperDepth = 0.97;

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
    final actors = <({double depth, void Function() paint})>[];

    void at(
      double wx,
      double wy,
      void Function(double depth) paint, {
      bool cull = true,
    }) {
      final depth = p.depthOf(wx, wy);
      if (cull && !p.isPointVisible(depth)) return;
      actors.add((depth: depth, paint: () => paint(depth)));
    }

    for (final player in ShotTarget.players) {
      final spot = game.playerAt(player, game.flightT);
      at(
        spot.x,
        spot.y,
        (depth) => _paintBody(
          canvas,
          p,
          feet: p.projectWorld(spot.x, spot.y, 0),
          depth: depth,
          halfWidth: ShotWorld.playerHalfWidth,
          height: ShotWorld.playerHeight,
          color: player.isRival ? _rival : Colors.white,
          alpha: player.isRival ? 0.75 : 0.55,
        ),
      );
    }

    // The keeper's absolute position follows the lateral offset his dive has
    // taken him to.
    final keeperX = game.keeperReachAt(game.flightT);
    at(
      keeperX,
      keeperDepth,
      (depth) => _paintBody(
        canvas,
        p,
        feet: p.projectWorld(keeperX, keeperDepth, 0),
        depth: depth,
        halfWidth: ShotWorld.keeperHalfWidth,
        height: ShotWorld.keeperHeight,
        color: _warning,
        alpha: 0.85,
      ),
    );

    if (game.phase != ShotPhase.strike) {
      final ball = game.ballAt(game.flightT);
      final resting = game.phase == ShotPhase.aim;
      final lateral = resting ? 0.0 : ball.lateral;
      final depth = resting ? 0.0 : ball.depth;
      final z = resting ? 0.0 : ball.z;
      final world = PitchProjector.cameraToWorld(
        lateral,
        depth,
        game.cameraAngle,
      );
      // Never culled: it starts at the camera line, where a body would be
      // thrown away, and it is the one thing that always has to be on screen.
      at(
        world.x,
        world.y,
        (_) => _paintBall(canvas, p, lateral, depth, z),
        cull: false,
      );
    }

    actors.sort((a, b) => b.depth.compareTo(a.depth));
    for (final actor in actors) {
      actor.paint();
    }
  }

  void _paintBody(
    Canvas canvas,
    PitchProjector p, {
    required Offset feet,
    required double depth,
    required double halfWidth,
    required double height,
    required Color color,
    required double alpha,
  }) {
    final o = p.pointOpacity(depth);
    final s = p.scale(depth);
    final w = halfWidth * 2 * p.halfWidth * s;
    final h = height * p.zScale * s;

    canvas.drawOval(
      Rect.fromCenter(center: feet, width: w * 1.6, height: w * 0.5),
      Paint()..color = Colors.black.withValues(alpha: 0.35 * o),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(feet.dx - w / 2, feet.dy - h, w, h),
        const Radius.circular(3),
      ),
      Paint()..color = color.withValues(alpha: alpha * o),
    );
  }

  void _paintBall(
    Canvas canvas,
    PitchProjector p,
    double lateral,
    double depth,
    double z,
  ) {
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
