import 'dart:async';

import 'package:flutter/material.dart';

/// Metni karakter karakter açan diyalog kutusu efekti.
///
/// [key] üzerinden [TypewriterTextState.skip] çağrılarak animasyon anında
/// tamamlanabilir. `text` değiştiğinde animasyon baştan başlar.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.characterInterval = const Duration(milliseconds: 18),
    this.onComplete,
  });

  final String text;
  final TextStyle style;
  final Duration characterInterval;
  final VoidCallback? onComplete;

  @override
  State<TypewriterText> createState() => TypewriterTextState();
}

class TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _visibleCount = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _visibleCount = 0;
    _completed = false;
    if (widget.text.isEmpty) {
      _finish();
      return;
    }
    _timer = Timer.periodic(widget.characterInterval, (_) => _tick());
  }

  void _tick() {
    _visibleCount++;
    if (_visibleCount >= widget.text.length) {
      _finish();
      return;
    }
    setState(() {});
  }

  void _finish() {
    _timer?.cancel();
    _visibleCount = widget.text.length;
    if (_completed) return;
    _completed = true;
    if (mounted) setState(() {});
    widget.onComplete?.call();
  }

  /// Animasyonu anında tamamlar; zaten bittiyse hiçbir şey yapmaz.
  void skip() {
    if (_completed) return;
    _finish();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.text.substring(0, _visibleCount),
      style: widget.style,
    );
  }
}
