import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/foundation.dart' show ValueChanged, ValueNotifier;

import 'package:project_srpg/game/game_banner.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Which button was pressed. The whole drill is one alternating rhythm, so
/// this is the entire input alphabet.
enum RunSide { left, right }

enum ConditioningPhase { ready, running, done }

const _skin = Color(0xFFC08A63);
const _danger = AppColors.dangerBright;

/// Green while there is room, amber past halfway, red inside the last
/// [ConditioningGame.warnFraction]. The bar is the clock — a conditioning run
/// never shows a number of seconds.
Color conditioningBarColor(double left) => left <= ConditioningGame.warnFraction
    ? _danger
    : (left <= 0.5 ? AppColors.warning : AppColors.success);

/// The treadmill drill: alternate SOL and SAĞ to keep the runner going, and
/// reach [targetSteps] before the clock runs out.
///
/// Follows the training-game convention documented in `training_result.dart`:
/// every rule lives in [advance], which never reads `size`, so the whole
/// scoring table is drivable from a unit test with no widget behind it.
class ConditioningGame extends FlameGame {
  ConditioningGame({required this.onStateChanged, required this.onFinished});

  final VoidCallback onStateChanged;
  final ValueChanged<TrainingResult> onFinished;

  static const targetSteps = 24;
  static const runDuration = 12.0;

  /// Fraction of the run left when the bar goes red.
  static const warnFraction = 0.25;

  /// What a wrong-side tap costs: a beat where nothing you press counts.
  static const stumbleTime = 0.35;

  static const cadenceGain = 0.22;
  static const cadenceDecay = 0.55;

  /// Radians of leg cycle per second at full cadence.
  static const strideRate = 2 * math.pi * 2.2;

  ConditioningPhase phase = ConditioningPhase.ready;

  double elapsed = 0;

  /// 0..1. Drives the belt, the stride and the bounce — everything that makes
  /// stopping look like stopping.
  double cadence = 0;

  RunSide? lastSide;
  double stumbleLeft = 0;

  double leftFlash = 0;
  double rightFlash = 0;

  double stridePhase = 0;
  double beltPhase = 0;

  /// Watched by the time bar, which changes every frame. A notifier keeps that
  /// out of `setState`, so the host rebuilds only when something structural
  /// changes.
  final ValueNotifier<double> timeLeft = ValueNotifier<double>(1);

  final ValueNotifier<int> stepCount = ValueNotifier<int>(0);

  int get steps => stepCount.value;

  bool get succeeded => steps >= targetSteps;

  TrainingResult get result => TrainingResult(
        drill: TrainingDrill.conditioning,
        outcome:
            succeeded ? TrainingOutcome.success : TrainingOutcome.failure,
        score: (steps / targetSteps).clamp(0.0, 1.0),
        detail: '$steps/$targetSteps adım',
      );

  @override
  Color backgroundColor() => AppColors.surface1;

  @override
  Future<void> onLoad() async {
    addAll([TreadmillComponent(), RunnerComponent()]);
  }

  @override
  void onRemove() {
    timeLeft.dispose();
    stepCount.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    advance(dt);
  }

  /// One foot down. The clock starts on the first press rather than on mount,
  /// so the run cannot bleed away while the screen animates in.
  void step(RunSide side) {
    if (phase == ConditioningPhase.done) return;

    if (phase == ConditioningPhase.ready) {
      phase = ConditioningPhase.running;
      _countStep(side);
      onStateChanged();
      return;
    }

    // Mid-stumble nothing lands. You have to let him recover first.
    if (stumbleLeft > 0) return;

    if (side == lastSide) {
      // Wrong foot. No step, and [lastSide] deliberately stays put — the way
      // out is to press the button you owed, not to press this one again. The
      // cost is indirect: lost cadence, and the time the stumble eats.
      stumbleLeft = stumbleTime;
      cadence *= 0.3;
      onStateChanged();
      return;
    }

    _countStep(side);
  }

  void _countStep(RunSide side) {
    stepCount.value++;
    lastSide = side;
    cadence = math.min(1, cadence + cadenceGain);
    if (side == RunSide.left) {
      leftFlash = 0.25;
    } else {
      rightFlash = 0.25;
    }
  }

  /// Every rule of the drill, in one clock-driven step. Reads no `size` and
  /// touches no component, so a test can run a whole 12-second run in a loop.
  void advance(double dt) {
    if (phase != ConditioningPhase.running) return;

    elapsed += dt;
    timeLeft.value = (1 - elapsed / runDuration).clamp(0.0, 1.0);

    stumbleLeft = math.max(0, stumbleLeft - dt);
    cadence = math.max(0, cadence - cadenceDecay * dt);
    leftFlash = math.max(0, leftFlash - dt);
    rightFlash = math.max(0, rightFlash - dt);

    beltPhase = (beltPhase + dt * (0.35 + 1.6 * cadence)) % 1;
    if (stumbleLeft == 0) stridePhase += dt * cadence * strideRate;

    if (succeeded || elapsed >= runDuration) _finish();
  }

