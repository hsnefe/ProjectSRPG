import 'package:flutter/material.dart';

class NewGameButton extends StatefulWidget {
  const NewGameButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<NewGameButton> createState() => _NewGameButtonState();
}

class _NewGameButtonState extends State<NewGameButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        style: TextStyle(
          color: _isPressed ? Colors.white : Colors.white.withValues(alpha: 0.9),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          shadows: _isPressed
              ? [
                  Shadow(
                    color: Colors.blueAccent.withValues(alpha: 0.9),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ]
              : [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: const Text('New Game'),
      ),
    );
  }
}
