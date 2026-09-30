import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueChanged, ValueNotifier;

import 'package:project_srpg/game/conditioning_game.dart' show RunSide;
import 'package:project_srpg/game/game_banner.dart';
import 'package:project_srpg/game/run_frames.dart';
import 'package:project_srpg/game/shot_objective.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Müdahalenin hangi aşamada olduğu: `closing` → `window` → `done`. Derece
/// verilir verilmez oturum biter — tek rakip, tek deneme.
enum TacklePhase { ready, closing, window, done }

const _skin = Color(0xFFC08A63);

/// Baskı zinciri: SOL/SAĞ dönüşümlü basarak rakibe koş, mesafe kapanınca açılan
/// pencerede MÜDAHALE'ye bas. Tek rakip, tek deneme.
///
/// İki beceri kasıtlı olarak ayrı ölçülüyor:
///
/// - **cadence** yaklaşma hızını belirler (hızlı bas → çabuk yetiş),
/// - **rhythm** pencere genişliğini belirler (düzenli bas → rahat müdahale).
///
/// Sayılar birbirini tutacak şekilde seçildi: [targetGap]'te saniyede 3.85 adım
/// düşer, bu da [cadenceGain] ile 0.85/sn kazanç demektir ve [cadenceDecay]'in
/// üstünde kalır — yani hedef tempo cadence'i zaten tavanda tutar. Daha hızlı
/// basmak cadence'e bir şey ekleyemez (1'de kapalı) ama ritmi yıkar. Böylece
/// hedef tempo kesin olarak en iyi strateji olur ve oyun bir "mash" oyununa
/// dönmez.
///
/// `training_result.dart`'taki konvansiyonu izler: bütün kurallar `size`
/// okumayan [advance] içinde, dolayısıyla bütün puan tablosu widget'sız bir
/// testten sürülebilir.
class TackleGame extends FlameGame {
  TackleGame({
    required this.onStateChanged,
    required this.onFinished,
    this.closeScale = 1,
    this.windowScale = 1,
  });

  final VoidCallback onStateChanged;
  final ValueChanged<TrainingResult> onFinished;

  /// Durumun kovalamaya ve dalış aralığına getirdiği çarpanlar. Katalog tipini
  /// bilmiyoruz bilerek — `tackle_scenarios.dart` kurallara sızmasın diye
  /// çarpanları host ekran geçiriyor (`shot_game.dart`'ın sahneyi alıp senaryoyu
  /// almaması ile aynı ayrım).
  final double closeScale;
  final double windowScale;

  static const runDuration = 12.0;

  /// Süre çubuğunun kızardığı kalan oran.
  static const warnFraction = 0.25;

  /// Tam cadence'te saniyede kapanan mesafe oranı. 1/[closeRate] ≈ bir rakibe
  /// yetişme süresi.
  static const closeRate = 0.42;

  /// Pencerenin sıfır ve tam ritimdeki süresi (saniye).
  static const minWindow = 0.50;
  static const maxWindow = 1.00;

  /// Pencere merkezine normalize uzaklığın `great` saydığı bant.
  static const greatBand = 0.4;

  /// Adımlar arasındaki hedef aralık — drill'in temposu. Metronom bunu çalar.
  static const targetGap = 0.26;

  /// Sapmanın vuruşu sıfırladığı eşik.
  static const gapTolerance = 0.13;

  /// Bir vuruşun [rhythm]'i kendine ne kadar çektiği.
  static const rhythmGain = 0.3;

  static const cadenceGain = 0.22;
  static const cadenceDecay = 0.55;

  /// Yanlış ayağın bedeli: hiçbir basışın saymadığı bir es.
  static const stumbleTime = 0.35;

  static const flashTime = 0.25;

  /// Tam cadence'te saniyede bacak döngüsü radyanı.
  static const strideRate = 2 * math.pi * 2.2;

  TacklePhase phase = TacklePhase.ready;

  double elapsed = 0;

  /// 0..1 — yaklaşma hızını ve bütün hareket ipuçlarını süren değer.
  double cadence = 0;

  RunSide? lastSide;
  double stumbleLeft = 0;

  int steps = 0;
  double leftFlash = 0;
  double rightFlash = 0;

  double stridePhase = 0;
  double pitchPhase = 0;

  /// 0..1 arası metronom fazı; bir tam tur iki adım (sol + sağ).
  double metronome = 0;

  /// Son sayılan adımdan bu yana geçen süre — ritim vuruşunun ölçüsü.
  double sinceLastStep = 0;

