import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueChanged;

import 'package:project_srpg/game/game_banner.dart';
import 'package:project_srpg/game/stage_fit.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';

enum FlexPhase { ready, showing, recalling, feedback, done }

/// The grid's fixed geometry. `advance` and the input/`nodeAt` machinery only
/// ever see a 0..1 unit square — [gridRectFor] is the one place that becomes
/// pixels, shared by the input layer and the render component so they always
/// agree on where the dots are.
Rect gridRectFor(Vector2 size) {
  final side = math.min(size.x, size.y) * 0.74;
  return Rect.fromCenter(
    center: Offset(size.x / 2, size.y / 2),
    width: side,
    height: side,
  );
}

/// Node `index`'s position in the unit square (row-major, 0 top-left).
Offset nodeUnit(int index) {
  final col = index % FlexibilityGame.gridSide;
  final row = index ~/ FlexibilityGame.gridSide;
  final step = 1 / (FlexibilityGame.gridSide - 1);
  return Offset(col * step, row * step);
}

Offset unitToCanvas(Offset unit, Rect grid) =>
    Offset(grid.left + unit.dx * grid.width, grid.top + unit.dy * grid.height);

Offset canvasToUnit(Offset point, Rect grid) => Offset(
  (point.dx - grid.left) / grid.width,
  (point.dy - grid.top) / grid.height,
);

/// The flexibility drill: three dot-to-dot patterns are shown one at a time,
/// then the player redraws all three from memory in order. A wrong node ends
/// the attempt immediately — the session restarts from pattern one, same
/// three patterns, up to two more times before it counts as a failure.
///
/// Follows the training-game convention in `training_result.dart`: every rule
/// lives in [advance], [begin], [extend] and [end], none of which read `size`
/// — the coordinate space is the unit square, converted to pixels only by the
/// render component and the input layer via [gridRectFor].
class FlexibilityGame extends FlameGame {
  FlexibilityGame({
    required this.onStateChanged,
    required this.onFinished,
    int? seed,
  }) : patterns = _generatePatterns(math.Random(seed));

  final VoidCallback onStateChanged;
  final ValueChanged<TrainingResult> onFinished;

  static const gridSide = 3;
  static const patternCount = 3;

  /// The third wrong attempt ends the session as a failure.
  static const allowedMistakes = 3;

  /// Öğretici → karar: ilk desen kısa, üçüncüsü asıl sınav.
  static const patternLengths = [3, 4, 5];

  /// Unit-square radius a touch must land within to count as hitting a node.
  /// Adjacent nodes are 0.5 apart, so this leaves clear space between them.
  static const hitRadius = 0.17;

  static const drawPerSegment = 0.42;
  static const holdTime = 0.55;
  static const fadeTime = 0.30;
  static const gapTime = 0.35;
  static const feedbackTime = 0.55;

  /// Generated once per session (seeded only from tests) — unlike the bench
  /// press's fixed zones, a *memory* drill that repeats the same three
  /// patterns every day stops testing memory at all.
  final List<List<int>> patterns;

  FlexPhase phase = FlexPhase.ready;

  int demoIndex = 0;
  double demoT = 0;

  int recallIndex = 0;
  final List<int> stroke = <int>[];

  int mistakes = 0;
  bool lastAttemptOk = false;
  double feedbackT = 0;

  bool succeeded = false;

  TrainingResult get result => TrainingResult(
    drill: TrainingDrill.flexibility,
    outcome: succeeded ? TrainingOutcome.success : TrainingOutcome.failure,
    score: succeeded ? 1 - 0.25 * mistakes : 0,
    detail: '$recallIndex/$patternCount desen · $mistakes hata',
  );

  /// How much of the current demo pattern has been traced, in fractional
  /// segments (e.g. 1.4 = the first segment plus 40% of the second). Drives
  /// the render component; 0 outside [FlexPhase.showing].
  double get demoRevealSegments {
    if (phase != FlexPhase.showing) return 0;
    final segments = patterns[demoIndex].length - 1;
    if (segments <= 0) return 0;
    return (demoT / drawPerSegment).clamp(0.0, segments.toDouble());
  }

