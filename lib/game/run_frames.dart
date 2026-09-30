import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// Blender'daki low-poly futbolcunun 8 karelik koşu döngüsü
/// (`sprites/footballer_run/` ev formasıyla, `footballer_run_away/` deplasman
/// formasıyla; 256×256, şeffaf, sağa koşuyor).
///
/// Kondisyon ve müdahale oyunları aynı kareleri çiziyor; kalça pikseli, bot
/// konumları ve kare seçimi iki yerde kopyalanmasın diye burada duruyor.
/// Sayılar Blender kamerasından ölçüldü, elle ayarlanmadı.
class RunFrames {
  RunFrames._(this._sprites);

  final List<Sprite> _sprites;

  static const count = 8;
  static const framePx = 256.0;

  /// Karenin içinde kalçanın durduğu piksel: oyunun `hip` noktasına bu piksel
  /// oturur, böylece kareler arası zıplama olmaz ve ayaklar aynı zemin
  /// çizgisine basar.
  static const hip = Offset(138.5, 175.8);

  /// Kare boyunun ekran yüksekliğine oranı: karakter karenin ~%90'ını kaplıyor,
  /// eski çubuk figürün `v * 0.34`'lük boyuna denk gelsin diye.
  static const heightFrac = 0.378;

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

  /// [dir] altındaki `run_01..08.png`'yi yükler; biri bile yüklenemezse null,
  /// çağıran eski çizimine döner.
  static Future<RunFrames?> load(String dir) async {
    try {
      return RunFrames._([
        for (var i = 1; i <= count; i++)
          await Sprite.load('$dir/run_${i.toString().padLeft(2, '0')}.png'),
      ]);
    } catch (_) {
      return null;
    }
  }

  /// Adımın fazına ([phi], 0…2π) denk gelen kare. Kareler Blender'da `phi` ile
  /// aynı yönde ilerleyen bir fazla üretildi (kare 1: öndeki bacak dikey,
  /// ileri savruluyor), yani kare seçmek `phi`'yi 8'e bölmekten ibaret.
  static int indexFor(double phi) {
    final turns = phi / (2 * math.pi);
    return ((turns - turns.floorToDouble()) * count).floor() % count;
  }

  /// [phi] fazındaki kareyi, kalçası [at]'e oturacak şekilde çizer; [size]
  /// karenin ekrandaki kenarı.
  void paint(Canvas canvas, Offset at, double phi, double size) {
    _sprites[indexFor(phi)].render(
      canvas,
      position: Vector2(at.dx, at.dy),
      size: Vector2(size, size),
      anchor: Anchor(hip.dx / framePx, hip.dy / framePx),
    );
  }

  /// Basan ayağın yanan ayakkabı ipucu: gerçek botun üstüne biner, yalnızca
  /// yanarken çizilir. [left] oyunun "sol" ayağı (arkadaki bacak).
  void paintFootFlash(
    Canvas canvas,
    Offset at,
    double phi,
    double size, {
    required bool left,
  }) {
    final px = (left ? _leftFootPx : _rightFootPx)[indexFor(phi)];
    final k = size / framePx;
    final foot = at + Offset((px.dx - hip.dx) * k, (px.dy - hip.dy) * k);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: foot, width: size * 0.15, height: size * 0.05),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.success.withValues(alpha: 0.85),
    );
  }
}
