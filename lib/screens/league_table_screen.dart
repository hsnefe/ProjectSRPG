import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/net/career_session.dart';

/// Lig tablosu. Veri `career_engine`'den gelir: W1 hangi liglerin olduğunu,
/// W2 seçili ligin puan durumunu verir (CONTRACT.md §5.3). Sıra, averaj ve
/// "kullanıcının takımı mı" BE'de türetilir; buradaki iş yalnızca çizim.
class LeagueTableScreen extends StatefulWidget {
  const LeagueTableScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır
  /// ve paylaşılan [CareerSession.instance] kullanılır.
  final CareerSession? session;

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _accentBg = Color(0x33228BFF);
  static const _promotion = Color(0xFF2E9E6B);
  static const _relegation = Color(0xFFC2413B);

  @override
  State<LeagueTableScreen> createState() => _LeagueTableScreenState();
}

class _LeagueTableScreenState extends State<LeagueTableScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;

  late Future<List<CompetitionRef>> _leagues;
  String? _selectedCompetitionId;
  Future<Standings>? _standings;

  @override
  void initState() {
    super.initState();
    _leagues = _loadLeagues();
  }

  /// W1'in listesinden yalnızca ligler; kupada puan durumu yoktur (§5.3, BE
  /// `409 no_standings` döner) ve v1'de uluslararası müsabaka kapalıdır.
  Future<List<CompetitionRef>> _loadLeagues() async {
    final careerId = await _session.resolve();
    final competitions = await _session.client.competitions(careerId);
    final leagues =
        competitions.where((c) => c.isLeague).toList(growable: false)
          ..sort((a, b) => (a.tier ?? 99).compareTo(b.tier ?? 99));
    if (leagues.isEmpty) {
      throw StateError('Kariyerde lig bulunamadı');
    }
    // Kullanıcının kendi ligi açılışta seçili gelir; D21 gereği bu alt
    // kademedir, üst kademe tabloya sekmeyle geçilerek görülür.
    final initial = leagues.firstWhere(
      (c) => c.userParticipates,
      orElse: () => leagues.first,
    );
    _select(initial.competitionId, careerId: careerId);
    return leagues;
  }

  void _select(String competitionId, {String? careerId}) {
    _selectedCompetitionId = competitionId;
    _standings = _loadStandings(competitionId, careerId: careerId);
  }

  Future<Standings> _loadStandings(String competitionId,
      {String? careerId}) async {
    final id = careerId ?? await _session.resolve();
    return _session.client.standings(id, competitionId: competitionId);
  }

  void _onSelect(String competitionId) {
    if (competitionId == _selectedCompetitionId) return;
    setState(() => _select(competitionId));
  }

  void _retry() {
    setState(() {
      _selectedCompetitionId = null;
      _standings = null;
      _leagues = _loadLeagues();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LeagueTableScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: LeagueTableScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: LeagueTableScreen._border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FutureBuilder<List<CompetitionRef>>(
                    future: _leagues,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          _HeaderSection(
                            title: _titleFor(snapshot.data),
                          ),
                          if (snapshot.hasData && snapshot.data!.length > 1)
                            _LeagueTabs(
                              leagues: snapshot.data!,
                              selectedId: _selectedCompetitionId,
                              onSelect: _onSelect,
                            ),
                          Expanded(child: _body(snapshot)),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Başlık artık veriden gelir: seçili ligin adı, henüz yüklenmediyse genel
  /// etiket.
  String _titleFor(List<CompetitionRef>? leagues) {
    if (leagues == null || _selectedCompetitionId == null) return 'Lig Tablosu';
    final selected = leagues.firstWhere(
      (c) => c.competitionId == _selectedCompetitionId,
      orElse: () => leagues.first,
    );
    return selected.name;
  }

  Widget _body(AsyncSnapshot<List<CompetitionRef>> leagueSnapshot) {
    if (leagueSnapshot.connectionState == ConnectionState.waiting) {
      return const _LoadingState();
    }
    if (leagueSnapshot.hasError) {
      return _ErrorState(error: leagueSnapshot.error!, onRetry: _retry);
    }
    return FutureBuilder<Standings>(
      future: _standings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _standings == null) {
          return const _LoadingState();
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error!, onRetry: _retry);
        }
        final standings = snapshot.data!;
        if (standings.rows.isEmpty) {
          return const _EmptyState();
        }
        return Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: standings.rows.length,
                itemBuilder: (context, index) {
                  return _StandingTile(
                    row: standings.rows[index],
                    zone: _zoneOf(index, standings),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Terfi/düşme hattı W2'nin `promotion_slots` / `relegation_slots`
  /// alanlarından okunur — kaç takımın çıktığı ligin kuralıdır, sabit değil.
  _Zone _zoneOf(int index, Standings standings) {
    if (index < standings.promotionSlots) return _Zone.promotion;
    if (index >= standings.rows.length - standings.relegationSlots) {
      return _Zone.relegation;
    }
    return _Zone.none;
  }
}

enum _Zone { promotion, relegation, none }

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.title});

  final String title;

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
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LeagueTableScreen._textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Piramitteki ligler arasında geçiş. Tek lig varsa hiç çizilmez.
class _LeagueTabs extends StatelessWidget {
  const _LeagueTabs({
    required this.leagues,
    required this.selectedId,
    required this.onSelect,
  });

  final List<CompetitionRef> leagues;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LeagueTableScreen._border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          for (final league in leagues)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _LeaguePill(
                league: league,
                selected: league.competitionId == selectedId,
                onTap: () => onSelect(league.competitionId),
              ),
            ),
        ],
      ),
    );
  }
}

