import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// Piyasa değeri geçmişinde tek bir ölçüm.
@immutable
class ValuePoint {
  const ValuePoint({required this.label, required this.value});

  /// X eksenindeki kısa etiket: 'Oca 24', 'Tem 25' gibi.
  final String label;

  /// ₺ cinsinden ham değer. Biçimlendirme [ValueScatterChart]'a bırakılır.
  final double value;
}

/// Zaman içindeki piyasa değeri için nokta grafiği.
///
/// `RadarChart` ile aynı reçete: elle çizim, `TextPainter` etiketler, nokta
/// halkaları arka plan rengiyle kesilir. Y ölçeği verilerden otomatik çıkar.
class ValueScatterChart extends StatelessWidget {
  const ValueScatterChart({
    super.key,
    required this.points,
    required this.accentColor,
    this.aspectRatio = 1.55,
    this.gridLineCount = 4,
    this.connectPoints = true,
    this.dotRadius = 3.5,
    this.highlightLast = true,
    this.gridColor = AppColors.border,
    this.labelColor = AppColors.textSecondary,
    this.backgroundColor = AppColors.surface1,
    this.valueFormatter = formatTry,
  }) : assert(points.length >= 2);

  final List<ValuePoint> points;
  final Color accentColor;
  final double aspectRatio;

  /// Y ekseninde çizilecek yatay ızgara çizgisi sayısı.
  final int gridLineCount;

  /// Noktaları soluk bir çizgiyle birleştirir. Kapatılırsa saf nokta grafiği.
  final bool connectPoints;

  final double dotRadius;

  /// Son (güncel) noktayı büyütür ve üstüne değerini yazar.
  final bool highlightLast;

  final Color gridColor;
  final Color labelColor;
  final Color backgroundColor;

  /// Y ekseni ve vurgu etiketlerini üretir.
  final String Function(double) valueFormatter;

  /// '₺4,2 M' / '₺450 B' — Türkçe ondalık ayracı virgül.
  static String formatTry(double value) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      final text = millions >= 10
          ? millions.round().toString()
          : millions.toStringAsFixed(1);
      return '₺${text.replaceAll('.', ',')} M';
    }
    if (value >= 1000) return '₺${(value / 1000).round()} B';
    return '₺${value.round()}';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: CustomPaint(
        painter: _ValueScatterPainter(
          points: points,
          accentColor: accentColor,
          gridLineCount: gridLineCount,
          connectPoints: connectPoints,
          dotRadius: dotRadius,
          highlightLast: highlightLast,
          gridColor: gridColor,
          labelColor: labelColor,
          backgroundColor: backgroundColor,
          valueFormatter: valueFormatter,
        ),
      ),
    );
  }
}

class _ValueScatterPainter extends CustomPainter {
  _ValueScatterPainter({
    required this.points,
    required this.accentColor,
    required this.gridLineCount,
    required this.connectPoints,
    required this.dotRadius,
    required this.highlightLast,
    required this.gridColor,
    required this.labelColor,
    required this.backgroundColor,
    required this.valueFormatter,
  });

  final List<ValuePoint> points;
  final Color accentColor;
  final int gridLineCount;
  final bool connectPoints;
  final double dotRadius;
  final bool highlightLast;
  final Color gridColor;
  final Color labelColor;
  final Color backgroundColor;
  final String Function(double) valueFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    // Piyasa değeri sıfırdan okunur; tabanı 0'a sabitleyip tavanı yuvarlak
    // bir adıma çıkarıyoruz ki en üstteki ızgara çizgisi tam sayıya otursun.
    final rawMax = points.fold<double>(0, (m, p) => math.max(m, p.value));
    final maxValue = _niceCeiling(rawMax);

