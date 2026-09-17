import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueChanged, ValueNotifier;

import 'package:project_srpg/game/dribble_courses.dart';
import 'package:project_srpg/game/game_banner.dart';
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';

enum DribblePhase { ready, running, done }

/// Top sürme: koridorda yukarı kaydırarak topu ilerlet.
///
/// Kaydırmanın kuralı üç durumdan ibaret ve üçü de [swipe]'ta yaşıyor:
///
/// * **aynı yöne** kaydırmak hızı artırır ve üst üste kaydırdıkça birikir,
/// * **tam ters yöne** kaydırmak frenler (hızı kırar, yönü çevirmez),
/// * **başka bir yöne** kaydırmak topu o yöne çevirir, hızın bir kısmı kalır.
///
/// Aradaki sınır [alignThreshold]: yön benzerliği (iki birim vektörün nokta
/// çarpımı) bunun üstündeyse "aynı yön", eksisinin altındaysa "tam ters".
/// Ortadaki bant çevirmedir — yani 90°'lik bir kaydırma ne hızlandırır ne
/// frenler, sadece yön değiştirir, ki oyuncu koniden kaçarken hızını
/// kaybetmeden yön değiştirebilsin.
///
/// `training_result.dart`'taki mini-oyun konvansiyonunu izler: bütün kurallar
/// `size` okumayan [advance] ve [swipe] içinde, dolayısıyla puanlama tablosu
/// arkada bir widget ya da oyun döngüsü olmadan test edilebilir.
class DribbleGame extends FlameGame {
  DribbleGame({
    required this.onStateChanged,
    required this.onFinished,
    DribbleCourse? course,
  }) : course = course ?? DribbleCourses.all.first;

  final VoidCallback onStateChanged;
  final ValueChanged<TrainingResult> onFinished;

  /// Oynanan kurs. Hangisinin oynanacağı oturumun kararı, oyunun değil —
  /// `shot_game.dart`'ın sahneyi alıp senaryoyu almaması ile aynı ayrım.
  /// Verilmezse katalogun ilki, yani eski tek kurs.
  final DribbleCourse course;

  /// Bitişe kadarki mesafe. Birim: koridor genişliği (x ekseni 0..1).
  double get courseLength => course.courseLength;

  double get timeLimit => course.timeLimit;

  /// Koridorun merkezden yarı genişliği. Dışına çıkmak topu duvara çarpar.
  static const corridorHalfWidth = 0.40;

  static const maxSpeed = 3.2;

  /// İlk kaydırmanın verdiği hız — durağan topun yön benzerliği tanımsız
  /// olduğu için üç durumdan hiçbirine girmez, doğrudan bu değere oturur.
  static const launchSpeed = 0.9;

  /// Aynı yöne her kaydırmanın eklediği hız.
  static const swipeAccel = 0.62;

  /// Tam ters yöne kaydırmanın hıza uyguladığı çarpan (frenleme).
  static const brakeFactor = 0.42;

  /// Yön değiştirirken korunan hız oranı — keskin dönüş bedelsiz değil.
  static const turnRetention = 0.62;

  /// Nokta çarpımı eşiği; bkz. sınıf açıklaması.
  static const alignThreshold = 0.5;

  /// Kaydırma olmadığında saniyede kaybedilen hız. Top kendi kendine durur,
  /// yani sürmek sürekli bir eylem.
  ///
  /// 0.42'de tavan hızdan (3.2) sıfıra inmek ~7.6 sn sürüyordu — kursun
  /// tamamından uzun, yani bir iki kaydırmayla tavana çıkıp gerisini
  /// sürtünmeye rağmen kayarak bitirmek mümkündü. 0.9'da bu süre ~3.6 sn'ye
  /// iner ve fırlatma hızından (0.9) sıfıra iniş tam 1 sn sürer — kaydırmayı
  /// bırakmanın bedeli artık hissediliyor. Denge noktası `swipeAccel /
  /// friction` ≈ 0.69 sn: oyuncu bu aralıktan daha seyrek kaydırırsa hız net
  /// düşer, daha sık kaydırırsa yükselir — "sürekli müdahale" tek bir
  /// kaydırmayla tavana çıkıp bırakmak değil, bu ritmi tutmak demek.
  static const friction = 0.9;