  /// Pencere açıldığı anda dondurulan süresi ve içinde geçen zaman.
  double windowDuration = 0;
  double windowElapsed = 0;

  /// Verilmiş derece; dalana ya da pencere kapanana kadar null.
  ShotGrade? grade;

  bool timedOut = false;

  /// Her karede değişenler notifier'da: süre çubuğu ve yaklaşma çubuğu bunlarla
  /// yenilenir, host ekran yalnızca yapısal değişimde `setState` yer.
  final ValueNotifier<double> timeLeft = ValueNotifier<double>(1);

  /// 0 = rakip uzakta, 1 = tam üstünde (pencere açılır).
  final ValueNotifier<double> approach = ValueNotifier<double>(0);

  final ValueNotifier<double> rhythmGauge = ValueNotifier<double>(0);

  /// 0..1 — ritim tutarlılığı. Pencere genişliğini yalnızca bu belirler.
  double get rhythm => rhythmGauge.value;

  set rhythm(double value) => rhythmGauge.value = value.clamp(0.0, 1.0);

  /// Müdahale tuttu mu — `good` ve `great` sayılır.
  bool get succeeded => grade?.counts ?? false;

  bool get finished => phase == TacklePhase.done;

  /// Üç kademenin 0..1 ağırlığı. `ShotObjective.weightOf` ile aynı tablo ama o
  /// metot bir senaryo hedefine bağlı, buradan çağrılamıyor.
  static double weightOf(ShotGrade grade) => switch (grade) {
    ShotGrade.fail => 0,
    ShotGrade.good => 0.6,
    ShotGrade.great => 1,
  };

  TrainingResult get result => TrainingResult(
    drill: TrainingDrill.tackling,
    outcome: succeeded ? TrainingOutcome.success : TrainingOutcome.failure,
    score: weightOf(grade ?? ShotGrade.fail),
    detail: timedOut ? 'Süre doldu' : (grade ?? ShotGrade.fail).label,
  );

  @override
  Color backgroundColor() => AppColors.surface1;

  @override
  Future<void> onLoad() async {
    addAll([PressPitchComponent(), ChaseComponent()]);
  }

  @override
  void onRemove() {
    timeLeft.dispose();
    approach.dispose();
    rhythmGauge.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    advance(dt);
  }

  /// Bir ayak yere. Saat mount'ta değil ilk basışta başlar, böylece ekran
  /// açılırken süre akmaz.
  void step(RunSide side) {
    if (phase == TacklePhase.done) return;

    if (phase == TacklePhase.ready) {
      phase = TacklePhase.closing;
      _countStep(side);
      onStateChanged();
      return;
    }

    // Tökezlerken hiçbir şey saymaz; doğru ayağın bile beklemesi gerekir.
    if (stumbleLeft > 0) return;

    if (side == lastSide) {
      // Yanlış ayak. [lastSide] bilerek yerinde kalıyor — çıkış yolu borçlu
      // olduğun tuşa basmak, aynısına tekrar basmak değil.
      stumbleLeft = stumbleTime;
      cadence *= 0.3;
      // Ritim cezası peşin alınıyor ve sayaç sıfırlanıyor: sıfırlamasaydık
      // tökezlemenin yediği süre bir sonraki adımın aralığına da yansır,
      // tek hata iki kez cezalandırılırdı.
      rhythm = rhythm * 0.5;
      sinceLastStep = 0;
      onStateChanged();
      return;
    }

    _countStep(side);
  }

  void _countStep(RunSide side) {
    // İlk adımın öncesinde bir aralık yok; tempo ikinciden itibaren ölçülür.
    if (steps > 0) {
      final beat = (1 - (sinceLastStep - targetGap).abs() / gapTolerance).clamp(
        0.0,
        1.0,
      );
      rhythm = rhythm + (beat - rhythm) * rhythmGain;
    }
    sinceLastStep = 0;
    steps++;
    lastSide = side;
    cadence = math.min(1, cadence + cadenceGain);
    if (side == RunSide.left) {
      leftFlash = flashTime;
    } else {
      rightFlash = flashTime;
    }
  }

  /// Dalış. Pencere açıkken derece verir, yaklaşırken erken dalış sayılır.
  void commit() {
    if (phase == TacklePhase.closing) {
      // Ayağın açıkta kaldı: adam henüz menzilde değilken daldın.
      _grade(ShotGrade.fail);
      return;
    }
    if (phase != TacklePhase.window) return;

    final offCentre = ((windowElapsed / windowDuration - 0.5).abs() * 2).clamp(
      0.0,
      1.0,
    );
    _grade(offCentre <= greatBand ? ShotGrade.great : ShotGrade.good);
  }

