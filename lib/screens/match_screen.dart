import 'package:flutter/material.dart';
import 'package:project_srpg/screens/shot_prototype_screen.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _success = Color(0xFF3DDC97);

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        24;

    return Scaffold(
      backgroundColor: _surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: panelHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border, width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: const Column(
                      children: [
                        _MatchBar(),
                        Expanded(child: _MatchScenePlaceholder()),
                        _ActionBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchBar extends StatelessWidget {
  const _MatchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MatchScreen._border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: _ScoreChip(
                    child: Text(
                      'FK Yıldız',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MatchScreen._textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const _ScoreChip(
                  minWidth: 30,
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: MatchScreen._textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const _ScoreChip(
                  minWidth: 30,
                  child: Text(
                    '0',
                    style: TextStyle(
                      color: MatchScreen._textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ScoreChip(
                    child: Text(
                      'Deniz SK',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: MatchScreen._textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: MatchScreen._textPrimary,
                backgroundColor: MatchScreen._surface1,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_run_outlined, size: 16),
                  SizedBox(height: 2),
                  Text(
                    "62'",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.child,
    this.minWidth,
  });

  final Widget child;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MatchScreen._surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _MatchScenePlaceholder extends StatelessWidget {
  const _MatchScenePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ShotPrototypeScreen(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: MatchScreen._surface1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: MatchScreen._border,
              width: 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(color: MatchScreen._border),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Maç sahnesi (boş)',
                    style: TextStyle(
                      color: MatchScreen._textMuted,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Şut prototipini aç →',
                    style: TextStyle(
                      color: MatchScreen._textSecondary,
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
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(8),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ActionBar extends StatelessWidget {
  const _ActionBar();

  void _showStubMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: MatchScreen._border, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          const Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kondisyon',
                    style: TextStyle(
                      color: MatchScreen._textMuted,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '72/100',
                    style: TextStyle(
                      color: MatchScreen._textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(3)),
                child: LinearProgressIndicator(
                  value: 0.72,
                  minHeight: 6,
                  backgroundColor: MatchScreen._surface1,
                  color: MatchScreen._success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MatchActionButton(
                  icon: Icons.bolt_outlined,
                  label: 'Efor',
                  onPressed: () =>
                      _showStubMessage(context, 'Efor aksiyonu yakında'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MatchActionButton(
                  icon: Icons.track_changes_outlined,
                  label: 'Rol',
                  onPressed: () =>
                      _showStubMessage(context, 'Rol aksiyonu yakında'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MatchActionButton(
                  icon: Icons.shield_outlined,
                  label: 'Sertlik',
                  onPressed: () =>
                      _showStubMessage(context, 'Sertlik aksiyonu yakında'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchActionButton extends StatelessWidget {
  const _MatchActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: MatchScreen._textPrimary,
        side: const BorderSide(color: MatchScreen._border),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