  /// Kaç temassızlık affedilir. Koni ya da duvar farketmez.
  static const maxHits = 3;

  DribblePhase phase = DribblePhase.ready;

  /// Topun koridordaki yanal yeri, 0..1 (0.5 orta).
  double ballX = 0.5;

  /// Kat edilen mesafe. Kamera bunu takip eder.
  double distance = 0;

  /// Birim vektör; topun gittiği yön. `dy` ileri (bitişe doğru) pozitif.
  Offset heading = const Offset(0, 1);

  double speed = 0;

  int hits = 0;

  double elapsed = 0;

  /// Son çarpışmanın üstünden geçen süre — kısa bir dokunulmazlık, yoksa tek
  /// bir koni ard arda üç temas birden sayar.
  double _hitCooldown = 0;

  /// Çarpma anında ekranı sarsmak için; yalnızca sunum.
  double shake = 0;

  /// Her karede değişen değerler notifier'da: zaman çubuğu ve hız göstergesi
  /// `setState` yerine bunları dinler, host yalnızca yapısal değişiklikte
  /// yeniden kurulur ([ConditioningGame] ile aynı gerekçe).
  final ValueNotifier<double> timeLeft = ValueNotifier<double>(1);
  final ValueNotifier<double> progress = ValueNotifier<double>(0);
  final ValueNotifier<double> speedGauge = ValueNotifier<double>(0);

  List<DribbleCone> get cones => course.cones;

  bool get finished => phase == DribblePhase.done;

  bool get succeeded => distance >= courseLength && hits <= maxHits;

  TrainingResult get result => TrainingResult(
        drill: TrainingDrill.dribble,
        outcome: succeeded ? TrainingOutcome.success : TrainingOutcome.failure,
        score: _score(),
        detail: succeeded
            ? '${elapsed.toStringAsFixed(1)} sn · $hits temas'
            : (hits > maxHits ? '$hits temas — çok fazla' : 'Süre doldu'),
      );

  /// Başarıda süreyi ve temizliği ödüllendirir; başarısızlıkta kat edilen
  /// mesafenin oranı, çünkü 0.0 ile "neredeyse bitiriyordun" aynı şey değil.
  double _score() {
    if (!succeeded) return (distance / courseLength).clamp(0.0, 0.5);
    final timeBonus = (1 - elapsed / timeLimit).clamp(0.0, 1.0);
    final clean = (maxHits - hits) / maxHits;
    return (0.55 + 0.3 * timeBonus + 0.15 * clean).clamp(0.0, 1.0);
  }

  @override
  Color backgroundColor() => AppColors.surface1;

  @override
  Future<void> onLoad() async {
    addAll([DribbleCourseComponent(), DribbleInputLayer()]);
  }

  @override
  void onRemove() {
    timeLeft.dispose();
    progress.dispose();
    speedGauge.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    advance(dt);
  }

  /// Bir kaydırma. [direction] ekran koordinatında ham delta olabilir —
  /// büyüklüğü yok sayılır, yalnızca yönü okunur, çünkü "ne kadar hızlı
  /// kaydırdın" parmak boyutuna ve ekran yoğunluğuna bağlı bir ölçü.
  ///
  /// Yukarı kaydırmak ileridir: çağıran taraf ekranın `dy` işaretini
  /// çevirerek verir (bkz. [DribbleInputLayer]).
  void swipe(Offset direction) {
    if (phase == DribblePhase.done) return;

    final len = direction.distance;
    if (len < 1e-6) return;
    final dir = direction / len;

    if (phase == DribblePhase.ready) {
      phase = DribblePhase.running;
      heading = dir;
      speed = launchSpeed;
      onStateChanged();
      return;
    }

    // Durmuş top: yön benzerliği tanımsız, yeniden fırlat.
    if (speed <= 1e-6) {
      heading = dir;
      speed = launchSpeed;
      return;
    }

    final alignment = dir.dx * heading.dx + dir.dy * heading.dy;

    if (alignment > alignThreshold) {
      // Aynı yön: hızlan. Yön kaydırmaya doğru biraz kayar ki hızlanırken de
      // nişan alınabilsin — yoksa ilk kaydırma yönü kilitleniyor.
      speed = math.min(maxSpeed, speed + swipeAccel);
      heading = _normalize(heading + (dir - heading) * 0.35);
    } else if (alignment < -alignThreshold) {
      // Tam ters: frenle. Yön bilerek korunuyor — fren geri gitmek değil.
      speed *= brakeFactor;
    } else {
      // Yan: çevir, hızın bir kısmını koru.
      heading = dir;
      speed *= turnRetention;
    }
  }

