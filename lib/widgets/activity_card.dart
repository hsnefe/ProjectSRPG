import 'dart:ui';

import 'package:flutter/material.dart';

/// Yaşam tarzı ekranındaki bir aktivite.
class LifestyleActivity {
  const LifestyleActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
    required this.duration,
    this.conditionDelta = 0,
    this.cost = 0,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Kartın cam gövdesine verilen renk tonu.
  final Color tint;

  /// '2 saat', 'Tüm gece' gibi serbest metin.
  final String duration;

  /// Kondisyona etkisi; eksi olabilir.
  final int conditionDelta;

  /// ₺ cinsinden maliyet.
  final int cost;
}

/// Buzlu cam aktivite kartı: renkli gradient gövde, köşede filigran ikon ve
/// altta gerçekten bulanıklaştırılmış koyu şerit üzerinde aktivite adı.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.width = 148,
    this.height = 176,
    this.borderRadius = 18,
    this.titleFontSize = 13,
  });

  static const _textPrimary = Color(0xFFE8EAED);

  final LifestyleActivity activity;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double borderRadius;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final stripHeight = height * 0.27;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
                color: activity.tint.withValues(alpha: 0.18),
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
                // Cam gövde: renk tonundan koyuya inen gradient.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        activity.tint.withValues(alpha: 0.55),
                        activity.tint.withValues(alpha: 0.22),
                        const Color(0xFF12151B).withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.45, 1.0],
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
                // Filigran ikon.
                Positioned(
                  right: -height * 0.12,
                  top: -height * 0.06,
                  child: Icon(
                    activity.icon,
                    size: height * 0.62,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                // Okunur boyuttaki asıl ikon.
                Positioned(
                  left: 14,
                  top: 14,
                  child: Icon(
                    activity.icon,
                    size: height * 0.17,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                // Alt şerit: kendi arkasındaki gövdeyi bulanıklaştırır.
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
                          vertical: 8,
                        ),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.46),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.14),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          activity.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
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
    );
  }
}