  /// Drill'in bütün kuralları, tek bir saat adımında. `size` okumaz ve hiçbir
  /// bileşene dokunmaz, yani bir test bütün oturumu döngüde koşturabilir.
  void advance(double dt) {
    if (phase == TacklePhase.ready || phase == TacklePhase.done) return;

    elapsed += dt;
    timeLeft.value = (1 - elapsed / runDuration).clamp(0.0, 1.0);

    sinceLastStep += dt;
    stumbleLeft = math.max(0, stumbleLeft - dt);
    leftFlash = math.max(0, leftFlash - dt);
    rightFlash = math.max(0, rightFlash - dt);
    cadence = math.max(0, cadence - cadenceDecay * dt);

    metronome = (metronome + dt / (targetGap * 2)) % 1;
    pitchPhase = (pitchPhase + dt * (0.25 + 1.6 * cadence)) % 1;
    if (stumbleLeft == 0) stridePhase += dt * cadence * strideRate;

    switch (phase) {
      case TacklePhase.closing:
        approach.value = math.min(
          1,
          approach.value + closeRate * closeScale * cadence * dt,
        );
        if (approach.value >= 1) _openWindow();
      case TacklePhase.window:
        windowElapsed += dt;
        // Pencere kapandı, dalmadın: adam geçti.
        if (windowElapsed >= windowDuration) _grade(ShotGrade.fail);
      case TacklePhase.ready || TacklePhase.done:
        break;
    }

    // Yetişemeden süre doldu: adam kaçmış sayılır.
    if (elapsed >= runDuration && phase != TacklePhase.done) {
      timedOut = true;
      _grade(ShotGrade.fail);
    }
  }

  void _openWindow() {
    phase = TacklePhase.window;
    // Genişlik açılış anında donuyor: sonraki karelerde ritim değişse bile
    // pencere değişmez, böylece derece tek bir ana bağlı ve test deterministik
    // kalır.
    windowDuration =
        (minWindow + (maxWindow - minWindow) * rhythm) * windowScale;
    windowElapsed = 0;
    onStateChanged();
  }

  void _grade(ShotGrade value) {
    grade = value;
    _finish();
  }

  void _finish() {
    phase = TacklePhase.done;
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

/// Saha: ufuk çizgisi, sana doğru kayan enine çizgiler ve daralan taç çizgileri.
/// Basmayı bırakınca çizgiler donar — hareket ipucunun tamamı bu.
class PressPitchComponent extends Component with HasGameReference<TackleGame> {
  /// Ufuk: sahanın üstündeki her şey tribün.
  static const horizonAt = 0.42;

  @override
  int get priority => 0;

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;
    final horizon = v * horizonAt;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, u, v),
      Paint()..color = AppColors.surface1,
    );

    // Tribün: iki bant yeterince "stat" diyor.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, u, horizon),
      Paint()..color = AppColors.surface0,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, horizon * 0.55, u, horizon * 0.72),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.04),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, u, v),
      Paint()..color = const Color(0xFF16221B),
    );

    _paintLines(canvas, u, v, horizon);
  }

  void _paintLines(Canvas canvas, double u, double v, double horizon) {
    final line = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.10)
      ..strokeWidth = 1.5;

    // Kareli değil, yaklaşan bir zemin: t² ufka doğru çizgileri sıkıştırıyor,
    // perspektif için tek gereken bu.
    const count = 10;
    for (var i = 0; i < count; i++) {
      final t = (i / count + game.pitchPhase) % 1;
      final e = t * t;
      final y = horizon + (v - horizon) * e;
      final inset = u * 0.5 * (1 - e) * 0.62;
      canvas.drawLine(Offset(inset, y), Offset(u - inset, y), line);
    }

    // Taç çizgileri ufukta birleşiyor.
    final touch = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.14)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(u * 0.5 - u * 0.31, horizon), Offset(0, v), touch);
    canvas.drawLine(Offset(u * 0.5 + u * 0.31, horizon), Offset(u, v), touch);
  }
}

/// Kovalamaca: önde rakip, arkada savunmacı, ve pencere açıkken rakibin
/// ayağının altında kapanan halka.
class ChaseComponent extends Component with HasGameReference<TackleGame> {
  @override
  int get priority => 5;

  /// Kondisyon koşusundaki Blender futbolcusunun koşu döngüsü: savunmacı ev
  /// formasıyla (kırmızı-mavi, her zamanki oyuncu), rakip deplasman formasıyla.
  /// İkisi de yüklenemezse eski çubuk figür çalışır.
  RunFrames? _home;
  RunFrames? _away;
  bool _settled = false;