  void _finish() {
    phase = ConditioningPhase.done;
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

/// The machine: backdrop, deck, console, and the scrolling belt that is the
/// drill's main motion cue. Stop tapping and the tread lines freeze.
class TreadmillComponent extends Component
    with HasGameReference<ConditioningGame> {
  @override
  int get priority => 0;

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;

    _paintBackdrop(canvas, u, v);
    _paintDeck(canvas, u, v);
    _paintConsole(canvas, u, v);
  }

  void _paintBackdrop(Canvas canvas, double u, double v) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, u, v),
      Paint()..color = AppColors.surface1,
    );

    // A mirrored wall panel: three shapes are enough to say "gym".
    canvas.drawRect(
      Rect.fromLTRB(u * 0.05, v * 0.20, u * 0.16, v * 0.66),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.05),
    );

    final seam = Paint()
      ..color = AppColors.border.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, v * 0.30), Offset(u, v * 0.30), seam);
    canvas.drawLine(Offset(0, v * 0.66), Offset(u, v * 0.66), seam);
  }

  void _paintDeck(Canvas canvas, double u, double v) {
    final deck = Rect.fromLTRB(u * 0.16, v * 0.735, u * 0.84, v * 0.795);

    // Offset slab behind the deck, standing in for its thickness.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        deck.translate(u * 0.01, v * 0.012),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF14171D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(deck, const Radius.circular(4)),
      Paint()..color = AppColors.surface2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(deck, const Radius.circular(4)),
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final belt = Rect.fromLTRB(u * 0.185, v * 0.740, u * 0.815, v * 0.772);
    canvas.drawRect(belt, Paint()..color = const Color(0xFF15181E));

    canvas.save();
    canvas.clipRect(belt);
    final tread = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.10)
      ..strokeWidth = 1.5;
    const count = 14;
    // Slanted so the belt reads as receding rather than as a flat ladder.
    final slant = belt.height * 0.6;
    for (var i = 0; i < count; i++) {
      final t = (i / count + game.beltPhase) % 1;
      final x = belt.left + t * belt.width;
      canvas.drawLine(
        Offset(x, belt.top),
        Offset(x - slant, belt.bottom),
        tread,
      );
    }
    canvas.restore();

    // Side rails along the deck edges.
    final rail = Paint()..color = AppColors.border;
    canvas.drawRect(
      Rect.fromLTRB(u * 0.16, v * 0.732, u * 0.84, v * 0.737),
      rail,
    );
  }

  void _paintConsole(Canvas canvas, double u, double v) {
    final console = Rect.fromLTWH(u * 0.72, v * 0.44, u * 0.13, v * 0.17);

    canvas.save();
    canvas.translate(console.center.dx, console.center.dy);
    canvas.rotate(-0.12);
    canvas.translate(-console.center.dx, -console.center.dy);

    canvas.drawRRect(
      RRect.fromRectAndRadius(console, const Radius.circular(5)),
      Paint()..color = AppColors.surface2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(console, const Radius.circular(5)),
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Three readout bars, lit as the run fills up. No text — the banner owns
    // the only words on this canvas.
    final lit = math.min(
      3,
      game.steps * 3 ~/ ConditioningGame.targetSteps,
    );
    for (var i = 0; i < 3; i++) {
      final bar = Rect.fromLTWH(
        console.left + console.width * 0.18,
        console.top + console.height * (0.24 + i * 0.22),
        console.width * 0.64,
        console.height * 0.10,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = i < lit ? AppColors.accent : AppColors.border.withValues(alpha: 0.6),
      );
    }
    canvas.restore();

    // Uprights down to the deck.
    final post = Paint()
      ..color = AppColors.surface2
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(console.left + console.width * 0.3, console.bottom),
      Offset(u * 0.76, v * 0.735),
      post,
    );
    canvas.drawLine(
      Offset(console.left + console.width * 0.8, console.bottom),
      Offset(u * 0.81, v * 0.735),
      post,
    );
  }
}

