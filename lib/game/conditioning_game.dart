import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueChanged, ValueNotifier;

import 'package:project_srpg/game/game_banner.dart';
import 'package:project_srpg/game/stage_fit.dart';
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

  /// The Blender-rendered gym layers loaded. Both components read it to
  /// decide between the image stage and the old procedural one — the runner
  /// must never sit on the image stage's coordinates over a procedural
  /// treadmill, or the other way round.
  bool stageReady = false;

  /// Watched by the time bar, which changes every frame. A notifier keeps that
  /// out of `setState`, so the host rebuilds only when something structural
  /// changes.
  final ValueNotifier<double> timeLeft = ValueNotifier<double>(1);

  final ValueNotifier<int> stepCount = ValueNotifier<int>(0);

  int get steps => stepCount.value;

  bool get succeeded => steps >= targetSteps;

  TrainingResult get result => TrainingResult(
    drill: TrainingDrill.conditioning,
    outcome: succeeded ? TrainingOutcome.success : TrainingOutcome.failure,
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
      add(
        GameBanner(succeeded ? 'BAŞARILI' : 'YETERSİZ', highlight: succeeded),
      );
    }
    onFinished(result);
    onStateChanged();
  }
}

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

/// Blender'da render edilen spor salonu sahnesinin ölçüleri. Bütün katmanlar
/// (`conditioning/gym_bg`, `treadmill_deck`, `treadmill_console`) aynı
/// 1600×900 kanvasta hizalı; sayılar `assets/images/conditioning/layout.json`
/// dosyasından, yani Blender kamerasından ölçüldü — elle ayarlanmadı.
///
/// Kanvas ekrana "cover" olarak oturur (ortadan kırpar): bant, koşucu ve
/// konsol kanvasın ortasındaki ~%75'lik şeritte, dar ekranda bile kalır.
class _Stage {
  static const canvas = Size(1600, 900);

  /// Koşucunun kalçası (Blender'da y=0, derinlik 4) ve karenin ölçeği:
  /// koşucu karesi 121.9 px/birim, sahne 170.2 px/birim çekildi.
  static const hip = Offset(704.7, 569.1);
  static const _runnerUnitRatio = (1600 / 9.4) / (256 / 2.1);

  /// Bandın görünen şeridi ve döşemenin bir tekrarı (8 çıta = 544 px).
  static const beltRect = Rect.fromLTRB(272.3, 656.0, 1327.7, 671.3);
  static const beltTileWidth = 544.0;
  static const beltPeriod = beltTileWidth / 8;

  /// Konsolun 3 gösterge yuvasının merkezleri, boyutu ve eğimi (oyunun
  /// eski konsolundaki -0.12 rad ile aynı).
  static const slotCenters = [
    Offset(1255.6, 433.7),
    Offset(1259.8, 468.6),
    Offset(1264.0, 503.6),
  ];
  static const slotSize = Size(140, 16);
  static const consoleTilt = -0.12;

  static double scale(Vector2 size) => coverScale(size, canvas);

  static Offset origin(Vector2 size) => coverOrigin(size, canvas);

  static Offset point(Offset p, Vector2 size) => coverPoint(p, size, canvas);

  /// Koşucu karesinin ekrandaki kenarı (kare 256 px, ama 1.396 kat daha
  /// düşük yoğunlukla çekildi).
  static double runnerFrameSize(Vector2 size) =>
      256 * _runnerUnitRatio * scale(size);
}

