import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// Bir kişinin görünüşü — gerçek portre görseli olmadığı için prosedürel.
///
/// `pubspec.yaml`'da kayıtlı tek görsel `landing.png`; altı ilişki için altı
/// portre çizdirmek bu turun işi değildi. Bunun yerine görünüş **kimlikten
/// türetiliyor**: aynı `relationship_id` her açılışta aynı yüzü verir, farklı
/// kimlikler farklı yüz verir, ve hiçbir dosya gerekmez.
///
/// [DialogScreen]'in `characterAsset` yolu bozulmadan duruyor — ileride
/// gerçek bir portre eklenirse asset'i geçmek yeter, bu katman devreden
/// çıkar.
class PortraitTraits {
  const PortraitTraits({
    required this.skin,
    required this.hair,
    required this.outfit,
    required this.hairStyle,
    required this.build,
    required this.accessory,
  });

  final Color skin;
  final Color hair;
  final Color outfit;

  /// 0 kısa, 1 dalgalı/orta, 2 toplu, 3 kel/çok kısa.
  final int hairStyle;

  /// 0.85 ince, 1.0 orta, 1.18 iri — omuz genişliği çarpanı.
  final double build;

  /// 0 yok, 1 gözlük, 2 sakal, 3 ikisi.
  final int accessory;

  /// Kimlikten deterministik türetme. Rastgelelik yok: `seed` bir karma, yani
  /// `coach` her zaman aynı antrenör. [tint] ilişkinin ekrandaki rengi —
  /// kıyafet ondan çıkıyor ki portre kartın tonuyla aynı aileden olsun.
  factory PortraitTraits.forId(String id, {required Color tint}) {
    var seed = 7;
    for (final unit in id.codeUnits) {
      seed = (seed * 31 + unit) & 0x7FFFFFFF;
    }
    int pick(int shift, int mod) => (seed >> shift) % mod;

    return PortraitTraits(
      skin: _skinTones[pick(3, _skinTones.length)],
      hair: _hairTones[pick(7, _hairTones.length)],
      outfit: Color.alphaBlend(tint.withValues(alpha: 0.72), AppColors.surface2),
      hairStyle: pick(11, 4),
      build: const [0.85, 1.0, 1.18][pick(15, 3)],
      accessory: pick(19, 4),
    );
  }

  static const _skinTones = [
    Color(0xFFE8C0A0),
    Color(0xFFD4A276),
    Color(0xFFB07B50),
    Color(0xFF8A5A38),
    Color(0xFF5E3A23),
  ];

  static const _hairTones = [
    Color(0xFF2B2118),
    Color(0xFF4A3524),
    Color(0xFF7A5B3A),
    Color(0xFFC9A227),
    Color(0xFF9A9A9A),
  ];
}

