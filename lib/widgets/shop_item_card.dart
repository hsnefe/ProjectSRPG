import 'dart:ui';

import 'package:flutter/material.dart';

/// Alışveriş ekranındaki bir ürün.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
    required this.price,
    this.note,
    this.imageAsset,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Kartın cam gövdesine verilen renk tonu.
  final Color tint;

  /// ₺ cinsinden fiyat.
  final int price;

  /// 'Yıllık %28 getiri', '3+1, 120 m²' gibi serbest metin.
  final String? note;

  /// Ürün fotoğrafı. Null ise ton ve ikondan prosedürel bir görsel çizilir.
  ///
  /// Foto eklemek için: `assets/images/shop/` klasörünü aç, `pubspec.yaml`
  /// içindeki `assets:` altına o klasörü ekle ve buraya yolu yaz. Kart kodu
  /// değişmez — dosya bulunamazsa yine prosedürel görsele düşer.
  final String? imageAsset;

  String get priceLabel => '₺${_thousands(price)}';

  static String _thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// Buzlu cam ürün kartı: fotoğraf (ya da tonlu prosedürel gövde), üstünde ışık
/// çizgisi ve altta gerçekten bulanıklaştırılmış şerit üzerinde ad ile fiyat.
///
/// [ActivityCard] ile aynı reçete; tek farkı en alttaki katmanın önce fotoğrafı
/// denemesi ve bakiye yetmediğinde kartın sönükleşmesi.
class ShopItemCard extends StatelessWidget {
  const ShopItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.owned = false,
    this.affordable = true,
    this.faded = false,
    this.width = 172,
    this.height = 210,
    this.borderRadius = 18,
  });

  static const _textPrimary = Color(0xFFE8EAED);
  static const _success = Color(0xFF3DDC97);
  static const _danger = Color(0xFFE85D5D);

  final ShopItem item;
  final VoidCallback? onTap;

  /// Satın alınmış: sağ üstte 'Sahip' pili çıkar.
  final bool owned;

  /// Bakiye yetiyor mu; yetmiyorsa fiyat kırmızıya döner.
  final bool affordable;

  /// Kartı soluklaştırır. Vitrinde alınamayan ürünler için açık, detay
  /// katmanında kapalı: orada kart zaten odağın kendisi.
  final bool faded;

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    // İki satır taşıyor (ad + fiyat), o yüzden aktivite kartının şeridinden
    // biraz daha yüksek.
    final stripHeight = height * 0.30;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: faded ? 0.6 : 1,
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: item.tint.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ShopItemArt(item: item),
                  // Şeridin üstünde metin okunsun diye alttan yukarı koyu geçiş.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: height * 0.55,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Üst kenardaki ışık çizgisi.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  if (owned)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _Pill(
                        icon: Icons.check,
                        label: 'Sahip',
                        color: _success,
                      ),
                    ),
                  // Alt şerit: kendi arkasındaki görüntüyü bulanıklaştırır.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: stripHeight,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.46),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withValues(alpha: 0.14),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.priceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: affordable ? _textPrimary : _danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Cam kenarlık, her şeyin üstünde.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ürünün görseli: dosya varsa fotoğraf, yoksa tonlu gradient ve kenardan taşan
/// filigran ikon. Detay katmanı da aynısını kullanır, böylece Hero uçuşu
/// boyunca kartın gövdesi değişmez.
class ShopItemArt extends StatelessWidget {
  const ShopItemArt({super.key, required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final asset = item.imageAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _procedural(),
      );
    }
    return _procedural();
  }

  Widget _procedural() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.tint.withValues(alpha: 0.55),
                    item.tint.withValues(alpha: 0.22),
                    const Color(0xFF12151B).withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              right: -size * 0.12,
              top: -size * 0.06,
              child: Icon(
                item.icon,
                size: size * 0.62,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: Icon(
                item.icon,
                size: size * 0.17,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
