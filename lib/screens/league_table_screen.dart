import 'package:flutter/material.dart';

class _StandingRow {
  const _StandingRow({
    required this.rank,
    required this.team,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.points,
    this.isPlayerTeam = false,
  });

  final int rank;
  final String team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int points;
  final bool isPlayerTeam;
}

class LeagueTableScreen extends StatelessWidget {
  const LeagueTableScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _accentBg = Color(0x33228BFF);

  static const _standings = [
    _StandingRow(
      rank: 1,
      team: 'Deniz SK',
      played: 12,
      won: 9,
      drawn: 2,
      lost: 1,
      points: 29,
    ),
    _StandingRow(
      rank: 2,
      team: 'Anadolu FC',
      played: 12,
      won: 8,
      drawn: 2,
      lost: 2,
      points: 26,
    ),
    _StandingRow(
      rank: 3,
      team: 'FK Yıldız',
      played: 12,
      won: 7,
      drawn: 3,
      lost: 2,
      points: 24,
      isPlayerTeam: true,
    ),
    _StandingRow(
      rank: 4,
      team: 'Kartalspor',
      played: 12,
      won: 6,
      drawn: 3,
      lost: 3,
      points: 21,
    ),
    _StandingRow(
      rank: 5,
      team: 'Boğaz United',
      played: 12,
      won: 5,
      drawn: 4,
      lost: 3,
      points: 19,
    ),
    _StandingRow(
      rank: 6,
      team: 'Yeşilova',
      played: 12,
      won: 4,
      drawn: 4,
      lost: 4,
      points: 16,
    ),
    _StandingRow(
      rank: 7,
      team: 'Sahil 61',
      played: 12,
      won: 3,
      drawn: 3,
      lost: 6,
      points: 12,
    ),
    _StandingRow(
      rank: 8,
      team: 'Doğu AS',
      played: 12,
      won: 1,
      drawn: 3,
      lost: 8,
      points: 6,
    ),
  ];

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
                    children: [
                      const _HeaderSection(),
                      const _TableHeader(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _standings.length,
                          itemBuilder: (context, index) {
                            return _StandingTile(row: _standings[index]);
                          },
                        ),
                      ),
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
          bottom: BorderSide(color: LeagueTableScreen._border, width: 0.5),
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
              color: LeagueTableScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Lig Tablosu',
            style: TextStyle(
              color: LeagueTableScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LeagueTableScreen._border, width: 0.5),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#',
              style: TextStyle(
                color: LeagueTableScreen._textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Takım',
              style: TextStyle(
                color: LeagueTableScreen._textMuted,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              'O',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LeagueTableScreen._textMuted,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              'G',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LeagueTableScreen._textMuted,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              'B',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LeagueTableScreen._textMuted,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              'M',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LeagueTableScreen._textMuted,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              'P',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LeagueTableScreen._textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.row});

  final _StandingRow row;

  @override
  Widget build(BuildContext context) {
    final textColor = row.isPlayerTeam
        ? LeagueTableScreen._accent
        : LeagueTableScreen._textPrimary;
    final bg = row.isPlayerTeam ? LeagueTableScreen._accentBg : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: LeagueTableScreen._border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${row.rank}',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.team,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight:
                    row.isPlayerTeam ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          _StatCell(value: row.played, color: textColor),
          _StatCell(value: row.won, color: textColor),
          _StatCell(value: row.drawn, color: textColor),
          _StatCell(value: row.lost, color: textColor),
          SizedBox(
            width: 36,
            child: Text(
              '${row.points}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 13),
      ),
    );
  }
}
