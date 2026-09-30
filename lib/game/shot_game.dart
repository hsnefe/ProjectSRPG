import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors, ValueChanged;

import 'package:project_srpg/game/game_banner.dart';
import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/player_sprites.dart';
import 'package:project_srpg/game/shot_objective.dart';
import 'package:project_srpg/game/training_result.dart';

export 'package:project_srpg/game/shot_objective.dart';
import 'package:project_srpg/theme/app_colors.dart';

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
  ///
  /// Kept as the shorthand it always was; the grading itself goes through
  /// [objective], which a scene can override with something finer-grained.
  final String? successLabel;

  /// How a session in this mode is graded when the scene does not say.
  ///
  /// Two-tier by construction: a plain drill has no "çok başarılı" — the third
  /// rung arrives with the scenarios, which bring their own objectives.
  ShotObjective get objective => switch (this) {
    ShotMode.free => ShotObjective.none,
    ShotMode.shot => ShotObjective.goalOnly,
    ShotMode.pass => ShotObjective.passOnly,
  };

  /// The world this mode plays in when the caller does not name one. Keeping
  /// the default here is what leaves every existing call site — the prototype
  /// screen and both training drills — constructing exactly the game it always
  /// did.
  ShotScene get defaultScene => switch (this) {
    ShotMode.free || ShotMode.shot => ShotScene.full,
    ShotMode.pass => ShotScene.passDrill,
  };
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
    this.isKey = false,
  });

  final String label;
  final double x;
  final double y;
  final bool isGoal;
  final bool isRival;

  /// The decisive option in a scenario: the man behind the line, the runner in
  /// behind, the one the safe ball is not going to. Finding him is what turns a
  /// completed pass from `başarılı` into `çok başarılı` — see
  /// [ShotObjective.keyPassIsGreat]. At most one per scene, by convention.
  final bool isKey;

  double get distance => math.sqrt(x * x + y * y);
  double get facingAngle => PitchProjector.angleToward(x, y);

  static const goal = ShotTarget(label: 'Kale', x: 0, y: 1, isGoal: true);
  static const leftWing = ShotTarget(label: 'Sol kanat', x: -0.9, y: 0.55);
  static const rightBack = ShotTarget(label: 'Sağ bek', x: 0.95, y: 0.15);
  static const backPass = ShotTarget(label: 'Geri pas', x: 0.05, y: -0.75);

  /// The opposition. They stand off the obvious lines rather than on them —
  /// a defender parked on the shot you are about to take is not a decision —
  /// and close the ball down once it is struck.
  static const rivalCentreBack = ShotTarget(
    label: 'Rakip stoper',
    x: -0.45,
    y: 0.80,
    isRival: true,
  );
  static const rivalMidfielder = ShotTarget(
    label: 'Rakip orta saha',
    x: -0.50,
    y: 0.66,
    isRival: true,
  );
  static const rivalFullBack = ShotTarget(
    label: 'Rakip bek',
    x: 0.85,
    y: 0.40,
    isRival: true,
  );

  /// The team mates of a full-sized scene. The goal is not in here: it is not
  /// somebody you pass to, and [ShotScene.scoresGoals] is what decides whether
  /// it can be scored in.
  static const teamMates = [leftWing, rightBack, backPass];

  /// What the free-mode compass can point at. A scene with its own cast passes
  /// its own list to [inFrontOf] instead.
  static const all = [goal, ...teamMates];

  static const rivals = [rivalCentreBack, rivalMidfielder, rivalFullBack];

  /// Whatever stands closest to the given bearing, if anything does. The
  /// player turns to look somewhere; what is in front of them follows from
  /// the world, rather than being picked from a menu.
  static ShotTarget? inFrontOf(
    Facing facing, {
    List<ShotTarget> candidates = all,
  }) {
    ShotTarget? best;
    var bestDiff = double.infinity;
    for (final t in candidates) {
      final diff = ShotGame.shortestAngle(t.facingAngle - facing.angle).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = t;
      }
    }
    return bestDiff <= math.pi / 4 ? best : null;
  }
}

/// The world a session is played in: who is standing on the pitch, whether a
/// keeper and a scoreable goal exist at all, and where the player takes the
/// ball from.
///
/// The rules do not branch on the mode — [ShotGame.resolve] still cannot see
/// one. They read this instead, which is what lets a skill exam strip the pitch
/// down to an empty goal or a single team mate without a second rule set.
class ShotScene {
  const ShotScene({
    required this.receivers,
    required this.rivals,
    this.facing = Facing.forward,
    this.lookAt,
    this.hasKeeper = true,
    this.scoresGoals = true,
    this.origin = (x: 0.0, y: 0.0),
    this.defaultAimDepth = ShotWorld.defaultAimDepth,
    this.defaultAimLateral = 0,
    this.maxAimDepth = ShotWorld.maxAimDepth,
    this.backY = PitchLines.backY,
    this.objective,
  });

