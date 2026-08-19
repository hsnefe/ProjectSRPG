import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/contract_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/pill_dropdown.dart';
import 'package:project_srpg/widgets/value_scatter_chart.dart';

/// P2'nin `competition_kind` üç değeri (API katmanı `league→lig`,
/// `cup→kupa`, `continental→uluslararasi` eşlemesini zaten yapar, §5.2).
enum _Competition { lig, kupa, uluslararasi }

_Competition? _competitionOf(String kind) => switch (kind) {
      'lig' => _Competition.lig,
      'kupa' => _Competition.kupa,
      'uluslararasi' => _Competition.uluslararasi,
      _ => null,
    };

/// Sezon filtresinin seçenekleri — P2 yanıtındaki satırlardan **türetilir**
/// (§1.3): hangi sezonların var olduğunu FE uydurmaz. [seasonId] null ise
/// bütün sezonlar eşleşir; 'Tümü' ayrı bir durum değil, sadece bu eksende
/// filtrelememek demek.
class _SeasonFilter {
  const _SeasonFilter(this.label, this.seasonId);

  final String label;
  final String? seasonId;

  bool matches(_SeasonStats row) => seasonId == null || row.seasonId == seasonId;

  /// Satırlardaki sezonları en yeniden eskiye sıralar; en yenisi "Bu sezon"
  /// etiketini alır (P2 zaten güncel sezonu ilk sırada döndürmez, sıralama
  /// burada yapılır — id'ler 'YY/YY' biçiminde olduğu için string sıralaması
  /// yeterli).
  static List<_SeasonFilter> optionsFrom(Iterable<_SeasonStats> rows) {
    final seasons = rows.map((r) => r.seasonId).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      const _SeasonFilter('Tümü', null),
      for (var i = 0; i < seasons.length; i++)
        _SeasonFilter(i == 0 ? 'Bu sezon' : '${seasons[i]} Sezonu', seasons[i]),
    ];
  }
}

/// Müsabaka filtresinin seçenekleri. [competition] null ise hepsi eşleşir.
enum _CompetitionFilter {
  all('Tümü', null),
  lig('Lig', _Competition.lig),
  kupa('Kupa', _Competition.kupa),
  uluslararasi('Uluslararası', _Competition.uluslararasi);

  const _CompetitionFilter(this.label, this.competition);

  final String label;
  final _Competition? competition;

  bool matches(_SeasonStats row) =>
      competition == null || row.competition == competition;
}

/// Tek bir (sezon, müsabaka) kesiti — P2'nin `rows[]` satırı, ekranın
/// kullandığı şekle çevrilmiş.
class _SeasonStats {
  const _SeasonStats({
    required this.seasonId,
    required this.competition,
    required this.appearances,
    required this.starts,
    required this.goals,
    required this.assists,
    required this.minutes,
    required this.passesCompleted,
    required this.passesAttempted,
  });

  factory _SeasonStats.from(api.SeasonStatRow row) => _SeasonStats(
        seasonId: row.seasonId,
        competition: _competitionOf(row.competitionKind) ?? _Competition.lig,
        appearances: row.appearances,
        starts: row.starts,
        goals: row.goals,
        assists: row.assists,
        minutes: row.minutes,
        passesCompleted: row.passesCompleted,
        passesAttempted: row.passesAttempted,
      );

  final String seasonId;
  final _Competition competition;
  final int appearances;
  final int starts;
  final int goals;
  final int assists;
  final int minutes;
  final int passesCompleted;
  final int passesAttempted;
}

/// Filtre sonucunda tabloda gösterilen tek satır.
class _StatTotals {
  const _StatTotals({
    this.appearances = 0,
    this.starts = 0,
    this.goals = 0,
    this.assists = 0,
    this.minutes = 0,
    this.passesCompleted = 0,
    this.passesAttempted = 0,
  });