  /// Yükleme `onLoad`'u bekletmez: 16 görselin çözülmesi dokunuşları alan
  /// bileşenlerin bağlanmasını geciktirmemeli (widget testleri sahte zamanda
  /// görsel çözülmesini hiç bitiremez). Yüklenene kadar figürler çizilmez,
  /// çubuk figür yalnızca yükleme başarısız olursa çıkar; yoksa her açılışta
  /// kısa bir süre yanıp sönerdi.
  @override
  Future<void> onLoad() async {
    _loadFrames();
  }

  Future<void> _loadFrames() async {
    _home = await RunFrames.load('sprites/footballer_run');
    _away = await RunFrames.load('sprites/footballer_run_away');
    _settled = true;
  }

  @override
  void render(Canvas canvas) {
    final u = game.size.x;
    final v = game.size.y;
    final horizon = v * PressPitchComponent.horizonAt;

    final closeness = game.approach.value;
    final phi = game.stridePhase;

    // Rakip ufuktan öne geliyor ve büyüyor; savunmacı ön planda sabit.
    final rivalY = horizon + (v * 0.60 - horizon) * closeness;
    final rivalX = u * (0.56 - 0.07 * closeness);
    final rivalScale = 0.30 + 0.70 * closeness;

    if (game.phase == TacklePhase.window) {
      _paintWindowRing(canvas, Offset(rivalX, rivalY), u, v, rivalScale);
    }

    _paintFigure(
      canvas,
      hip: Offset(rivalX, rivalY),
      scale: rivalScale,
      phi: phi + 1.3,
      u: u,
      v: v,
      shirt: AppColors.dangerBright,
      rival: true,
    );

    _paintFigure(
      canvas,
      hip: Offset(u * 0.40, v * 0.78),
      scale: 1,
      phi: phi,
      u: u,
      v: v,
      shirt: AppColors.accent,
      rival: false,
    );

    _paintMetronome(canvas, u, v);
  }

  /// Kalan pencere bir halka olarak kapanıyor; rengi doğrudan derece kuralını
  /// okuyor — yeşilken basmak `great`, sarıyken `good`.
  void _paintWindowRing(
    Canvas canvas,
    Offset centre,
    double u,
    double v,
    double scale,
  ) {
    final left = (1 - game.windowElapsed / game.windowDuration).clamp(0.0, 1.0);
    final offCentre =
        ((game.windowElapsed / game.windowDuration - 0.5).abs() * 2).clamp(
          0.0,
          1.0,
        );
    final colour = offCentre <= TackleGame.greatBand
        ? AppColors.success
        : AppColors.warning;

    final rect = Rect.fromCenter(
      center: centre + Offset(0, v * 0.20 * scale),
      width: u * 0.26 * scale,
      height: v * 0.075 * scale,
    );

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * left,
      false,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Hedef tempoyu öğreten iki pip: sırayla yanar, aralıkları [targetGap].
  /// Ritmi göz kararı bulmak yerine takip edilebilir olması gerekiyor.
  void _paintMetronome(Canvas canvas, double u, double v) {
    if (game.phase == TacklePhase.done) return;

    final onLeft = game.metronome < 0.5;
    final beat = (game.metronome % 0.5) / 0.5;
    // Vuruşun hemen ardından sönüyor: yanan pip "şimdi bas" demek.
    final glow = (1 - beat * 2).clamp(0.0, 1.0);

    for (final left in [true, false]) {
      final lit = left == onLeft;
      canvas.drawCircle(
        Offset(u * (left ? 0.44 : 0.56), v * 0.055),
        v * 0.011,
        Paint()
          ..color = lit
              ? AppColors.textPrimary.withValues(alpha: 0.25 + 0.75 * glow)
              : AppColors.border,
      );
    }
  }

  /// Bir koşan figür. Rakip de savunmacı da aynı çubuk-ve-levha dilini
  /// kullanıyor, tek fark ölçek ve forma rengi.
  void _paintFigure(
    Canvas canvas, {
    required Offset hip,
    required double scale,
    required double phi,
    required double u,
    required double v,
    required Color shirt,
    required bool rival,
  }) {
    final frames = rival ? _away : _home;
    if (frames == null && !_settled) return;

    final stumbling = !rival && game.stumbleLeft > 0;
    final cadence = game.cadence;
    // Kareler zıplamayı zaten içinde taşıyor; üstüne ikincisini eklemek
    // ayakları zeminden koparırdı.
    final bob = frames != null
        ? 0.0
        : math.sin(phi * 2) * v * 0.012 * cadence * scale;

    canvas.save();
    canvas.translate(0, bob);
    if (stumbling) {
      canvas.translate(hip.dx, hip.dy);
      canvas.rotate(0.18);
      canvas.translate(-hip.dx, -hip.dy);
    }

    if (frames != null) {
      final size = v * RunFrames.heightFrac * scale;
      frames.paint(canvas, hip, phi, size);
      // Basan ayağın kramponu yanıyor: dönüşümlü basmanın geri bildirimi bu,
      // o yüzden kareler üstünde de aynen duruyor. Rakipte böyle bir şey yok.
      if (!rival) {
        for (final left in [true, false]) {
          if ((left ? game.leftFlash : game.rightFlash) <= 0) continue;
          frames.paintFootFlash(canvas, hip, phi, size, left: left);
        }
      }
    } else {
      final thigh = v * 0.085 * scale;
      final shin = v * 0.085 * scale;

      // Arka bacak, gövde, ön bacak, kollar, kafa — figür z-sıralaması
      // olmadan derinlikli okunsun diye bu sırada.
      _paintLeg(
        canvas,
        hip,
        phi + math.pi,
        thigh,
        shin,
        u,
        v,
        scale,
        side: RunSide.left,
        back: true,
        rival: rival,
      );
      _paintTorso(canvas, hip, u, v, scale, shirt);
      _paintLeg(
        canvas,
        hip,
        phi,
        thigh,
        shin,
        u,
        v,
        scale,
        side: RunSide.right,
        back: false,
        rival: rival,
      );
      _paintArms(canvas, hip, phi, v, scale);
      _paintHead(canvas, hip, v, scale);
    }

    if (stumbling) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(hip.dx, hip.dy + v * 0.10),
          width: u * 0.14,
          height: v * 0.05,
        ),
        0,
        math.pi,
        false,
        Paint()
          ..color = AppColors.dangerBright
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    canvas.restore();
  }