  /// 1 while drawing and holding, fading to 0 over [fadeTime], 0 during the
  /// gap before the next pattern (or before `recalling` starts).
  double get demoOpacity {
    if (phase != FlexPhase.showing) return 0;
    final segments = patterns[demoIndex].length - 1;
    final drawDuration = segments * drawPerSegment;
    final holdEnd = drawDuration + holdTime;
    final fadeEnd = holdEnd + fadeTime;
    if (demoT < holdEnd) return 1;
    if (demoT < fadeEnd) return 1 - (demoT - holdEnd) / fadeTime;
    return 0;
  }

  @override
  Color backgroundColor() => AppColors.surface1;

  @override
  Future<void> onLoad() async {
    addAll([MatSceneComponent(), PatternGridComponent(), PatternInputLayer()]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    advance(dt);
  }

  void advance(double dt) {
    switch (phase) {
      case FlexPhase.ready:
      case FlexPhase.recalling:
        break;
      case FlexPhase.showing:
        demoT += dt;
        if (demoT >= _demoDuration(demoIndex)) {
          demoT = 0;
          demoIndex++;
          if (demoIndex >= patternCount) {
            phase = FlexPhase.recalling;
            recallIndex = 0;
            stroke.clear();
            onStateChanged();
          }
        }
      case FlexPhase.feedback:
        feedbackT += dt;
        if (feedbackT >= feedbackTime) {
          feedbackT = 0;
          _afterFeedback();
        }
      case FlexPhase.done:
        break;
    }
  }

  double _demoDuration(int index) {
    final segments = patterns[index].length - 1;
    return segments * drawPerSegment + holdTime + fadeTime + gapTime;
  }

  /// A tap starts the session from [FlexPhase.ready]; the same call, made by
  /// a drag's start event, opens a new stroke while [FlexPhase.recalling].
  /// Harmless in every other phase or if both fire for one touch (a tap that
  /// becomes a drag calls this twice with the same first node).
  void begin(Offset unit) {
    if (phase == FlexPhase.ready) {
      phase = FlexPhase.showing;
      demoIndex = 0;
      demoT = 0;
      onStateChanged();
      return;
    }
    if (phase != FlexPhase.recalling) return;
    stroke.clear();
    _capture(unit);
  }

  void extend(Offset unit) {
    if (phase != FlexPhase.recalling) return;
    _capture(unit);
  }

  /// Lifting the finger before the pattern is complete is a miss — a real
  /// pattern lock counts a short stroke as wrong, not as "still trying".
  void end() {
    if (phase != FlexPhase.recalling) return;
    if (stroke.length < patterns[recallIndex].length) {
      _judge(false);
    }
  }

  /// Nearest node within [hitRadius] of `unit`, or null.
  int? nodeAt(Offset unit) {
    int? best;
    var bestDist = hitRadius;
    for (var i = 0; i < gridSide * gridSide; i++) {
      final d = (nodeUnit(i) - unit).distance;
      if (d <= bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  void _capture(Offset unit) {
    final node = nodeAt(unit);
    if (node == null || stroke.contains(node)) return;

    final expected = patterns[recallIndex];
    final wrong = node != expected[stroke.length];
    stroke.add(node);
    onStateChanged();

    if (wrong) {
      _judge(false);
    } else if (stroke.length == expected.length) {
      _judge(true);
    }
  }

  void _judge(bool ok) {
    lastAttemptOk = ok;
    if (!ok) mistakes++;
    phase = FlexPhase.feedback;
    feedbackT = 0;
    onStateChanged();
  }

  void _afterFeedback() {
    if (lastAttemptOk) {
      recallIndex++;
      if (recallIndex >= patternCount) {
        _finish(true);
        return;
      }
      stroke.clear();
      phase = FlexPhase.recalling;
      onStateChanged();
      return;
    }

    if (mistakes >= allowedMistakes) {
      _finish(false);
      return;
    }

    // Back to the start: same three patterns, shown again from scratch.
    demoIndex = 0;
    demoT = 0;
    recallIndex = 0;
    stroke.clear();
    phase = FlexPhase.showing;
    onStateChanged();
  }

  void _finish(bool ok) {
    succeeded = ok;
    phase = FlexPhase.done;
    if (isMounted) {
      add(GameBanner(ok ? 'BAŞARILI' : 'YETERSİZ', highlight: ok));
    }
    onFinished(result);
    onStateChanged();
  }

  // ---------------------------------------------------------------------
  // Pattern generation
  // ---------------------------------------------------------------------

  static List<List<int>> _generatePatterns(math.Random rng) {
    final result = <List<int>>[];
    for (final length in patternLengths) {
      List<int> candidate;
      do {
        candidate = _walk(rng, length);
      } while (result.any((p) => _sameOrder(p, candidate)));
      result.add(candidate);
    }
    return result;
  }

  static bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// A self-avoiding random walk on the grid that never jumps over an
  /// unvisited node — the Android-lock rule: a straight line between two
  /// nodes two apart always passes through the node between them, so that
  /// node must already be part of the stroke for the jump to be legal.
  /// Retries from scratch if a walk paints itself into a corner, which is
  /// rare on a 3×3 grid at these lengths.
  static List<int> _walk(math.Random rng, int length) {
    while (true) {
      final order = <int>[rng.nextInt(gridSide * gridSide)];
      var stuck = false;
      while (order.length < length) {
        final candidates = <int>[];
        for (var next = 0; next < gridSide * gridSide; next++) {
          if (order.contains(next)) continue;
          final mid = _forbiddenMidpoint(order.last, next);
          if (mid != null && !order.contains(mid)) continue;
          candidates.add(next);
        }
        if (candidates.isEmpty) {
          stuck = true;
          break;
        }
        order.add(candidates[rng.nextInt(candidates.length)]);
      }
      if (!stuck) return order;
    }
  }

  /// The node exactly between `a` and `b`, if they sit two grid steps apart
  /// on a row, column or diagonal — null if they are adjacent or unrelated.
  static int? _forbiddenMidpoint(int a, int b) {
    final ar = a ~/ gridSide, ac = a % gridSide;
    final br = b ~/ gridSide, bc = b % gridSide;
    final dr = br - ar, dc = bc - ac;
    if (dr == 0 && dc == 0) return null;
    if (dr % 2 != 0 || dc % 2 != 0) return null;
    return (ar + dr ~/ 2) * gridSide + (ac + dc ~/ 2);
  }
}

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

const _skin = Color(0xFFC08A63);

/// The backdrop: a mat and a slow, looping forward-stretch figure. Purely
/// decorative — nothing here is read by [FlexibilityGame.advance] — but
/// without it the screen is a bare lock pad with no read on "esneklik".
class MatSceneComponent extends Component
    with HasGameReference<FlexibilityGame> {
  @override
  int get priority => 0;

  double _t = 0;

  /// Blender'da render edilen esneme odası (`flexibility/bg_stretch_room`) ve
  /// öne eğilme döngüsünün 24 karesi. Hepsi yüklenemezse aşağıdaki çubuk
  /// figürlü eski çizim çalışmaya devam eder.
  Sprite? _bg;
  List<Sprite>? _frames;

  static const _canvas = Size(1600, 900);
  static const _frameCount = 24;

  /// Kare 320×256; içindeki kalça pivotu bu piksele, o da kanvasta aşağıdaki
  /// noktaya oturur (`layout.json`). Kareler sahneden 1.396 kat düşük
  /// yoğunlukla çekildi, o yüzden büyütülerek çizilir.
  static const _frameSize = Size(320, 256);
  static const _frameHip = Offset(130, 162.1);
  static const _figureHip = Offset(720, 680.9);
  static const _frameScale = (1600 / 9.4) / (256 / 2.1);

  /// Görseller yüklenene (ya da yüklenemeyeceği anlaşılana) kadar düz zemin
  /// çizilir; eski çubuk figür yalnızca yükleme başarısız olursa çıkar, yoksa
  /// her açılışta kısa bir süre yanıp söner.
  bool _settled = false;

  /// Yükleme `onLoad`'u bekletmez: bu bileşen giriş katmanıyla aynı ağaçta ve
  /// 25 görselin çözülmesi, dokunuşları alan `PatternInputLayer`'ın
  /// bağlanmasını geciktirmemeli (widget testleri de sahte zamanda görsel
  /// çözülmesini hiç bitiremez).
  @override
  Future<void> onLoad() async {
    _loadStage();
  }

  Future<void> _loadStage() async {
    try {
      _bg = await Sprite.load('flexibility/bg_stretch_room.png');
      _frames = [
        for (var i = 1; i <= _frameCount; i++)
          await Sprite.load(
            'flexibility/stretch_${i.toString().padLeft(2, '0')}.png',
          ),
      ];
    } catch (_) {
      _bg = null;
      _frames = null;
    }
    _settled = true;
  }

  @override
  void update(double dt) {
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;

    final bg = _bg;
    final frames = _frames;
    if (bg != null && frames != null) {
      _paintStage(canvas, bg, frames);
      return;
    }
    if (!_settled) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, u, v),
        Paint()..color = AppColors.surface1,
      );
      return;
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, u, v),
      Paint()..color = AppColors.surface1,
    );

    final mat = Rect.fromCenter(
      center: Offset(u * 0.16, v * 0.90),
      width: u * 0.30,
      height: v * 0.05,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mat, Radius.circular(v * 0.015)),
      Paint()..color = AppColors.surface2,
    );