  /// Eşleşen bütün kesitleri toplar. Hiç eşleşme yoksa sıfırlı satır döner.
  factory _StatTotals.of(
    Iterable<_SeasonStats> rows,
    _SeasonFilter season,
    _CompetitionFilter competition,
  ) {
    var total = const _StatTotals();
    for (final row in rows) {
      if (season.matches(row) && competition.matches(row)) {
        total = total._plus(row);
      }
    }
    return total;
  }

  final int appearances;
  final int starts;
  final int goals;
  final int assists;
  final int minutes;
  final int passesCompleted;
  final int passesAttempted;

  _StatTotals _plus(_SeasonStats row) => _StatTotals(
        appearances: appearances + row.appearances,
        starts: starts + row.starts,
        goals: goals + row.goals,
        assists: assists + row.assists,
        minutes: minutes + row.minutes,
        passesCompleted: passesCompleted + row.passesCompleted,
        passesAttempted: passesAttempted + row.passesAttempted,
      );

  /// '609/698'
  String get passLabel => '$passesCompleted/$passesAttempted';

  /// Toplanmış pay ve paydadan hesaplanır; alt kesitlerin yüzdeleri
  /// ortalanmaz — 'Tümü' seçildiğinde doğru sonuç ancak böyle çıkar.
  String get passAccuracyLabel {
    if (passesAttempted == 0) return 'Başarılı pas: —';
    final percent = (passesCompleted * 100 / passesAttempted).round();
    return 'Başarılı pas: %$percent';
  }
}

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  late Future<api.PlayerStats> _statsFuture;

  _SeasonFilter? _season;
  _CompetitionFilter _competition = _CompetitionFilter.all;

  @override
  void initState() {
    super.initState();
    _statsFuture = _load();
  }

  /// P2 · `GET /careers/{cid}/player/stats`.
  Future<api.PlayerStats> _load() async {
    final careerId = await _session.resolve();
    return _session.client.playerStats(careerId);
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);

    return Scaffold(
      backgroundColor: PlayerProfileScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PlayerProfileScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PlayerProfileScreen._border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      const _HeaderSection(),
                      _IdentityRow(
                        age: player.age,
                        name: player.name,
                        teamName: player.teamName,
                      ),
                      Expanded(
                        child: FutureBuilder<api.PlayerStats>(
                          future: _statsFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData && !snapshot.hasError) {
                              return const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: PlayerProfileScreen._textMuted,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'İstatistikler alınamadı.',
                                    style: const TextStyle(
                                      color: PlayerProfileScreen._textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final stats = snapshot.data!;
                            final rows = stats.rows
                                .map(_SeasonStats.from)
                                .toList(growable: false);
                            final seasonOptions =
                                _SeasonFilter.optionsFrom(rows);
                            // Kullanıcı henüz bir sezon seçmediyse varsayılan
                            // "Bu sezon" (varsa) — 'Tümü' ile karıştırılmasın
                            // diye null burada ayrı ele alınıyor.
                            final chosen = _season;
                            final season = chosen == null
                                ? (seasonOptions.length > 1
                                    ? seasonOptions[1]
                                    : seasonOptions.first)
                                : seasonOptions.firstWhere(
                                    (o) => o.seasonId == chosen.seasonId,
                                    orElse: () => seasonOptions.first,
                                  );
                            final totals =
                                _StatTotals.of(rows, season, _competition);
                            final points = stats.valueHistory
                                .map((p) => ValuePoint(
                                      label: _monthLabel(p.measuredOn),
                                      value: p.value.toDouble(),
                                    ))
                                .toList(growable: false);

                            return ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 20),
                              children: [
                                _FilterRow(
                                  season: season,
                                  seasonOptions: seasonOptions,
                                  competition: _competition,
                                  onSeasonChanged: (value) =>
                                      setState(() => _season = value),
                                  onCompetitionChanged: (value) =>
                                      setState(() => _competition = value),
                                ),
                                const SizedBox(height: 10),
                                _StatsPanel(totals: totals),
                                if (points.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _ValuePanel(points: points),
                                ],
                              ],
                            );
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

const _monthAbbrevs = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];

/// '2024-01-15' → 'Oca 24' — §1.3: BE `measured_on` tarihini verir, kısa
/// etiketi ekran türetir.
String _monthLabel(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  final year2 = (date.year % 100).toString().padLeft(2, '0');
  return '${_monthAbbrevs[date.month - 1]} $year2';
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PlayerProfileScreen._border, width: 0.5),
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
              color: PlayerProfileScreen._textMuted,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ContractScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: PlayerProfileScreen._textPrimary,
              side: const BorderSide(color: PlayerProfileScreen._border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sözleşme'),
          ),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.age,
    required this.name,
    required this.teamName,
  });

  final int age;
  final String name;
  final String teamName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PlayerProfileScreen._border, width: 0.5),
        ),
      ),
      // Üç eşit Expanded, ismi gerçekten ortalayan şey bu; Spacer tabanlı
      // düzen takım adı uzadıkça kayardı.
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Yaş: $age',
              style: const TextStyle(
                color: PlayerProfileScreen._textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PlayerProfileScreen._textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              teamName,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PlayerProfileScreen._textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.season,
    required this.seasonOptions,
    required this.competition,
    required this.onSeasonChanged,
    required this.onCompetitionChanged,
  });

  final _SeasonFilter season;
  final List<_SeasonFilter> seasonOptions;
  final _CompetitionFilter competition;
  final ValueChanged<_SeasonFilter> onSeasonChanged;
  final ValueChanged<_CompetitionFilter> onCompetitionChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PillDropdown<_SeasonFilter>(
          key: const ValueKey('seasonFilter'),
          value: season,
          items: seasonOptions,
          labelOf: (value) => value.label,
          onChanged: onSeasonChanged,
        ),
        PillDropdown<_CompetitionFilter>(
          key: const ValueKey('competitionFilter'),
          value: competition,
          items: _CompetitionFilter.values,
          labelOf: (value) => value.label,
          onChanged: onCompetitionChanged,
        ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.totals});

  final _StatTotals totals;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PlayerProfileScreen._surface1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _StatRow(label: 'Maç', value: '${totals.appearances}'),
          _StatRow(label: 'İlk 11', value: '${totals.starts}'),
          _StatRow(label: 'Gol', value: '${totals.goals}'),
          _StatRow(label: 'Asist', value: '${totals.assists}'),
          _StatRow(label: 'Oynanan dakika', value: '${totals.minutes}'),
          _StatRow(
            label: 'Pas',
            value: totals.passLabel,
            trailing: totals.passAccuracyLabel,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.trailing,
    this.isLast = false,
  });

  final String label;
  final String value;

  /// Aynı satırda, değerin solunda duran ikincil metin (pas isabeti gibi).
  final String? trailing;

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: PlayerProfileScreen._border,
                  width: 0.5,
                ),
              ),
      ),
      // Yüzde önce, kesir sonra: böylece her satırın sağ kenarı aynı sütunda
      // hizalı kalıyor. Boşluğu ikincil metin yutuyor; 'Tümü' filtresindeki
      // dört haneli pas sayıları dar ekranda satırı taşırmasın diye.
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PlayerProfileScreen._textMuted,
              fontSize: 12,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                trailing!,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PlayerProfileScreen._textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ] else
            const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: PlayerProfileScreen._textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePanel extends StatelessWidget {
  const _ValuePanel({required this.points});

  final List<ValuePoint> points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PlayerProfileScreen._surface1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DEĞER TABLOSU',
              style: TextStyle(
                color: PlayerProfileScreen._accent.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ValueScatterChart(
              points: points,
              accentColor: PlayerProfileScreen._accent,
            ),
            const SizedBox(height: 10),
            const Text(
              'Kariyer boyunca piyasa değeri',
              style: TextStyle(
                color: PlayerProfileScreen._textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