class _LeaguePill extends StatelessWidget {
  const _LeaguePill({
    required this.league,
    required this.selected,
    required this.onTap,
  });

  final CompetitionRef league;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? LeagueTableScreen._accentBg : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? LeagueTableScreen._accent
                : LeagueTableScreen._border,
            width: 0.5,
          ),
        ),
        child: Text(
          league.name,
          style: TextStyle(
            color: selected
                ? LeagueTableScreen._accent
                : LeagueTableScreen._textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
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
  const _StandingTile({required this.row, required this.zone});

  final StandingRow row;
  final _Zone zone;

  @override
  Widget build(BuildContext context) {
    final textColor = row.isUserTeam
        ? LeagueTableScreen._accent
        : LeagueTableScreen._textPrimary;
    final bg = row.isUserTeam ? LeagueTableScreen._accentBg : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          left: BorderSide(color: _zoneColor, width: 2),
          bottom: const BorderSide(
            color: LeagueTableScreen._border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${row.rank}',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // D17: takımın kimlik renkleri BE'den ham gelir; rozet ikisini de
          // gösterir, ekranın kendi tonlarıyla karışmasın diye küçük tutulur.
          _TeamDot(team: row.team),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.team.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: row.isUserTeam ? FontWeight.w500 : FontWeight.w400,
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

  Color get _zoneColor {
    switch (zone) {
      case _Zone.promotion:
        return LeagueTableScreen._promotion;
      case _Zone.relegation:
        return LeagueTableScreen._relegation;
      case _Zone.none:
        return Colors.transparent;
    }
  }
}

class _TeamDot extends StatelessWidget {
  const _TeamDot({required this.team});

  final TeamRef team;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: team.colorPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: team.colorSecondary, width: 2),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: LeagueTableScreen._textMuted,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Bu ligde henüz oynanmış maç yok.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LeagueTableScreen._textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Lig verisi alınamadı.',
              style: TextStyle(
                color: LeagueTableScreen._textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LeagueTableScreen._textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: LeagueTableScreen._accent,
              ),
              child: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }

  /// Bağlantı hatasında sunucunun kapalı olması en olası sebep; kullanıcıya
  /// ham istisna yerine ne yapacağını söyleyen bir satır gösterilir.
  String get _detail {
    final e = error;
    if (e is CareerApiException) {
      return e.message ?? 'Sunucu ${e.statusCode} döndü.';
    }
    return 'career_engine çalışıyor mu? (127.0.0.1:8001)';
  }
}
