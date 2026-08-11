import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';

/// Flame-based version of the shot prototype.
///
/// The player picks a destination first — including one behind them — and the
/// camera turns to face it. Nothing about the shot mechanic changes with the
/// direction, which is the point of the demo.
class FlameShotDemoScreen extends StatefulWidget {
  const FlameShotDemoScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _success = Color(0xFF3DDC97);

  @override
  State<FlameShotDemoScreen> createState() => _FlameShotDemoScreenState();
}

class _FlameShotDemoScreenState extends State<FlameShotDemoScreen> {
  late final ShotGame _game = ShotGame(onStateChanged: _onGameState);
  bool _rebuildScheduled = false;

  /// The game loop can report state from inside Flutter's build phase (a
  /// flight ending mid-frame, for instance), where setState throws. Coalesce
  /// every notification into a single post-frame rebuild instead.
  void _onGameState() {
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlameShotDemoScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FlameShotDemoScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FlameShotDemoScreen._border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _Header(onReset: _game.reset),
                      _DirectionPad(
                        facing: _game.facing,
                        ahead: _game.target,
                        onTurn: _game.turnTo,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GameWidget(game: _game),
                          ),
                        ),
                      ),
                      _Readout(game: _game),
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

class _Header extends StatelessWidget {
  const _Header({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FlameShotDemoScreen._border, width: 0.5),
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
              color: FlameShotDemoScreen._textMuted,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Şut Prototipi (Flame)',
            style: TextStyle(
              color: FlameShotDemoScreen._textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onReset,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Sıfırla',
            icon: const Icon(
              Icons.refresh,
              size: 20,
              color: FlameShotDemoScreen._textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compass rather than a destination list: the world is fixed, so the only
/// thing to choose is which way to look. The arrow you are facing is red.
class _DirectionPad extends StatelessWidget {
  const _DirectionPad({
    required this.facing,
    required this.ahead,
    required this.onTurn,
  });

  final Facing facing;
  final ShotTarget? ahead;
  final ValueChanged<Facing> onTurn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FlameShotDemoScreen._border, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Arrow(
            icon: Icons.arrow_upward,
            direction: Facing.forward,
            facing: facing,
            onTurn: onTurn,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Arrow(
                icon: Icons.arrow_back,
                direction: Facing.left,
                facing: facing,
                onTurn: onTurn,
              ),
              SizedBox(
                width: 120,
                child: Text(
                  ahead?.label ?? 'boşluk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: FlameShotDemoScreen._textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              _Arrow(
                icon: Icons.arrow_forward,
                direction: Facing.right,
                facing: facing,
                onTurn: onTurn,
              ),
            ],
          ),
          _Arrow(
            icon: Icons.arrow_downward,
            direction: Facing.back,
            facing: facing,
            onTurn: onTurn,
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.direction,
    required this.facing,
    required this.onTurn,
  });

  static const _facingColor = Color(0xFFE5484D);

  final IconData icon;
  final Facing direction;
  final Facing facing;
  final ValueChanged<Facing> onTurn;

  @override
  Widget build(BuildContext context) {
    final active = direction == facing;
    return IconButton(
      onPressed: () => onTurn(direction),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 22,
        color: active ? _facingColor : Colors.white,
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.game});

  final ShotGame game;

  String get _hint {
    switch (game.phase) {
      case ShotPhase.aim:
        return '1) Sürükle: sahada bir nokta seç, bırak';
      case ShotPhase.strike:
        return '2) Topa vur: merkez = güç, kenar = kavis, alt = yükselt';
      case ShotPhase.flight:
        return 'Uçuşta…';
      case ShotPhase.result:
        return 'Tekrar denemek için sahaya dokun';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: FlameShotDemoScreen._border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _hint,
            style: const TextStyle(
              color: FlameShotDemoScreen._textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                label: 'Yön',
                value: game.aimLateral,
                max: ShotWorld.maxAimLateral,
                signed: true,
              ),
              _Stat(
                label: 'Mesafe',
                value: game.aimDepth,
                max: ShotWorld.maxAimDepth,
              ),
              _Stat(label: 'Güç', value: game.power),
              _Stat(label: 'Yükseklik', value: game.loft),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.max = 1.0,
    this.signed = false,
  });

  final String label;
  final double value;

  /// Full-bar value. The number stays raw; only the bar is normalised, so a
  /// distance of 2.30 reads as 2.30 rather than pinning the bar at 1.
  final double max;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final magnitude = (value.abs() / max).clamp(0.0, 1.0);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlameShotDemoScreen._textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  signed && value > 0
                      ? '+${value.toStringAsFixed(2)}'
                      : value.toStringAsFixed(2),
                  style: const TextStyle(
                    color: FlameShotDemoScreen._textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: magnitude,
                minHeight: 4,
                backgroundColor: FlameShotDemoScreen._surface1,
                color: magnitude > 0.75
                    ? FlameShotDemoScreen._success
                    : FlameShotDemoScreen._accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
