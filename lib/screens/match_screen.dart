import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project_srpg/game/match_feed.dart';
import 'package:project_srpg/screens/flame_shot_demo_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    this.feed = const ScriptedMatchFeed(),
    this.home = 'FK Yıldız',
    this.away = 'Deniz SK',
  });

  final MatchFeed feed;
  final String home;
  final String away;

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _success = Color(0xFF3DDC97);
  static const _accent = Color(0xFF1E6FD9);
  static const _accentBg = Color(0x33228BFF);
  static const _danger = Color(0xFFE85D5D);
  static const _dangerBg = Color(0x33E85D5D);

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final List<MatchEvent> _events = [];
  final ScrollController _scroll = ScrollController();

  StreamSubscription<MatchEvent>? _sub;
  int _minute = 0;
  int _homeGoals = 0;
  int _awayGoals = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.feed.events().listen(_onEvent);
  }

  void _onEvent(MatchEvent event) {
    if (!mounted) return;
    setState(() {
      _events.add(event);
      _minute = event.minute;
      if (event.isGoal) {
        if (event.side == MatchSide.home) {
          _homeGoals++;
        } else if (event.side == MatchSide.away) {
          _awayGoals++;
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        24;

    return Scaffold(
      backgroundColor: MatchScreen._surface1,
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
                    color: MatchScreen._surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MatchScreen._border, width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        _MatchBar(
                          home: widget.home,
                          away: widget.away,
                          homeGoals: _homeGoals,
                          awayGoals: _awayGoals,
                          minute: _minute,
                        ),
                        const _PhaseStrip(),
                        Expanded(
                          child: _CommentaryFeed(
                            events: _events,
                            controller: _scroll,
                          ),
                        ),
                        const _ActionBar(),
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
  const _MatchBar({
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.minute,
  });

  final String home;
  final String away;
  final int homeGoals;
  final int awayGoals;
  final int minute;

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
                    tint: MatchScreen._accent,
                    tintBg: MatchScreen._accentBg,
                    child: Text(
                      home,
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
                _ScoreChip(
                  minWidth: 30,
                  child: Text(
                    '$homeGoals',
                    style: const TextStyle(
                      color: MatchScreen._textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ScoreChip(
                  minWidth: 30,
                  child: Text(
                    '$awayGoals',
                    style: const TextStyle(
                      color: MatchScreen._textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ScoreChip(
                    tint: MatchScreen._danger,
                    tintBg: MatchScreen._dangerBg,
                    child: Text(
                      away,
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FlameShotDemoScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: MatchScreen._textPrimary,
                backgroundColor: MatchScreen._surface1,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_run_outlined, size: 16),
                  const SizedBox(height: 2),
                  Text(
                    "$minute'",
                    style: const TextStyle(
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

/// Skorbordun altındaki ince, ortalanmış maç durumu şeridi
/// ("Kick Off", "Devre arası" gibi ilk/nötr olayı vurgular).
class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: MatchScreen._surface1,
        border: Border(
          bottom: BorderSide(color: MatchScreen._border, width: 0.5),
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Kick Off',
        style: TextStyle(
          color: MatchScreen._textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.child,
    this.minWidth,
    this.tint,
    this.tintBg,
  });

  final Widget child;
  final double? minWidth;
  final Color? tint;
  final Color? tintBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tintBg ?? MatchScreen._surface1,
        borderRadius: BorderRadius.circular(8),
        border: tint == null ? null : Border.all(color: tint!, width: 0.5),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Kayan maç yorumu akışı. Ekranın boş sahne yer tutucusunun yerini alır.
class _CommentaryFeed extends StatelessWidget {
  const _CommentaryFeed({required this.events, required this.controller});

  final List<MatchEvent> events;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'Maç başlıyor…',
          style: TextStyle(color: MatchScreen._textMuted, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _EventCard(event: events[index]),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final side = event.side;
    final isNeutral = side == MatchSide.neutral;
    final tint = side == MatchSide.home
        ? MatchScreen._accent
        : side == MatchSide.away
            ? MatchScreen._danger
            : MatchScreen._textMuted;
    final tintBg = side == MatchSide.home
        ? MatchScreen._accentBg
        : side == MatchSide.away
            ? MatchScreen._dangerBg
            : MatchScreen._surface1;
    final alignment = side == MatchSide.home
        ? Alignment.centerLeft
        : side == MatchSide.away
            ? Alignment.centerRight
            : Alignment.center;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tintBg,
        borderRadius: BorderRadius.circular(8),
        border: event.isGoal ? Border.all(color: tint, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: MatchScreen._surface1,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${event.minute}'",
              style: const TextStyle(
                color: MatchScreen._textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (event.icon != null) ...[
            Icon(event.icon, size: 14, color: tint),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              event.text,
              style: TextStyle(
                color: event.isGoal ? tint : MatchScreen._textPrimary,
                fontSize: event.isGoal ? 13 : 12,
                fontWeight: event.isGoal ? FontWeight.w700 : FontWeight.w400,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isNeutral
              ? double.infinity
              : MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: isNeutral ? SizedBox(width: double.infinity, child: card) : card,
      ),
    );
  }
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