  void advance(double dt) {
    if (phase != DribblePhase.running) return;

    elapsed += dt;
    if (_hitCooldown > 0) _hitCooldown -= dt;
    if (shake > 0) shake = math.max(0, shake - dt * 3);

    speed = math.max(0, speed - friction * dt);

    ballX += heading.dx * speed * dt;
    distance += heading.dy * speed * dt;

    // Geri kaçmayı engelle: bitişe doğru olmayan bir yöne uzun süre gitmek
    // mesafeyi eksiye çeviremesin, yoksa ilerleme çubuğu geri sayar.
    if (distance < 0) distance = 0;

    _checkWalls();
    _checkCones();

    timeLeft.value = (1 - elapsed / timeLimit).clamp(0.0, 1.0);
    progress.value = (distance / courseLength).clamp(0.0, 1.0);
    speedGauge.value = (speed / maxSpeed).clamp(0.0, 1.0);

    if (distance >= courseLength) {
      _finish();
    } else if (elapsed >= timeLimit || hits > maxHits) {
      _finish();
    }
  }

  void _checkWalls() {
    final left = 0.5 - corridorHalfWidth;
    final right = 0.5 + corridorHalfWidth;
    if (ballX >= left && ballX <= right) return;

    ballX = ballX.clamp(left, right);
    // Duvara sürtmek yönü içeri çevirir ve hızı kırar; oyuncu duvar boyunca
    // kayarak bedava ilerleyemesin.
    heading = _normalize(Offset(-heading.dx, heading.dy.abs()));
    speed *= brakeFactor;
    _registerHit();
  }

  void _checkCones() {
    if (_hitCooldown > 0) return;
    for (final cone in cones) {
      final dx = (ballX - cone.x).abs();
      final dd = (distance - cone.distance).abs();
      if (dx < 0.08 && dd < 0.16) {
        speed = 0;
        _registerHit();
        return;
      }
    }
  }

  void _registerHit() {
    hits++;
    _hitCooldown = 0.5;
    shake = 1;
    onStateChanged();
  }

  void _finish() {
    phase = DribblePhase.done;
    speed = 0;
    add(GameBanner(succeeded ? 'BAŞARILI' : 'YETERSİZ', highlight: succeeded));
    onStateChanged();
    onFinished(result);
  }

  static Offset _normalize(Offset v) {
    final len = v.distance;
    return len < 1e-6 ? const Offset(0, 1) : v / len;
  }
}

