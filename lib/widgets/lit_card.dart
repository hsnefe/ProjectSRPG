import 'package:flutter/material.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Kariyer merkezinin "aydınlatılmış" kart yüzeyi: gradyan kenar + üç katmanlı
/// gölge + üstte ince ışık çizgisi + altta vinyet.
///
/// `career_center_screen.dart`'ta private bir sınıftı; takvim ekranının gün
/// detay paneli de aynı yüzeyi istediği için
/// [`app_colors.dart`](../theme/app_colors.dart)'ın kendi kuralı gereği
/// (iki dosyada kullanılan ton/bileşen ortak kütüphaneye taşınır) buraya
/// çıkarıldı. Görsel olarak **hiçbir şey değişmedi** — taşıma mekanik.

class LitCard extends StatelessWidget {
  const LitCard({
    super.key,
    required this.child,
    this.onTap,
    this.minHeight,
    this.borderRadius = 16,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? minHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final innerRadius = borderRadius - 1;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.22),
            blurRadius: 48,
            spreadRadius: -10,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.06),
              Colors.black.withValues(alpha: 0.35),
            ],
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: Container(
          constraints:
              minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.cardTop, AppColors.cardMid, AppColors.cardBottom],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.42),
                        Colors.white.withValues(alpha: 0.42),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                bottom: 14,
                left: 0,
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(innerRadius),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return card;

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}
