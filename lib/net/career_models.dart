import 'dart:ui' show Color;

/// `career_engine` yanıt gövdelerinin Dart karşılıkları (CONTRACT.md §5).
///
/// Yalnızca lig tablosunun ihtiyaç duyduğu nesneler burada: ortak `TeamRef` ve
/// `CompetitionRef` (§5.0), W2'nin puan durumu satırı, bir de kariyeri
/// çözümlemek için gereken C0/C2 kabukları. Sözleşme "FE tanımadığı alanı yok
/// sayar" dediği için (§5.0) burada olmayan alanlar sessizce atlanır.

/// §5.0 `TeamRef`.
class TeamRef {
  const TeamRef({
    required this.teamId,
    required this.name,
    required this.shortName,
    required this.colorPrimary,
    required this.colorSecondary,
  });

  factory TeamRef.fromJson(Map<String, dynamic> json) {
    return TeamRef(
      teamId: json['team_id'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String,
      colorPrimary: _parseHex(json['color_primary'] as String?),
      colorSecondary: _parseHex(json['color_secondary'] as String?),
    );
  }

  final String teamId;
  final String name;
  final String shortName;

  /// D17: kimlik rengi, BE'den ham `#RRGGBB` olarak gelir. Koyu zeminde
  /// okunabilirlik düzeltmesi ekranın kendi işi (§1.3).
  final Color colorPrimary;
  final Color colorSecondary;
}

/// §5.0 `CompetitionRef` + W1'in eklediği alanlar.
class CompetitionRef {
  const CompetitionRef({
    required this.competitionId,
    required this.kind,
    required this.name,
    this.country,
    this.tier,
    this.teamCount,
    this.userParticipates = false,
  });

  factory CompetitionRef.fromJson(Map<String, dynamic> json) {
    return CompetitionRef(
      competitionId: json['competition_id'] as String,
      kind: json['kind'] as String,
      name: json['name'] as String,
      country: json['country'] as String?,
      tier: json['tier'] as int?,
      teamCount: json['team_count'] as int?,
      userParticipates: json['user_participates'] as bool? ?? false,
    );
  }

  final String competitionId;

  /// 'league' | 'cup' | 'continental'.
  final String kind;
  final String name;
  final String? country;

  /// Piramit seviyesi (1 = en üst); lig dışında null.
  final int? tier;
  final int? teamCount;

  /// W1'e özel: kullanıcının takımı bu sezon bu müsabakada mı.
  final bool userParticipates;

  bool get isLeague => kind == 'league';
}

/// §5.3 W2'nin puan durumu satırı.
class StandingRow {
  const StandingRow({
    required this.rank,
    required this.team,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
    required this.isUserTeam,
  });

  factory StandingRow.fromJson(Map<String, dynamic> json) {
    return StandingRow(
      rank: json['rank'] as int,
      team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
      played: json['played'] as int,
      won: json['won'] as int,
      drawn: json['drawn'] as int,
      lost: json['lost'] as int,
      goalsFor: json['goals_for'] as int,
      goalsAgainst: json['goals_against'] as int,
      goalDifference: json['goal_difference'] as int,
      points: json['points'] as int,
      isUserTeam: json['is_user_team'] as bool? ?? false,
    );
  }

  final int rank;
  final TeamRef team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;
  final bool isUserTeam;
}

/// §5.3 W2 yanıtının tamamı.
class Standings {
  const Standings({
    required this.competition,
    required this.seasonId,
    required this.rows,
    required this.promotionSlots,
    required this.relegationSlots,
  });

  factory Standings.fromJson(Map<String, dynamic> json) {
    return Standings(
      competition:
          CompetitionRef.fromJson(json['competition'] as Map<String, dynamic>),
      seasonId: json['season_id'] as String,
      rows: (json['rows'] as List<dynamic>)
          .map((e) => StandingRow.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      promotionSlots: json['promotion_slots'] as int? ?? 0,
      relegationSlots: json['relegation_slots'] as int? ?? 0,
    );
  }

  final CompetitionRef competition;
  final String seasonId;
  final List<StandingRow> rows;

  /// Yükselen ve düşen takım sayısı — tablodaki ayraç çizgileri bundan gelir.
  final int promotionSlots;
  final int relegationSlots;
}

/// §5.1 C2'nin kariyer listesi satırı. Lig tablosu için gereken tek alan
/// `careerId`; kalanı kariyeri kullanıcıya tanıtmak içindir.
class CareerSummary {
  const CareerSummary({
    required this.careerId,
    required this.playerName,
    required this.seasonId,
    required this.currentDate,
    this.team,
    this.competition,
  });

  factory CareerSummary.fromJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>?;
    final competition = json['competition'] as Map<String, dynamic>?;
    return CareerSummary(
      careerId: json['career_id'] as String,
      playerName: json['player_name'] as String,
      seasonId: json['season_id'] as String,
      currentDate: json['current_date'] as String,
      team: team == null ? null : TeamRef.fromJson(team),
      competition:
          competition == null ? null : CompetitionRef.fromJson(competition),
    );
  }

  final String careerId;
  final String playerName;
  final String seasonId;
  final String currentDate;
  final TeamRef? team;
  final CompetitionRef? competition;
}

/// §5.1 C0'ın seçilebilir kulübü. C1 yalnızca `team.teamId`'yi ister.
class ClubOption {
  const ClubOption({
    required this.team,
    required this.competition,
    required this.strengthHint,
  });

  factory ClubOption.fromJson(Map<String, dynamic> json) {
    return ClubOption(
      team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
      competition:
          CompetitionRef.fromJson(json['competition'] as Map<String, dynamic>),
      strengthHint: json['strength_hint'] as String? ?? '',
    );
  }

  final TeamRef team;
  final CompetitionRef competition;

  /// 'zayıf' | 'orta' | 'güçlü'.
  final String strengthHint;
}

/// `#RRGGBB` → [Color]. Alan sözleşmede zorunlu ama gövde bozuksa ekranın
/// çökmesindense nötr bir gri döner — renk kimliktir, kritik veri değil.
Color _parseHex(String? hex) {
  if (hex == null) return const Color(0xFF6B7280);
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null || cleaned.length != 6) return const Color(0xFF6B7280);
  return Color(0xFF000000 | value);
}
