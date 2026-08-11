import 'dart:math' as math;

import 'package:flutter/material.dart';

enum RadarGridShape { polygon, circle }

class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.accentColor,
    this.max = 100,
    this.ringCount = 4,
    this.gridShape = RadarGridShape.polygon,
    this.gridColor = const Color(0xFF333845),
    this.labelColor = const Color(0xFFA0A6B0),
    this.backgroundColor = const Color(0xFF1A1D24),
  }) : assert(labels.length == values.length && labels.length >= 3);

  final List<String> labels;
  final List<double> values;
  final Color accentColor;
  final double max;
  final int ringCount;
  final RadarGridShape gridShape;
  final Color gridColor;
  final Color labelColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _RadarChartPainter(
          labels: labels,
          values: values,
          max: max,
          ringCount: ringCount,
          gridShape: gridShape,
          accentColor: accentColor,
          gridColor: gridColor,
          labelColor: labelColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  _RadarChartPainter({
    required this.labels,
    required this.values,
    required this.max,
    required this.ringCount,
    required this.gridShape,
    required this.accentColor,
    required this.gridColor,
    required this.labelColor,
    required this.backgroundColor,
  });

  final List<String> labels;
  final List<double> values;
  final double max;
  final int ringCount;
  final RadarGridShape gridShape;
  final Color accentColor;
  final Color gridColor;
  final Color labelColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    final center = Offset(size.width / 2, size.height / 2);

    final labelPainters = [
      for (final label in labels)
        TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(color: labelColor, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final labelMargin = labelPainters.fold<double>(
      0,
      (prev, tp) => math.max(prev, math.max(tp.width, tp.height)),
    );
    final radius = math.min(size.width, size.height) / 2 - labelMargin - 14;

    final angleStep = 2 * math.pi / n;
    Offset pointFor(int index, double fraction) {
      final angle = -math.pi / 2 + angleStep * index;
      return center +
          Offset(math.cos(angle), math.sin(angle)) * radius * fraction;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var r = 1; r <= ringCount; r++) {
      final fraction = r / ringCount;
      if (gridShape == RadarGridShape.circle) {
        canvas.drawCircle(center, radius * fraction, gridPaint);
        continue;
      }
      final ringPath = Path();
      for (var i = 0; i < n; i++) {
        final p = pointFor(i, fraction);
        if (i == 0) {
          ringPath.moveTo(p.dx, p.dy);
        } else {
          ringPath.lineTo(p.dx, p.dy);
        }
      }
      ringPath.close();
      canvas.drawPath(ringPath, gridPaint);
    }

    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, pointFor(i, 1), gridPaint);
    }

    final dataPath = Path();
    final dataPoints = <Offset>[];
    for (var i = 0; i < n; i++) {
      final fraction = (values[i] / max).clamp(0.0, 1.0);
      final p = pointFor(i, fraction);
      dataPoints.add(p);
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = accentColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    for (final p in dataPoints) {
      canvas.drawCircle(p, 3.5, Paint()..color = accentColor);
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + angleStep * i;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final tp = labelPainters[i];
      final labelCenter = pointFor(i, 1) + dir * (tp.height / 2 + 12);
      tp.paint(
        canvas,
        Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2),
      );

      final valueFraction = (values[i] / max).clamp(0.0, 1.0);
      final valuePoint = pointFor(i, valueFraction);
      final valueTp = TextPainter(
        text: TextSpan(
          text: values[i].toInt().toString(),
          style: TextStyle(
            color: accentColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valueTp.paint(
        canvas,
        Offset(valuePoint.dx - valueTp.width / 2, valuePoint.dy - valueTp.height - 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.values != values ||
        oldDelegate.max != max ||
        oldDelegate.ringCount != ringCount ||
        oldDelegate.gridShape != gridShape ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
