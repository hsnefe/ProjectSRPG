import 'dart:ui';

import 'package:flutter/material.dart';

/// Karakter kartında gösterilen kişi/kurum.
class CharacterCardData {
  const CharacterCardData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.score,
    required this.icon,
    required this.tint,
    required this.badgeCode,
    required this.leftTag,
    required this.rightTag,
    required this.dateLabel,
    this.imageAsset,
  });

  final String id;

  /// Kart başlığı: 'Antrenör'.
  final String name;

  /// Başlığın altındaki tek satırlık durum metni.
  final String subtitle;

  /// 0-100 arası puan; kapsülde 10'a bölünüp tek ondalıkla gösterilir.
  final int score;

  final IconData icon;

  /// Arka plandaki bloom, siluetin kenar ışığı ve puan kapsülü bu renkten.
  final Color tint;

  /// Sağ üstteki dairesel rozette yazan iki harfli kod.
  final String badgeCode;

  /// Puan kapsülünün solundaki küçük etiket.
  final String leftTag;

  /// Puan kapsülünün sağındaki küçük etiket.
  final String rightTag;

  /// Sol üstteki son temas bilgisi: '12 Ağu · 14:30'.
  final String dateLabel;

  /// Gerçek karakter render'ı. Null ise prosedürel siluet çizilir.
  final String? imageAsset;
}

/// Neon ışıklı karakter kartı: koyu gövde, karakterin arkasında karta özel
/// renkte bloom, altta buzlu cam panel ve panelin kenarına binen puan kapsülü.
class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.data,
    this.width = 215,
    this.height = 300,
    this.borderRadius = 22,
    this.primaryLabel = 'ARA',
    this.secondaryLabel = 'PROFİL',
    this.primaryKey,
    this.onPrimary,
    this.onSecondary,
  });

  static const _base = Color(0xFF0E1116);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFF8A909B);

  final CharacterCardData data;
  final double width;
  final double height;
  final double borderRadius;
  final String primaryLabel;
  final String secondaryLabel;

  /// Birincil butona takılan anahtar; `ExpandPageRoute` için rect okumakta
  /// kullanılır.
  final Key? primaryKey;

  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final panelHeight = height * 0.40;
    final tint = data.tint;

    // Kart gövdesinde onTap yok: olsaydı butonlarla aynı jest arenasına
    // girip dokunuşu kapabilirdi. Etkileşim yalnızca iki butonda.
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: tint.withValues(alpha: 0.22),
              blurRadius: 26,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: _base),
              // Karakterin arkasından gelen renkli ışık.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 0.95,
                    colors: [
                      tint.withValues(alpha: 0.55),
                      tint.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              // Zeminden yukarı vuran hafif yansıma.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: height * 0.35,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        tint.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Filigran ikon: sol kenardan taşar, başın arkasına girmez.
              Positioned(
                left: -height * 0.08,
                top: height * 0.13,
                child: Icon(
                  data.icon,
                  size: height * 0.30,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              // Karakter: gerçek görsel yoksa prosedürel siluet. Kartın
              // tamamını kaplar; gövdenin alt kısmı cam panelin arkasında
              // kalır, böylece görünür bir kesik kenar oluşmaz.
              Positioned.fill(
                child: _CharacterLayer(imageAsset: data.imageAsset, tint: tint),
              ),
              // Üst şerit: son temas ve kod rozeti.
              Positioned(
                left: 14,
                right: 12,
                top: 12,
                child: Row(
                  children: [
                    Text(
                      data.dateLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: tint.withValues(alpha: 0.55)),
                      ),
                      child: Text(
                        data.badgeCode,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: tint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Buzlu cam panel: arkasındaki gövdeyi bulanıklaştırır.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: panelHeight,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Panelin dışına taşan etiket satırının yeri.
                          const SizedBox(height: 22),
                          Text(
                            data.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: _GhostButton(
                                  key: primaryKey,
                                  label: primaryLabel,
                                  onTap: onPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _GhostButton(
                                  label: secondaryLabel,
                                  onTap: onSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Etiketler ve puan kapsülü; panelin üst kenarına biner.
              Positioned(
                left: 12,
                right: 12,
                bottom: panelHeight - 13,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MiniTag(label: data.leftTag),
                      _ScoreCapsule(score: data.score, tint: tint),
                      _MiniTag(label: data.rightTag),
                    ],
                  ),
                ),
              ),
              // Cam kenarlık, her şeyin üstünde. Dokunmayı yutmaması için
              // IgnorePointer şart: aksi halde alttaki butonlara basılamaz.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterLayer extends StatelessWidget {
  const _CharacterLayer({required this.imageAsset, required this.tint});

  final String? imageAsset;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset;
    if (asset == null) {
      return CustomPaint(painter: _CharacterSilhouettePainter(tint: tint));
    }

    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      errorBuilder: (_, _, _) =>
          CustomPaint(painter: _CharacterSilhouettePainter(tint: tint)),
    );
  }
}

/// Gerçek render gelene kadarki mock karakter: arkadan aydınlatılmış koyu
/// büst silueti.
class _CharacterSilhouettePainter extends CustomPainter {
  const _CharacterSilhouettePainter({required this.tint});

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Omuzlar ve yan kenarlar kartın dışına taşar: geriye yalnızca eğimli
    // omuz hattı ve baş kalır, kesik kenarların parlaması engellenir.
    final shoulders = Path()
      ..moveTo(-w * 0.08, h * 1.1)
      ..cubicTo(-w * 0.02, h * 0.66, w * 0.16, h * 0.48, w * 0.33, h * 0.46)
      ..lineTo(w * 0.67, h * 0.46)
      ..cubicTo(w * 0.84, h * 0.48, w * 1.02, h * 0.66, w * 1.08, h * 1.1)
      ..close();

    final neck = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.42),
            width: w * 0.20,
            height: h * 0.12,
          ),
          Radius.circular(w * 0.05),
        ),
      );

    final head = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.26),
          width: w * 0.30,
          height: h * 0.26,
        ),
      );

    final body = Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, shoulders, neck),
      head,
    );

    // 1) Dış hale.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeJoin = StrokeJoin.round
        ..color = tint.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 2) Kenar ışığı.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = tint.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 3) Gövde en son: siluet koyu kalsın, ışık kenarlardan sızsın.
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEE0A0C10), Color(0xFF05070A)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CharacterSilhouettePainter oldDelegate) {
    return oldDelegate.tint != tint;
  }
}

class _ScoreCapsule extends StatelessWidget {
  const _ScoreCapsule({required this.score, required this.tint});

  final int score;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.95), tint.withValues(alpha: 0.55)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: tint.withValues(alpha: 0.45), blurRadius: 14),
        ],
      ),
      child: Text(
        (score / 10).toStringAsFixed(1),
        style: const TextStyle(
          color: CharacterCard._base,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}