  void _paintLeg(
    Canvas canvas,
    Offset hip,
    double phi,
    double thigh,
    double shin,
    double u,
    double v,
    double scale, {
    required RunSide side,
    required bool back,
    required bool rival,
  }) {
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
      ..strokeWidth = 6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hip, knee, paint);
    canvas.drawLine(knee, foot, paint);

    // Basan ayağın kramponu yanıyor: dönüşümlü basmanın geri bildiriminin
    // tamamı bu, o yüzden şaşmaz olmalı. Rakipte böyle bir şey yok.
    final flashing =
        !rival && (side == RunSide.left ? game.leftFlash : game.rightFlash) > 0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: foot,
          width: u * 0.030 * scale,
          height: v * 0.012 * scale,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = flashing ? AppColors.success : const Color(0xFF11131A),
    );
  }

  void _paintTorso(
    Canvas canvas,
    Offset hip,
    double u,
    double v,
    double scale,
    Color shirt,
  ) {
    final shoulder = hip + Offset(0, -v * 0.14 * scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          shoulder - Offset(u * 0.0275 * scale, 0),
          hip + Offset(u * 0.0275 * scale, 0),
        ),
        const Radius.circular(3),
      ),
      Paint()..color = shirt.withValues(alpha: 0.85),
    );
  }

  void _paintArms(
    Canvas canvas,
    Offset hip,
    double phi,
    double v,
    double scale,
  ) {
    final shoulder = hip + Offset(0, -v * 0.14 * scale);
    final upper = v * 0.062 * scale;
    final fore = v * 0.058 * scale;

    for (final side in [0, 1]) {
      final swing = side == 0 ? phi + math.pi : phi;
      final elbowAngle = -1.2 + 0.9 * math.sin(swing);
      final elbow =
          shoulder +
          Offset(math.sin(elbowAngle) * upper, math.cos(elbowAngle) * upper);
      final handAngle = elbowAngle + 1.1;
      final hand =
          elbow +
          Offset(math.sin(handAngle) * fore, math.cos(handAngle) * fore);

      final paint = Paint()
        ..color = side == 0
            ? AppColors.textSecondary
            : AppColors.textSecondary.withValues(alpha: 0.55)
        ..strokeWidth = 5 * scale
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(shoulder, elbow, paint);
      canvas.drawLine(elbow, hand, paint);
    }
  }

  void _paintHead(Canvas canvas, Offset hip, double v, double scale) {
    final center = hip + Offset(0, -v * 0.175 * scale);
    final r = v * 0.030 * scale;
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
