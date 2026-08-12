/// What a training mini-game hands back to the screen that launched it.
///
/// Every training game follows the same three rules, by convention rather than
/// by a shared base class — the games have almost nothing structural in common
/// (a countdown driven by outside buttons, a one-dimensional oscillator, a
/// drag-then-tap over a pseudo-3D pitch), so a common supertype would hold one
/// field and buy nothing:
///
/// 1. the constructor takes `onStateChanged` — a bare rebuild signal for the
///    hosting widget — and `onFinished`, a [TrainingResult] sink fired exactly
///    once per session;
/// 2. all the rules live in `void advance(double dt)`, which never reads
///    `size`;
/// 3. `update(dt)` is only `super.update(dt); advance(dt);`.
///
/// Rule 2 is what makes the scoring testable with no widget and no game loop,
/// the same constraint `test/shot_aim_test.dart` already relies on.
library;

/// Which drill produced a result. This doubles as the identity a training card
/// carries, so the card, the launcher and the future PlayerState effect all
/// agree on one key.
enum TrainingDrill { conditioning, strength, shot, pass, flexibility, dribble }

enum TrainingOutcome { success, failure }

class TrainingResult {
  const TrainingResult({
    required this.drill,
    required this.outcome,
    required this.score,
    required this.detail,
  });

  final TrainingDrill drill;

  final TrainingOutcome outcome;

  /// 0..1 — how well it went, not just whether it passed. Nothing reads this
  /// yet; it is here so the eventual stat gain can be proportional rather than
  /// a flat bonus.
  final double score;

  /// One Turkish line for the result panel, e.g. '22/24 adım'.
  final String detail;

  bool get succeeded => outcome == TrainingOutcome.success;
}