/// Koridoru, konileri ve topu çizer. Render `size` okuyabilir — konvansiyonun
/// yasakladığı yer yalnızca kural katmanı ([DribbleGame.advance]).
class DribbleCourseComponent extends PositionComponent
    with HasGameReference<DribbleGame> {
  /// Topun ekranda durduğu dikey oran: kamera topu takip eder, top alt üçte
  /// birde sabit kalır, böylece önü hep görünür.
  static const _ballAnchorY = 0.72;

  /// Bir birim mesafenin kaç piksel olduğu, ekran yüksekliğine oranla.
  double _unitPx(Vector2 s) => s.y * 0.30;

  @override
  void render(Canvas canvas) {
    final s = game.size;
    final unit = _unitPx(s);
    final corridorW = s.x * 0.82;
    final left = (s.x - corridorW) / 2;
    final shakeX = game.shake > 0
        ? math.sin(game.elapsed * 60) * 4 * game.shake
        : 0.0;

    canvas.save();
    canvas.translate(shakeX, 0);

    // Koridor zemini.
    final floor = Rect.fromLTWH(left, 0, corridorW, s.y);
    canvas.drawRect(floor, Paint()..color = const Color(0xFF16301F));

    // Kaydıkça geçen enine çizgiler — hız duygusu bunlardan geliyor.
    final linePaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 2;
    final offset = (game.distance * unit) % (unit / 2);
    for (var y = -unit; y < s.y + unit; y += unit / 2) {
      final py = y + offset;
      canvas.drawLine(Offset(left, py), Offset(left + corridorW, py), linePaint);
    }

    // Duvarlar.
    final wallPaint = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.55)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(left, 0), Offset(left, s.y), wallPaint);
    canvas.drawLine(
        Offset(left + corridorW, 0), Offset(left + corridorW, s.y), wallPaint);

    double screenY(double d) =>
        s.y * _ballAnchorY - (d - game.distance) * unit;
    double screenX(double x) => left + x * corridorW;

    // Bitiş çizgisi.
    final finishY = screenY(game.courseLength);
    if (finishY > -20 && finishY < s.y + 20) {
      canvas.drawLine(
        Offset(left, finishY),
        Offset(left + corridorW, finishY),
        Paint()
          ..color = AppColors.success
          ..strokeWidth = 5,
      );
    }

    for (final cone in game.cones) {
      final cy = screenY(cone.distance);
      if (cy < -30 || cy > s.y + 30) continue;
      final cx = screenX(cone.x);
      final path = Path()
        ..moveTo(cx, cy - 13)
        ..lineTo(cx + 9, cy + 7)
        ..lineTo(cx - 9, cy + 7)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFE2622F));
    }

    // Top.
    final bx = screenX(game.ballX);
    final by = s.y * _ballAnchorY;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bx, by + 12), width: 20, height: 7),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawCircle(Offset(bx, by), 11, Paint()..color = const Color(0xFFF3F4F2));
    canvas.drawCircle(
      Offset(bx, by),
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF20211F),
    );

    // Hız oku — topun gittiği yön, uzunluğu hıza orantılı.
    if (game.speed > 0.05) {
      final h = game.heading;
      final len = 14 + 26 * (game.speed / DribbleGame.maxSpeed);
      canvas.drawLine(
        Offset(bx, by),
        Offset(bx + h.dx * len, by - h.dy * len),
        Paint()
          ..color = AppColors.accent
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
  }
}

/// Tam ekran sürükleme yüzeyi. `onGameResize` zorunlu — bir bileşen yalnızca
/// kendi `size`'ı içinde jest alır, bu satır olmadan kaydırmalar sessizce
/// düşer (`PatternInputLayer` ile aynı gerekçe).
class DribbleInputLayer extends PositionComponent
    with HasGameReference<DribbleGame>, DragCallbacks {
  /// Bir kaydırma sayılması için gereken en küçük piksel mesafesi. Altındaki
  /// hareketler titremedir, yön bilgisi taşımaz.
  static const minSwipePx = 18.0;

  Offset? _from;

  @override
  int get priority => 20;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _from = event.canvasPosition.toOffset();
  }

  /// Kaydırma parmağı kaldırmayı beklemez: eşiği geçen her parça bir kaydırma
  /// sayılır ve sayaç oradan yeniden başlar. Böylece parmağı bırakmadan üst
  /// üste itmek — oyunun asıl ritmi — çalışır.
  @override
  void onDragUpdate(DragUpdateEvent event) {
    final from = _from;
    if (from == null) return;
    final to = event.canvasEndPosition.toOffset();
    final delta = to - from;
    if (delta.distance < minSwipePx) return;
    // Ekranda yukarı (-dy) ileridir; oyun uzayında ileri +dy.
    game.swipe(Offset(delta.dx, -delta.dy));
    _from = to;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _from = null;
  }
}