/// The machine: backdrop, deck, console, and the scrolling belt that is the
/// drill's main motion cue. Stop tapping and the tread lines freeze.
class TreadmillComponent extends Component
    with HasGameReference<ConditioningGame> {
  @override
  int get priority => 0;

  Sprite? _bg;
  Sprite? _deck;
  Sprite? _console;
  Sprite? _belt;

  @override
  Future<void> onLoad() async {
    try {
      _bg = await Sprite.load('conditioning/gym_bg.png');
      _deck = await Sprite.load('conditioning/treadmill_deck.png');
      _console = await Sprite.load('conditioning/treadmill_console.png');
      _belt = await Sprite.load('conditioning/belt_tile.png');
      game.stageReady = true;
    } catch (_) {
      game.stageReady = false;
    }
  }

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;

    if (game.stageReady) {
      _paintStage(canvas);
      return;
    }

    _paintBackdrop(canvas, u, v);
    _paintDeck(canvas, u, v);
    _paintConsole(canvas, u, v);
  }

  /// The Blender gym: background, deck, scrolling belt, console — one shared
  /// 1600×900 canvas, drawn cover-fit so every layer keeps its alignment.
  void _paintStage(Canvas canvas) {
    final size = game.size;
    final s = _Stage.scale(size);
    final origin = _Stage.origin(size);

    canvas.save();
    // Whatever the cover-fit crops off must not bleed over the screen chrome.
    canvas.clipRect(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(s);

    const full = _Stage.canvas;
    for (final layer in [_bg, _deck]) {
      layer?.render(canvas, size: Vector2(full.width, full.height));
    }

    // The belt runs backwards under a runner facing right, so the tile
    // slides left. The pattern repeats every tile-width/8, and [beltPhase]
    // wraps at 1 over four of those, so the seam never shows.
    final belt = _belt;
    if (belt != null) {
      final rect = _Stage.beltRect;
      final shift = game.beltPhase * _Stage.beltPeriod * 4;
      canvas.save();
      canvas.clipRect(rect);
      for (
        var x = rect.left - shift;
        x < rect.right;
        x += _Stage.beltTileWidth
      ) {
        belt.render(
          canvas,
          position: Vector2(x, rect.top),
          size: Vector2(_Stage.beltTileWidth, rect.height),
        );
      }
      canvas.restore();
    }

    _console?.render(canvas, size: Vector2(full.width, full.height));

    // Readout bars light up with the run, exactly as the procedural console
    // does; the slots are baked into the console layer, only the glow is here.
    final lit = math.min(3, game.steps * 3 ~/ ConditioningGame.targetSteps);
    for (var i = 0; i < 3; i++) {
      final c = _Stage.slotCenters[i];
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(_Stage.consoleTilt);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: _Stage.slotSize.width,
            height: _Stage.slotSize.height,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = i < lit
              ? AppColors.accent
              : AppColors.border.withValues(alpha: 0.6),
      );
      canvas.restore();
    }
    canvas.restore();
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
    final lit = math.min(3, game.steps * 3 ~/ ConditioningGame.targetSteps);
    for (var i = 0; i < 3; i++) {
      final bar = Rect.fromLTWH(
        console.left + console.width * 0.18,
        console.top + console.height * (0.24 + i * 0.22),
        console.width * 0.64,
        console.height * 0.10,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()
          ..color = i < lit
              ? AppColors.accent
              : AppColors.border.withValues(alpha: 0.6),
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

/// The runner. Prefers a real cutout rig cut from the pixel-art running pose
/// (torso+head as a static core, plus a thigh/shin/upper-arm/forearm each
/// reused for both limb instances) and falls back to the stick-and-slab
/// figure the shot game's players already use when the assets are missing.
///
/// The rig parts were cut from the single `run_side_1.png` pose with a
/// one-off slicing script (see the plan history — not part of the build):
/// every opaque pixel was assigned to whichever bone segment (hip→knee,
/// knee→foot, shoulder→elbow, elbow→fist) it sits closest to, each limb
/// crop was then de-rotated so its bone points straight down, and the joint
/// pixel was recorded as that crop's pivot. That is why every angle below
/// can reuse the fallback rig's own `sin`/`cos` gait formulas verbatim: both
/// rigs share the same "0 = hanging straight down" convention.
class RunnerComponent extends Component
    with HasGameReference<ConditioningGame> {
  @override
  int get priority => 5;

  /// Height of the source pose (`run_side_1.png`) in pixels — the reference
  /// the old two-still sprite was scaled against (`destHeight = v * 0.34`);
  /// every rig part and joint offset below is scaled against it the same way
  /// so the rig comes out the same on-screen size the sprite did.
  static const _srcHeight = 459.0;

  /// Hip → shoulder offset measured on the source pose, used as-is rather
  /// than the fallback rig's simplified `Offset(0, -v * 0.14)` so the arms
  /// hang from where the jacket collar actually is.
  static const _hipToShoulder = Offset(17, -145);

  static const _thighBoneLength = 77.9;
  static const _shinBoneLength = 101.6;
  static const _upperArmBoneLength = 60.2;
  static const _forearmBoneLength = 73.0;

  static const _thighPivot = Offset(45, 2);
  static const _shinPivot = Offset(23, 2);
  static const _upperArmPivot = Offset(52, 3);
  static const _forearmPivot = Offset(59, 3);
  static const _torsoPivot = Offset(46, 293);

  Sprite? _torsoHead;
  Sprite? _thigh;
  Sprite? _shin;
  Sprite? _upperArm;
  Sprite? _forearm;

  /// Kare kare koşu döngüsü: Blender'daki low-poly futbolcunun 8 karelik
  /// koşusu (`sprites/footballer_run/run_01..08.png`, 256×256, şeffaf).
  /// Varsa parça parça rig'in ve çubuk figürün önüne geçer; yoksa onlar
  /// çalışmaya devam eder.
  List<Sprite>? _frames;

  static const _frameCount = 8;
  static const _framePx = 256.0;

  /// Karenin içinde kalçanın durduğu piksel (Blender kamerasından ölçüldü) —
  /// oyunun `hip` noktasına bu piksel oturur, böylece kareler arası zıplama
  /// olmaz ve ayaklar aynı zemin çizgisine basar.
  static const _frameHip = Offset(138.5, 175.8);

  /// Kare boyunun ekran yüksekliğine oranı: karakter karenin ~%90'ını
  /// kaplıyor, eski rig'in `v * 0.34`'lük boyuna denk gelsin diye.
  static const _frameHeightFrac = 0.378;

  /// Her karede iki ayakkabının merkezi (kare pikseli). "Sağ" ayak, oyunun
  /// `phi` fazıyla ilerleyen, öndeki bacak; Blender'daki `Boot_L`.
  static const _rightFootPx = [
    Offset(100.4, 208.5),
    Offset(131.1, 227.5),
    Offset(173.0, 219.9),
    Offset(161.0, 230.3),
    Offset(128.9, 238.0),
    Offset(99.4, 220.8),
    Offset(89.7, 207.1),
    Offset(86.5, 193.6),
  ];
  static const _leftFootPx = [
    Offset(128.9, 238.0),
    Offset(99.4, 220.8),
    Offset(89.7, 207.1),
    Offset(86.5, 193.6),
    Offset(100.4, 208.5),
    Offset(131.1, 227.5),
    Offset(173.0, 219.9),
    Offset(161.0, 230.3),
  ];

  @override
  Future<void> onLoad() async {
    try {
      _frames = [
        for (var i = 1; i <= _frameCount; i++)
          await Sprite.load(
            'sprites/footballer_run/run_${i.toString().padLeft(2, '0')}.png',
          ),
      ];
    } catch (_) {
      _frames = null;
    }
    try {
      _torsoHead = await Sprite.load('sprites/run_torso_head.png');
      _thigh = await Sprite.load('sprites/run_thigh.png');
      _shin = await Sprite.load('sprites/run_shin.png');
      _upperArm = await Sprite.load('sprites/run_upper_arm.png');
      _forearm = await Sprite.load('sprites/run_forearm.png');
    } catch (_) {
      _torsoHead = null;
      _thigh = null;
      _shin = null;
      _upperArm = null;
      _forearm = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;

    final phi = game.stridePhase;
    final cadence = game.cadence;
    final stumbling = game.stumbleLeft > 0;

    // Blender sahnesi hazırsa koşucu onun kanvasına oturur: kalça, sahnenin
    // ölçtüğü noktada, kare boyu da sahnenin birim/piksel oranında. Değilse
    // eski oransal yerleşim (u*0.44, v*0.60) aynen geçerli.
    final onStage = game.stageReady && _frames != null;
    final hip = onStage
        ? _Stage.point(_Stage.hip, game.size)
        : Offset(u * 0.44, v * 0.60);
    // Kareler zıplamayı zaten içinde taşıyor; üstüne ikinci bir zıplama
    // eklemek sahnede ayakları bandın içine gömerdi.
    final bob = onStage ? 0.0 : math.sin(phi * 2) * v * 0.012 * cadence;

    canvas.save();
    canvas.translate(0, bob);
    if (stumbling) {
      canvas.translate(hip.dx, hip.dy);
      canvas.rotate(0.18);
      canvas.translate(-hip.dx, -hip.dy);
    }

    final torsoHead = _torsoHead;
    final thighSprite = _thigh;
    final shinSprite = _shin;
    final upperArmSprite = _upperArm;
    final forearmSprite = _forearm;
    final frames = _frames;
    if (frames != null) {
      _paintFrame(
        canvas,
        hip,
        phi,
        onStage ? _Stage.runnerFrameSize(game.size) : v * _frameHeightFrac,
        frames,
      );
    } else if (torsoHead != null &&
        thighSprite != null &&
        shinSprite != null &&
        upperArmSprite != null &&
        forearmSprite != null) {
      _paintRig(
        canvas,
        hip,
        phi,
        u,
        v,
        torsoHead,
        thighSprite,
        shinSprite,
        upperArmSprite,
        forearmSprite,
      );
    } else {
      final thigh = v * 0.085;
      final shin = v * 0.085;

      // Back leg first, then the torso, then the front leg and arms, so the
      // figure reads with depth without any z-sorting machinery.
      _paintLeg(
        canvas,
        hip,
        phi + math.pi,
        thigh,
        shin,
        u,
        v,
        side: RunSide.left,
        back: true,
      );
      _paintTorso(canvas, hip, u, v);
      _paintLeg(
        canvas,
        hip,
        phi,
        thigh,
        shin,
        u,
        v,
        side: RunSide.right,
        back: false,
      );
      _paintArms(canvas, hip, phi, v);
      _paintHead(canvas, hip, v);
    }

    if (stumbling) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(
            hip.dx,
            onStage
                ? _Stage.point(Offset(0, _Stage.beltRect.bottom), game.size).dy
                : v * 0.70,
          ),
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

  /// Adımın fazına ([phi], 0…2π) denk gelen kareyi çizer. Kareler Blender'da
  /// `phi` ile aynı yönde ilerleyen bir fazla üretildi (kare 1: öndeki bacak
  /// dikey, ileri savruluyor), yani kare seçmek `phi`'yi 8'e bölmekten ibaret.
  /// Basan ayağın yanan ayakkabı ipucu diğer iki rig'deki gibi çalışır, sadece
  /// gerçek botların üstüne biner ve yalnızca yanarken çizilir.
  void _paintFrame(
    Canvas canvas,
    Offset hip,
    double phi,
    double size,
    List<Sprite> frames,
  ) {
    final turns = phi / (2 * math.pi);
    final index =
        ((turns - turns.floorToDouble()) * _frameCount).floor() % _frameCount;
    final k = size / _framePx;

    frames[index].render(
      canvas,
      position: Vector2(hip.dx, hip.dy),
      size: Vector2(size, size),
      anchor: Anchor(_frameHip.dx / _framePx, _frameHip.dy / _framePx),
    );

    for (final side in RunSide.values) {
      final flashing =
          (side == RunSide.left ? game.leftFlash : game.rightFlash) > 0;
      if (!flashing) continue;
      final px = (side == RunSide.left ? _leftFootPx : _rightFootPx)[index];
      final foot =
          hip + Offset((px.dx - _frameHip.dx) * k, (px.dy - _frameHip.dy) * k);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: foot,
            width: size * 0.15,
            height: size * 0.05,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = AppColors.success.withValues(alpha: 0.85),
      );
    }
  }

  /// The cutout rig. Back leg and back arm first, then the static torso+head
  /// core, then the front leg and arm on top — the same depth order the
  /// fallback rig's own draw calls use, just with the torso and head merged
  /// into one static image instead of two separate shapes.
  void _paintRig(
    Canvas canvas,
    Offset hip,
    double phi,
    double u,
    double v,
    Sprite torsoHead,
    Sprite thighSprite,
    Sprite shinSprite,
    Sprite upperArmSprite,
    Sprite forearmSprite,
  ) {
    final scale = (v * 0.34) / _srcHeight;
    final thighLen = _thighBoneLength * scale;
    final shinLen = _shinBoneLength * scale;
    final upperLen = _upperArmBoneLength * scale;
    final foreLen = _forearmBoneLength * scale;
    final shoulder =
        hip + Offset(_hipToShoulder.dx * scale, _hipToShoulder.dy * scale);

    _paintLegRig(
      canvas,
      hip,
      phi + math.pi,
      thighLen,
      shinLen,
      scale,
      thighSprite,
      shinSprite,
      u,
      v,
      side: RunSide.left,
    );
    _paintArmRig(
      canvas,
      shoulder,
      phi + math.pi,
      upperLen,
      foreLen,
      scale,
      upperArmSprite,
      forearmSprite,
    );

    final torsoW = torsoHead.srcSize.x;
    final torsoH = torsoHead.srcSize.y;
    torsoHead.render(
      canvas,
      position: Vector2(hip.dx, hip.dy),
      size: Vector2(torsoW * scale, torsoH * scale),
      anchor: Anchor(_torsoPivot.dx / torsoW, _torsoPivot.dy / torsoH),
    );

    _paintLegRig(
      canvas,
      hip,
      phi,
      thighLen,
      shinLen,
      scale,
      thighSprite,
      shinSprite,
      u,
      v,
      side: RunSide.right,
    );
    _paintArmRig(
      canvas,
      shoulder,
      phi,
      upperLen,
      foreLen,
      scale,
      upperArmSprite,
      forearmSprite,
    );
  }

  /// Thigh and shin, each rotated around its own joint from the same
  /// hip/knee-bend formulas [_paintLeg] uses, plus the unchanged foot-flash
  /// cue on top.
  void _paintLegRig(
    Canvas canvas,
    Offset hip,
    double phi,
    double thighLen,
    double shinLen,
    double scale,
    Sprite thighSprite,
    Sprite shinSprite,
    double u,
    double v, {
    required RunSide side,
  }) {
    final thighAngle = 0.55 * math.sin(phi);
    final kneeBend = 0.60 + 0.60 * math.max(0, -math.sin(phi));
    final shinAngle = thighAngle - kneeBend;

    final knee =
        hip +
        Offset(
          math.sin(thighAngle) * thighLen,
          math.cos(thighAngle) * thighLen,
        );
    final foot =
        knee +
        Offset(math.sin(shinAngle) * shinLen, math.cos(shinAngle) * shinLen);

    _paintPart(canvas, thighSprite, hip, thighAngle, _thighPivot, scale);
    _paintPart(canvas, shinSprite, knee, shinAngle, _shinPivot, scale);

    // The shoe of whichever foot just planted lights up — same cue the
    // fallback rig draws, kept identical so the feedback loop doesn't change
    // depending on which renderer is active.
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

  /// Upper arm and forearm, counter-swinging the legs via the same
  /// elbow/hand formulas [_paintArms] uses.
  ///
  /// The swing sits just behind vertical and still reaches ~29° in front of
  /// it. The old `-1.2 + 0.9 * sin(swing)` never came further forward than
  /// -17°, which read fine as an abstract stick figure but left the drawn arm
  /// pinned behind the runner's back for the whole cycle. At the top of the
  /// drive these values land the fist within a few pixels of where it was
  /// drawn in the source pose.
  void _paintArmRig(
    Canvas canvas,
    Offset shoulder,
    double swing,
    double upperLen,
    double foreLen,
    double scale,
    Sprite upperArmSprite,
    Sprite forearmSprite,
  ) {
    final elbowAngle = -0.22 + 0.72 * math.sin(swing);
    // The elbow stays folded across the forward drive and opens out on the
    // backswing, the way the knee does on its own recovery swing. Both ends
    // of that range are taken from the source pose: at the extremes these
    // put the fists within a few pixels of the two the artist drew.
    final handAngle = elbowAngle + 1.30 - 0.95 * math.max(0, -math.sin(swing));
    final elbow =
        shoulder +
        Offset(
          math.sin(elbowAngle) * upperLen,
          math.cos(elbowAngle) * upperLen,
        );

    _paintPart(
      canvas,
      upperArmSprite,
      shoulder,
      elbowAngle,
      _upperArmPivot,
      scale,
    );
    _paintPart(canvas, forearmSprite, elbow, handAngle, _forearmPivot, scale);
  }

  /// Renders [sprite] rotated by [angle] around [worldPivot], with the
  /// sprite's own [localPivot] pixel (recorded when the rig was cut — see
  /// the class doc comment) placed exactly on that point. `-angle`: the
  /// slicing script measured its de-rotation angle the same way the gait
  /// formulas above measure `thighAngle` (0 = straight down, growing toward
  /// +x), but `Canvas.rotate` turns positive values the opposite way round
  /// screen, so the sign has to flip here to land the limb back where the
  /// gait math intends it.
  void _paintPart(
    Canvas canvas,
    Sprite sprite,
    Offset worldPivot,
    double angle,
    Offset localPivot,
    double scale,
  ) {
    final w = sprite.srcSize.x;
    final h = sprite.srcSize.y;
    canvas.save();
    canvas.translate(worldPivot.dx, worldPivot.dy);
    canvas.rotate(-angle);
    sprite.render(
      canvas,
      position: Vector2.zero(),
      size: Vector2(w * scale, h * scale),
      anchor: Anchor(localPivot.dx / w, localPivot.dy / h),
    );
    canvas.restore();
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

    final knee =
        hip +
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
      final elbowAngle = -0.22 + 0.72 * math.sin(swing);
      final elbow =
          shoulder +
          Offset(math.sin(elbowAngle) * upper, math.cos(elbowAngle) * upper);
      final handAngle =
          elbowAngle + 1.30 - 0.95 * math.max(0, -math.sin(swing));
      final hand =
          elbow +
          Offset(math.sin(handAngle) * fore, math.cos(handAngle) * fore);

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
