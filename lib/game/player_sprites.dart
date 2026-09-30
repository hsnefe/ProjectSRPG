import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/flame.dart';
import 'package:flame/cache.dart';

/// Maç mini oyunundaki oyuncu ve kaleci sprite'ları.
///
/// Sayfalar `tools/blender/` betikleriyle Blender'dan üretilir
/// (`render_match_sprites.py` + `assemble_match_sprites.py`); elle
/// düzenlenmez. Burada yalnızca okunur: hangi sütun hangi kare, hangi satır
/// hangi yön, ve forma rengi nasıl uygulanır.
///
/// **Renklendirme.** Her tür dört sayfadan oluşur: `base` (ten, saç, krampon,
/// şeritler — forma parçaları oyulmuş) ve `shirt` / `shorts` / `socks`
/// (yalnızca o parça, *beyaz* ve gerçek ışıkla gölgelenmiş). Kit katmanı
/// `BlendMode.modulate` ile takım rengine çarpılır; böylece tek render her
/// takıma yetiyor ve gölge/yüz yapısı renkte de korunuyor.
class Kit {
  const Kit({required this.shirt, required this.shorts, required this.socks});

  final Color shirt;
  final Color shorts;
  final Color socks;

  /// Oyuncunun kendi takımı: koşu animasyonundaki kırmızı-mavi forma.
  static const home = Kit(
    shirt: Color(0xFFDC2328),
    shorts: Color(0xFF2848C8),
    socks: Color(0xFFDC2328),
  );

  /// Rakip: mavi forma, beyaz şort.
  static const away = Kit(
    shirt: Color(0xFF1E78DC),
    shorts: Color(0xFFFAFAFA),
    socks: Color(0xFF1E78DC),
  );

  /// Kaleci, sahadaki iki takımdan da ayrışsın diye amber.
  static const keeper = Kit(
    shirt: Color(0xFFFAB81A),
    shorts: Color(0xFF1E1E28),
    socks: Color(0xFFFAB81A),
  );
}

enum SpriteKind { outfield, keeper }

/// Bir kipin sayfadaki kare aralığı.
class SpriteClip {
  const SpriteClip(this.start, this.count);

  final int start;
  final int count;

  /// [i] kare numarası; aralık dışına taşarsa başa sarar (koşu döngüsü).
  int column(int i) => start + i % count;
}

class PlayerSprites {
  PlayerSprites._(this._sheets);

  /// `assemble_match_sprites.py`'nin yazdığı `layout.json` ile aynı sayılar;
  /// `test/player_sprites_test.dart` ikisini karşılaştırır.
  static const directions = 8;
  static const layers = ['base', 'shirt', 'shorts', 'socks'];

  static const outfieldIdle = SpriteClip(0, 1);
  static const outfieldRun = SpriteClip(1, 8);

  static const keeperReady = SpriteClip(0, 1);
  static const keeperDiveLeft = SpriteClip(1, 4);
  static const keeperDiveRight = SpriteClip(5, 4);

  static const _frameSize = {
    SpriteKind.outfield: Size(128, 176),
    SpriteKind.keeper: Size(192, 176),
  };

  /// Render kamerası: metre başına 140 piksel, 22° yukarıdan. Saçın tepesi
  /// 1.22 m ve dikeyde `cos(22°)` ile kısalır; ayaklar karenin altından 4
  /// piksel içeride durur.
  static const _modelHeightPx = 1.22 * 0.9272 * 140;
  static const _footMarginPx = 4.0;

  final Map<(SpriteKind, String), Image> _sheets;

  static PlayerSprites? _cached;

  /// Sayfaları yükler; ikinci çağrı aynı örneği döndürür. Testlerde ya da
  /// varlık eksikse atar — çağıran bunu yakalayıp eski gövde çizimine düşer.
  static Future<PlayerSprites> load([Images? images]) async {
    final cached = _cached;
    if (cached != null) return cached;

    final cache = images ?? Flame.images;
    final sheets = <(SpriteKind, String), Image>{};
    for (final kind in SpriteKind.values) {
      for (final layer in layers) {
        sheets[(kind, layer)] = await cache.load(
          'sprites/players/${kind.name}_$layer.png',
        );
      }
    }
    return _cached = PlayerSprites._(sheets);
  }

  /// Sayfadaki satır: oyuncunun yüzü kameraya göre nereye dönük.
  ///
  /// 0 = sırtı dönük (kamerayla aynı yöne bakıyor), 2 = ekranın sağına,
  /// 4 = kameraya, 6 = ekranın soluna. [facing] ve [cameraAngle] yerdeki
  /// mutlak yönlerdir (`+y`'den saat yönünde, bkz. `PitchProjector`); ekranın
  /// sağ ekseni `(cos c, -sin c)` olduğundan fark `sin(facing - camera)` ile
  /// sağa bakmayı verir.
  static int viewRow(double facing, double cameraAngle) {
    final turn = (facing - cameraAngle) % (2 * math.pi);
    return (turn / (math.pi / 4)).round() % directions;
  }

  /// [feet] ayakların ekrandaki noktası, [bodyHeight] gövdenin piksel boyu.
  void paint(
    Canvas canvas, {
    required SpriteKind kind,
    required Kit kit,
    required int column,
    required int row,
    required Offset feet,
    required double bodyHeight,
    double opacity = 1,
  }) {
    final frame = _frameSize[kind]!;
    final scale = bodyHeight / _modelHeightPx;
    final dst = Rect.fromLTWH(
      feet.dx - frame.width * scale / 2,
      feet.dy - (frame.height - _footMarginPx) * scale,
      frame.width * scale,
      frame.height * scale,
    );
    final src = Rect.fromLTWH(
      column * frame.width,
      row * frame.height,
      frame.width,
      frame.height,
    );

    final white = Color.fromRGBO(255, 255, 255, opacity);
    final tints = {
      'base': white,
      'shirt': _withOpacity(kit.shirt, opacity),
      'shorts': _withOpacity(kit.shorts, opacity),
      'socks': _withOpacity(kit.socks, opacity),
    };
    for (final layer in layers) {
      canvas.drawImageRect(
        _sheets[(kind, layer)]!,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(tints[layer]!, BlendMode.modulate),
      );
    }
  }

  static Color _withOpacity(Color c, double o) => c.withValues(alpha: o);
}
