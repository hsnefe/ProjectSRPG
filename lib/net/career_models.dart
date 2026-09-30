import 'dart:ui' show Color;
import 'package:project_srpg/net/money.dart';

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
    this.playerAge,
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
      playerAge: json['player_age'] as int?,
      team: team == null ? null : TeamRef.fromJson(team),
      competition:
          competition == null ? null : CompetitionRef.fromJson(competition),
    );
  }

  final String careerId;
  final String playerName;
  final String seasonId;
  final String currentDate;

  /// Nullable: motorun eski/ara bir sürümü bu alanı hiç göndermeyebilir,
  /// liste yine de çizilsin diye kart bunu koşullu gösterir.
  final int? playerAge;
  final TeamRef? team;
  final CompetitionRef? competition;
}

/// §5.1 C0 — yeni kariyer formunun tüm seçenekleri tek çağrıda.
///
/// Sihirbaz hiçbir sayıyı kendi bilmez: sınav ölçeği ve başlangıç değerleri de
/// (taban yetenek, rol bonusu, para/kondisyon, ilişki skorları) buradan gelir,
/// böylece motorun katalogları değişince ekran yalan söylemez.
class CareerOptions {
  const CareerOptions({
    required this.nationalities,
    required this.positions,
    required this.targetTeams,
    required this.skillExams,
    required this.startingValues,
  });

  factory CareerOptions.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        ((json[key] as List<dynamic>?) ?? const [])
            .map((e) => parse(e as Map<String, dynamic>))
            .toList(growable: false);