/// Göğüs hizasından yukarısı — diyalog ekranının görsel alanına oturan büst.
///
/// §1.2 · [imageAsset] verilirse (ve dosya gerçekten varsa) o çizilir;
/// [traits] yine de zorunlu — `outfit` rengi gibi başka yerlerde de
/// kullanılan bir tondan türüyor, görsel geldiğinde bile atılmıyor.
/// `shop_item_card.dart`'ın `ShopItemArt`'ı ve `character_card.dart`'ın
/// `_CharacterLayer`'ıyla aynı desen: asset yok/bulunamıyorsa prosedürel
/// büst geri düşer.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({super.key, required this.traits, this.imageAsset});

  final PortraitTraits traits;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(
      painter: _PortraitPainter(traits),
      size: Size.infinite,
    );

    final asset = imageAsset;
    if (asset == null) return fallback;
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.t);

  final PortraitTraits t;

  @override
  void paint(Canvas canvas, Size size) {
    // Büst ekranın altına yaslanır ve genişlikle değil yükseklikle ölçeklenir,
    // böylece dar bir ekranda kafa ezilmez.
    final unit = size.height / 5.2;
    final cx = size.width / 2;
    final chinY = size.height * 0.62;

    final shoulderW = unit * 2.5 * t.build;
    final shoulderY = chinY + unit * 0.72;

    // Gövde.
    final body = Path()
      ..moveTo(cx - shoulderW / 2, size.height)
      ..lineTo(cx - shoulderW / 2, shoulderY + unit * 0.35)
      ..quadraticBezierTo(
          cx - shoulderW / 2, shoulderY - unit * 0.1, cx - unit * 0.52, shoulderY - unit * 0.18)
      ..lineTo(cx + unit * 0.52, shoulderY - unit * 0.18)
      ..quadraticBezierTo(
          cx + shoulderW / 2, shoulderY - unit * 0.1, cx + shoulderW / 2, shoulderY + unit * 0.35)
      ..lineTo(cx + shoulderW / 2, size.height)
      ..close();
    canvas.drawPath(body, Paint()..color = t.outfit);

    // Yaka — kıyafetin koyu tonu, gövdeyi boyundan ayıran tek çizgi.
    final collar = Path()
      ..moveTo(cx - unit * 0.55, shoulderY - unit * 0.16)
      ..lineTo(cx, shoulderY + unit * 0.42)
      ..lineTo(cx + unit * 0.55, shoulderY - unit * 0.16)
      ..close();
    canvas.drawPath(
      collar,
      Paint()..color = Color.alphaBlend(const Color(0x66000000), t.outfit),
    );

    // Boyun.
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, chinY + unit * 0.3),
        width: unit * 0.62,
        height: unit * 0.7,
      ),
      Paint()..color = Color.alphaBlend(const Color(0x22000000), t.skin),
    );

    // Kafa.
    final headRect = Rect.fromCenter(
      center: Offset(cx, chinY - unit * 0.62),
      width: unit * 1.34,
      height: unit * 1.62,
    );
    canvas.drawOval(headRect, Paint()..color = t.skin);

    _paintHair(canvas, cx, headRect, unit);
    _paintFace(canvas, cx, headRect, unit);
  }

  void _paintHair(Canvas canvas, double cx, Rect head, double unit) {
    final paint = Paint()..color = t.hair;
    switch (t.hairStyle) {
      case 0: // kısa
        canvas.drawArc(
          Rect.fromCenter(
            center: head.center.translate(0, -unit * 0.06),
            width: head.width * 1.04,
            height: head.height * 1.0,
          ),
          math.pi,
          math.pi,
          true,
          paint,
        );
      case 1: // orta, yanlara düşen
        canvas.drawArc(
          Rect.fromCenter(
              center: head.center, width: head.width * 1.1, height: head.height * 1.06),
          math.pi,
          math.pi,
          true,
          paint,
        );
        for (final side in [-1, 1]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                cx + side * head.width * 0.5 - (side > 0 ? 0 : unit * 0.22),
                head.top + unit * 0.1,
                unit * 0.22,
                unit * 0.85,
              ),
              Radius.circular(unit * 0.11),
            ),
            paint,
          );
        }
      case 2: // toplu
        canvas.drawArc(
          Rect.fromCenter(
              center: head.center, width: head.width * 1.06, height: head.height),
          math.pi,
          math.pi,
          true,
          paint,
        );
        canvas.drawCircle(
            Offset(cx, head.top - unit * 0.05), unit * 0.3, paint);
      case _: // çok kısa / kel — yalnızca ince bir saç çizgisi
        canvas.drawArc(
          Rect.fromCenter(
            center: head.center.translate(0, -unit * 0.2),
            width: head.width * 0.98,
            height: head.height * 0.72,
          ),
          math.pi,
          math.pi,
          true,
          paint,
        );
    }
  }

  void _paintFace(Canvas canvas, double cx, Rect head, double unit) {
    final eyeY = head.center.dy + unit * 0.06;
    final eyeDx = unit * 0.27;
    final ink = Paint()..color = const Color(0xFF20242C);

    for (final side in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + side * eyeDx, eyeY),
          width: unit * 0.17,
          height: unit * 0.12,
        ),
        ink,
      );
    }

    // Ağız — düz ve kısa; ifade taşımıyor, çünkü ifade repliğin işi.
    canvas.drawLine(
      Offset(cx - unit * 0.16, head.bottom - unit * 0.3),
      Offset(cx + unit * 0.16, head.bottom - unit * 0.3),
      Paint()
        ..color = Color.alphaBlend(const Color(0x55000000), t.skin)
        ..strokeWidth = unit * 0.06
        ..strokeCap = StrokeCap.round,
    );

    final hasGlasses = t.accessory == 1 || t.accessory == 3;
    final hasBeard = t.accessory == 2 || t.accessory == 3;

    if (hasBeard) {
      canvas.save();
      canvas.clipPath(Path()..addOval(head));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, head.bottom - unit * 0.12),
          width: head.width * 0.86,
          height: unit * 0.72,
        ),
        Paint()..color = t.hair.withValues(alpha: 0.85),
      );
      canvas.restore();
      // Sakalın üstüne ağzı yeniden çiz, yoksa yutuluyor.
      canvas.drawLine(
        Offset(cx - unit * 0.14, head.bottom - unit * 0.3),
        Offset(cx + unit * 0.14, head.bottom - unit * 0.3),
        Paint()
          ..color = const Color(0x99000000)
          ..strokeWidth = unit * 0.05
          ..strokeCap = StrokeCap.round,
      );
    }

    if (hasGlasses) {
      final frame = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.05
        ..color = const Color(0xFF2C3038);
      for (final side in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx + side * eyeDx, eyeY),
              width: unit * 0.36,
              height: unit * 0.3,
            ),
            Radius.circular(unit * 0.08),
          ),
          frame,
        );
      }
      canvas.drawLine(
        Offset(cx - eyeDx + unit * 0.18, eyeY),
        Offset(cx + eyeDx - unit * 0.18, eyeY),
        frame,
      );
    }
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.t.skin != t.skin ||
      old.t.hair != t.hair ||
      old.t.outfit != t.outfit ||
      old.t.hairStyle != t.hairStyle ||
      old.t.build != t.build ||
      old.t.accessory != t.accessory;
}
