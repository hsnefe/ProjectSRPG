import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' show Vector2;

/// Blender'dan gelen sahne katmanları sabit bir kanvasta (1600×900) hizalı
/// çekilir; bu üçü onu ekrana "cover" olarak oturtur: kanvas ekranı tamamen
/// kaplar, taşan kısım ortadan kırpılır. Kanvasın ortasındaki şerit her en/boy
/// oranında görünür kalır, bu yüzden sahnenin önemli kısmı oraya konur.
///
/// Kondisyon ve esneme sahneleri aynı hesabı paylaşsın diye burada duruyor;
/// her biri kendi kanvas boyutunu ve nokta koordinatlarını kendi dosyasında
/// tutar (`layout.json`'dan ölçülmüş).
double coverScale(Vector2 size, Size canvas) =>
    math.max(size.x / canvas.width, size.y / canvas.height);

Offset coverOrigin(Vector2 size, Size canvas) {
  final s = coverScale(size, canvas);
  return Offset(
    (size.x - canvas.width * s) / 2,
    (size.y - canvas.height * s) / 2,
  );
}

/// Kanvas pikselini ekran pikseline çevirir.
Offset coverPoint(Offset p, Vector2 size, Size canvas) {
  final o = coverOrigin(size, canvas);
  final s = coverScale(size, canvas);
  return Offset(o.dx + p.dx * s, o.dy + p.dy * s);
}
