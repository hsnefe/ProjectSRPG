import 'package:flutter/material.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/screens/match_screen.dart';
import 'package:project_srpg/state/match_controller.dart';
import 'package:project_srpg/state/player_scope.dart';

class PreMatchScreen extends StatelessWidget {
  const PreMatchScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _success = Color(0xFF3DDC97);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _HeaderSection(),
                      _FieldPlaceholder(),
                      _TacticsRow(),
                      _ConditionBar(),
                      _ActionRow(),
                    ],
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

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PreMatchScreen._border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_left,
              size: 24,
              color: PreMatchScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Maça Çıkış',
              style: TextStyle(
                color: PreMatchScreen._textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'FK Yıldız - Deniz SK',
                style: TextStyle(
                  color: PreMatchScreen._textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Cumartesi, 20:00',
                style: TextStyle(
                  color: PreMatchScreen._textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldPlaceholder extends StatelessWidget {
  const _FieldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 260),
        width: double.infinity,
        decoration: BoxDecoration(
          color: PreMatchScreen._surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: PreMatchScreen._border,
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: PreMatchScreen._border),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.grid_view_outlined,
                  size: 28,
                  color: PreMatchScreen._textMuted,
                ),
                SizedBox(height: 6),
                Text(
                  'Saha dizilişi (yakında)',
                  style: TextStyle(
                    color: PreMatchScreen._textMuted,
                    fontSize: 12,
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

class _TacticsRow extends StatelessWidget {
  const _TacticsRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _InfoTile(label: 'Takım taktiği', value: 'Yüksek Pres'),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _InfoTile(label: 'Bireysel rol', value: 'Oyun Kurucu'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PreMatchScreen._surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PreMatchScreen._textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: PreMatchScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionBar extends StatelessWidget {
  const _ConditionBar();

  @override
  Widget build(BuildContext context) {
    final condition = PlayerScope.of(context).condition;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kondisyon',
                style: TextStyle(
                  color: PreMatchScreen._textMuted,
                  fontSize: 12,
                ),
              ),
              Text(
                '$condition/100',
                style: const TextStyle(
                  color: PreMatchScreen._textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: condition / 100,
              minHeight: 6,
              backgroundColor: PreMatchScreen._surface1,
              color: PreMatchScreen._success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showStubMessage(context, 'Antrenörle konuşma yakında'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PreMatchScreen._textPrimary,
                side: const BorderSide(color: PreMatchScreen._border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 13),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Antrenörle konuş'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            height: 64,
            child: OutlinedButton(
              onPressed: () {
                // GEÇİCİ yer tutucu: MatchScreen artık bir MatchController
                // gerektiriyor. Gerçek GET /next → POST /start akışı bir
                // sonraki commit'te buraya bağlanacak; şimdilik derlemeyi
                // ayakta tutmak için sabit değerlerle kuruluyor.
                final controller = MatchController(
                  matchId: 'placeholder',
                  streamUrl: '/matches/placeholder/stream',
                  userSide: 'home',
                  teams: const MatchTeams(
                    home: TeamInfo(name: 'FK Yıldız'),
                    away: TeamInfo(name: 'Deniz SK'),
                  ),
                  staminaCatalog: const StaminaCatalog(
                    current: 100,
                    floor: 35,
                    ceiling: 100,
                    substitutionBonus: 6,
                  ),
                  directiveOptions:
                      const DirectiveOptions(effort: [], aggression: [], focus: []),
                );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MatchScreen(controller: controller),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: PreMatchScreen._textPrimary,
                side: const BorderSide(color: PreMatchScreen._border),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.play_arrow, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