    TextPainter label(String text, Color color, {FontWeight? weight}) {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    // Etiketleri önce ölç, sonra kenar boşluklarını ayır — radar grafiğindeki
    // labelMargin hesabının aynısı.
    final yLabels = [
      for (var i = 0; i <= gridLineCount; i++)
        label(valueFormatter(maxValue * i / gridLineCount), labelColor),
    ];
    final xLabels = [
      for (final point in points) label(point.label, labelColor),
    ];

    final leftGutter =
        yLabels.fold<double>(0, (m, tp) => math.max(m, tp.width)) + 8;
    final bottomGutter =
        xLabels.fold<double>(0, (m, tp) => math.max(m, tp.height)) + 6;
    // Son noktanın üstündeki vurgu etiketi için tepede yer bırak.
    final topGutter = highlightLast ? 16.0 : 4.0;

    final plotLeft = leftGutter;
    final plotRight = size.width - 4;
    final plotTop = topGutter;
    final plotBottom = size.height - bottomGutter;
    if (plotRight <= plotLeft || plotBottom <= plotTop) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i <= gridLineCount; i++) {
      final fraction = i / gridLineCount;
      final y = plotBottom - (plotBottom - plotTop) * fraction;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);

      final tp = yLabels[i];
      tp.paint(canvas, Offset(plotLeft - 8 - tp.width, y - tp.height / 2));
    }

    // Dikey taban çizgisi. Dikey ızgara yok: az sayıda noktada tablo gibi
    // okunuyor ve noktaların önüne geçiyor.
    canvas.drawLine(
      Offset(plotLeft, plotTop),
      Offset(plotLeft, plotBottom),
      gridPaint,
    );

    final n = points.length;
    final dataPoints = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          n == 1
              ? (plotLeft + plotRight) / 2
              : plotLeft + (plotRight - plotLeft) * i / (n - 1),
          plotBottom -
              (plotBottom - plotTop) *
                  (maxValue == 0 ? 0 : points[i].value / maxValue),
        ),
    ];

    if (connectPoints) {
      final path = Path()..moveTo(dataPoints.first.dx, dataPoints.first.dy);
      for (var i = 1; i < dataPoints.length; i++) {
        path.lineTo(dataPoints[i].dx, dataPoints[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = accentColor.withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (var i = 0; i < dataPoints.length; i++) {
      final isLast = highlightLast && i == dataPoints.length - 1;
      final radius = isLast ? dotRadius * 1.6 : dotRadius;
      canvas.drawCircle(dataPoints[i], radius, Paint()..color = accentColor);
      canvas.drawCircle(
        dataPoints[i],
        radius,
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (highlightLast) {
      final last = dataPoints.last;
      final tp = label(
        valueFormatter(points.last.value),
        accentColor,
        weight: FontWeight.w600,
      );
      // Sağ kenardan taşmasın diye çizim alanına sıkıştır.
      final dx = (last.dx - tp.width / 2).clamp(plotLeft, plotRight - tp.width);
      tp.paint(canvas, Offset(dx, last.dy - tp.height - 6));
    }

    // X etiketleri. Nokta sayısı arttıkça etiketler çakışır; ilk ve son hep
    // basılır, aradakiler seyreltilir. ~12 noktadan sonra bu yaklaşım yetmez,
    // o noktada etiketleri döndürmek gerekir.
    final step = math.max(1, (n / 4).ceil());
    for (var i = 0; i < n; i++) {
      if (i != 0 && i != n - 1 && i % step != 0) continue;
      final tp = xLabels[i];
      final dx = (dataPoints[i].dx - tp.width / 2)
          .clamp(0.0, math.max(0.0, size.width - tp.width))
          .toDouble();
      tp.paint(canvas, Offset(dx, plotBottom + 6));
    }
  }

  /// [value]'yu 1-2-5 adımlarıyla yukarı yuvarlar ki ızgara etiketleri
  /// okunabilir yuvarlak sayılar olsun.
  static double _niceCeiling(double value) {
    if (value <= 0) return 1;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor())
        .toDouble();
    final normalized = value / magnitude;
    final step = normalized <= 1
        ? 1.0
        : normalized <= 2
            ? 2.0
            : normalized <= 5
                ? 5.0
                : 10.0;
    return step * magnitude;
  }

  @override
  bool shouldRepaint(covariant _ValueScatterPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.connectPoints != connectPoints ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.highlightLast != highlightLast ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.valueFormatter != valueFormatter;
  }
}