/// The runner. Prefers the two-frame pixel-art stride ([_frame1]/[_frame2],
/// §1.2 — swapped on the sign of `sin(stridePhase)` the same way the
/// procedural rig alternates legs) and falls back to the stick-and-slab
/// figure the shot game's players already use when the assets are missing.
class RunnerComponent extends Component
    with HasGameReference<ConditioningGame> {
  @override
  int get priority => 5;

  Sprite? _frame1;
  Sprite? _frame2;

  @override
  Future<void> onLoad() async {
    try {
      _frame1 = await Sprite.load('sprites/run_side_1.png');
      _frame2 = await Sprite.load('sprites/run_side_2.png');
    } catch (_) {
      _frame1 = null;
      _frame2 = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;

    final phi = game.stridePhase;
    final cadence = game.cadence;
    final stumbling = game.stumbleLeft > 0;

    final hip = Offset(u * 0.44, v * 0.60);
    final bob = math.sin(phi * 2) * v * 0.012 * cadence;

    canvas.save();
    canvas.translate(0, bob);
    if (stumbling) {
      canvas.translate(hip.dx, hip.dy);
      canvas.rotate(0.18);
      canvas.translate(-hip.dx, -hip.dy);
    }

    final frame1 = _frame1;
    final frame2 = _frame2;
    if (frame1 != null && frame2 != null) {
      _paintSprite(canvas, math.sin(phi) >= 0 ? frame1 : frame2, hip, v);
    } else {
      final thigh = v * 0.085;
      final shin = v * 0.085;

      // Back leg first, then the torso, then the front leg and arms, so the
      // figure reads with depth without any z-sorting machinery.
      _paintLeg(canvas, hip, phi + math.pi, thigh, shin, u, v,
          side: RunSide.left, back: true);
      _paintTorso(canvas, hip, u, v);
      _paintLeg(canvas, hip, phi, thigh, shin, u, v,
          side: RunSide.right, back: false);
      _paintArms(canvas, hip, phi, v);
      _paintHead(canvas, hip, v);
    }

    if (stumbling) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(hip.dx, v * 0.70),
          width: u * 0.14,
          height: v * 0.05,
        ),
        0,
        math.pi,
        false,
        Paint()
          ..color = _danger
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    canvas.restore();
  }

  /// One stride frame, feet anchored near the old rig's average foot height
  /// so swapping frame doesn't move the ground contact point.
  void _paintSprite(Canvas canvas, Sprite sprite, Offset hip, double v) {
    final destHeight = v * 0.34;
    final destWidth = destHeight * sprite.srcSize.x / sprite.srcSize.y;
    sprite.render(
      canvas,
      position: Vector2(hip.dx, hip.dy + v * 0.14),
      size: Vector2(destWidth, destHeight),
      anchor: Anchor.bottomCenter,
    );
  }

  void _paintLeg(
    Canvas canvas,
    Offset hip,
    double phi,
    double thigh,
    double shin,
    double u,
    double v, {
    required RunSide side,
    required bool back,
  }) {
    // The knee folds on the recovery swing and straightens on the drive.
    final thighAngle = 0.55 * math.sin(phi);
    final kneeBend = 0.60 + 0.60 * math.max(0, -math.sin(phi));

    final knee = hip +
        Offset(math.sin(thighAngle) * thigh, math.cos(thighAngle) * thigh);
    final shinAngle = thighAngle - kneeBend;
    final foot =
        knee + Offset(math.sin(shinAngle) * shin, math.cos(shinAngle) * shin);

    final paint = Paint()
      ..color = back
          ? AppColors.textSecondary.withValues(alpha: 0.55)
          : AppColors.textSecondary
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hip, knee, paint);
    canvas.drawLine(knee, foot, paint);

    // The shoe of whichever foot just planted lights up: that is the entire
    // feedback loop for alternating, so it has to be unmistakable.
    final flashing =
        (side == RunSide.left ? game.leftFlash : game.rightFlash) > 0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: foot, width: u * 0.030, height: v * 0.012),
        const Radius.circular(3),
      ),
      Paint()..color = flashing ? AppColors.success : const Color(0xFF11131A),
    );
  }

  void _paintTorso(Canvas canvas, Offset hip, double u, double v) {
    final shoulder = hip + Offset(0, -v * 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          shoulder - Offset(u * 0.0275, 0),
          hip + Offset(u * 0.0275, 0),
        ),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.accent.withValues(alpha: 0.85),
    );
  }

  /// Both arms, counter-swinging the legs.
  void _paintArms(Canvas canvas, Offset hip, double phi, double v) {
    final shoulder = hip + Offset(0, -v * 0.14);
    final upper = v * 0.062;
    final fore = v * 0.058;

    // Arm 0 swings against the right leg, arm 1 against the left.
    for (final side in [0, 1]) {
      final swing = side == 0 ? phi + math.pi : phi;
      final elbowAngle = -1.2 + 0.9 * math.sin(swing);
      final elbow = shoulder +
          Offset(math.sin(elbowAngle) * upper, math.cos(elbowAngle) * upper);
      final handAngle = elbowAngle + 1.1;
      final hand =
          elbow + Offset(math.sin(handAngle) * fore, math.cos(handAngle) * fore);

      final paint = Paint()
        ..color = side == 0
            ? AppColors.textSecondary
            : AppColors.textSecondary.withValues(alpha: 0.55)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(shoulder, elbow, paint);
      canvas.drawLine(elbow, hand, paint);
    }
  }

  void _paintHead(Canvas canvas, Offset hip, double v) {
    final center = hip + Offset(0, -v * 0.175);
    final r = v * 0.030;
    canvas.drawCircle(center, r, Paint()..color = _skin);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF2A2119),
    );
  }
}