  /// Everyone in your own shirt: they get drawn, they block the ball, and a
  /// ball arriving at one of them is judged as a pass.
  final List<ShotTarget> receivers;

  final List<ShotTarget> rivals;

  /// Which way the camera starts out looking, on the four-point compass. Only
  /// the free-mode prototype turns, so this is a starting bearing everywhere
  /// else — and [lookAt] overrides it when a scene needs one off the compass.
  final Facing facing;

  /// An absolute ground point to face instead. A scenario is built by placing
  /// people and then looking at them, rather than by working out the bearing
  /// that happens to put them on screen.
  final GroundPoint? lookAt;

  /// Whether anybody is minding the goal. False leaves it empty — a shot on
  /// target simply goes in.
  final bool hasKeeper;

  /// Whether crossing the goal line is an outcome at all. False is not "the
  /// goal is gone": it is "this drill is not about the goal", so a ball that
  /// runs on past a team mate is a stray pass rather than a goal.
  final bool scoresGoals;

  /// Where the player stands, in absolute world coordinates.
  final GroundPoint origin;

  final double defaultAimDepth;

  /// Nişanın açılışta durduğu yanal kayma.
  ///
  /// Sıfır "tam karşı" demek ve uzun süre öyleydi, çünkü kamera zaten
  /// seçeneklerin ortasına bakıyordu. Kamera oyun yönüne sabitlenince bu
  /// bozuldu: yana kalan bir seçenekte nişan hedeften uzakta başlıyordu.
  /// Artık derinlik gibi bu da sahnenin kendi kadrosundan geliyor.
  final double defaultAimLateral;

  final double maxAimDepth;

  /// How far back the ground is drawn, in absolute world coordinates.
  ///
  /// The default stops at the halfway line, which is where the attacking half
  /// ends and — at every bearing from the origin — past the top of the screen.
  /// A scene that stands behind that line has to open the pitch out behind it,
  /// or the player would be standing on the edge of the world.
  final double backY;

  /// What this scene is asking for. Null falls back to [ShotMode.objective],
  /// which is what leaves the two drills and the two exams graded exactly as
  /// they were before scenarios existed.
  final ShotObjective? objective;

  /// The bearing the camera starts at: [lookAt] if the scene named a point,
  /// otherwise the compass point in [facing].
  double get startAngle {
    final look = lookAt;
    return look == null
        ? facing.angle
        : math.atan2(look.x - origin.x, look.y - origin.y);
  }

  /// The same scene with a few things changed. Used by the catalog test to
  /// strip the opposition out and check the geometry on its own.
  ShotScene copyWith({
    List<ShotTarget>? receivers,
    List<ShotTarget>? rivals,
    bool? hasKeeper,
    bool? scoresGoals,
    ShotObjective? objective,
  }) => ShotScene(
    receivers: receivers ?? this.receivers,
    rivals: rivals ?? this.rivals,
    facing: facing,
    lookAt: lookAt,
    hasKeeper: hasKeeper ?? this.hasKeeper,
    scoresGoals: scoresGoals ?? this.scoresGoals,
    origin: origin,
    defaultAimDepth: defaultAimDepth,
    defaultAimLateral: defaultAimLateral,
    maxAimDepth: maxAimDepth,
    backY: backY,
    objective: objective ?? this.objective,
  );

  /// Everyone with a body on the pitch: what the ball can run into, and what
  /// gets drawn. The goal has no body and the keeper is his own case.
  ///
  /// Built on every read, so the contact sweep hoists it out of its loop rather
  /// than allocating one per sample.
  List<ShotTarget> get bodies => [...receivers, ...rivals];

  /// The prototype and the shooting drill: a full pitch, everyone on it.
  static const full = ShotScene(
    receivers: ShotTarget.teamMates,
    rivals: ShotTarget.rivals,
    facing: Facing.forward,
  );

  /// The passing drill. Same world, and the player simply starts out looking
  /// at a team mate instead of at the goal.
  static const passDrill = ShotScene(
    receivers: ShotTarget.teamMates,
    rivals: ShotTarget.rivals,
    facing: Facing.left,
  );

  /// The shooting exam: a penalty into an empty goal, three times.
  ///
  /// [origin] is the penalty spot, so the spot sits under the ball rather than
  /// eleven metres in front of it and the goal is the distance it should be.
  /// The aim reach shrinks with the distance — reaching the far touchline from
  /// here would only make the reticle harder to place on the goal.
  static const shotExam = ShotScene(
    receivers: [],
    rivals: [],
    facing: Facing.forward,
    hasKeeper: false,
    origin: (x: 0.0, y: PitchLines.penaltySpotY),
    defaultAimDepth: PitchLines.penaltySpotDepth,
    maxAimDepth: 0.75,
  );