    _paintFigure(canvas, u, v);
  }

  /// Oda ve eğilen figür. Figürün eğimi eski çubuk figürle aynı eğriyi
  /// izler, `0.5 + 0.5·sin(0.9t)`: kare 1 dik durur, kare 13 tam eğilir ve
  /// `sin`'in başlangıcı (yarı eğik) `π/2` faz kaydırmasıyla tutulur. Kare
  /// başına ~8° kaldığı için komşu kareler birbirine karıştırılır; yoksa
  /// yavaş bir esneme 24 kareli bir slayta dönerdi.
  void _paintStage(Canvas canvas, Sprite bg, List<Sprite> frames) {
    final size = game.size;
    final s = coverScale(size, _canvas);
    final origin = coverOrigin(size, _canvas);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(s);

    bg.render(canvas, size: Vector2(_canvas.width, _canvas.height));

    final turns = (0.9 * _t + math.pi / 2) / (2 * math.pi);
    final pos = (turns - turns.floorToDouble()) * _frameCount;
    final i = pos.floor() % _frameCount;
    final blend = pos - pos.floorToDouble();

    final w = _frameSize.width * _frameScale;
    final h = _frameSize.height * _frameScale;
    final anchor = Anchor(
      _frameHip.dx / _frameSize.width,
      _frameHip.dy / _frameSize.height,
    );
    final at = Vector2(_figureHip.dx, _figureHip.dy);
    frames[i].render(canvas, position: at, size: Vector2(w, h), anchor: anchor);
    frames[(i + 1) % _frameCount].render(
      canvas,
      position: at,
      size: Vector2(w, h),
      anchor: anchor,
      overridePaint: Paint()..color = Color.fromRGBO(255, 255, 255, blend),
    );

    canvas.restore();
  }

  void _paintFigure(Canvas canvas, double u, double v) {
    // A slow bend-and-ease toward the toes, so the corner reads "stretching"
    // rather than just idling.
    final bend = 0.5 + 0.5 * math.sin(_t * 0.9);
    final leanAngle = lerpDouble(0.15, 1.15, bend)!;

    final hip = Offset(u * 0.16, v * 0.84);
    final torsoLen = v * 0.20;
    final shoulder =
        hip +
        Offset(math.sin(leanAngle) * torsoLen, -math.cos(leanAngle) * torsoLen);

    final limb = Paint()
      ..color = _skin
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.016
      ..strokeCap = StrokeCap.round;
    final torso = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.020
      ..strokeCap = StrokeCap.round;

    // Straight legs — a real stretch keeps the knee locked.
    canvas.drawLine(hip, hip + Offset(-u * 0.022, v * 0.14), limb);
    canvas.drawLine(hip, hip + Offset(u * 0.055, v * 0.14), limb);

    canvas.drawLine(hip, shoulder, torso);

    // Arms reach past the shoulder toward the floor as the lean deepens.
    final reach =
        shoulder + Offset(math.sin(leanAngle) * v * 0.13, v * 0.11 * bend);
    canvas.drawLine(shoulder, reach, limb);

    canvas.drawCircle(
      shoulder + Offset(math.sin(leanAngle) * v * 0.045, -v * 0.045),
      v * 0.030,
      Paint()..color = _skin,
    );
  }
}