    return CareerOptions(
      nationalities: list('nationalities', NationalityOption.fromJson),
      positions: list('positions', PositionOption.fromJson),
      targetTeams: list('target_teams', TargetTeamOption.fromJson),
      skillExams: list('skill_exams', SkillExamOption.fromJson),
      startingValues: StartingValues.fromJson(
        (json['starting_values'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  final List<NationalityOption> nationalities;
  final List<PositionOption> positions;

  /// Hedef ("hayalindeki") kulüpler. Oynanacak kulüp burada seçilmez —
  /// D21/§3 uyarınca milliyetin en alt liginden atanır.
  final List<TargetTeamOption> targetTeams;

  /// C5'te girilecek sınavların katalogu (Şut / Pas / Müdahale).
  final List<SkillExamOption> skillExams;

  final StartingValues startingValues;
}

/// §5.1 C0'ın milliyet kalemi. C1'e giden değer [countryCode].
class NationalityOption {
  const NationalityOption({
    required this.countryCode,
    required this.name,
    required this.nationality,
  });

  factory NationalityOption.fromJson(Map<String, dynamic> json) {
    return NationalityOption(
      countryCode: json['country_code'] as String,
      name: json['name'] as String,
      nationality: json['nationality'] as String,
    );
  }

  final String countryCode;

  /// Ülke adı ('Türkiye').
  final String name;

  /// FE'ye gösterilen sıfat ('Türk') — anahtar değil.
  final String nationality;
}

/// §5.1 C0'ın pozisyonu, kendi rolleriyle. Roller pozisyona göre değişir ve
/// C1 uyumluluğu doğrular — bu yüzden rol listesi pozisyonun içinde gelir.
class PositionOption {
  const PositionOption({required this.position, required this.roles});

  factory PositionOption.fromJson(Map<String, dynamic> json) {
    return PositionOption(
      position: json['position'] as String,
      roles: ((json['roles'] as List<dynamic>?) ?? const [])
          .map((e) => RoleOption.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String position;
  final List<RoleOption> roles;
}

/// §5.1 C0'ın rolü. C1'e giden değer [roleId].
class RoleOption {
  const RoleOption({
    required this.roleId,
    required this.name,
    required this.group,
    required this.attributes,
  });

  factory RoleOption.fromJson(Map<String, dynamic> json) {
    return RoleOption(
      roleId: json['role_id'] as String,
      name: json['name'] as String,
      group: json['group'] as String,
      attributes: ((json['attributes'] as List<dynamic>?) ?? const [])
          .cast<String>()
          .toList(growable: false),
    );
  }

  final String roleId;
  final String name;

  /// Saha bölgesi etiketi ('DC', 'DL/DR', 'MC'…).
  final String group;

  /// Rolün uzmanlaştığı iki yetenek yuvası; aynı anahtar iki kez geçebilir
  /// (o zaman rol bonusu o yeteneğe iki kat biner).
  final List<String> attributes;
}

/// §5.1 C0'ın hedef kulüp kalemi. C1 yalnızca `team.teamId`'yi ister.
class TargetTeamOption {
  const TargetTeamOption({
    required this.team,
    required this.competition,
    required this.strengthHint,
  });

  factory TargetTeamOption.fromJson(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>?;
    return TargetTeamOption(
      team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
      // Yalnızca lig kayıtlarından doldurulur; hiçbir lige yazılmamış kulüpte
      // null gelir (kupa kayıtları hesaba katılmaz).
      competition:
          competition == null ? null : CompetitionRef.fromJson(competition),
      strengthHint: json['strength_hint'] as String? ?? '',
    );
  }

  final TeamRef team;
  final CompetitionRef? competition;

  /// 'zayıf' | 'orta' | 'güçlü'.
  final String strengthHint;
}

/// §5.1 C0'ın yetenek sınavı kalemi (`catalog/skill_exams.py`).
///
/// Puanlama tek formül: `level * pointsPerLevel`, niteliğin **mevcut** değerine
/// eklenir ve [maxValue]'da kesilir. Sihirbazın "20 → 25" önizlemesi de bunu
/// kullanır, ayrı bir sabit tutmaz.
class SkillExamOption {
  const SkillExamOption({
    required this.examId,
    required this.title,
    required this.description,
    required this.attributeKey,
    required this.pointsPerLevel,
    required this.minLevel,
    required this.maxLevel,
    required this.maxValue,
  });

  factory SkillExamOption.fromJson(Map<String, dynamic> json) {
    return SkillExamOption(
      examId: json['exam_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      attributeKey: json['attribute_key'] as String,
      pointsPerLevel: (json['points_per_level'] as num).toDouble(),
      minLevel: (json['min_level'] as num).toInt(),
      maxLevel: (json['max_level'] as num).toInt(),
      maxValue: (json['max_value'] as num).toDouble(),
    );
  }

  /// C5'e giden değer.
  final String examId;
  final String title;
  final String description;

  /// Sınavın yükselttiği nitelik anahtarı ('shooting' | 'passing' | 'tackling').
  final String attributeKey;
  final double pointsPerLevel;
  final int minLevel;
  final int maxLevel;

  /// Sınavın niteliği çıkarabileceği tavan — player_attribute'un 0-100
  /// sınırından ayrı, sınava özgü bir kesme noktası.
  final double maxValue;

  /// [level] notunun bu sınavda ne kadar puan ettiği (tavan uygulanmadan).
  double awardFor(int level) => level * pointsPerLevel;
}

/// §5.1 C0'ın `starting_values` bloğu — yeni kariyerin açılış değerleri.
class StartingValues {
  const StartingValues({
    required this.money,
    required this.condition,
    required this.relationships,
    required this.baseSkillValue,
    required this.roleBonusPerSlot,
  });

  factory StartingValues.fromJson(Map<String, dynamic> json) {
    return StartingValues(
      money: (json['money'] as num?)?.toInt() ?? 0,
      condition: (json['condition'] as num?)?.toInt() ?? 0,
      relationships:
          ((json['relationships'] as Map<String, dynamic>?) ?? const {}).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      baseSkillValue: (json['base_skill_value'] as num?)?.toDouble() ?? 0,
      roleBonusPerSlot: (json['role_bonus_per_slot'] as num?)?.toDouble() ?? 0,
    );
  }

  final int money;
  final int condition;

  /// İlişki türü → başlangıç skoru ('coach': 70, 'fans': 40 …).
  final Map<String, int> relationships;

  /// Her saha yeteneğinin rol bonusundan önceki taban değeri.
  final double baseSkillValue;

  /// Rolün harcadığı her yuvanın o yeteneğe eklediği puan.
  final double roleBonusPerSlot;

  /// [roleAttributes] iki yuvalı bir rolün anahtar listesi; aynı anahtar iki
  /// kez geçerse bonus o yeteneğe iki kat biner.
  double skillFor(String attributeKey, List<String> roleAttributes) {
    final slots = roleAttributes.where((a) => a == attributeKey).length;
    return baseSkillValue + slots * roleBonusPerSlot;
  }
}

/// §5.1 C5 yanıtının `results[]` satırı — bir sınavın niteliğe yansıması.
class SkillExamOutcome {
  const SkillExamOutcome({
    required this.examId,
    required this.level,
    required this.attributeKey,
    required this.before,
    required this.after,
    required this.applied,
  });

  factory SkillExamOutcome.fromJson(Map<String, dynamic> json) {
    return SkillExamOutcome(
      examId: json['exam_id'] as String,
      level: (json['level'] as num).toInt(),
      attributeKey: json['attribute_key'] as String,
      before: (json['before'] as num).toDouble(),
      after: (json['after'] as num).toDouble(),
      applied: (json['applied'] as num).toDouble(),
    );
  }

  final String examId;
  final int level;
  final String attributeKey;
  final double before;
  final double after;

  /// Tavana takıldıysa ham kazançtan küçük olabilir.
  final double applied;
}

/// §5.0 `CareerState` — durumu değiştiren her yanıtta bulunur (D28, INV-18).
class CareerState {
  const CareerState({
    required this.currentDate,
    required this.seasonId,
    this.seasonPhase,
    required this.money,
    required this.condition,
    required this.dayBudget,
  });

  factory CareerState.fromJson(Map<String, dynamic> json) {
    return CareerState(
      currentDate: json['current_date'] as String,
      seasonId: json['season_id'] as String,
      seasonPhase: json['season_phase'] as String?,
      money: json['money'] as int,
      condition: json['condition'] as int,
      dayBudget: (json['day_budget'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }

  final String currentDate;
  final String seasonId;

  /// §11.2/D45 · `pre_season` | `first_half` | `winter_break` |
  /// `second_half` | `season_end` | `summer_transfer_window`.
  ///
  /// Türetilmiş değer, saklanmıyor — niteliğin `level`'ıyla aynı desen (D43).
  /// Nullable: alanı göndermeyen bir career_engine sürümüne karşı ekran
  /// çökmemeli, fazı bilmiyoruz demek yeterli.
  final String? seasonPhase;

  /// Transfer penceresi açık mı (§11.7). Yalnızca iki tatil fazında açık.
  bool get transferWindowOpen =>
      seasonPhase == 'winter_break' || seasonPhase == 'summer_transfer_window';

  /// Sezon bitti ve devir bekliyor (§11.5). `advance` bu fazda
  /// `409 season_rollover_required` döner.
  bool get rolloverDue => seasonPhase == 'season_end';

  final int money;

  /// Bugünkü değer, 0-100. D15: bu, `player_attribute['condition']` (tavan)
  /// ile aynı kavramın farklı bir yüzüdür — bkz. [PlayerAttribute].
  final int condition;

  /// D41 · anahtarlar ⟦AÇIK-5⟧ — bugün yalnızca `time`/`energy`.
  final Map<String, double> dayBudget;

  /// '48.200 ₭' — biçimlendirme FE'nin işi (§1.3); biçimin tek sahibi
  /// [formatMoney] (`lib/net/money.dart`).
  String get moneyLabel => formatMoney(money);
}

/// §12.7 · sponsorluk durumu — teklifler, aktif anlaşmalar ve bekleyen
/// zorunlu etkinlikler tek yanıtta. Oyuncunun sorusu "sponsorluk durumum ne",
/// "masada ne var" değil.
class SponsorshipState {
  const SponsorshipState({
    required this.offers,
    required this.active,
    required this.pendingObligations,
  });

  final List<SponsorshipDeal> offers;
  final List<SponsorshipDeal> active;

  /// Bugün ya da daha önce vadesi gelmiş, henüz cevaplanmamış randevular.
  /// Bunlardan biri varken `advance` `409` döner (§12.7).
  final List<SponsorshipObligation> pendingObligations;

  factory SponsorshipState.fromJson(Map<String, dynamic> json) {
    List<SponsorshipDeal> deals(String key) =>
        ((json[key] as List<dynamic>?) ?? const [])
            .map((e) => SponsorshipDeal.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
    return SponsorshipState(
      offers: deals('offers'),
      active: deals('active'),
      pendingObligations:
          ((json['pending_obligations'] as List<dynamic>?) ?? const [])
              .map((e) =>
                  SponsorshipObligation.fromJson(e as Map<String, dynamic>))
              .toList(growable: false),
    );
  }
}

class SponsorshipDeal {
  const SponsorshipDeal({
    required this.dealId,
    required this.brand,
    required this.title,
    required this.body,
    required this.acceptLabel,
    required this.declineLabel,
    required this.weeklyIncome,
    required this.seasons,
    required this.requires,
    required this.obligation,
    required this.status,
    required this.expiresOn,
  });

  final String dealId;
  final String brand;
  final String title;
  final String body;
  final String acceptLabel;
  final String declineLabel;

  /// ₭ cinsinden, her Pazartesi. İmza anında donar.
  final int weeklyIncome;
  final int seasons;

  /// D42 eşikleri — kişi nitelikleri.
  final Map<String, int> requires;

  /// Null ise yükümlülüksüz bir anlaşma. **İmzadan önce gösterilir**:
  /// sonradan öğrenilen bir bedel karar değil tuzaktır.
  final SponsorshipObligationSpec? obligation;

  final String status;
  final String? expiresOn;

  factory SponsorshipDeal.fromJson(Map<String, dynamic> json) {
    final obligation = json['obligation'] as Map<String, dynamic>?;
    return SponsorshipDeal(
      dealId: json['deal_id'] as String,
      brand: json['brand'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      acceptLabel: json['accept_label'] as String? ?? 'Kabul et',
      declineLabel: json['decline_label'] as String? ?? 'Reddet',
      weeklyIncome: json['weekly_income'] as int,
      seasons: json['seasons'] as int? ?? 1,
      requires: ((json['requires'] as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toInt())),
      obligation: obligation == null
          ? null
          : SponsorshipObligationSpec.fromJson(obligation),
      status: json['status'] as String,
      expiresOn: json['expires_on'] as String?,
    );
  }
}

/// Anlaşmanın yükümlülük ritmi — kaç günde bir, neye mal oluyor.
class SponsorshipObligationSpec {
  const SponsorshipObligationSpec({
    required this.title,
    required this.everyDays,
    required this.costs,
    required this.condition,
  });

  final String title;
  final int everyDays;
  final Map<String, double> costs;

  /// Katılmanın kondisyon bedeli (negatif).
  final int condition;

  factory SponsorshipObligationSpec.fromJson(Map<String, dynamic> json) =>
      SponsorshipObligationSpec(
        title: json['title'] as String,
        everyDays: json['every_days'] as int,
        costs: ((json['costs'] as Map<String, dynamic>?) ?? const {})
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
        condition: (json['condition'] as num?)?.toInt() ?? 0,
      );
}

class SponsorshipObligation {
  const SponsorshipObligation({
    required this.obligationId,
    required this.dealId,
    required this.dueOn,
  });

  final String obligationId;
  final String dealId;
  final String dueOn;

  factory SponsorshipObligation.fromJson(Map<String, dynamic> json) =>
      SponsorshipObligation(
        obligationId: json['obligation_id'] as String,
        dealId: json['deal_id'] as String? ?? '',
        dueOn: json['due_on'] as String,
      );
}

/// §11.7 S3 · transfer penceresindeki teklifler.
class TransferOffers {
  const TransferOffers({
    required this.window,
    required this.closesOn,
    required this.offers,
  });

  /// `winter` | `summer` | null (pencere kapalı).
  final String? window;

  /// Pencerenin son günü; kapalıysa null.
  final String? closesOn;

  /// Pencere kapalıyken **boş liste** — hata değil (§11.7).
  final List<TransferOffer> offers;

  bool get isOpen => window != null;

  /// Mevcut kulübün yenileme teklifi; yoksa null.
  TransferOffer? get renewal {
    for (final o in offers) {
      if (o.isRenewal) return o;
    }
    return null;
  }

  List<TransferOffer> get rivals =>
      offers.where((o) => !o.isRenewal).toList(growable: false);

  factory TransferOffers.fromJson(Map<String, dynamic> json) => TransferOffers(
        window: json['window'] as String?,
        closesOn: json['closes_on'] as String?,
        offers: ((json['offers'] as List<dynamic>?) ?? const [])
            .map((e) => TransferOffer.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class TransferOffer {
  const TransferOffer({
    required this.offerId,
    required this.team,
    required this.competition,
    required this.weeklyWage,
    required this.appearanceBonus,
    required this.goalBonus,
    required this.releaseClause,
    required this.lengthSeasons,
    required this.expiresAt,
    required this.isRenewal,
    required this.counterUsed,
  });

  final String offerId;
  final TeamRef team;
  final CompetitionRef? competition;
  final int weeklyWage;
  final int appearanceBonus;
  final int goalBonus;
  final int releaseClause;
  final int lengthSeasons;

  /// Kabul edilirse sözleşmenin biteceği gün — daima bir sezon sınırı
  /// (D50/INV-35).
  final String expiresAt;

  /// Mevcut kulübün teklifi mi. Yalnızca bunun bir karşı teklif hakkı var.
  final bool isRenewal;
  final bool counterUsed;

  bool get canCounter => isRenewal && !counterUsed;

  factory TransferOffer.fromJson(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>?;
    return TransferOffer(
      offerId: json['offer_id'] as String,
      team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
      competition:
          competition == null ? null : CompetitionRef.fromJson(competition),
      weeklyWage: json['weekly_wage'] as int,
      appearanceBonus: json['appearance_bonus'] as int,
      goalBonus: json['goal_bonus'] as int,
      releaseClause: json['release_clause'] as int,
      lengthSeasons: json['length_seasons'] as int,
      expiresAt: json['expires_at'] as String,
      isRenewal: json['is_renewal'] as bool? ?? false,
      counterUsed: json['counter_used'] as bool? ?? false,
    );
  }
}

/// §12.4 · karşı teklifin sonucu.
class CounterOfferResult {
  const CounterOfferResult({required this.accepted, required this.offer});

  final bool accepted;
  final TransferOffer offer;

  factory CounterOfferResult.fromJson(Map<String, dynamic> json) =>
      CounterOfferResult(
        accepted: json['accepted'] as bool,
        offer: TransferOffer.fromJson(json['offer'] as Map<String, dynamic>),
      );
}

/// §11.7 S4 · kabul edilen teklifin sonucu.
class TransferAcceptResult {
  const TransferAcceptResult({
    required this.careerState,
    required this.team,
    required this.competition,
    required this.weeklyWage,
    required this.expiresAt,
    this.relationshipsReset = const [],
  });

  final CareerState careerState;
  final TeamRef team;
  final CompetitionRef? competition;
  final int weeklyWage;
  final String expiresAt;

  /// §13.1 · yeni kulüpte sıfırlanan antrenör/takım/taraftar satırları. Yeni
  /// isimler burada geliyor; kartların tazelenmesi için ayrıca R1 çekilmeli.
  final List<RelationshipReset> relationshipsReset;

  factory TransferAcceptResult.fromJson(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>?;
    final contract = json['contract'] as Map<String, dynamic>;
    return TransferAcceptResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
      competition:
          competition == null ? null : CompetitionRef.fromJson(competition),
      weeklyWage: contract['weekly_wage'] as int,
      expiresAt: contract['expires_at'] as String,
      relationshipsReset: ((json['relationships_reset'] as List<dynamic>?) ?? const [])
          .map((e) => RelationshipReset.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// §11.5 S1 · sezon devrinin sonucu.
class SeasonRolloverResult {
  const SeasonRolloverResult({
    required this.careerState,
    required this.previousSeasonId,
    required this.newSeasonId,
    required this.summary,
    required this.finalRank,
    required this.outcomes,
    required this.movedWithTeam,
    required this.contractStatus,
    required this.newsCreated,
  });

  final CareerState careerState;
  final String previousSeasonId;
  final String newSeasonId;
  final SeasonSummary summary;

  /// Kullanıcının takımının bitirdiği sıra; takım hiçbir ligde değilse null.
  final int? finalRank;

  /// `champion` | `continental` | `promoted` | `relegated` — cümle değil
  /// enum dizisi (§1.3): "Şampiyon oldun!" metnini FE yazar.
  final List<String> outcomes;

  /// Takım düştü ya da çıktı mı — oyuncu da onunla birlikte taşındı.
  final bool movedWithTeam;

  /// `active` | `expired`.
  final String contractStatus;

  final List<String> newsCreated;

  factory SeasonRolloverResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return SeasonRolloverResult(
      careerState: CareerState.fromJson(
        json['career_state'] as Map<String, dynamic>,
      ),
      previousSeasonId: json['previous_season_id'] as String,
      newSeasonId: json['new_season_id'] as String,
      summary: SeasonSummary.fromJson(json['summary'] as Map<String, dynamic>),
      finalRank: user['final_rank'] as int?,
      outcomes: ((user['outcomes'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      movedWithTeam: user['moved_with_team'] as bool? ?? false,
      contractStatus: user['contract_status'] as String? ?? 'active',
      newsCreated: ((json['news_created'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
    );
  }
}

/// §11.6 S2 · bir sezonun kapanış defteri.
class SeasonSummary {
  const SeasonSummary({
    required this.seasonId,
    required this.leagues,
    required this.continentalSlots,
  });

  final String seasonId;

  /// Kupa burada **yok**: eleme usulünün tablosu olmaz (W2'nin
  /// `no_standings` cevabıyla aynı gerekçe).
  final List<SeasonLeagueResult> leagues;

  /// `competition_id` → kıta turnuvası kontenjanı.
  final Map<String, int> continentalSlots;

  factory SeasonSummary.fromJson(Map<String, dynamic> json) => SeasonSummary(
        seasonId: json['season_id'] as String,
        leagues: ((json['leagues'] as List<dynamic>?) ?? const [])
            .map((e) => SeasonLeagueResult.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        continentalSlots:
            ((json['continental_slots'] as Map<String, dynamic>?) ?? const {})
                .map((key, value) => MapEntry(key, (value as num).toInt())),
      );
}

class SeasonLeagueResult {
  const SeasonLeagueResult({
    required this.competition,
    required this.champion,
    required this.rows,
  });

  final CompetitionRef competition;
  final TeamRef? champion;
  final List<SeasonResultRow> rows;

  factory SeasonLeagueResult.fromJson(Map<String, dynamic> json) {
    final champion = json['champion'] as Map<String, dynamic>?;
    return SeasonLeagueResult(
      competition:
          CompetitionRef.fromJson(json['competition'] as Map<String, dynamic>),
      champion: champion == null ? null : TeamRef.fromJson(champion),
      rows: ((json['rows'] as List<dynamic>?) ?? const [])
          .map((e) => SeasonResultRow.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class SeasonResultRow {
  const SeasonResultRow({
    required this.team,
    required this.finalRank,
    required this.outcomes,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  final TeamRef team;
  final int finalRank;
  final List<String> outcomes;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  factory SeasonResultRow.fromJson(Map<String, dynamic> json) => SeasonResultRow(
        team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
        finalRank: json['final_rank'] as int,
        outcomes: ((json['outcomes'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(growable: false),
        played: json['played'] as int,
        won: json['won'] as int,
        drawn: json['drawn'] as int,
        lost: json['lost'] as int,
        goalsFor: json['goals_for'] as int,
        goalsAgainst: json['goals_against'] as int,
        goalDifference: json['goal_difference'] as int,
        points: json['points'] as int,
      );
}

/// §12.1 M4 · `POST /careers/{cid}/matches/{fid}/coach-talk` yanıtı.
///
/// `granted` yalnızca talep konularında (`request_position`/`request_role`)
/// dolu; kabul/ret konularında `null` gelir — "reddedildi" ile "zaten bir
/// talep değildi" iki ayrı şey.
class CoachTalkResult {
  const CoachTalkResult({
    required this.careerState,
    required this.topic,
    required this.granted,
    required this.relationshipChanges,
    required this.traitChanges,
    required this.conditionAfter,
    required this.position,
    required this.role,
    this.instructionFocus,
    this.instructionLabel,
    this.instructionPositionGroup,
  });

  final CareerState careerState;
  final String topic;
  final bool? granted;
  final List<RelationshipChange> relationshipChanges;
  final List<TraitChange> traitChanges;

  /// Konu kondisyon oynatmıyorsa null.
  final int? conditionAfter;

  /// Talep kabul edildiyse oyuncunun yeni pozisyonu/rolü; aksi halde null.
  final String? position;
  final String? role;

  /// §12.10 · yalnızca kabul edilmiş bir `request_instruction` (ya da rolü
  /// değiştiren bir `request_position`/`request_role`) talimatı gerçekten
  /// değiştirdiyse doludur — M1'in `coach_instruction`'ından daha dar: rol
  /// ve kaynak bilgisi taşımaz, ama §12.14'ten beri `position_group` taşır
  /// (kabul edilmiş bir `request_role`/`request_position` grubu da
  /// değiştirebilir, ve M1'in kopyası o anda bayatlar).
  final String? instructionFocus;
  final String? instructionLabel;

  /// §12.14 · kabul edilmiş bir `request_role`/`request_position` mevki
  /// grubunu da taşımış olabilir; maç öncesi ekranı bunu M1'den aldığı
  /// değerin üstüne yazıyor, yoksa motora bayat bir grup giderdi.
  final String? instructionPositionGroup;

  /// Antrenörün güveni — komisyon değeri. Talep başarısı bunun üstünden
  /// hesaplandığı için ekran bunu ayrıca gösteriyor.
  TraitChange? get trust {
    for (final c in traitChanges) {
      if (c.key == 'trust') return c;
    }
    return null;
  }

  factory CoachTalkResult.fromJson(Map<String, dynamic> json) {
    final player = json['player'] as Map<String, dynamic>?;
    final instruction = json['coach_instruction'] as Map<String, dynamic>?;
    return CoachTalkResult(
      careerState: CareerState.fromJson(
        json['career_state'] as Map<String, dynamic>,
      ),
      topic: json['topic'] as String,
      granted: json['granted'] as bool?,
      relationshipChanges: (json['relationship_changes'] as List<dynamic>? ?? [])
          .map((e) => RelationshipChange.fromJson(e as Map<String, dynamic>))
          .toList(),
      traitChanges: (json['trait_changes'] as List<dynamic>? ?? [])
          .map((e) => TraitChange.fromJson(e as Map<String, dynamic>))
          .toList(),
      conditionAfter: (json['condition_after'] as num?)?.toInt(),
      position: player?['position'] as String?,
      role: player?['role'] as String?,
      instructionFocus: instruction?['focus'] as String?,
      instructionLabel: instruction?['label'] as String?,
      instructionPositionGroup: instruction?['position_group'] as String?,
    );
  }
}

/// §12.1 · `relationship.traits` içindeki sayısal bir alanın hareketi.
/// `delta` uygulanan miktardır, istenen değil — sınıra dayanmışsa ikisi
/// farklı olur (`relationships.apply_trait_delta`).
class TraitChange {
  const TraitChange({
    required this.key,
    required this.before,
    required this.after,
    required this.delta,
  });

  final String key;
  final double before;
  final double after;
  final double delta;

  factory TraitChange.fromJson(Map<String, dynamic> json) => TraitChange(
        key: json['key'] as String,
        before: (json['before'] as num).toDouble(),
        after: (json['after'] as num).toDouble(),
        delta: (json['delta'] as num).toDouble(),
      );
}

/// §5.4 `LedgerEntry` — para hareketi olan yanıtlarda (D25).
class LedgerEntry {
  const LedgerEntry({
    required this.happenedAt,
    required this.amount,
    required this.kind,
    required this.reason,
    required this.balanceAfter,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      happenedAt: json['happened_at'] as String,
      amount: json['amount'] as int,
      kind: json['kind'] as String,
      reason: json['reason'] as String,
      balanceAfter: json['balance_after'] as int,
    );
  }

  final String happenedAt;

  /// + gelir, − gider.
  final int amount;
  final String kind;
  final String reason;
  final int balanceAfter;
}

List<LedgerEntry> _parseLedgerEntries(dynamic json) {
  return ((json as List<dynamic>?) ?? const [])
      .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// §5.1 C3 `next_fixture`.
class NextFixtureSummary {
  const NextFixtureSummary({
    required this.fixtureId,
    required this.competition,
    required this.roundNo,
    required this.kickoffAt,
    required this.home,
    required this.away,
    required this.userSide,
    required this.daysUntil,
  });

  factory NextFixtureSummary.fromJson(Map<String, dynamic> json) {
    return NextFixtureSummary(
      fixtureId: json['fixture_id'] as String,
      competition:
          CompetitionRef.fromJson(json['competition'] as Map<String, dynamic>),
      roundNo: json['round_no'] as int,
      kickoffAt: json['kickoff_at'] as String,
      home: TeamRef.fromJson(json['home'] as Map<String, dynamic>),
      away: TeamRef.fromJson(json['away'] as Map<String, dynamic>),
      userSide: json['user_side'] as String,
      daysUntil: json['days_until'] as int,
    );
  }

  final String fixtureId;
  final CompetitionRef competition;
  final int roundNo;
  final String kickoffAt;
  final TeamRef home;
  final TeamRef away;
  final String userSide;
  final int daysUntil;

  TeamRef get userTeam => userSide == 'home' ? home : away;
  TeamRef get opponent => userSide == 'home' ? away : home;
}

/// §5.1 C3 `standing_summary`.
class StandingSummary {
  const StandingSummary({
    required this.competitionId,
    this.rank,
    required this.played,
    required this.points,
    required this.promotionSlots,
    required this.relegationSlots,
  });

  factory StandingSummary.fromJson(Map<String, dynamic> json) {
    return StandingSummary(
      competitionId: json['competition_id'] as String,
      rank: json['rank'] as int?,
      played: json['played'] as int,
      points: json['points'] as int,
      promotionSlots: json['promotion_slots'] as int? ?? 0,
      relegationSlots: json['relegation_slots'] as int? ?? 0,
    );
  }

  final String competitionId;
  final int? rank;
  final int played;
  final int points;
  final int promotionSlots;
  final int relegationSlots;
}

/// C3 `news_preview[]` satırı — N1'in bir alt kümesi (`excerpt` yok).
class NewsPreviewItem {
  const NewsPreviewItem({
    required this.newsId,
    required this.category,
    required this.title,
    required this.source,
    required this.publishedAt,
  });

  factory NewsPreviewItem.fromJson(Map<String, dynamic> json) {
    return NewsPreviewItem(
      newsId: json['news_id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      source: json['source'] as String,
      publishedAt: json['published_at'] as String,
    );
  }

  final String newsId;
  final String category;
  final String title;
  final String source;
  final String publishedAt;
}

/// C3 · `GET /careers/{cid}` — kariyer merkezi. Tek çağrıda hub verisi.
class CareerHub {
  const CareerHub({
    required this.careerId,
    required this.careerState,
    required this.playerName,
    required this.firstName,
    required this.lastName,
    required this.nationality,
    required this.playerPosition,
    this.role,
    this.roleName,
    required this.playerAge,
    required this.playerTeam,
    this.targetTeam,
    this.nextFixture,
    this.standingSummary,
    required this.newsPreview,
  });

  factory CareerHub.fromJson(Map<String, dynamic> json) {
    final player = json['player'] as Map<String, dynamic>;
    final targetTeam = player['target_team'] as Map<String, dynamic>?;
    final nextFixture = json['next_fixture'] as Map<String, dynamic>?;
    final standingSummary = json['standing_summary'] as Map<String, dynamic>?;
    return CareerHub(
      careerId: json['career_id'] as String,
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      playerName: player['name'] as String,
      firstName: player['first_name'] as String? ?? '',
      lastName: player['last_name'] as String? ?? '',
      nationality: player['nationality'] as String? ?? '',
      playerPosition: player['position'] as String,
      role: player['role'] as String?,
      roleName: player['role_name'] as String?,
      playerAge: player['age'] as int,
      playerTeam: TeamRef.fromJson(player['team'] as Map<String, dynamic>),
      targetTeam: targetTeam == null ? null : TeamRef.fromJson(targetTeam),
      nextFixture: nextFixture == null
          ? null
          : NextFixtureSummary.fromJson(nextFixture),
      standingSummary: standingSummary == null
          ? null
          : StandingSummary.fromJson(standingSummary),
      newsPreview: (json['news_preview'] as List<dynamic>)
          .map((e) => NewsPreviewItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String careerId;
  final CareerState careerState;

  /// Ad + soyadın motorda birleştirilmiş hali.
  final String playerName;
  final String firstName;
  final String lastName;

  /// `country_code` ('TR'), sıfat hali değil.
  final String nationality;
  final String playerPosition;

  /// Rol kimliği ve adı: roller gelmeden açılmış kariyerlerde ikisi de null
  /// gelir (BE kimliği yine de yankılar, "rolsüz" ile "bilinmeyen rol" ayrılsın
  /// diye).
  final String? role;
  final String? roleName;
  final int playerAge;
  final TeamRef playerTeam;

  /// Hedeflenen kulüp — oynanan kulüp [playerTeam].
  final TeamRef? targetTeam;

  /// Sezon bittiyse null.
  final NextFixtureSummary? nextFixture;
  final StandingSummary? standingSummary;
  final List<NewsPreviewItem> newsPreview;
}

// ---------------------------------------------------------------------------
// §5.2 Oyuncu — P1-P3
// ---------------------------------------------------------------------------

/// P1 `attributes[]` satırı — D30: tam 11 anahtar, eksiksiz (INV-21).
class PlayerAttribute {
  const PlayerAttribute({
    required this.key,
    required this.family,
    required this.value,
    this.passiveBonus = 0,
    double? effectiveValue,
    required this.level,
  }) : _effectiveValue = effectiveValue;

  factory PlayerAttribute.fromJson(Map<String, dynamic> json) {
    final value = (json['value'] as num).toDouble();
    final bonus = (json['passive_bonus'] as num?)?.toDouble() ?? 0.0;
    return PlayerAttribute(
      key: json['key'] as String,
      family: json['family'] as String,
      value: value,
      passiveBonus: bonus,
      effectiveValue:
          (json['effective_value'] as num?)?.toDouble() ?? (value + bonus),
      level: (json['level'] as num).toInt(),
    );
  }

  final String key;

  /// 'saha' | 'kişi'.
  final String family;

  /// §13.3 · **taban** değer — antrenman, aktivite ve diyalog bunu oynatır.
  /// İlerleme çubuğu bunu gösterir: oyuncunun gerçekten kazandığı şey.
  final double value;

  /// §13.3 · sahip olunan eşyaların katkısı. Saklanmaz, her okumada BE'de
  /// türetilir; eşya elden çıkınca kendiliğinden sıfırlanır.
  final double passiveBonus;

  final double? _effectiveValue;

  /// §13.3 · `value + passiveBonus`, 0-100'e sıkışmış. Bir kapının
  /// karşılaştırdığı değer budur.
  ///
  /// BE gönderdiğinde onunki kullanılır; elle kurulan bir nesnede (testler,
  /// `orElse` yedeği) aynı formülden türetilir. Toplama işlemi bir kural
  /// kopyası değil — kopyalanmaması gereken tek şey [level]'ın ölçeği ve o
  /// daima BE'den geliyor (D74/INV-61).
  double get effectiveValue =>
      _effectiveValue ?? (value + passiveBonus).clamp(0.0, 100.0);

  /// D43/D74 · 0-10, **`effectiveValue`'dan** BE'de türetilir. FE bu kuralın
  /// bir kopyasını tutmaz — tutamaz da: bonusu hesaplamak için envanteri ve
  /// dükkân kataloğunu birleştirmesi gerekirdi (§13.3/INV-61).
  final int level;
}

/// P1 `tactics[]` satırı — §12.11. [PlayerAttribute]'un aksine ne bir
/// `family` ayrımı ne de bir `level` ölçeği taşır; taktik kartlarının
/// hiçbiri kilitli değil, karşılaştırılacak bir eşik yok.
class PlayerTactic {
  const PlayerTactic({required this.key, required this.value});

  factory PlayerTactic.fromJson(Map<String, dynamic> json) {
    return PlayerTactic(
      key: json['key'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }

  final String key;
  final double value;
}

/// P1 `fame[]` satırı — D35, anlamı ⟦AÇIK-9⟧.
class FameEntry {
  const FameEntry({required this.scope, required this.value});

  factory FameEntry.fromJson(Map<String, dynamic> json) {
    return FameEntry(
      scope: json['scope'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }

  final String scope;
  final double value;
}

/// P1 `market_value` — ⟦AÇIK-8⟧ formül; henüz ölçüm yoksa BE `null` döner.
class MarketValue {
  const MarketValue({required this.current, required this.measuredOn});

  factory MarketValue.fromJson(Map<String, dynamic> json) {
    return MarketValue(
      current: (json['current'] as num).toInt(),
      measuredOn: json['measured_on'] as String,
    );
  }

  final int current;
  final String measuredOn;
}

/// P1 · `GET /careers/{cid}/player`.
class PlayerProfile {
  const PlayerProfile({
    required this.playerId,
    required this.name,
    required this.position,
    required this.birthDate,
    required this.age,
    required this.team,
    required this.careerState,
    required this.attributes,
    required this.tactics,
    required this.fame,
    this.marketValue,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final marketValueJson = json['market_value'] as Map<String, dynamic>?;
    return PlayerProfile(
      playerId: json['player_id'] as String,
      name: json['name'] as String,
      position: json['position'] as String,
      birthDate: json['birth_date'] as String,
      age: json['age'] as int,
      team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      attributes: (json['attributes'] as List<dynamic>)
          .map((e) => PlayerAttribute.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      // §12.11 · INV-55 her zaman üç satır vaat ediyor, ama alanı hiç
      // göndermeyen bir career_engine sürümüne karşı sert cast yapmak tek
      // eksik alanı TÜM P1'in çökmesine çeviriyordu — ve PlayerState.load()
      // onu sessizce yutuyor, ekran nitelikleri boş sanıyordu. `seasonPhase`
      // ile aynı duruş: bilmiyoruz demek, çökmekten iyidir.
      tactics: ((json['tactics'] as List<dynamic>?) ?? const [])
          .map((e) => PlayerTactic.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      fame: (json['fame'] as List<dynamic>)
          .map((e) => FameEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      marketValue:
          marketValueJson == null ? null : MarketValue.fromJson(marketValueJson),
    );
  }

  final String playerId;
  final String name;
  final String position;
  final String birthDate;
  final int age;
  final TeamRef team;
  final CareerState careerState;
  final List<PlayerAttribute> attributes;
  final List<PlayerTactic> tactics;
  final List<FameEntry> fame;
  final MarketValue? marketValue;

  double attribute(String key) =>
      attributes.firstWhere((a) => a.key == key, orElse: () =>
          const PlayerAttribute(key: '', family: '', value: 0, passiveBonus: 0,
              effectiveValue: 0, level: 0)).value;

  double tacticProficiency(String key) =>
      tactics.firstWhere((t) => t.key == key,
          orElse: () => const PlayerTactic(key: '', value: 0)).value;
}

/// P2 `rows[]` satırı — bir (sezon, müsabaka) kesiti.
class SeasonStatRow {
  const SeasonStatRow({
    required this.seasonId,
    required this.competitionId,
    required this.competitionKind,
    required this.competitionName,
    required this.appearances,
    required this.starts,
    required this.goals,
    required this.assists,
    required this.minutes,
    required this.passesCompleted,
    required this.passesAttempted,
  });

  factory SeasonStatRow.fromJson(Map<String, dynamic> json) {
    return SeasonStatRow(
      seasonId: json['season_id'] as String,
      competitionId: json['competition_id'] as String,
      // 'lig' | 'kupa' | 'uluslararasi' — API katmanı bu eşlemeyi yapar.
      competitionKind: json['competition_kind'] as String,
      competitionName: json['competition_name'] as String,
      appearances: json['appearances'] as int,
      starts: json['starts'] as int,
      goals: json['goals'] as int,
      assists: json['assists'] as int,
      minutes: json['minutes'] as int,
      passesCompleted: json['passes_completed'] as int,
      passesAttempted: json['passes_attempted'] as int,
    );
  }

  final String seasonId;
  final String competitionId;
  final String competitionKind;
  final String competitionName;
  final int appearances;
  final int starts;
  final int goals;
  final int assists;
  final int minutes;
  final int passesCompleted;
  final int passesAttempted;
}

/// P2 `value_history[]` satırı. Widget'ların kullandığı `ValuePoint`'ten
/// (`widgets/value_scatter_chart.dart`) farklı: `label` burada yok, BE yalnızca
/// tarihi verir — 'Oca 24' gibi kısa etiketi ekran türetir (§1.3).
class ValueHistoryPoint {
  const ValueHistoryPoint({required this.measuredOn, required this.value});

  factory ValueHistoryPoint.fromJson(Map<String, dynamic> json) {
    return ValueHistoryPoint(
      measuredOn: json['measured_on'] as String,
      value: (json['value'] as num).toInt(),
    );
  }

  final String measuredOn;
  final int value;
}

/// P2 · `GET /careers/{cid}/player/stats`.
class PlayerStats {
  const PlayerStats({required this.rows, required this.valueHistory});

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      rows: (json['rows'] as List<dynamic>)
          .map((e) => SeasonStatRow.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      valueHistory: (json['value_history'] as List<dynamic>)
          .map((e) => ValueHistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<SeasonStatRow> rows;
  final List<ValueHistoryPoint> valueHistory;
}

/// P3 · `GET /careers/{cid}/player/contract`. BE gövdesiz `null` dönebilir
/// (henüz hiç sözleşme yazılmamışsa) — çağıran bunu ele almalı.
class PlayerContract {
  const PlayerContract({
    required this.team,
    required this.signedAt,
    required this.expiresAt,
    required this.weeklyWage,
    required this.appearanceBonus,
    required this.goalBonus,
    required this.releaseClause,
    required this.daysUntilExpiry,
  });

  factory PlayerContract.fromJson(Map<String, dynamic> json) {
    return PlayerContract(
      team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
      signedAt: json['signed_at'] as String,
      expiresAt: json['expires_at'] as String,
      weeklyWage: json['weekly_wage'] as int,
      appearanceBonus: json['appearance_bonus'] as int,
      goalBonus: json['goal_bonus'] as int,
      releaseClause: json['release_clause'] as int,
      daysUntilExpiry: json['days_until_expiry'] as int,
    );
  }

  final TeamRef team;
  final String signedAt;
  final String expiresAt;
  final int weeklyWage;
  final int appearanceBonus;
  final int goalBonus;
  final int releaseClause;
  final int daysUntilExpiry;

  /// Türetilmiş — `weekly_wage × 4`, ayrı bir ödeme değil (§3.2).
  int get monthlyWage => weeklyWage * 4;
}

// ---------------------------------------------------------------------------
// §5.3 Dünya — W3-W4
// ---------------------------------------------------------------------------

/// W3 `fixtures[]` satırı.
class FixtureRef {
  const FixtureRef({
    required this.fixtureId,
    required this.competition,
    required this.roundNo,
    this.leg,
    required this.kickoffAt,
    required this.home,
    required this.away,
    required this.status,
    this.homeScore,
    this.awayScore,
    required this.isUserMatch,
  });

  factory FixtureRef.fromJson(Map<String, dynamic> json) {
    final score = json['score'] as Map<String, dynamic>?;
    return FixtureRef(
      fixtureId: json['fixture_id'] as String,
      competition:
          CompetitionRef.fromJson(json['competition'] as Map<String, dynamic>),
      roundNo: json['round_no'] as int,
      leg: json['leg'] as int?,
      kickoffAt: json['kickoff_at'] as String,
      home: TeamRef.fromJson(json['home'] as Map<String, dynamic>),
      away: TeamRef.fromJson(json['away'] as Map<String, dynamic>),
      // 'scheduled' | 'in_progress' | 'played'.
      status: json['status'] as String,
      homeScore: score?['home'] as int?,
      awayScore: score?['away'] as int?,
      isUserMatch: json['is_user_match'] as bool? ?? false,
    );
  }

  final String fixtureId;
  final CompetitionRef competition;
  final int roundNo;

  /// Çift maçlı elemede 1|2; tek maçlıkta null.
  final int? leg;
  final String kickoffAt;
  final TeamRef home;
  final TeamRef away;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final bool isUserMatch;

  bool get isPlayed => status == 'played';
}

/// W3 `rounds[]` satırı — takvim, kupada kura çekilmeden önce de dolu.
class CompetitionRoundInfo {
  const CompetitionRoundInfo({
    required this.roundNo,
    required this.stage,
    required this.scheduledOn,
    required this.drawn,
  });

  factory CompetitionRoundInfo.fromJson(Map<String, dynamic> json) {
    return CompetitionRoundInfo(
      roundNo: json['round_no'] as int,
      stage: json['stage'] as String,
      scheduledOn: json['scheduled_on'] as String,
      drawn: json['drawn'] as bool,
    );
  }

  final int roundNo;
  final String stage;
  final String scheduledOn;
  final bool drawn;
}

/// W3 · `GET /careers/{cid}/fixtures`.
class FixturesPage {
  const FixturesPage({
    required this.fixtures,
    required this.rounds,
    this.nextBefore,
  });

  factory FixturesPage.fromJson(Map<String, dynamic> json) {
    return FixturesPage(
      fixtures: (json['fixtures'] as List<dynamic>)
          .map((e) => FixtureRef.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      rounds: (json['rounds'] as List<dynamic>)
          .map((e) => CompetitionRoundInfo.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      nextBefore: json['next_before'] as String?,
    );
  }

  final List<FixtureRef> fixtures;
  final List<CompetitionRoundInfo> rounds;
  final String? nextBefore;
}

/// W4 `standing` alt nesnesi.
class TeamStandingSummary {
  const TeamStandingSummary({
    required this.rank,
    required this.played,
    required this.points,
  });

  factory TeamStandingSummary.fromJson(Map<String, dynamic> json) {
    return TeamStandingSummary(
      rank: json['rank'] as int,
      played: json['played'] as int,
      points: json['points'] as int,
    );
  }

  final int rank;
  final int played;
  final int points;
}

/// W4 · `GET /careers/{cid}/teams/{tid}`.
class TeamDetail {
  const TeamDetail({
    required this.team,
    required this.country,
    required this.mentality,
    required this.attack,
    required this.midfield,
    required this.defense,
    required this.goalkeeper,
    this.competition,
    this.standing,
  });

  factory TeamDetail.fromJson(Map<String, dynamic> json) {
    final ratings = json['ratings'] as Map<String, dynamic>;
    final competition = json['competition'] as Map<String, dynamic>?;
    final standing = json['standing'] as Map<String, dynamic>?;
    return TeamDetail(
      team: TeamRef.fromJson(json['team'] as Map<String, dynamic>),
      country: json['country'] as String,
      mentality: json['mentality'] as String,
      attack: (ratings['attack'] as num).toDouble(),
      midfield: (ratings['midfield'] as num).toDouble(),
      defense: (ratings['defense'] as num).toDouble(),
      goalkeeper: (ratings['goalkeeper'] as num).toDouble(),
      competition:
          competition == null ? null : CompetitionRef.fromJson(competition),
      standing: standing == null
          ? null
          : TeamStandingSummary.fromJson(standing),
    );
  }

  final TeamRef team;
  final String country;
  final String mentality;
  final double attack;
  final double midfield;
  final double defense;
  final double goalkeeper;

  /// Bu sezon oynadığı lig — takım hiçbir ligde değilse (kupa dışı) null.
  final CompetitionRef? competition;
  final TeamStandingSummary? standing;
}

// ---------------------------------------------------------------------------
// §5.4 İlişki — R1-R3
// ---------------------------------------------------------------------------

/// §13.2 · bir ilişkinin ömrü. Yalnızca `partner` bu makinenin içinden
/// geçer; diğer beşi daima [active]'dir (INV-59).
class RelationshipState {
  static const String absent = 'absent';
  static const String courting = 'courting';
  static const String active = 'active';
}

/// R1 `relationships[]` satırı — beş **veya** altı kart (§3.4, §13.2).
///
/// `absent` bir ilişki R1'den hiç dönmez (INV-58): tanışılmamış bir partner
/// listede yoktur. Kart sayısı bu yüzden sabit değil.
class RelationshipCard {
  const RelationshipCard({
    required this.relationshipId,
    required this.kind,
    required this.category,
    required this.score,
    required this.personName,
    required this.contactName,
    this.lastContactAt,
    required this.hasPendingRequest,
    this.state = RelationshipState.active,
    required this.traits,
  });

  factory RelationshipCard.fromJson(Map<String, dynamic> json) {
    return RelationshipCard(
      relationshipId: json['relationship_id'] as String,
      kind: json['kind'] as String,
      category: json['category'] as String,
      score: json['score'] as int,
      personName: json['person_name'] as String,
      contactName: json['contact_name'] as String,
      lastContactAt: json['last_contact_at'] as String?,
      hasPendingRequest: json['has_pending_request'] as bool? ?? false,
      state: json['state'] as String? ?? RelationshipState.active,
      traits: (json['traits'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String relationshipId;
  final String kind;
  final String category;

  /// 0-100, SAKLANIR (D24).
  final int score;
  final String personName;
  final String contactName;
  final String? lastContactAt;
  final bool hasPendingRequest;

  /// §13.2 · `absent` | `courting` | `active`. Her kartta gelir; partner
  /// dışındaki beşinde daima `active`.
  final String state;

  /// §13.2 · henüz kurulmamış ama tanışılmış bir ilişki — diyalog ağacının
  /// kurulum dalı bunun için açılır.
  bool get isCourting => state == RelationshipState.courting;

  /// Türe özel alanlar (D23) — FE tanımadığı anahtarı yok sayar.
  final Map<String, dynamic> traits;
}

/// §13.2 · R3/T2/T6 `relationship_state_changes[]` satırı. Bir ilişkinin
/// kurulduğu ya da bittiği tek yerden okunur; boş liste normaldir.
class RelationshipStateChange {
  const RelationshipStateChange({
    required this.relationshipId,
    required this.before,
    required this.after,
  });

  factory RelationshipStateChange.fromJson(Map<String, dynamic> json) {
    return RelationshipStateChange(
      relationshipId: json['relationship_id'] as String,
      before: json['before'] as String,
      after: json['after'] as String,
    );
  }

  final String relationshipId;
  final String before;
  final String after;

  /// Flörtten ilişkiye — kart artık kalıcı.
  bool get isEstablished => after == RelationshipState.active;

  /// İlişki bitti; kart listeden düştü.
  bool get isEnded => after == RelationshipState.absent;
}

/// §13.1 · S4 `relationships_reset[]` satırı — transferde sıfırlanan kulüp
/// ilişkisi. İsim alanları ekli çünkü FE yeni antrenörü başka türlü R1'i
/// yeniden çekmeden öğrenemez.
class RelationshipReset {
  const RelationshipReset({
    required this.relationshipId,
    required this.before,
    required this.after,
    required this.personName,
    required this.contactName,
  });

  factory RelationshipReset.fromJson(Map<String, dynamic> json) {
    return RelationshipReset(
      relationshipId: json['relationship_id'] as String,
      before: (json['before'] as num).toInt(),
      after: (json['after'] as num).toInt(),
      personName: json['person_name'] as String,
      contactName: json['contact_name'] as String,
    );
  }

  final String relationshipId;
  final int before;
  final int after;
  final String personName;
  final String contactName;
}

/// R2 `recent_events[]` satırı — en yeni 20 kayıt, geçmiş görünümü (D24).
class RelationshipEvent {
  const RelationshipEvent({
    required this.happenedAt,
    required this.delta,
    required this.reason,
  });

  factory RelationshipEvent.fromJson(Map<String, dynamic> json) {
    return RelationshipEvent(
      happenedAt: json['happened_at'] as String,
      delta: json['delta'] as int,
      reason: json['reason'] as String,
    );
  }

  final String happenedAt;
  final int delta;
  final String reason;
}

/// R2 · `GET /careers/{cid}/relationships/{rid}` — R1'in bütün alanları +
/// profil künyesi.
class RelationshipProfile {
  const RelationshipProfile({
    required this.card,
    this.age,
    this.occupation,
    this.bio,
    required this.hobbies,
    required this.recentEvents,
  });

  factory RelationshipProfile.fromJson(Map<String, dynamic> json) {
    return RelationshipProfile(
      card: RelationshipCard.fromJson(json),
      age: json['age'] as int?,
      occupation: json['occupation'] as String?,
      bio: json['bio'] as String?,
      hobbies: ((json['hobbies'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      recentEvents: ((json['recent_events'] as List<dynamic>?) ?? const [])
          .map((e) => RelationshipEvent.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final RelationshipCard card;
  final int? age;
  final String? occupation;
  final String? bio;
  final List<String> hobbies;
  final List<RelationshipEvent> recentEvents;
}

/// R3 yanıtının `relationship_changes[]` satırı.
class RelationshipChange {
  const RelationshipChange({
    required this.relationshipId,
    required this.before,
    required this.after,
    required this.delta,
  });

  factory RelationshipChange.fromJson(Map<String, dynamic> json) {
    return RelationshipChange(
      relationshipId: json['relationship_id'] as String,
      before: json['before'] as int,
      after: json['after'] as int,
      delta: json['delta'] as int,
    );
  }

  final String relationshipId;
  final int before;
  final int after;
  final int delta;
}

/// T2/R3 yanıtlarının `attribute_changes[]` satırı.
class AttributeChange {
  const AttributeChange({
    required this.key,
    required this.before,
    required this.after,
    this.passiveBonus = 0.0,
    required this.levelBefore,
    required this.levelAfter,
  });

  factory AttributeChange.fromJson(Map<String, dynamic> json) {
    return AttributeChange(
      key: json['key'] as String,
      before: (json['before'] as num).toDouble(),
      after: (json['after'] as num).toDouble(),
      passiveBonus: (json['passive_bonus'] as num?)?.toDouble() ?? 0.0,
      levelBefore: (json['level_before'] as num).toInt(),
      levelAfter: (json['level_after'] as num).toInt(),
    );
  }

  final String key;

  /// §13.3 · taban değerin iki yakası. Pasif bonus buraya girmez (INV-60).
  final double before;
  final double after;

  /// §13.3 · o anki eşya bonusu, `effectiveValue`'yu yerel kopyada yeniden
  /// kurabilmek için. Seviyeler zaten bonuslu değerden geliyor (D74).
  final double passiveBonus;

  /// D43 · deltanın iki yakasındaki seviye. Yerel kopyayı bu yanıtla
  /// güncelleyen ekran, bir kilidin açılıp açılmadığını kendi hesaplamadan
  /// görür (§5.5 notu).
  final int levelBefore;
  final int levelAfter;
}

/// T2 `tactic_changes[]` satırı — §12.11. [AttributeChange]'in aksine bir
/// seviye çifti taşımaz; taktik yeterliliğinin bir seviye ölçeği yok.
class TacticChange {
  const TacticChange({
    required this.key,
    required this.before,
    required this.after,
  });

  factory TacticChange.fromJson(Map<String, dynamic> json) {
    return TacticChange(
      key: json['key'] as String,
      before: (json['before'] as num).toDouble(),
      after: (json['after'] as num).toDouble(),
    );
  }

  final String key;
  final double before;
  final double after;
}

/// R3 · `POST /careers/{cid}/relationships/{rid}/interact`.
class InteractResult {
  const InteractResult({
    required this.careerState,
    required this.relationshipChanges,
    this.relationshipStateChanges = const [],
    required this.attributeChanges,
    required this.ledgerEntries,
  });

  factory InteractResult.fromJson(Map<String, dynamic> json) {
    return InteractResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      relationshipChanges: ((json['relationship_changes'] as List<dynamic>?) ?? const [])
          .map((e) => RelationshipChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      relationshipStateChanges: parseRelationshipStateChanges(
        json['relationship_state_changes'],
      ),
      attributeChanges: ((json['attribute_changes'] as List<dynamic>?) ?? const [])
          .map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
    );
  }

  final CareerState careerState;
  final List<RelationshipChange> relationshipChanges;

  /// §13.2 · bu konuşma bir ilişki kurduysa ya da bitirdiyse burada görünür.
  final List<RelationshipStateChange> relationshipStateChanges;
  final List<AttributeChange> attributeChanges;
  final List<LedgerEntry> ledgerEntries;
}

/// §13.2 · `relationship_state_changes` çözümleyicisi — R3, T2 ve T6 aynı
/// listeyi taşıyor, üç yerde aynı satırı yazmamak için.
List<RelationshipStateChange> parseRelationshipStateChanges(dynamic raw) {
  return ((raw as List<dynamic>?) ?? const [])
      .map((e) => RelationshipStateChange.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

// ---------------------------------------------------------------------------
// §5.5 Zaman — T1-T4
// ---------------------------------------------------------------------------

/// İlk eşleşen olayın `ref_id`'si, yoksa null. `firstOrNull` package:collection
/// içinde; iki çağrı için bağımlılık eklemek yerine açıkça yazıldı.
String? _firstRefId(List<DayEvent> events, String kind) {
  for (final event in events) {
    if (event.kind == kind) return event.refId;
  }
  return null;
}

/// T1 `events[]` satırı. `kind`: match · cup_draw · contract_expiring ·
/// upkeep_warning · relationship_low · season_end · social_offer.
/// Cümle gönderilmez — ekran
/// `kind`/`refId` ve `extra`'dan kendi metnini kurar (§1.3).
class DayEvent {
  const DayEvent({required this.kind, this.refId, required this.extra});

  factory DayEvent.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json)
      ..remove('kind')
      ..remove('ref_id');
    return DayEvent(
      kind: json['kind'] as String,
      refId: json['ref_id'] as String?,
      extra: extra,
    );
  }

  final String kind;
  final String? refId;

  /// `round_no` (cup_draw), `shortfall` (upkeep_warning) gibi olay-özel alanlar.
  final Map<String, dynamic> extra;
}

/// T1 · `GET /careers/{cid}/day`.
class DayInfo {
  const DayInfo({
    required this.careerState,
    required this.isMatchDay,
    required this.events,
    this.conditionRecovery,
  });

  factory DayInfo.fromJson(Map<String, dynamic> json) {
    final recovery = json['condition_recovery'] as Map<String, dynamic>?;
    return DayInfo(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      isMatchDay: json['is_match_day'] as bool,
      events: (json['events'] as List<dynamic>)
          .map((e) => DayEvent.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      conditionRecovery:
          recovery == null ? null : ConditionRecovery.fromJson(recovery),
    );
  }

  final CareerState careerState;
  final bool isMatchDay;
  final List<DayEvent> events;

  /// §6.6 · bir sonraki günün kondisyon kazancı. §5.0 gereği null olabilir
  /// (alanı tanımayan bir backend).
  final ConditionRecovery? conditionRecovery;

  /// Cevap bekleyen sosyal teklifin kimliği, yoksa null (§6.3 D53).
  String? get pendingOfferId => _firstRefId(events, 'social_offer');
}

/// T1 `condition_recovery` — §6.6.
class ConditionRecovery {
  const ConditionRecovery({
    required this.base,
    required this.bonus,
    required this.total,
    required this.capped,
    required this.sources,
  });

  factory ConditionRecovery.fromJson(Map<String, dynamic> json) {
    return ConditionRecovery(
      base: (json['base'] as num).toInt(),
      bonus: (json['bonus'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      capped: json['capped'] as bool? ?? false,
      sources: ((json['sources'] as List<dynamic>?) ?? const [])
          .map((e) => ConditionRecoverySource.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final int base;

  /// Sahip olunan eşyalardan gelen pay — tavan uygulanmadan ÖNCEki toplam,
  /// yani `base + bonus` her zaman `total`'a eşit değildir.
  final int bonus;
  final int total;

  /// Tavana takıldıysa true; ekran "daha fazlası bir işe yaramıyor" diyebilir.
  final bool capped;
  final List<ConditionRecoverySource> sources;
}

/// T1 `condition_recovery.sources[]` — bonusu veren tek bir eşya.
class ConditionRecoverySource {
  const ConditionRecoverySource({
    required this.itemId,
    required this.title,
    required this.amount,
  });

  factory ConditionRecoverySource.fromJson(Map<String, dynamic> json) {
    return ConditionRecoverySource(
      itemId: json['item_id'] as String,
      title: json['title'] as String? ?? json['item_id'] as String,
      amount: (json['amount'] as num).toInt(),
    );
  }

  final String itemId;

  /// Katalogda yazan ad — kurulmuş bir cümle değil (§1.3).
  final String title;
  final int amount;
}

/// T2 · `POST /careers/{cid}/actions`.
/// §13.4 · T2 `event` bloğu — bir aktivite sırasında gelişen olay.
///
/// Ödül tablosu gelmez (R4'ün ayrımı): seçeneğin `requires`/`costs`'u gelir
/// ki kilitli dal seçilmeden önce gri görünsün, `effects`'i gelmez.
class ActivityEventOption {
  const ActivityEventOption({
    required this.optionId,
    required this.label,
    required this.requires,
    required this.costs,
  });

  factory ActivityEventOption.fromJson(Map<String, dynamic> json) {
    return ActivityEventOption(
      optionId: json['option_id'] as String,
      label: json['label'] as String,
      requires: ((json['requires'] as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toInt())),
      costs: ((json['costs'] as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toDouble())),
    );
  }

  final String optionId;
  final String label;

  /// D42 · nitelik seviyesi eşikleri. Boşsa kapı yok.
  final Map<String, int> requires;

  /// §6.2 · günün bütçesinden ne yiyeceği.
  final Map<String, double> costs;
}

/// §13.4 · T2'nin doğurduğu, T5'in kurtardığı, T6'nın çözdüğü olay.
class ActivityEvent {
  const ActivityEvent({
    required this.eventId,
    required this.templateId,
    required this.catalogId,
    required this.title,
    required this.body,
    required this.openedOn,
    required this.status,
    required this.options,
    this.chosenOption,
    this.resolvedOn,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      eventId: json['event_id'] as String,
      templateId: json['template_id'] as String,
      catalogId: json['catalog_id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      openedOn: json['opened_on'] as String,
      status: json['status'] as String,
      options: ((json['options'] as List<dynamic>?) ?? const [])
          .map((e) => ActivityEventOption.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      chosenOption: json['chosen_option'] as String?,
      resolvedOn: json['resolved_on'] as String?,
    );
  }

  final String eventId;
  final String templateId;

  /// Olayı doğuran aktivite — FE sahneyi bundan seçiyor (§5.8).
  final String catalogId;
  final String title;
  final String body;
  final String openedOn;

  /// `open` | `resolved` | `expired`. Cevapsız kalan bir olay `advance`
  /// sırasında `expired` olur ve hiçbir etki yazmaz (D76/INV-63).
  final String status;
  final List<ActivityEventOption> options;
  final String? chosenOption;
  final String? resolvedOn;

  bool get isOpen => status == 'open';
}

/// §13.4 · T6 · seçeneğin uygulanmış hâli.
class ActivityEventResult {
  const ActivityEventResult({
    required this.careerState,
    required this.event,
    required this.appliedCosts,
    required this.appliedEffects,
    required this.attributeChanges,
    required this.relationshipChanges,
    required this.relationshipStateChanges,
    required this.ledgerEntries,
  });

  factory ActivityEventResult.fromJson(Map<String, dynamic> json) {
    return ActivityEventResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      event: ActivityEvent.fromJson(json['event'] as Map<String, dynamic>),
      appliedCosts: ((json['applied_costs'] as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toDouble())),
      appliedEffects:
          (json['applied_effects'] as Map<String, dynamic>?) ?? const {},
      attributeChanges: ((json['attribute_changes'] as List<dynamic>?) ?? const [])
          .map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      relationshipChanges: ((json['relationship_changes'] as List<dynamic>?) ?? const [])
          .map((e) => RelationshipChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      relationshipStateChanges: parseRelationshipStateChanges(
        json['relationship_state_changes'],
      ),
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
    );
  }

  final CareerState careerState;
  final ActivityEvent event;
  final Map<String, double> appliedCosts;
  final Map<String, dynamic> appliedEffects;
  final List<AttributeChange> attributeChanges;
  final List<RelationshipChange> relationshipChanges;

  /// §13.2 · bir seçenek biriyle tanıştırdıysa burada görünür.
  final List<RelationshipStateChange> relationshipStateChanges;
  final List<LedgerEntry> ledgerEntries;
}

class ActionResult {
  const ActionResult({
    required this.careerState,
    required this.appliedCosts,
    required this.appliedEffects,
    required this.attributeChanges,
    required this.tacticChanges,
    required this.relationshipChanges,
    this.relationshipStateChanges = const [],
    required this.ledgerEntries,
    this.event,
    this.risk,
    this.withKind,
  });

  factory ActionResult.fromJson(Map<String, dynamic> json) {
    return ActionResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      appliedCosts: (json['applied_costs'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      appliedEffects: json['applied_effects'] as Map<String, dynamic>,
      attributeChanges: ((json['attribute_changes'] as List<dynamic>?) ?? const [])
          .map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      tacticChanges: ((json['tactic_changes'] as List<dynamic>?) ?? const [])
          .map((e) => TacticChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      relationshipChanges: ((json['relationship_changes'] as List<dynamic>?) ?? const [])
          .map((e) => RelationshipChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      relationshipStateChanges: parseRelationshipStateChanges(
        json['relationship_state_changes'],
      ),
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
      event: json['event'] == null
          ? null
          : ActivityEvent.fromJson(json['event'] as Map<String, dynamic>),
      risk: json['risk'] == null
          ? null
          : ActionRisk.fromJson(json['risk'] as Map<String, dynamic>),
      withKind: json['with'] as String?,
    );
  }

  /// §14.3 D85 · riskli aktivitede zarın sonucu; güvenli aktivitede null.
  final ActionRisk? risk;

  /// §14.3 D84 · aktivitenin yapıldığı ilişki türü, tek başınaysa null.
  final String? withKind;

  final CareerState careerState;
  final Map<String, double> appliedCosts;
  final Map<String, dynamic> appliedEffects;
  final List<AttributeChange> attributeChanges;
  final List<TacticChange> tacticChanges;
  final List<RelationshipChange> relationshipChanges;

  /// §13.2 · bir `relationship:` etkisi partneri sıfıra düşürdüyse burada.
  final List<RelationshipStateChange> relationshipStateChanges;
  final List<LedgerEntry> ledgerEntries;

  /// §13.4 · aktivite sırasında bir olay geliştiyse dolu. Aktivitenin kendi
  /// etkileri her hâlükârda uygulandı (INV-3); olay onun DEVAMI, şartı değil.
  final ActivityEvent? event;
}

/// §14.3 D85 · T2 yanıtındaki `risk`: zarın uygulanan şansı ve sonucu.
class ActionRisk {
  const ActionRisk({required this.chance, required this.failed});

  factory ActionRisk.fromJson(Map<String, dynamic> json) {
    return ActionRisk(
      chance: (json['chance'] as num).toDouble(),
      failed: json['failed'] as bool,
    );
  }

  final double chance;
  final bool failed;
}

/// T3 · `POST /careers/{cid}/advance`.
class AdvanceResult {
  const AdvanceResult({
    required this.careerState,
    required this.daysAdvanced,
    required this.stoppedOn,
    required this.stopReason,
    required this.simulatedFixtures,
    required this.simulatedCompetitions,
    required this.ledgerEntries,
    required this.newsCreated,
    required this.repossessed,
    required this.stoppedEvents,
    this.conditionBefore,
    this.conditionAfter,
  });

  factory AdvanceResult.fromJson(Map<String, dynamic> json) {
    final simulated = json['simulated'] as Map<String, dynamic>;
    return AdvanceResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      daysAdvanced: json['days_advanced'] as int,
      stoppedOn: json['stopped_on'] as String,
      // T1's events[].kind ile aynı küme, artı 'none'.
      stopReason: json['stop_reason'] as String,
      simulatedFixtures: simulated['fixtures'] as int,
      simulatedCompetitions: simulated['competitions'] as int,
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
      newsCreated: ((json['news_created'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      repossessed: (json['repossessed'] as List<dynamic>?) ?? const [],
      // §5.0 · sonradan eklenen alanlar; eski bir backend bunları
      // göndermezse ekran yine çalışır (boş liste / null).
      stoppedEvents: ((json['stopped_events'] as List<dynamic>?) ?? const [])
          .map((e) => DayEvent.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      conditionBefore: (json['condition_before'] as num?)?.toInt(),
      conditionAfter: (json['condition_after'] as num?)?.toInt(),
    );
  }

  final CareerState careerState;
  final int daysAdvanced;
  final String stoppedOn;
  final String stopReason;
  final int simulatedFixtures;
  final int simulatedCompetitions;
  final List<LedgerEntry> ledgerEntries;
  final List<String> newsCreated;

  /// D29 · elden çıkan eşyalar — henüz belgelenmiş bir şekli yok, ham liste.
  final List<dynamic> repossessed;

  /// Durulan günün T1 olay listesi. `stopReason` yalnız türü söyler; açılacak
  /// şeyin kimliği (fikstür, teklif) burada.
  final List<DayEvent> stoppedEvents;

  /// §6.6 · çağrının iki yakasındaki kondisyon. Gün gün ilerleyen ekran
  /// çubuğu kendi önceki kopyasını tutmadan canlandırır.
  final int? conditionBefore;
  final int? conditionAfter;

  /// Durulan günde bekleyen sosyal teklifin kimliği, yoksa null.
  String? get stoppedOfferId => _firstRefId(stoppedEvents, 'social_offer');
}

/// T4 `item` alanı.
class PurchasedItem {
  const PurchasedItem({
    required this.catalogId,
    required this.purchasedAt,
    required this.pricePaid,
    required this.upkeepWeekly,
    this.slot,
    this.grade,
    this.equipped = false,
  });

  factory PurchasedItem.fromJson(Map<String, dynamic> json) {
    return PurchasedItem(
      catalogId: json['catalog_id'] as String,
      purchasedAt: json['purchased_at'] as String,
      pricePaid: json['price_paid'] as int,
      upkeepWeekly: json['upkeep_weekly'] as int,
      slot: json['slot'] as String?,
      grade: json['grade'] as int?,
      equipped: json['equipped'] as bool? ?? false,
    );
  }

  final String catalogId;
  final String purchasedAt;
  final int pricePaid;
  final int upkeepWeekly;

  /// §14.2 · yuva boşsa kalem satın alınır alınmaz giyilir (`equipped`).
  final String? slot;
  final int? grade;
  final bool equipped;
}

/// §14.2 · `GET /careers/{cid}/inventory` satırı. Sahiplik ve "üstünde mi"
/// artık sunucunun durumu (INV-66): istemci kendi kümesini bu listeden kurar.
class InventoryItem {
  const InventoryItem({
    required this.catalogId,
    required this.equipped,
    this.slot,
    this.grade,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      catalogId: json['catalog_id'] as String,
      slot: json['slot'] as String?,
      grade: json['grade'] as int?,
      equipped: json['equipped'] as bool? ?? false,
    );
  }

  final String catalogId;
  final String? slot;
  final int? grade;
  final bool equipped;
}

/// §14.2 · equip/unequip yanıtı. `passiveBonus` burada yalnız bilgi için:
/// seviye ölçeği FE'de yeniden yazılmasın diye ekran P1'i tazeler.
class EquipResult {
  const EquipResult({required this.careerState, required this.items});

  factory EquipResult.fromJson(Map<String, dynamic> json) {
    return EquipResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      items: [
        for (final row in (json['items'] as List<dynamic>? ?? const []))
          InventoryItem.fromJson(row as Map<String, dynamic>),
      ],
    );
  }

  final CareerState careerState;
  final List<InventoryItem> items;
}

/// §14.4 · konut kataloğundaki bir satır ve kariyerin ona göre durumu.
/// `kind`: start (ücretsiz) · rent (aylık kira) · hotel (günlük, kulüp verir) ·
/// buy (satın alınır) · holiday (yalnız dinlenme günü).
class Residence {
  const Residence({
    required this.id,
    required this.title,
    required this.kind,
    required this.sleep,
    required this.grade,
    required this.price,
    required this.rentMonthly,
    required this.dailyFee,
    required this.noiseChance,
    required this.description,
    required this.note,
    required this.held,
    required this.active,
    required this.tenure,
    required this.expiresOn,
    required this.upgrades,
    required this.restCondition,
  });

  factory Residence.fromJson(Map<String, dynamic> json) {
    return Residence(
      id: json['residence_id'] as String,
      title: json['title'] as String,
      kind: json['kind'] as String,
      sleep: json['sleep'] as int,
      grade: json['grade'] as int,
      price: json['price'] as int,
      rentMonthly: json['rent_monthly'] as int,
      dailyFee: json['daily_fee'] as int,
      noiseChance: (json['noise_chance'] as num).toDouble(),
      description: json['description'] as String,
      note: json['note'] as String,
      held: json['held'] as bool,
      active: json['active'] as bool,
      tenure: json['tenure'] as String?,
      expiresOn: json['expires_on'] as String?,
      upgrades: (json['upgrades'] as List<dynamic>? ?? const []).cast<String>(),
      restCondition:
          (json['rest'] as Map<String, dynamic>?)?['condition'] as int?,
    );
  }

  final String id;
  final String title;
  final String kind;

  /// Bir gecenin kondisyonu (dokümanın 0,3 katı, §14.4 D88).
  final int sleep;

  /// Karizma derecesi 0-5; yalnız aktifken sayılır.
  final int grade;
  final int price;
  final int rentMonthly;
  final int dailyFee;
  final double noiseChance;
  final String description;
  final String note;
  final bool held;
  final bool active;
  final String? tenure;
  final String? expiresOn;
  final List<String> upgrades;

  /// Tatil mülkünün dinlenme günü kazancı; diğerlerinde null.
  final int? restCondition;

  bool get isHoliday => kind == 'holiday';
  bool get isOwnedHome => kind == 'buy' && held;
}

/// §14.4 D95 · sahip olunan eve takılan geliştirme.
class ResidenceUpgrade {
  const ResidenceUpgrade({
    required this.id,
    required this.title,
    required this.price,
    required this.monthlyFee,
    required this.note,
  });

  factory ResidenceUpgrade.fromJson(Map<String, dynamic> json) {
    return ResidenceUpgrade(
      id: json['upgrade_id'] as String,
      title: json['title'] as String,
      price: json['price'] as int,
      monthlyFee: (json['monthly_fee'] as int?) ?? 0,
      note: json['note'] as String,
    );
  }

  final String id;
  final String title;
  final int price;
  final int monthlyFee;
  final String note;
}

/// §14.4 · `GET/POST /careers/{cid}/housing…`. Her yazan uç `career_state` ve
/// güncel konut resmini birlikte döner (D28); `conditionTotal` yarınki gecenin
/// kondisyon değeri, `restEffects` yalnız dinlenme gününde dolu.
class HousingState {
  const HousingState({
    required this.careerState,
    required this.activeResidenceId,
    required this.residences,
    required this.upgrades,
    required this.conditionTotal,
    required this.noiseChance,
    required this.moved,
  });

  factory HousingState.fromJson(Map<String, dynamic> json) {
    final recovery = json['condition_recovery'] as Map<String, dynamic>;
    return HousingState(
      careerState: CareerState.fromJson(
        json['career_state'] as Map<String, dynamic>,
      ),
      activeResidenceId: json['active_residence_id'] as String,
      residences: [
        for (final row in (json['residences'] as List<dynamic>))
          Residence.fromJson(row as Map<String, dynamic>),
      ],
      upgrades: [
        for (final row in (json['upgrades'] as List<dynamic>))
          ResidenceUpgrade.fromJson(row as Map<String, dynamic>),
      ],
      conditionTotal: (recovery['total'] as num).toInt(),
      noiseChance:
          ((recovery['noise'] as Map<String, dynamic>)['chance'] as num)
              .toDouble(),
      moved: json['moved'] as bool? ?? false,
    );
  }

  final CareerState careerState;
  final String activeResidenceId;
  final List<Residence> residences;
  final List<ResidenceUpgrade> upgrades;
  final int conditionTotal;
  final double noiseChance;
  final bool moved;

  Residence get active =>
      residences.firstWhere((r) => r.id == activeResidenceId);
}

/// T4 · `POST /careers/{cid}/purchases`.
class PurchaseResult {
  const PurchaseResult({
    required this.careerState,
    required this.item,
    required this.ledgerEntries,
  });

  factory PurchaseResult.fromJson(Map<String, dynamic> json) {
    return PurchaseResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      item: PurchasedItem.fromJson(json['item'] as Map<String, dynamic>),
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
    );
  }

  final CareerState careerState;
  final PurchasedItem item;
  final List<LedgerEntry> ledgerEntries;
}

// ---------------------------------------------------------------------------
// §5.6 Maç — M1-M3
// ---------------------------------------------------------------------------

/// M1 · `GET /careers/{cid}/matches/next`. `enginePayload` **olduğu gibi**
/// match_engine'e iletilir (E11) — FE içeriğini yorumlamaz (§5.6).
class NextCareerMatch {
  const NextCareerMatch({
    required this.fixtureId,
    required this.competition,
    required this.kickoffAt,
    required this.userSide,
    this.squadStatus = 'first_eleven',
    this.formationId,
    this.coachInstruction,
    required this.enginePayload,
  });

  factory NextCareerMatch.fromJson(Map<String, dynamic> json) {
    final instruction = json['coach_instruction'] as Map<String, dynamic>?;
    return NextCareerMatch(
      fixtureId: json['fixture_id'] as String,
      competition:
          CompetitionRef.fromJson(json['competition'] as Map<String, dynamic>),
      kickoffAt: json['kickoff_at'] as String,
      userSide: json['user_side'] as String,
      squadStatus: json['squad_status'] as String? ?? 'first_eleven',
      formationId: json['formation_id'] as String?,
      coachInstruction:
          instruction == null ? null : CoachInstruction.fromJson(instruction),
      enginePayload: json['engine_payload'] as Map<String, dynamic>,
    );
  }

  final String fixtureId;
  final CompetitionRef competition;
  final String kickoffAt;
  final String userSide;

  /// §12.2 · `first_eleven` | `bench`. `out` buraya hiç gelmez — o fikstür
  /// M1'de teklif edilmiyor. Alanı tanımayan bir sürüme karşı varsayılan
  /// ilk 11: §12.2 öncesi davranış buydu.
  final String squadStatus;

  /// Kullanıcının takımının dizilişi (`lib/game/formations.g.dart`'taki id).
  /// Nullable: dizilişleri bilmeyen bir career_engine sürümüne karşı ekran
  /// çökmemeli — o durumda varsayılan diziliş çizilir.
  final String? formationId;

  /// §12.10 · antrenörün bu maç için beklediği oyun tarzı. Nullable: alanı
  /// tanımayan bir sürüme karşı ekran çökmemeli — `pre_match_screen.dart`
  /// bu durumda eski yoluna, C3'e (hub) düşer.
  final CoachInstruction? coachInstruction;

  /// `engine_payload` motora olduğu gibi POST'lanır; [formationId] ve
  /// [coachInstruction] onun dışındadır, motor ne diziliş ne rol bilir.
  final Map<String, dynamic> enginePayload;
}

/// M1 `coach_instruction` — §12.10. `role_name`/`position` FE'nin bunun için
/// ayrıca C3'e (hub) gitmesini gerektiren alanlardı; artık M1'de geliyor.
class CoachInstruction {
  const CoachInstruction({
    required this.focus,
    required this.label,
    required this.roleId,
    required this.roleName,
    required this.position,
    required this.source,
    this.positionGroup,
  });

  factory CoachInstruction.fromJson(Map<String, dynamic> json) {
    return CoachInstruction(
      focus: json['focus'] as String?,
      label: json['label'] as String,
      roleId: json['role_id'] as String?,
      roleName: json['role_name'] as String?,
      position: json['position'] as String?,
      positionGroup: json['position_group'] as String?,
      source: json['source'] as String,
    );
  }

  /// `"attack"|"defend"|"tactical"|null` — API_CONTRACT §6.1'in `focus`'uyla
  /// aynı ölçek; `null` = "farketmez".
  final String? focus;

  /// Türkçe etiket — `Hücum`/`Savunma`/`Taktik`/`Farketmez`, §8.1'in
  /// `directive_options.focus` etiketleriyle aynı dört string.
  final String label;

  final String? roleId;
  final String? roleName;
  final String? position;

  /// §12.14 · Mevki grubunun wire hâli — `"dc"|"fb"|"dm"|"mc"|"amc"|"wing"|"st"`.
  /// Bu bloktaki tek alan ki maç motoru onu **tüketiyor**: E2 `/start`'ın
  /// `position` alanına olduğu gibi gidiyor ve hangi senaryonun teklif
  /// edileceğini eğiyor (API_CONTRACT §6.8). Rolü olmayan bir kariyerde null;
  /// motor null'ı "eğilim yok" diye okuyor.
  final String? positionGroup;

  /// `"role"` | `"coach_talk"` — talimat rolden mi türedi, yoksa kabul
  /// edilmiş bir M4 talebiyle mi değişti.
  final String source;
}

/// M2/M3 `fixture` alt nesnesi.
class FixtureStatus {
  const FixtureStatus({
    required this.fixtureId,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  factory FixtureStatus.fromJson(Map<String, dynamic> json) {
    final score = json['score'] as Map<String, dynamic>?;
    return FixtureStatus(
      fixtureId: json['fixture_id'] as String,
      status: json['status'] as String,
      homeScore: score?['home'] as int?,
      awayScore: score?['away'] as int?,
    );
  }

  final String fixtureId;
  final String status;
  final int? homeScore;
  final int? awayScore;
}

/// M2 `standing_delta`.
class StandingDelta {
  const StandingDelta({this.rankBefore, this.rankAfter});

  factory StandingDelta.fromJson(Map<String, dynamic> json) {
    return StandingDelta(
      rankBefore: json['rank_before'] as int?,
      rankAfter: json['rank_after'] as int?,
    );
  }

  final int? rankBefore;
  final int? rankAfter;
}

/// M2 `player_stat_delta`. `assists` yoksa (henüz eski bir backend'e karşı
/// konuşuluyorsa) `0` varsayılır — career_engine v1.4 öncesi bu alanı hiç
/// göndermiyordu.
class PlayerStatDelta {
  const PlayerStatDelta({
    required this.appearances,
    required this.goals,
    required this.assists,
    required this.minutes,
  });

  factory PlayerStatDelta.fromJson(Map<String, dynamic> json) {
    return PlayerStatDelta(
      appearances: json['appearances'] as int,
      goals: json['goals'] as int,
      assists: (json['assists'] as int?) ?? 0,
      minutes: json['minutes'] as int,
    );
  }

  final int appearances;
  final int goals;
  final int assists;
  final int minutes;
}

/// M2 · `POST /careers/{cid}/matches/{fid}/result`.
class MatchResultResponse {
  const MatchResultResponse({
    required this.careerState,
    required this.fixture,
    required this.standingDelta,
    required this.playerStatDelta,
    required this.relationshipChanges,
    required this.ledgerEntries,
    required this.newsCreated,
  });

  factory MatchResultResponse.fromJson(Map<String, dynamic> json) {
    return MatchResultResponse(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      fixture: FixtureStatus.fromJson(json['fixture'] as Map<String, dynamic>),
      standingDelta: StandingDelta.fromJson(
          json['standing_delta'] as Map<String, dynamic>? ?? const {}),
      playerStatDelta: PlayerStatDelta.fromJson(
          json['player_stat_delta'] as Map<String, dynamic>),
      // Antrenör/Takım/Taraftarlar/Medya için maçın yarattığı kalıcı ±5
      // delta (§5.6 M2, career_engine CONTRACT.md). Yoksa (eski backend)
      // boş liste — ekran bu bölümü hiç çizmez.
      relationshipChanges: ((json['relationship_changes'] as List<dynamic>?) ??
              const [])
          .map((e) => RelationshipChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
      newsCreated: ((json['news_created'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
    );
  }

  final CareerState careerState;
  final FixtureStatus fixture;
  final StandingDelta standingDelta;
  final PlayerStatDelta playerStatDelta;
  final List<RelationshipChange> relationshipChanges;
  final List<LedgerEntry> ledgerEntries;
  final List<String> newsCreated;
}

/// M3 · `POST /careers/{cid}/matches/{fid}/abandon`.
class AbandonResult {
  const AbandonResult({required this.careerState, required this.fixture});

  factory AbandonResult.fromJson(Map<String, dynamic> json) {
    return AbandonResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      fixture: FixtureStatus.fromJson(json['fixture'] as Map<String, dynamic>),
    );
  }

  final CareerState careerState;
  final FixtureStatus fixture;
}

// ---------------------------------------------------------------------------
// §5.7 İçerik — N1-N3
// ---------------------------------------------------------------------------

/// N1 `items[]` satırı.
class NewsSummary {
  const NewsSummary({
    required this.newsId,
    required this.publishedAt,
    required this.category,
    required this.title,
    required this.source,
    required this.excerpt,
    this.fixtureId,
  });

  factory NewsSummary.fromJson(Map<String, dynamic> json) {
    return NewsSummary(
      newsId: json['news_id'] as String,
      publishedAt: json['published_at'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      source: json['source'] as String,
      excerpt: json['excerpt'] as String,
      fixtureId: json['fixture_id'] as String?,
    );
  }

  final String newsId;
  final String publishedAt;
  final String category;
  final String title;
  final String source;

  /// Gövdenin ilk paragrafı — içerik olduğu için gönderilir (§1.3).
  final String excerpt;
  final String? fixtureId;
}

/// N1 · `GET /careers/{cid}/news`.
class NewsFeed {
  const NewsFeed({required this.items, this.nextBefore});

  factory NewsFeed.fromJson(Map<String, dynamic> json) {
    return NewsFeed(
      items: (json['items'] as List<dynamic>)
          .map((e) => NewsSummary.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      nextBefore: json['next_before'] as String?,
    );
  }

  final List<NewsSummary> items;
  final String? nextBefore;
}

/// N2 · `GET /careers/{cid}/news/{nid}` — N1'in bütün alanları + tam gövde.
class NewsDetail {
  const NewsDetail({required this.summary, required this.body});

  factory NewsDetail.fromJson(Map<String, dynamic> json) {
    return NewsDetail(
      summary: NewsSummary.fromJson(json),
      body: json['body'] as String,
    );
  }

  final NewsSummary summary;

  /// `\n\n` ile ayrılmış paragraflar.
  final String body;
}

/// N3 · `GET /catalog/{kind}` tek kalemi. Üç kalem türü de ortak alanları
/// (`catalogId/title/description/costs/effects`) taşır; türe özel alanlar
/// (`family`/`drill`, `durationLabel`/`group`, `category`/`price`/…) ham
/// JSON olarak [raw]'da kalır — her ekran kendi türünü orada okur.
class CatalogItem {
  const CatalogItem({
    required this.catalogId,
    required this.title,
    this.description,
    required this.costs,
    required this.effects,
    required this.raw,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      catalogId: json['catalog_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      costs: ((json['costs'] as Map<String, dynamic>?) ?? const {}).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      effects: (json['effects'] as Map<String, dynamic>?) ?? const {},
      raw: json,
    );
  }

  final String catalogId;
  final String title;
  final String? description;

  /// Günün bütçesinden çeker (§6.2) — `time`/`energy`.
  final Map<String, double> costs;

  /// Dünyayı değiştirir: `attribute:<key>` · `tactic:<key>` · `condition` ·
  /// `energy` · `money` · `fame:<scope>` · `relationship:<rid>`. Değeri
  /// `null` olan anahtar henüz aktif değildir (⟦AÇIK-9⟧ vb.) — uygulanmaz.
  final Map<String, dynamic> effects;

  final Map<String, dynamic> raw;

  /// `training` kataloğu — 'saha' | 'kişi' | 'taktik'.
  String? get family => raw['family'] as String?;

  /// `training` kataloğu — [TrainingDrill] enum string karşılığı; `null` ise
  /// mini-oyunu yok. `kişi` kalemleri bugün bu yüzden "Yakında" görünür;
  /// `taktik` kalemleri de `drill: null` ama training_screen.dart onları
  /// doğrudan uygular (§12.11) — ayrım `family`'de, burada değil.
  String? get drill => raw['drill'] as String?;

  /// `lifestyle` kataloğu — 'Tüm gece', '2 saat' gibi.
  String? get durationLabel => raw['duration_label'] as String?;

  /// `lifestyle`/`shop` kataloğu — grup/kategori başlığı.
  String? get group => raw['group'] as String? ?? raw['category'] as String?;

  /// D42 · `attribute_key` -> gereken seviye (0-10). Boşsa kapı yok.
  /// Eşiği FE **karşılaştırır**, ama son sözü BE söyler: T2/T4 çağrısı aynı
  /// kontrolü tekrarlar (INV-30), buradaki gri kart yalnızca kullanıcıyı
  /// boşuna dokunmaktan kurtarır.
  Map<String, int> get requires => _requiresOf(raw);

  /// §14.3 · 'S' tek başına, 'B' biriyle, 'S/B' ikisi de. Alanı olmayan
  /// (eski) aktivite tek başınadır.
  String get mode => raw['mode'] as String? ?? 'S';

  /// §14.3 D84 · aktivitenin yapılabileceği ilişki türleri (`relationship_id`).
  List<String> get withKinds =>
      ((raw['with'] as List<dynamic>?) ?? const []).cast<String>();

  /// §14.3 D85 · ters gidebilen aktivite (toplu/şaka/poker/paylaşım).
  bool get risky => raw['risk'] != null;

  /// §14.2 · giyilebilir kalemin yuvası ('watch', 'shoes'…). Null ise kalem
  /// giyilmez (gayrimenkul, yatırım): her zaman sayılır.
  String? get slot => raw['slot'] as String?;

  /// §14.2 · 1-5 derece; yalnızca yuvası olan kalemlerde dolu.
  int? get grade => raw['grade'] as int?;

  /// §14.2 D82 · 'shop' satın alınır, 'grant' bir olay/sponsorluk verir.
  bool get grantOnly => raw['acquire'] == 'grant';

  /// `shop` kataloğu.
  int? get price => raw['price'] as int?;
  int? get upkeepWeekly => raw['upkeep_weekly'] as int?;
  String? get note => raw['note'] as String?;

  /// §13.3 · sahip olunan kalemin bir kişi niteliğine kattığı pasif bonus.
  /// `daily_effects`'ten farklı: hiçbir şey YAZMAZ, okuma anında tabanın
  /// üstüne biner ve eşya elden çıkınca kaybolur.
  Map<String, double> get passiveEffects =>
      ((raw['passive_effects'] as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toDouble()));

  /// §13.4 · bu aktivitenin olay doğurma sıklığı. Yalnızca `lifestyle`
  /// kalemlerinde dolu.
  double? get eventChance => (raw['event_chance'] as num?)?.toDouble();

  /// §12.12 · sahip olunan bir kalemin gün döngüsüne kattığı pasif etkiler.
  /// (`condition`/`energy`/`fame:overall`). `note`'un aksine bu canlı: bir
  /// kalemin gerçekte ne yaptığı, vitrin metninden ayrı okunabiliyor.
  Map<String, dynamic> get dailyEffects =>
      (raw['daily_effects'] as Map<String, dynamic>?) ?? const {};
}

/// N3 · `GET /catalog/{kind}`.
Map<String, int> _requiresOf(Map<String, dynamic> json) {
  final raw = json['requires'] as Map<String, dynamic>?;
  if (raw == null || raw.isEmpty) return const {};
  return raw.map((key, value) => MapEntry(key, (value as num).toInt()));
}

/// N3 `GET /catalog/dialogue` · bir ağacın tek yaprağı. **Yalnızca eşik**
/// taşır — `relationship_delta`/`attribute_effects` bu uçtan hiç gelmez
/// (§5.7): ödül tablosu sunucuda kalır.
class DialogueLeaf {
  const DialogueLeaf({required this.leafId, required this.requires});

  factory DialogueLeaf.fromJson(Map<String, dynamic> json) {
    return DialogueLeaf(
      leafId: json['leaf_id'] as String,
      requires: _requiresOf(json),
    );
  }

  final String leafId;
  final Map<String, int> requires;
}

/// N3 `GET /catalog/dialogue` · bir diyalog ağacının eşik künyesi.
class DialogueCatalogEntry {
  const DialogueCatalogEntry({
    required this.dialogueId,
    required this.relationshipId,
    required this.leaves,
  });

  factory DialogueCatalogEntry.fromJson(Map<String, dynamic> json) {
    return DialogueCatalogEntry(
      dialogueId: json['dialogue_id'] as String,
      relationshipId: json['relationship_id'] as String,
      leaves: ((json['leaves'] as List<dynamic>?) ?? const [])
          .map((e) => DialogueLeaf.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String dialogueId;
  final String relationshipId;
  final List<DialogueLeaf> leaves;

  /// `leaf_id` -> `requires`; eşiği olmayan yaprak da haritada yer alır
  /// (boş sözlükle), böylece "bilinmeyen yaprak" ile "kapısız yaprak"
  /// karışmaz.
  Map<String, Map<String, int>> get requiresByLeaf => {
        for (final leaf in leaves) leaf.leafId: leaf.requires,
      };
}

class DialogueCatalog {
  const DialogueCatalog({required this.items});

  factory DialogueCatalog.fromJson(Map<String, dynamic> json) {
    return DialogueCatalog(
      items: (json['items'] as List<dynamic>)
          .map((e) => DialogueCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<DialogueCatalogEntry> items;

  DialogueCatalogEntry? byId(String dialogueId) {
    for (final item in items) {
      if (item.dialogueId == dialogueId) return item;
    }
    return null;
  }
}

class Catalog {
  const Catalog({required this.items});

  factory Catalog.fromJson(Map<String, dynamic> json) {
    return Catalog(
      items: (json['items'] as List<dynamic>)
          .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<CatalogItem> items;
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

// ---------------------------------------------------------------------------
// §5.3 W5 — takvim
// ---------------------------------------------------------------------------

/// W5 `days[].marks[]` satırı.
///
/// `kind`, T1'in `events[].kind`'ından **ayrı** bir sözlüktür: T1 "bugün ne
/// doğru", W5 "bu güne ne planlanmış" sorusunu cevaplar. Bilinen türler:
/// `match` · `wage` · `cup_round` · `contract_expiry` · `season_start` ·
/// `season_end`. Tanınmayan bir tür sessizce yok sayılır (§5.0).
class CalendarMark {
  const CalendarMark({
    required this.kind,
    this.refId,
    this.home,
    this.away,
    this.competition,
    this.kickoffAt,
    this.status,
    this.homeScore,
    this.awayScore,
    this.isUserMatch = false,
    this.roundNo,
    this.stage,
    this.drawn,
  });

  factory CalendarMark.fromJson(Map<String, dynamic> json) {
    final home = json['home'] as Map<String, dynamic>?;
    final away = json['away'] as Map<String, dynamic>?;
    final competition = json['competition'] as Map<String, dynamic>?;
    final score = json['score'] as Map<String, dynamic>?;
    return CalendarMark(
      kind: json['kind'] as String,
      refId: json['ref_id'] as String?,
      home: home == null ? null : TeamRef.fromJson(home),
      away: away == null ? null : TeamRef.fromJson(away),
      competition:
          competition == null ? null : CompetitionRef.fromJson(competition),
      kickoffAt: json['kickoff_at'] as String?,
      status: json['status'] as String?,
      homeScore: (score?['home'] as num?)?.toInt(),
      awayScore: (score?['away'] as num?)?.toInt(),
      isUserMatch: json['is_user_match'] as bool? ?? false,
      roundNo: (json['round_no'] as num?)?.toInt(),
      stage: json['stage'] as String?,
      drawn: json['drawn'] as bool?,
    );
  }

  final String kind;
  final String? refId;

  // kind == 'match'
  final TeamRef? home;
  final TeamRef? away;
  final CompetitionRef? competition;
  final String? kickoffAt;
  final String? status;
  final int? homeScore;
  final int? awayScore;
  final bool isUserMatch;

  // kind == 'cup_round' — kura çekilmeden önce de dolu (§5.3).
  final int? roundNo;
  final String? stage;
  final bool? drawn;

  bool get isMatch => kind == 'match';
  bool get isPlayed => status == 'played';
}

/// W5 `days[]` satırı — yalnızca en az bir işareti olan günler döner.
class CalendarDay {
  const CalendarDay({required this.date, required this.marks});

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    return CalendarDay(
      date: json['date'] as String,
      marks: (json['marks'] as List<dynamic>)
          .map((e) => CalendarMark.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String date;
  final List<CalendarMark> marks;
}

/// W5 `season` alt nesnesi — sezon sınırlarını döndüren tek uç burasıdır.
class CalendarSeason {
  const CalendarSeason({
    required this.seasonId,
    required this.startsOn,
    required this.endsOn,
  });

  factory CalendarSeason.fromJson(Map<String, dynamic> json) {
    return CalendarSeason(
      seasonId: json['season_id'] as String,
      startsOn: json['starts_on'] as String,
      endsOn: json['ends_on'] as String,
    );
  }

  final String seasonId;
  final String startsOn;
  final String endsOn;
}

/// W5 · `GET /careers/{cid}/calendar`.
class CalendarPage {
  const CalendarPage({
    required this.from,
    required this.to,
    required this.today,
    required this.days,
    this.season,
  });

  factory CalendarPage.fromJson(Map<String, dynamic> json) {
    final season = json['season'] as Map<String, dynamic>?;
    return CalendarPage(
      from: json['from'] as String,
      to: json['to'] as String,
      today: json['today'] as String,
      season: season == null ? null : CalendarSeason.fromJson(season),
      days: (json['days'] as List<dynamic>)
          .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String from;
  final String to;
  final String today;
  final CalendarSeason? season;
  final List<CalendarDay> days;

  /// Tarihe göre işaretler — grid her hücre için tek bir arama yapar.
  Map<String, List<CalendarMark>> get marksByDate => {
        for (final day in days) day.date: day.marks,
      };
}

// ---------------------------------------------------------------------------
// §5.4 R4-R6 — sosyal teklifler
// ---------------------------------------------------------------------------

/// R4 `offers[]` satırı. Metin BE'de yazarlanır (§5.4); `accept`/`decline`
/// ödülleri **gönderilmez**, yalnız kapı (`costs`/`requires`) gelir.
class SocialOffer {
  const SocialOffer({
    required this.offerId,
    required this.templateId,
    required this.relationshipId,
    required this.title,
    required this.body,
    required this.acceptLabel,
    required this.declineLabel,
    required this.openedOn,
    required this.status,
    required this.costs,
    required this.requires,
    this.relationship,
    this.resolvedOn,
  });

  factory SocialOffer.fromJson(Map<String, dynamic> json) {
    final relationship = json['relationship'] as Map<String, dynamic>?;
    return SocialOffer(
      offerId: json['offer_id'] as String,
      templateId: json['template_id'] as String,
      relationshipId: json['relationship_id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      acceptLabel: json['accept_label'] as String? ?? 'Kabul et',
      declineLabel: json['decline_label'] as String? ?? 'Reddet',
      openedOn: json['opened_on'] as String,
      status: json['status'] as String,
      resolvedOn: json['resolved_on'] as String?,
      costs: ((json['costs'] as Map<String, dynamic>?) ?? const {}).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      requires: ((json['requires'] as Map<String, dynamic>?) ?? const {}).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      relationship: relationship == null
          ? null
          : SocialOfferContact.fromJson(relationship),
    );
  }

  final String offerId;
  final String templateId;
  final String relationshipId;
  final String title;
  final String body;
  final String acceptLabel;
  final String declineLabel;
  final String openedOn;
  final String status;
  final String? resolvedOn;

  /// Kabulün günden götüreceği kaynaklar; reddetmek hiçbir şey harcamaz.
  final Map<String, double> costs;

  /// D42 · kabul için gereken nitelik seviyeleri. Boşsa kapı yok.
  final Map<String, int> requires;

  final SocialOfferContact? relationship;

  bool get isOpen => status == 'open';
}

/// R4 `offers[].relationship` — teklifi yapan kişinin kartı.
class SocialOfferContact {
  const SocialOfferContact({
    required this.relationshipId,
    required this.kind,
    required this.category,
    required this.score,
    required this.personName,
    required this.contactName,
  });

  factory SocialOfferContact.fromJson(Map<String, dynamic> json) {
    return SocialOfferContact(
      relationshipId: json['relationship_id'] as String,
      kind: json['kind'] as String,
      category: json['category'] as String,
      score: (json['score'] as num).toInt(),
      personName: json['person_name'] as String? ?? '',
      contactName: json['contact_name'] as String? ?? '',
    );
  }

  final String relationshipId;
  final String kind;
  final String category;
  final int score;
  final String personName;
  final String contactName;
}

/// R5/R6 · teklif yanıtı. R3'ün şekli, artı çözümlenmiş `offer`. `plan`,
/// §12.8/D58'in `plan_days_ahead` taşıyan bir şablonu kabul edince yazdığı
/// randevu — taşımayan şablonlarda ve her reddetmede null kalır.
class SocialOfferResult {
  const SocialOfferResult({
    required this.careerState,
    required this.offer,
    this.plan,
    required this.relationshipChanges,
    required this.attributeChanges,
    required this.ledgerEntries,
  });

  factory SocialOfferResult.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>?;
    return SocialOfferResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      offer: SocialOffer.fromJson(json['offer'] as Map<String, dynamic>),
      plan: plan == null ? null : SocialPlan.fromJson(plan),
      relationshipChanges:
          ((json['relationship_changes'] as List<dynamic>?) ?? const [])
              .map((e) => RelationshipChange.fromJson(e as Map<String, dynamic>))
              .toList(growable: false),
      attributeChanges: ((json['attribute_changes'] as List<dynamic>?) ?? const [])
          .map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
    );
  }

  final CareerState careerState;
  final SocialOffer offer;
  final SocialPlan? plan;
  final List<RelationshipChange> relationshipChanges;
  final List<AttributeChange> attributeChanges;
  final List<LedgerEntry> ledgerEntries;
}

// ---------------------------------------------------------------------------
// §12.8 D58 — sosyal planlar (ileri tarihli teklif)
// ---------------------------------------------------------------------------

/// Bir `plan_days_ahead` şablonunun kabulünden doğan randevu. Sponsorluk
/// yükümlülüğünün aksine (`SponsorshipObligation`, yalnızca id/tarih —
/// başlık/gövde sahibi anlaşma) kendi `title`/`body`/`costs`'unu taşır: bir
/// deal sarmalayıcısı yok, R4'ün `SocialOffer`'ı gibi kendi başına yeterli.
class SocialPlan {
  const SocialPlan({
    required this.planId,
    required this.offerId,
    required this.templateId,
    required this.relationshipId,
    required this.title,
    required this.body,
    required this.dueOn,
    required this.status,
    required this.costs,
    this.relationship,
  });

  factory SocialPlan.fromJson(Map<String, dynamic> json) {
    final relationship = json['relationship'] as Map<String, dynamic>?;
    return SocialPlan(
      planId: json['plan_id'] as String,
      offerId: json['offer_id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      relationshipId: json['relationship_id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      dueOn: json['due_on'] as String,
      status: json['status'] as String,
      costs: ((json['costs'] as Map<String, dynamic>?) ?? const {}).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      relationship: relationship == null
          ? null
          : SocialOfferContact.fromJson(relationship),
    );
  }

  final String planId;
  final String offerId;
  final String templateId;
  final String relationshipId;
  final String title;
  final String body;
  final String dueOn;
  final String status;
  final Map<String, double> costs;
  final SocialOfferContact? relationship;

  bool get isPending => status == 'pending';
}

/// `attend`/`skip` yanıtı — R5/R6 ile aynı zarf, `offer` yerine `plan`.
class SocialPlanResult {
  const SocialPlanResult({
    required this.careerState,
    required this.plan,
    required this.relationshipChanges,
    required this.attributeChanges,
    required this.ledgerEntries,
  });

  factory SocialPlanResult.fromJson(Map<String, dynamic> json) {
    return SocialPlanResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      plan: SocialPlan.fromJson(json['plan'] as Map<String, dynamic>),
      relationshipChanges:
          ((json['relationship_changes'] as List<dynamic>?) ?? const [])
              .map((e) => RelationshipChange.fromJson(e as Map<String, dynamic>))
              .toList(growable: false),
      attributeChanges: ((json['attribute_changes'] as List<dynamic>?) ?? const [])
          .map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
    );
  }

  final CareerState careerState;
  final SocialPlan plan;
  final List<RelationshipChange> relationshipChanges;
  final List<AttributeChange> attributeChanges;
  final List<LedgerEntry> ledgerEntries;
}

// ---------------------------------------------------------------------------
// §12.9 D59 — çakışan sosyal planlar (iki taraflı seçim)
// ---------------------------------------------------------------------------

/// Çakışmanın bir yakası. `SocialPlan`/`SocialOffer`'ın aksine `costs` ve
/// deltalar yok: çakışma hiçbir şey harcamıyor (D60) ve ödül tablosu tel
/// üzerine çıkmıyor (§5.7, §5.4 R4). Barların oynadığı sayılar seçimden
/// **sonra** `SocialConflictResult.relationshipChanges`'ten geliyor.
class SocialConflictSide {
  const SocialConflictSide({
    required this.refId,
    required this.relationshipId,
    required this.templateId,
    required this.title,
    required this.body,
    this.relationship,
  });

  factory SocialConflictSide.fromJson(Map<String, dynamic> json) {
    final relationship = json['relationship'] as Map<String, dynamic>?;
    return SocialConflictSide(
      refId: json['ref_id'] as String,
      relationshipId: json['relationship_id'] as String,
      templateId: json['template_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      relationship: relationship == null
          ? null
          : SocialOfferContact.fromJson(relationship),
    );
  }

  /// `source`'a göre bir `plan_id` ya da `offer_id`; seçim bununla yapılıyor.
  final String refId;

  final String relationshipId;
  final String templateId;
  final String title;
  final String body;
  final SocialOfferContact? relationship;
}

/// Aynı akşamı isteyen iki davet. `sides` daima iki elemanlıdır.
class SocialConflict {
  const SocialConflict({
    required this.conflictId,
    required this.source,
    required this.dueOn,
    required this.status,
    required this.sides,
    this.chosenRef,
  });

  factory SocialConflict.fromJson(Map<String, dynamic> json) {
    return SocialConflict(
      conflictId: json['conflict_id'] as String,
      source: json['source'] as String,
      dueOn: json['due_on'] as String,
      status: json['status'] as String,
      chosenRef: json['chosen_ref'] as String?,
      sides: ((json['sides'] as List<dynamic>?) ?? const [])
          .map((e) => SocialConflictSide.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String conflictId;

  /// `'plan'` — ikisine de söz verilmişti, elenen ağır öder; `'offer'` — iki
  /// kişi birbirinden habersiz sormuş, elenen hafif atlatır.
  final String source;

  final String dueOn;
  final String status;
  final String? chosenRef;
  final List<SocialConflictSide> sides;

  bool get isOpen => status == 'open';
}

/// `choose` yanıtı — R5/R6 zarfı, `offer` yerine `conflict`.
///
/// `relationshipChanges` **iki elemanlıdır** (INV-52): biri seçilen tarafın
/// artısı, biri elenenin eksisi. Ekranın iki barı doğrudan bunların
/// `before`/`after`'ından oynuyor.
class SocialConflictResult {
  const SocialConflictResult({
    required this.careerState,
    required this.conflict,
    required this.relationshipChanges,
    required this.attributeChanges,
    required this.ledgerEntries,
  });

  factory SocialConflictResult.fromJson(Map<String, dynamic> json) {
    return SocialConflictResult(
      careerState:
          CareerState.fromJson(json['career_state'] as Map<String, dynamic>),
      conflict:
          SocialConflict.fromJson(json['conflict'] as Map<String, dynamic>),
      relationshipChanges:
          ((json['relationship_changes'] as List<dynamic>?) ?? const [])
              .map((e) => RelationshipChange.fromJson(e as Map<String, dynamic>))
              .toList(growable: false),
      attributeChanges: ((json['attribute_changes'] as List<dynamic>?) ?? const [])
          .map((e) => AttributeChange.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      ledgerEntries: _parseLedgerEntries(json['ledger_entries']),
    );
  }

  final CareerState careerState;
  final SocialConflict conflict;
  final List<RelationshipChange> relationshipChanges;
  final List<AttributeChange> attributeChanges;
  final List<LedgerEntry> ledgerEntries;

  /// Bu ilişkinin bu seçimde nereden nereye gittiği; yoksa null.
  RelationshipChange? changeFor(String relationshipId) {
    for (final change in relationshipChanges) {
      if (change.relationshipId == relationshipId) return change;
    }
    return null;
  }
}
