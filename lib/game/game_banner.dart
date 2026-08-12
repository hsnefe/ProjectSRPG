import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart'
    show Colors, Curves, TextStyle, FontWeight;

const _success = Color(0xFF3DDC97);
const _textPrimary = Color(0xFFE8EAED);

/// The outcome card every mini-game pops up when a round ends.
///
/// Deliberately game-agnostic: it locates its parent with [findGame] instead of
/// `HasGameReference<T>`, and takes [highlight] rather than matching the text
/// against a table of labels, so each game decides for itself what counts as a
/// good result.
class GameBanner extends PositionComponent {
  GameBanner(this.text, {this.highlight = false})
      : super(anchor: Anchor.center, scale: Vector2.all(0.6));

  final String text;

  /// Paints the text green. False leaves it neutral rather than red — a banner
  /// is a readout, and the games say "bad" with colour elsewhere.
  final bool highlight;

  late final TextPaint _painter = TextPaint(
    style: TextStyle(
      color: highlight ? _success : _textPrimary,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
    ),
  );

  @override
  int get priority => 10;

  @override
  Future<void> onLoad() async {
    final size = findGame()!.size;
    position = Vector2(size.x / 2, size.y * 0.42);
    add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.25, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final metrics = _painter.getLineMetrics(text);
    final w = metrics.width;
    final h = metrics.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w / 2 - 18, -h / 2 - 10, w + 36, h + 20),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    _painter.render(canvas, text, Vector2(-w / 2, -h / 2));
  }
}