  /// The passing exam: one team mate standing still, and nothing else.
  ///
  /// [scoresGoals] is off because the goal is still out there to the right of
  /// frame: without it a pass hit hard enough to run on across the line would
  /// come back as 'GOL!' in a passing exam. A ball that misses its man is a
  /// missed pass no matter where it ends up.
  static const passExam = ShotScene(
    receivers: [ShotTarget.leftWing],
    rivals: [],
    facing: Facing.left,
    hasKeeper: false,
    scoresGoals: false,
  );
}

/// Which family a scenario belongs to. Drives nothing in the rules — it is how
/// a session picks a varied playlist and how the header labels what you are
/// about to be asked to do.
enum ShotScenarioKind {
  /// Bitiriş: kaleye şut, her seferinde başka bir açıdan.
  shot('Şut'),

  /// Geriden oyun kurulumu: kendi yarı sahandan ilk pas.
  buildUp('Geriden kurulum'),

  /// Geçiş başlatma: topu kazandıktan sonraki ilk top.
  transition('Geçiş'),

  /// İleride pas: son otuz metre, son pas.
  finalThird('Son bölge');

  const ShotScenarioKind(this.label);

  final String label;

  /// Which drill a session of these scenarios reports itself as.
  ShotMode get mode =>
      this == ShotScenarioKind.shot ? ShotMode.shot : ShotMode.pass;
}

/// One authored situation: a place on the pitch, a cast, and what is being
/// asked for. The catalog of them lives in `shot_scenarios.dart`.
///
/// A scenario is deliberately thin — it is a [ShotScene] plus the words that
/// go around it. The rules never read one; they read the scene it carries,
/// which is what keeps a forty-entry catalog from leaking into [ShotGame].
class ShotScenario {
  const ShotScenario({
    required this.id,
    required this.kind,
    required this.title,
    required this.brief,
    required this.scene,
    required this.aimHint,
    this.actionKey,
  });

  /// Stable key, unique across the catalog. Logged with each attempt.
  final String id;

  final ShotScenarioKind kind;

  /// Ekran başlığı, ör. 'Sol yarı alandan içeri kat'.
  final String title;

  /// Tek satırlık durum tarifi — ne olduğu ve ne beklendiği.
  final String brief;

  final ShotScene scene;

  /// Nişan fazının ipucu: bu durumda neye bakılacağı.
  final String aimHint;

  /// Bu durumun hangi maç aksiyonunda teklif edileceği (§7.3), ya da hiçbirinde
  /// çıkmıyorsa null.
  ///
  /// Havuzları ayrı bir listede tutmak iki yerin elle senkron kalmasını
  /// gerektiriyordu; müdahale katalogu bunu zaten aile adıyla çözmüştü
  /// (`match_scenarios.dart`). Anahtarın senaryonun kendisinde durması aynı
  /// çözümün şut tarafındaki karşılığı: bir durumu editörde bir aksiyona
  /// bağlamak onu havuza da sokuyor.
  final String? actionKey;

  ShotObjective get objective => scene.objective ?? kind.mode.objective;
}

/// One resolved flight, kept for the footer and the session total.
class ShotAttempt {
  const ShotAttempt({
    required this.grade,
    required this.label,
    required this.score,
    this.scenarioId,
  });

  final ShotGrade grade;

  /// The raw outcome label the flight produced, e.g. 'PAS TUTTU'.
  final String label;

  /// 0..1. Carried per attempt rather than derived at the end, because a
  /// playlist can grade each of its attempts against a different objective.
  final double score;

  final String? scenarioId;

