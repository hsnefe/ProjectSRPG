import 'package:flutter/material.dart';
import 'package:project_srpg/game/formation_pick.dart';
import 'package:project_srpg/game/formations.g.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Kuşbakışı diziliş tahtası: kendi kalesi altta, hücum yukarı. Oyuncunun
/// oynadığı slot sarı, kalan dokuzu mavi.
///
/// `lib/game/pitch_projector.dart`'taki [PitchLines] burada kullanılmıyor: o
/// sınıf perspektifli şut sahnesi için tek kaleye göre dünya birimlerinde
/// tanımlı, buradaki tahta ise normalize edilmiş (0-1) kuşbakışı bir kutu.
/// İki koordinat sistemini birbirine zorlamak ikisini de bozardı.
class FormationBoard extends StatelessWidget {
  const FormationBoard({
    super.key,
    required this.formation,
    required this.playerName,
    required this.playerPosition,
  });

  final Formation formation;

  /// Sarı dairenin altına yazılır. Diğer dokuz oyuncunun adı yok — v1'de
  /// kadro yok (CONTRACT.md D4), onlar slot kısaltmasıyla anılır.
  final String playerName;

  /// `CareerHub.playerPosition` / `PlayerState.position` — 'Defans',
  /// 'Orta saha' veya 'Forvet'.
  final String playerPosition;

  /// Çizgilerin kutuya değmemesi için bırakılan kenar payı.
  static const _inset = 10.0;

  @override
  Widget build(BuildContext context) {
    final highlighted = userSlotIndex(formation, playerPosition);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final playArea = Rect.fromLTWH(
            _inset,
            _inset,
            size.width - _inset * 2,
            size.height - _inset * 2,
          );
          // Daireler kutunun kısa kenarına göre ölçekleniyor ki dar bir
          // ekranda taşmasınlar.
          final diameter =
              (playArea.shortestSide * 0.10).clamp(18.0, 34.0).toDouble();

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PitchPainter(playArea: playArea),
                ),
              ),
              for (var i = 0; i < formation.slots.length; i++)
                _positionedSlot(
                  slot: formation.slots[i],
                  playArea: playArea,
                  diameter: diameter,
                  isUser: i == highlighted,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _positionedSlot({
    required FormationSlot slot,
    required Rect playArea,
    required double diameter,
    required bool isUser,
  }) {
    // y sözleşmesi ters: 0 kendi kale çizgisi, 1 rakibinki. Ekranda kendi
    // kalesi altta olduğu için y büyüdükçe yukarı çıkılır.
    final center = Offset(
      playArea.left + slot.x * playArea.width,
      playArea.top + (1 - slot.y) * playArea.height,
    );
    // Etiket dairenin altında, ama kendi genişliğini dairenin dışına taşırarak
    // — 'Kanat' ya da oyuncunun adı daireden geniştir.
    const labelWidth = 74.0;

    return Positioned(
      left: center.dx - labelWidth / 2,
      top: center.dy - diameter / 2,
      width: labelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SlotDot(diameter: diameter, isUser: isUser),
          const SizedBox(height: 3),
          Text(
            isUser ? playerName : slotAbbreviation(slot),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              height: 1.1,
              fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
              color: isUser ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotDot extends StatelessWidget {
  const _SlotDot({required this.diameter, required this.isUser});

  final double diameter;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final color = isUser ? AppColors.warning : AppColors.accent;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUser ? Colors.white : Colors.white24,
          width: isUser ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isUser ? 0.55 : 0.30),
            blurRadius: isUser ? 10 : 5,
          ),
        ],
      ),
    );
  }
}

/// Kuşbakışı saha çizgileri. Ölçüler gerçek sahanın (105 x 68 m) oranlarından
/// normalize edildi; kutu kareye yakın olduğu için dikey eksen sıkışık çizilir
/// — birebir ölçekli bir dikey saha kartın genişliğinin bir buçuk katı
/// yükseklik ister ve maç önü ekranına sığmaz.
class _PitchPainter extends CustomPainter {
  const _PitchPainter({required this.playArea});

  final Rect playArea;

  // 68 m genişliğin kesirleri.
  static const _penaltyWidth = 40.32 / 68;
  static const _goalAreaWidth = 18.32 / 68;
  static const _circleRadius = 9.15 / 68;

  // 105 m uzunluğun kesirleri.
  static const _penaltyDepth = 16.5 / 105;
  static const _goalAreaDepth = 5.5 / 105;

  static const _grassDark = Color(0xFF15251B);
  static const _grassLight = Color(0xFF1A2D20);
  static const _lineColor = Color(0x55FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _grassDark);
    _paintMowBands(canvas, size);

    final line = Paint()
      ..color = _lineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawRect(playArea, line);

    final middle = playArea.top + playArea.height / 2;
    canvas.drawLine(
      Offset(playArea.left, middle),
      Offset(playArea.right, middle),
      line,
    );
    // Ölçek iki eksende farklı olduğu için orta yuvarlak elips çizilir —
    // daire çizmek sahayı değil çemberi doğru gösterirdi.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(playArea.center.dx, middle),
        width: _circleRadius * 2 * playArea.width,
        height: _circleRadius * 2 * playArea.height,
      ),
      line,
    );

    for (final atBottom in const [true, false]) {
      _paintBox(canvas, line, _penaltyWidth, _penaltyDepth, atBottom);
      _paintBox(canvas, line, _goalAreaWidth, _goalAreaDepth, atBottom);
    }
  }

  /// Çim şeritleri: sahanın boş kalan yarısını doldurup kutunun bir arka plan
  /// değil bir saha olduğunu söyleyen tek işaret.
  void _paintMowBands(Canvas canvas, Size size) {
    final paint = Paint()..color = _grassLight;
    const bands = 6;
    final bandHeight = size.height / bands;
    for (var i = 0; i < bands; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * bandHeight, size.width, bandHeight),
        paint,
      );
    }
  }

  void _paintBox(
    Canvas canvas,
    Paint line,
    double widthFraction,
    double depthFraction,
    bool atBottom,
  ) {
    final boxWidth = widthFraction * playArea.width;
    final boxDepth = depthFraction * playArea.height;
    canvas.drawRect(
      Rect.fromLTWH(
        playArea.center.dx - boxWidth / 2,
        atBottom ? playArea.bottom - boxDepth : playArea.top,
        boxWidth,
        boxDepth,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) =>
      oldDelegate.playArea != playArea;
}