/// The 3×3 pad: dots, the demo trace and the player's own stroke.
class PatternGridComponent extends Component
    with HasGameReference<FlexibilityGame> {
  @override
  int get priority => 6;

  @override
  void render(Canvas canvas) {
    final grid = gridRectFor(game.size);
    _paintNodes(canvas, grid);
    if (game.phase == FlexPhase.showing) _paintDemo(canvas, grid);
    if (game.phase == FlexPhase.recalling || game.phase == FlexPhase.feedback) {
      _paintStroke(canvas, grid);
    }
  }

  void _paintNodes(Canvas canvas, Rect grid) {
    final r = grid.width * 0.05;
    for (
      var i = 0;
      i < FlexibilityGame.gridSide * FlexibilityGame.gridSide;
      i++
    ) {
      final p = unitToCanvas(nodeUnit(i), grid);
      final visited =
          game.phase == FlexPhase.recalling && game.stroke.contains(i);
      canvas.drawCircle(p, r, Paint()..color = AppColors.surface1);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = visited ? AppColors.accent : AppColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = visited ? 3 : 1.5,
      );
      if (visited) {
        canvas.drawCircle(
          p,
          grid.width * 0.02,
          Paint()..color = AppColors.accent,
        );
      }
    }
  }

  void _paintDemo(Canvas canvas, Rect grid) {
    final pattern = game.patterns[game.demoIndex];
    final opacity = game.demoOpacity;
    if (opacity <= 0) return;
    final reveal = game.demoRevealSegments;

    final linePaint = Paint()
      ..color = AppColors.warning.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = grid.width * 0.026
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < pattern.length - 1; i++) {
      final segProgress = (reveal - i).clamp(0.0, 1.0);
      if (segProgress <= 0) break;
      final a = unitToCanvas(nodeUnit(pattern[i]), grid);
      final b = unitToCanvas(nodeUnit(pattern[i + 1]), grid);
      canvas.drawLine(a, Offset.lerp(a, b, segProgress)!, linePaint);
    }

    // Dots on the visited nodes so the *order* reads, not just the shape.
    final dotPaint = Paint()
      ..color = AppColors.warning.withValues(alpha: opacity);
    final shown = reveal.floor().clamp(0, pattern.length - 1);
    for (var i = 0; i <= shown; i++) {
      canvas.drawCircle(
        unitToCanvas(nodeUnit(pattern[i]), grid),
        grid.width * 0.026,
        dotPaint,
      );
    }
  }

  void _paintStroke(Canvas canvas, Rect grid) {
    final stroke = game.stroke;
    if (stroke.isEmpty) return;

    final color = game.phase == FlexPhase.feedback
        ? (game.lastAttemptOk ? AppColors.success : AppColors.dangerBright)
        : AppColors.accent;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grid.width * 0.026
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final first = unitToCanvas(nodeUnit(stroke.first), grid);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < stroke.length; i++) {
      final p = unitToCanvas(nodeUnit(stroke[i]), grid);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }
}

/// Full-bleed drag+tap surface. `onGameResize` is required — a component only
/// receives gestures inside its own size, so without this taps are silently
/// dropped (same reasoning as `ShotGame`'s and `BenchPressGame`'s input
/// layers).
class PatternInputLayer extends PositionComponent
    with HasGameReference<FlexibilityGame>, TapCallbacks, DragCallbacks {
  @override
  int get priority => 20;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  Offset _unitOf(Offset canvasPos) =>
      canvasToUnit(canvasPos, gridRectFor(game.size));

  @override
  void onTapDown(TapDownEvent event) {
    game.begin(_unitOf(event.canvasPosition.toOffset()));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.begin(_unitOf(event.canvasPosition.toOffset()));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game.extend(_unitOf(event.canvasEndPosition.toOffset()));
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.end();
  }
}