  bool get made => grade.counts;
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
    ShotScene? scene,
    this.playlist = const [],
    this.onFinished,
    this.teamKit = Kit.home,
    this.rivalKit = Kit.away,
    this.keeperKit = Kit.keeper,
  }) : _fixedScene = scene ?? mode.defaultScene {
    // A pass drill starts out looking at a team mate rather than at the goal,
    // and an exam or a scenario looks wherever its scene points. The bearing is
    // the only thing set up front; every other rule reads the scene as it runs.
    facing = this.scene.facing;
    desiredAngle = this.scene.startAngle;
    cameraAngle = desiredAngle;
    aimDepth = this.scene.defaultAimDepth;
    aimLateral = this.scene.defaultAimLateral;
  }

  /// Lets the surrounding Flutter UI rebuild its readout.
  final VoidCallback onStateChanged;

  /// Colours of the three shirts on the pitch. One sprite set serves every kit
  /// (see [PlayerSprites]), so a club's colours are just three [Kit]s.
  final Kit teamKit;
  final Kit rivalKit;
  final Kit keeperKit;

  /// Null until the sheets have decoded, and for good when they cannot be
  /// loaded (a test bundle without them): [ActorsComponent] then falls back to
  /// the plain bodies this game was first drawn with.
  PlayerSprites? sprites;

  /// Defaulted so the prototype screen and the existing tests construct this
  /// game exactly as they always did.
  final ShotMode mode;

  /// The world used when there is no playlist. Fixed for the life of the game.
  final ShotScene _fixedScene;

  /// The situations this session runs through, one per attempt.
  ///
  /// Empty is the old behaviour and still the common one: the prototype, the
  /// two exams and any caller that names a scene outright play all three
  /// attempts in the same world. A non-empty playlist moves the player to a
  /// different part of the pitch between attempts, which is the whole point of
  /// it — the shot you just took is not the shot you are about to take.
  ///
  /// Shorter than [attemptsPerSession] is allowed; the last entry simply
  /// repeats.
  final List<ShotScenario> playlist;

  /// Which entry the *current* attempt is being played on.
  ///
  /// Advanced by [reset], not by [attempts], so the world cannot change out
  /// from under a ball that has already been struck: the tally goes up the
  /// moment a flight resolves, and the result banner is still being read.
  int _scenarioIndex = 0;

  ShotScenario? get scenario => playlist.isEmpty
      ? null
      : playlist[_scenarioIndex.clamp(0, playlist.length - 1)];

  /// The pitch the current attempt is played on.
  ShotScene get scene => scenario?.scene ?? _fixedScene;

  /// What the current attempt is being graded against.
  ShotObjective get objective => scene.objective ?? mode.objective;

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
  ShotTarget? get target => ShotTarget.inFrontOf(
    facing,
    candidates: [ShotTarget.goal, ...scene.receivers],
  );

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
  final List<ShotAttempt> attemptLog = <ShotAttempt>[];

  int get attempts => attemptLog.length;

  int get made => attemptLog.where((a) => a.made).length;

  /// How many of the made attempts were the *good* answer rather than the safe
  /// one — the third rung the scenarios brought with them.
  int get great => attemptLog.where((a) => a.grade == ShotGrade.great).length;

  /// How well the flight now showing went, derived from the label rather than
  /// stored: the same outcome is a different grade depending on what the
  /// scenario was asking for, and on which of two team mates it reached.
  ShotGrade get lastGrade {
    final label = result;
    return label == null
        ? ShotGrade.fail
        : objective.gradeOf(label, keyReceiver: _lastReceiver?.isKey ?? false);
  }

  bool get lastAttemptSucceeded => lastGrade.counts;

  /// Whoever took the last pass in, when anybody did. Only a *caught* ball
  /// fills this in — the grade is about who received it, not who it was near.
  ShotTarget? _lastReceiver;

  /// Made attempts → exam grade, on the catalog's five-level scale.
  ///
  /// Three attempts produce four outcomes and the scale has five rungs, so one
  /// rung is unreachable by construction; it is the middle one, which keeps the
  /// table symmetric. Retune here and nowhere else.
  static const gradeByMade = [1, 2, 4, 5];

  int get examGrade => gradeByMade[made];

  /// What the attempts were worth, 0..1. Averaged over the *session* length
  /// rather than over what was played, so an abandoned session cannot score
  /// full marks, and weighted per attempt because a playlist grades each of
  /// its situations against its own objective.
  double get sessionScore =>
      attemptLog.fold<double>(0, (sum, a) => sum + a.score) /
      attemptsPerSession;

  /// What the tally is counting. A playlist mixes finishes with lay-offs and
  /// line-breaking passes, so it counts plain successes.
  String get _unit {
    if (playlist.isNotEmpty) return 'başarılı';
    return mode == ShotMode.pass ? 'isabetli pas' : 'gol';
  }

  TrainingResult get sessionResult => TrainingResult(
    drill: mode == ShotMode.pass ? TrainingDrill.pass : TrainingDrill.shot,
    outcome: made >= madeToPass
        ? TrainingOutcome.success
        : TrainingOutcome.failure,
    score: sessionScore,
    detail: great > 0
        ? '$made/$attemptsPerSession $_unit · $great çok başarılı'
        : '$made/$attemptsPerSession $_unit',
  );

  Size get screenSize => Size(size.x, size.y);

  PitchProjector get projector => PitchProjector(
    size: screenSize,
    cameraAngle: cameraAngle,
    origin: scene.origin,
  );

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
    // Not awaited: the pitch is playable as plain bodies the moment it mounts,
    // and the sprites take over a few frames later.
    _loadSprites();
  }

  Future<void> _loadSprites() async {
    try {
      sprites = await PlayerSprites.load(images);
    } catch (_) {
      sprites = null;
    }
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
    // Reset first: it re-points the camera at the scene's own bearing, which
    // would undo the turn if it ran second.
    reset();
    facing = next;
    desiredAngle = next.angle;
    onStateChanged();
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

    final reach = scene.maxAimDepth - ShotWorld.minAimDepth;
    aimDepth = (scene.defaultAimDepth - delta.dy / (size.y * 0.34) * reach)
        .clamp(ShotWorld.minAimDepth, scene.maxAimDepth);

    // Two caps: the gameplay one, and whatever is still on screen at this
    // depth, kept just inside the edge.
    final limit = math.min(
      ShotWorld.maxAimLateral,
      projector.visibleLateral(aimDepth) * 0.97,
    );
    // Derinlik gibi yanal da nişanın durduğu yerden itibaren sürükleniyor;
    // sıfırdan başlasaydı ilk dokunuş reticle'ı hedefin yanından kaçırırdı.
    aimLateral =
        (scene.defaultAimLateral +
                delta.dx / (size.x * 0.32) * ShotWorld.maxAimLateral)
            .clamp(-limit, limit);

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

    final timing =
        1 -
        ((ringRadius - strikeRadius).abs() / (strikeRadius * 0.9)).clamp(
          0.0,
          1.0,
        );

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
    _keeperTarget = !scene.hasKeeper || _shotAtGoal() == null
        ? 0
        : _goalLineCrossing(
                withSpin: false,
              )?.x.clamp(-ShotWorld.keeperMaxX, ShotWorld.keeperMaxX) ??
              0;

    final outcome = resolve();
    result = outcome.label;
    _lastReceiver = outcome.receiver;
    // A touched ball stops where it was touched and is given a moment to drop;
    // everything else plays out the whole flight.
    _stopT = outcome.touched ? outcome.t : null;
    flightDuration = outcome.touched
        ? outcome.t + ShotWorld.settleTime
        : _flightSpan;

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
  GroundPoint worldAt(double t) => PitchProjector.cameraToWorld(
    lateralAt(t),
    depthAt(t),
    cameraAngle,
    origin: scene.origin,
  );

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
    for (final rival in scene.rivals) {
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
        origin: scene.origin,
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

    final bodies = scene.bodies;
    if (bodies.isEmpty) return null;

    for (var i = 1; i <= _sweepSamples; i++) {
      final t = _flightSpan * i / _sweepSamples;
      // Over everyone's head there is nothing to hit.
      if (heightAt(t) >= ShotWorld.blockHeight) continue;

      final ball = worldAt(t);
      for (final player in bodies) {
        final at = playerAt(player, t);
        if (_gap(ball, at) < ShotWorld.blockRadius) {
          return (t: t, player: player);
        }
      }
    }
    return null;
  }

  /// The lateral offset the keeper commits to at launch, for the dive pose.
  double get keeperTarget => _keeperTarget;

  /// How a body is turned and moving at time [t], for picking its sprite.
  ///
  /// Everybody looks at the ball's spot — a receiver faces the man passing to
  /// him, a defender the man shooting — except a rival on his run, who faces
  /// where he is going. A body standing on the spot itself has nothing to look
  /// at and turns to the camera.
  ({double facing, bool running}) stanceOf(ShotTarget player, double t) {
    final at = playerAt(player, t);
    final toBall = scene.origin;

    if (player.isRival) {
      final aim = _rivalRuns[player];
      if (aim != null && t > ShotWorld.rivalReaction) {
        final dx = aim.x - player.x;
        final dy = aim.y - player.y;
        final gap = math.sqrt(dx * dx + dy * dy);
        final travel = (t - ShotWorld.rivalReaction) * ShotWorld.rivalSpeed;
        if (gap > 1e-9 && travel < gap) {
          return (facing: PitchProjector.angleToward(dx, dy), running: true);
        }
      }
    }
    return (facing: facingFrom(at, toBall), running: false);
  }

  /// Bearing from [from] toward [to], or the camera's own reverse (so the body
  /// shows its front) when they coincide.
  double facingFrom(GroundPoint from, GroundPoint to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    if (dx * dx + dy * dy < 1e-4) return cameraAngle + math.pi;
    return PitchProjector.angleToward(dx, dy);
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
      z: math.max(0, heightAt(stop) - 0.5 * ShotWorld.gravity * fall * fall),
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
      origin: scene.origin,
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
    for (final t in scene.receivers) {
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
    if (!scene.scoresGoals) return null;

    final crossing = _goalLineCrossing();
    if (crossing == null) return null;

    final contact = _contact;
    if (contact != null && contact.t <= crossing.t) return null;
    if (crossing.t > timeToTarget && _receiver() != null) return null;
    return crossing;
  }

  void finishFlight() {
    phase = ShotPhase.result;
    if (result == null) {
      final outcome = resolve();
      result = outcome.label;
      _lastReceiver = outcome.receiver;
    }
    // Purely visual, and there is no view in a headless test — which is where
    // the session accounting below gets driven from.
    if (isMounted) {
      add(
        GameBanner(
          result!,
          // A scored session paints the banner with the grade the attempt just
          // earned; the free prototype has no objective, so it falls back to
          // "was that a good ball".
          highlight: mode == ShotMode.free
              ? _isGoodOutcome(result!)
              : lastGrade.counts,
        ),
      );
    }

    if (mode != ShotMode.free) {
      final grade = lastGrade;
      attemptLog.add(
        ShotAttempt(
          grade: grade,
          label: result!,
          score: objective.weightOf(grade),
          scenarioId: scenario?.id,
        ),
      );
      if (attempts >= attemptsPerSession) onFinished?.call(sessionResult);
    }

    onStateChanged();
  }

  /// Which labels the banner paints green. Broader than the mode's success
  /// criterion on purpose: a caught pass reads as a good ball even in a
  /// shooting drill, it just does not score.
  static bool _isGoodOutcome(String label) =>
      label == ShotLabel.goal || label == ShotLabel.passCaught;

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
  ({String label, double t, bool touched, ShotTarget? receiver}) resolve() {
    const r = ShotWorld.ballRadius;

    final atGoal = _shotAtGoal();
    if (atGoal != null) {
      final x = atGoal.x;
      final z = atGoal.z;
      // Anything that beats the keeper keeps flying; only a save stops here.
      ({String label, double t, bool touched, ShotTarget? receiver}) past(
        String label,
      ) => (label: label, t: _flightSpan, touched: false, receiver: null);

      if (x.abs() > ShotWorld.goalHalfWidth + r) return past(ShotLabel.wide);
      if (z > ShotWorld.crossbarHeight + r) return past(ShotLabel.over);
      if (x.abs() > ShotWorld.goalHalfWidth - r ||
          z > ShotWorld.crossbarHeight - r) {
        return past(ShotLabel.post);
      }

      // Keeper reach: harder to get to high balls. An empty goal has nobody
      // to beat, so anything on target simply goes in.
      final reach = z < 0.28 ? 0.15 : (z < 0.42 ? 0.07 : 0.0);
      if (scene.hasKeeper && (keeperReachAt(atGoal.t) - x).abs() < reach) {
        return (
          label: ShotLabel.save,
          t: atGoal.t,
          touched: true,
          receiver: null,
        );
      }

      return past(ShotLabel.goal);
    }

    // Nobody in your shirt gets it now: a rival got there first.
    final contact = _contact;
    if (contact != null && contact.player.isRival) {
      return (
        label: ShotLabel.intercepted,
        t: contact.t,
        touched: true,
        receiver: null,
      );
    }

    final tg = timeToTarget;
    final receiver = _receiver();
    if (receiver != null) {
      final caught =
          receiver.gap < ShotWorld.passCatchRadius &&
          heightAt(tg) < ShotWorld.passCatchHeight;
      return (
        label: caught ? ShotLabel.passCaught : ShotLabel.passMissed,
        t: contact?.t ?? tg,
        touched: contact != null,
        // Only a ball that actually arrives credits the man it arrived at:
        // the grade turns on which team mate took it in, and a pass that ran
        // past him was not taken in by anybody.
        receiver: caught ? receiver.player : null,
      );
    }

    // It ran into one of your own without having been meant for him: still a
    // ball you gave away, just not one you meant to give.
    if (contact != null) {
      return (
        label: ShotLabel.passMissed,
        t: contact.t,
        touched: true,
        receiver: null,
      );
    }

    final landing = worldAt(tg);
    final inPlay =
        landing.x.abs() <= PitchLines.halfWidth &&
        landing.y <= PitchLines.goalLineY &&
        landing.y >= scene.backY;
    return (
      label: inPlay ? ShotLabel.intoSpace : ShotLabel.wide,
      t: _flightSpan,
      touched: false,
      receiver: null,
    );
  }

  /// Clears the shot, not the session. [handleTap] calls this in the result
  /// phase to line up the next attempt, so zeroing [attempts] here would mean a
  /// scored session never ends — use [restartSession] for that.
  void reset() {
    // Line up whichever situation this attempt is played in *before* anything
    // reads the scene, and only re-point the camera when it actually moved —
    // the free prototype resets constantly and must keep the bearing it was
    // turned to.
    final previous = scene;
    _scenarioIndex = playlist.isEmpty
        ? 0
        : attempts.clamp(0, playlist.length - 1);
    if (!identical(previous, scene)) {
      facing = scene.facing;
      desiredAngle = scene.startAngle;
      cameraAngle = desiredAngle;
    }

    phase = ShotPhase.aim;
    aimLateral = scene.defaultAimLateral;
    aimDepth = scene.defaultAimDepth;
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
    _lastReceiver = null;
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

/// Sahanın bittiği yerin üstü. Ufuk kadraja girdiği andan beri orada bir şey
/// olmak zorunda: çimin tonuyla doldurmak yer düzlemini sonsuza uzatıyor ve
/// kuşbakışı hissini geri getiriyordu.
const _skyTop = Color(0xFF090D11);
const _skyHorizon = Color(0xFF17251D);
const _lineColor = Color(0x55FFFFFF);
const _rival = AppColors.dangerBright;

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
    // Ufkun altı yer, üstü değil. İkisinin arasındaki geçiş sert bir çizgi
    // olmasın diye gökyüzü tepede karadan ufukta çim tonuna iniyor.
    final horizon = p.horizonY;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, p.size.width, horizon),
      Paint()
        ..shader = Gradient.linear(
          Offset(p.size.width / 2, 0),
          Offset(p.size.width / 2, horizon),
          const [_skyTop, _skyHorizon],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, p.size.width, p.size.height - horizon),
      Paint()..color = _grassDark,
    );

    // Mowing bands, as world-space strips rather than screen-space stripes, so
    // they turn with the markings. Outside the touchlines the darker base
    // shows through, which is what makes the pitch read as a rectangle.
    final back = game.scene.backY;
    const front = PitchLines.goalLineY;
    const w = PitchLines.halfWidth;
    final bands = math.max(
      1,
      ((front - back) / PitchLines.mowBandDepth).round(),
    );
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
    final back = game.scene.backY;

    // Touchlines and the goal line.
    _seg(canvas, p, paint, (x: -w, y: back), (x: -w, y: front));
    _seg(canvas, p, paint, (x: w, y: back), (x: w, y: front));
    _seg(canvas, p, paint, (x: -w, y: front), (x: w, y: front));

    _box(
      canvas,
      p,
      paint,
      PitchLines.penaltyHalfWidth,
      PitchLines.penaltyDepth,
    );
    _box(
      canvas,
      p,
      paint,
      PitchLines.goalAreaHalfWidth,
      PitchLines.goalAreaDepth,
    );

    _paintPenaltySpot(canvas, p, PitchLines.penaltySpotY);
    _paintPenaltyArc(canvas, p, paint, PitchLines.penaltySpotY, -1);

    // The rest of the pitch, drawn only by the scenes that stand deep enough to
    // see it. A build-up scene starts behind the halfway line, so the default
    // back edge would leave the player looking out over nothing.
    if (back < PitchLines.halfwayY - 0.02) _paintHalfway(canvas, p, paint);
    if (back <= PitchLines.ownGoalLineY + 0.02) {
      _paintOwnHalf(canvas, p, paint);
    }

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
  ///
  /// [lineY] and [into] are what let the same three segments draw our own box
  /// at the other end of the pitch, where the box runs the other way.
  void _box(
    Canvas canvas,
    PitchProjector p,
    Paint paint,
    double halfWidth,
    double depth, {
    double lineY = PitchLines.goalLineY,
    int into = -1,
  }) {
    final y = lineY + depth * into;
    for (final side in [-1, 1]) {
      _seg(
        canvas,
        p,
        paint,
        (x: halfWidth * side, y: lineY),
        (x: halfWidth * side, y: y),
      );
    }
    _seg(canvas, p, paint, (x: -halfWidth, y: y), (x: halfWidth, y: y));
  }

  /// The halfway line and the centre circle. Only drawn from deep, where the
  /// scene has opened the ground out past them.
  void _paintHalfway(Canvas canvas, PitchProjector p, Paint paint) {
    const w = PitchLines.halfWidth;
    const y = PitchLines.halfwayY;
    _seg(canvas, p, paint, (x: -w, y: y), (x: w, y: y));
    _arc(
      canvas,
      p,
      paint,
      centre: (x: 0.0, y: y),
      radius: PitchLines.centreCircleRadius,
      from: 0,
      sweep: math.pi * 2,
      samples: 24,
    );
  }

  /// Our own end: the goal line we are playing away from, its two boxes, the
  /// spot and the arc. No frame — the far goal is never in shot from here, and
  /// nothing can be scored in it.
  void _paintOwnHalf(Canvas canvas, PitchProjector p, Paint paint) {
    const line = PitchLines.ownGoalLineY;
    const w = PitchLines.halfWidth;
    _seg(canvas, p, paint, (x: -w, y: line), (x: w, y: line));
    _box(
      canvas,
      p,
      paint,
      PitchLines.penaltyHalfWidth,
      PitchLines.penaltyDepth,
      lineY: line,
      into: 1,
    );
    _box(
      canvas,
      p,
      paint,
      PitchLines.goalAreaHalfWidth,
      PitchLines.goalAreaDepth,
      lineY: line,
      into: 1,
    );

    const spot = line + PitchLines.penaltySpotDepth;
    _paintPenaltySpot(canvas, p, spot);
    _paintPenaltyArc(canvas, p, paint, spot, 1);
  }

  void _paintPenaltySpot(Canvas canvas, PitchProjector p, double spotY) {
    final spot = (x: 0.0, y: spotY);
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
  /// the rest is inside the box and never drawn. [into] is which way the box
  /// runs, so our own arc bulges the other way.
  void _paintPenaltyArc(
    Canvas canvas,
    PitchProjector p,
    Paint paint,
    double spotY,
    int into,
  ) {
    const radius = PitchLines.penaltyArcRadius;
    const reach = PitchLines.penaltyDepth - PitchLines.penaltySpotDepth;
    if (radius <= reach) return;

    final half = math.acos(reach / radius);
    final centreAngle = into > 0 ? math.pi / 2 : -math.pi / 2;
    _arc(
      canvas,
      p,
      paint,
      centre: (x: 0.0, y: spotY),
      radius: radius,
      from: centreAngle - half,
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
      ..color = AppColors.warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawOval(
      Rect.fromCenter(center: spot, width: radius * 2, height: radius * 0.7),
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

  /// Run-cycle frames per second: eight frames make a stride in about 0.6 s,
  /// which matches how far a rival covers at [ShotWorld.rivalSpeed].
  static const _strideFps = 13.0;

  /// Which keeper frame to show: ready until he commits, then the dive toward
  /// whichever of *his own* sides the ball is on. The sheet has a left and a
  /// right dive rather than a mirror, so the facing decides the name — a keeper
  /// turned to the shooter has the world's `+x` on his left.
  int _keeperColumn(double keeperX, double facing) {
    final dived = keeperX.abs();
    if (game.flightT <= ShotWorld.keeperReaction ||
        dived < 0.01 ||
        game.keeperTarget == 0) {
      return PlayerSprites.keeperReady.start;
    }
    final progress = (dived / game.keeperTarget.abs()).clamp(0.0, 1.0);
    final frame = math.min(3, (progress * 4).floor());
    // For a bearing f the forward vector is (sin f, cos f), so the left-hand
    // one is (-cos f, sin f); the dive runs along world x, hence the dot
    // product reduces to -cos f times the side he moved to.
    final left = -math.cos(facing) * keeperX.sign;
    return (left >= 0
            ? PlayerSprites.keeperDiveLeft
            : PlayerSprites.keeperDiveRight)
        .column(frame);
  }

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

    for (final player in game.scene.bodies) {
      final spot = game.playerAt(player, game.flightT);
      final stance = game.stanceOf(player, game.flightT);
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
          kind: SpriteKind.outfield,
          kit: player.isRival ? game.rivalKit : game.teamKit,
          row: PlayerSprites.viewRow(stance.facing, game.cameraAngle),
          column: stance.running
              ? PlayerSprites.outfieldRun.column(
                  ((game.flightT - ShotWorld.rivalReaction) * _strideFps)
                      .floor(),
                )
              : PlayerSprites.outfieldIdle.start,
        ),
      );
    }

    // The keeper's absolute position follows the lateral offset his dive has
    // taken him to. An empty goal has none to draw.
    if (game.scene.hasKeeper) {
      final keeperX = game.keeperReachAt(game.flightT);
      final post = (x: keeperX, y: keeperDepth);
      final facing = game.facingFrom(post, game.scene.origin);
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
          color: AppColors.warning,
          alpha: 0.85,
          kind: SpriteKind.keeper,
          kit: game.keeperKit,
          row: PlayerSprites.viewRow(facing, game.cameraAngle),
          column: _keeperColumn(keeperX, facing),
        ),
      );
    }

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
        origin: game.scene.origin,
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
    required SpriteKind kind,
    required Kit kit,
    required int row,
    required int column,
  }) {
    final o = p.pointOpacity(depth);
    final s = p.scale(depth);
    final w = halfWidth * 2 * p.halfWidth * s;
    final h = height * p.zScale * s;

    canvas.drawOval(
      Rect.fromCenter(center: feet, width: w * 1.6, height: w * 0.5),
      Paint()..color = Colors.black.withValues(alpha: 0.35 * o),
    );

    final sprites = game.sprites;
    if (sprites != null) {
      sprites.paint(
        canvas,
        kind: kind,
        kit: kit,
        column: column,
        row: row,
        feet: feet,
        bodyHeight: h,
        opacity: o,
      );
      return;
    }

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
      Paint()..color = AppColors.accent.withValues(alpha: 0.35),
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
        ..color = sweet ? AppColors.success : AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = sweet ? 3 : 2,
    );
  }
}
