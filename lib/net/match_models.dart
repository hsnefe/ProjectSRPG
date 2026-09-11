/// match_engine API'sinin JSON gövdelerine 1:1 karşılık gelen düz veri
/// sınıfları (bkz. `API_CONTRACT.md` §3, §6, §8). Alan adları contract'taki
/// snake_case anahtarlarla eşleşecek şekilde elle yazılmıştır; kod üretimi
/// kullanılmaz (bu depoda json_serializable/freezed yok).
library;

class TeamInfo {
  const TeamInfo({required this.name});

  final String name;

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(name: json['name'] as String);
  }
}

class MatchTeams {
  const MatchTeams({required this.home, required this.away});

  final TeamInfo home;
  final TeamInfo away;

  factory MatchTeams.fromJson(Map<String, dynamic> json) {
    return MatchTeams(
      home: TeamInfo.fromJson(json['home'] as Map<String, dynamic>),
      away: TeamInfo.fromJson(json['away'] as Map<String, dynamic>),
    );
  }
}

class TeamTactic {
  const TeamTactic({required this.code, required this.label});

  final String code;
  final String label;

  factory TeamTactic.fromJson(Map<String, dynamic> json) {
    return TeamTactic(
      code: json['code'] as String,
      label: json['label'] as String,
    );
  }
}

/// `GET /matches/next`'in `stamina` bloğu — kondisyon barının taban/tavan
/// sabitleri buradan gelir, FE'de hardcode edilmez (§6.4).
class StaminaCatalog {
  const StaminaCatalog({
    required this.current,
    required this.floor,
    required this.ceiling,
    required this.substitutionBonus,
  });

  final int current;
  final int floor;
  final int ceiling;
  final int substitutionBonus;

  factory StaminaCatalog.fromJson(Map<String, dynamic> json) {
    return StaminaCatalog(
      current: json['current'] as int,
      floor: json['floor'] as int,
      ceiling: json['ceiling'] as int,
      substitutionBonus: json['substitution_bonus'] as int,
    );
  }
}

class EffortOption {
  const EffortOption({
    required this.value,
    required this.label,
    required this.offersPerMatch,
    required this.staminaMultiplier,
    required this.projectedEndStamina,
  });

  final int value;
  final String label;
  final int offersPerMatch;
  final double staminaMultiplier;
  final int projectedEndStamina;

  factory EffortOption.fromJson(Map<String, dynamic> json) {
    return EffortOption(
      value: json['value'] as int,
      label: json['label'] as String,
      offersPerMatch: json['offers_per_match'] as int,
      staminaMultiplier: (json['stamina_multiplier'] as num).toDouble(),
      projectedEndStamina: json['projected_end_stamina'] as int,
    );
  }
}

class AggressionOption {
  const AggressionOption({
    required this.value,
    required this.label,
    required this.foulMultiplier,
  });

  final int value;
  final String label;
  final double foulMultiplier;

  factory AggressionOption.fromJson(Map<String, dynamic> json) {
    return AggressionOption(
      value: json['value'] as int,
      label: json['label'] as String,
      foulMultiplier: (json['foul_multiplier'] as num).toDouble(),
    );
  }
}

class FocusOption {
  const FocusOption({required this.value, required this.label});

  /// `attack`|`defend`|`tactical`|`null` — `null` "farketmez" seçeneğidir.
  final String? value;
  final String label;

  factory FocusOption.fromJson(Map<String, dynamic> json) {
    return FocusOption(
      value: json['value'] as String?,
      label: json['label'] as String,
    );
  }
}

class DirectiveOptions {
  const DirectiveOptions({
    required this.effort,
    required this.aggression,
    required this.focus,
  });

  final List<EffortOption> effort;
  final List<AggressionOption> aggression;
  final List<FocusOption> focus;

  factory DirectiveOptions.fromJson(Map<String, dynamic> json) {
    return DirectiveOptions(
      effort: (json['effort'] as List<dynamic>)
          .map((e) => EffortOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      aggression: (json['aggression'] as List<dynamic>)
          .map((e) => AggressionOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      focus: (json['focus'] as List<dynamic>)
          .map((e) => FocusOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DirectiveDefaults {
  const DirectiveDefaults({
    required this.effort,
    required this.aggression,
    required this.focus,
  });

  final int effort;
  final int aggression;
  final String? focus;

  factory DirectiveDefaults.fromJson(Map<String, dynamic> json) {
    return DirectiveDefaults(
      effort: json['effort'] as int,
      aggression: json['aggression'] as int,
      focus: json['focus'] as String?,
    );
  }
}

/// `GET /matches/next` (E1) yanıtı — bkz. `API_CONTRACT.md` §8.1.
class NextMatchResponse {
  const NextMatchResponse({
    required this.matchId,
    required this.kickoffAt,
    required this.userSide,
    required this.teams,
    required this.teamTactic,
    required this.stamina,
    required this.directiveOptions,
    required this.defaults,
  });

  final String matchId;
  final DateTime kickoffAt;
  final String userSide;
  final MatchTeams teams;
  final TeamTactic teamTactic;
  final StaminaCatalog stamina;
  final DirectiveOptions directiveOptions;
  final DirectiveDefaults defaults;

  factory NextMatchResponse.fromJson(Map<String, dynamic> json) {
    return NextMatchResponse(
      matchId: json['match_id'] as String,
      kickoffAt: DateTime.parse(json['kickoff_at'] as String),
      userSide: json['user_side'] as String,
      teams: MatchTeams.fromJson(json['teams'] as Map<String, dynamic>),
      teamTactic:
          TeamTactic.fromJson(json['team_tactic'] as Map<String, dynamic>),
      stamina: StaminaCatalog.fromJson(json['stamina'] as Map<String, dynamic>),
      directiveOptions: DirectiveOptions.fromJson(
        json['directive_options'] as Map<String, dynamic>,
      ),
      defaults:
          DirectiveDefaults.fromJson(json['defaults'] as Map<String, dynamic>),
    );
  }
}

/// `POST /matches/{id}/start` (E2) yanıtı.
class StartMatchResponse {
  const StartMatchResponse({required this.matchId, required this.streamUrl});

  final String matchId;

  /// Örn. `/matches/m_xxx/stream` — `ApiConfig.baseUrl` ile birleştirilir.
  final String streamUrl;

  factory StartMatchResponse.fromJson(Map<String, dynamic> json) {
    return StartMatchResponse(
      matchId: json['match_id'] as String,
      streamUrl: json['stream_url'] as String,
    );
  }
}

class DirectiveApplied {
  const DirectiveApplied({
    required this.effort,
    required this.aggression,
    required this.focus,
  });

  final int effort;
  final int aggression;
  final String? focus;

  factory DirectiveApplied.fromJson(Map<String, dynamic> json) {
    return DirectiveApplied(
      effort: json['effort'] as int,
      aggression: json['aggression'] as int,
      focus: json['focus'] as String?,
    );
  }
}

/// `POST /matches/{id}/directive` (E4) yanıtı — daima 200/`accepted:true`
/// döner (toleranslı davranış, §6.1).
class DirectiveResponse {
  const DirectiveResponse({
    required this.accepted,
    required this.note,
    required this.effectiveFromMinute,
    required this.applied,
  });

  final bool accepted;
  final String? note;
  final int effectiveFromMinute;
  final DirectiveApplied applied;

  factory DirectiveResponse.fromJson(Map<String, dynamic> json) {
    return DirectiveResponse(
      accepted: json['accepted'] as bool,
      note: json['note'] as String?,
      effectiveFromMinute: json['effective_from_minute'] as int,
      applied:
          DirectiveApplied.fromJson(json['applied'] as Map<String, dynamic>),
    );
  }
}

// ---------------------------------------------------------------------------
// Müdahale teklifi (§7) — SSE `event: intervention_offer` verisi.
// ---------------------------------------------------------------------------

/// `intervention_offer` zarfındaki tek bir sonuç seçeneği (§7.2) — yalnızca
/// `resolution:"minigame"` tekliflerinde gelir. Motor bunları dört atak
/// aksiyonunda üretiyor (`api/config.py`'deki `MINIGAME_ACTION_KEYS`:
/// `finish_power`, `finish_finesse`, `long_shot`, `counter_attack`).
/// Ekranda gösterilmiyorlar — sonucu şut mini-oyunu belirliyor, kullanıcı
/// listeden seçmiyor.
class OutcomeKeyOption {
  const OutcomeKeyOption({
    required this.key,
    required this.label,
    required this.tone,
  });

  final String key;
  final String label;

  /// `positive` | `neutral` | `negative`.
  final String tone;

  factory OutcomeKeyOption.fromJson(Map<String, dynamic> json) {
    return OutcomeKeyOption(
      key: json['key'] as String,
      label: json['label'] as String,
      tone: json['tone'] as String,
    );
  }
}

/// SSE `event: intervention_offer` zarfı (§7.2) — motor oyuncuya bir karar
/// teklif ettiğinde gelir, motor bu tick'i yanıt gelene (ya da 180 sn'lik
/// sunucu emniyet zaman aşımına) kadar durdurur.
class InterventionOfferFrame {
  const InterventionOfferFrame({
    required this.seq,
    required this.matchId,
    required this.offerId,
    required this.minute,
    required this.resolution,
    required this.actionKey,
    required this.prompt,
    required this.riskHint,
    required this.timeoutSeconds,
    required this.onTimeout,
    this.minigame,
    this.outcomeKeys = const [],
    this.resolved,
  });

  final int seq;
  final String matchId;
  final String offerId;
  final int minute;

  /// `minigame` | `engine`. Bu turda daima `engine` — sonucu sunucu atıyor.
  final String resolution;
  final String actionKey;

  /// ≤110 karakter, motorun `DevAction.setup`'ı — olduğu gibi çizilir.
  final String prompt;
  final String? riskHint;
  final int timeoutSeconds;

  /// Daima `"decline"` sabiti (§7.2 [İ-35]) — zaman aşımı asla bir sonuç
  /// anahtarına düşmez.
  final String onTimeout;

  /// SADECE `resolution:"minigame"` iken dolu. v1'de tek değer: `"shot"`.
  final String? minigame;

  /// SADECE `resolution:"minigame"` iken dolu; 2 (binary) ya da 3 (graded)
  /// eleman, en iyiden en kötüye sıralı.
  final List<OutcomeKeyOption> outcomeKeys;

  /// SADECE E8 `GET /timeline` yanıtında dolu (§9.2) — canlı SSE'de hiç
  /// gelmez. `true` ise teklif zaten kapanmış, FE hiç göstermeden atlar.
  final bool? resolved;

  factory InterventionOfferFrame.fromJson(Map<String, dynamic> json) {
    return InterventionOfferFrame(
      seq: json['seq'] as int,
      matchId: json['match_id'] as String,
      offerId: json['offer_id'] as String,
      minute: json['minute'] as int,
      // §7.2 [İ-31]: tanınmayan bir `resolution` `engine` gibi işlenir.
      // §7.2 [İ-31]: yalnızca "minigame" tanınır, eksik ya da başka her
      // değer (gelecekte tanımlanabilecek üçüncü bir mod dahil) "engine"
      // gibi işlenir.
      resolution: json['resolution'] == 'minigame' ? 'minigame' : 'engine',
      actionKey: json['action_key'] as String,
      prompt: json['prompt'] as String,
      riskHint: json['risk_hint'] as String?,
      timeoutSeconds: json['timeout_seconds'] as int? ?? 20,
      onTimeout: json['on_timeout'] as String? ?? 'decline',
      minigame: json['minigame'] as String?,
      outcomeKeys: (json['outcome_keys'] as List<dynamic>? ?? const [])
          .map((e) => OutcomeKeyOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      resolved: json['resolved'] as bool?,
    );
  }
}

/// Tick zarfının `resolved_intervention` bloğu (§3.1/§3.2) — yalnızca kabul
/// edilmiş bir müdahalenin çözümlendiği tick'te bulunur. `outcome_key` zarını
/// sunucu attığı için (§7.4) FE'nin sonucu öğrenebildiği **tek** yer burasıdır
/// — `events[]`'ten türetilemez (bkz. `match_engine/api/envelope.py`'nin
/// kendi yorumu: bazı dallar olay bazında birebir aynı).
class ResolvedInterventionDto {
  const ResolvedInterventionDto({
    required this.offerId,
    required this.actionKey,
    required this.outcomeKey,
  });

  final String offerId;
  final String actionKey;
  final String outcomeKey;

  factory ResolvedInterventionDto.fromJson(Map<String, dynamic> json) {
    return ResolvedInterventionDto(
      offerId: json['offer_id'] as String,
      actionKey: json['action_key'] as String,
      outcomeKey: json['outcome_key'] as String,
    );
  }
}

/// `POST /matches/{id}/intervention` (E5) yanıtı — başarıda daima
/// `{accepted: true, reason: null}` döner.
class InterventionResponse {
  const InterventionResponse({required this.accepted, required this.reason});

  final bool accepted;
  final String? reason;

  factory InterventionResponse.fromJson(Map<String, dynamic> json) {
    return InterventionResponse(
      accepted: json['accepted'] as bool,
      reason: json['reason'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Tick zarfı (§3) — SSE `event: tick` verisi.
// ---------------------------------------------------------------------------

class ScoreInfo {
  const ScoreInfo({required this.home, required this.away});

  final int home;
  final int away;

  factory ScoreInfo.fromJson(Map<String, dynamic> json) {
    return ScoreInfo(home: json['home'] as int, away: json['away'] as int);
  }
}

class PossessionInfo {
  const PossessionInfo({required this.home, required this.away});

  final int home;
  final int away;

  factory PossessionInfo.fromJson(Map<String, dynamic> json) {
    return PossessionInfo(home: json['home'] as int, away: json['away'] as int);
  }
}

class TeamTickInfo {
  const TeamTickInfo({
    required this.userSide,
    required this.stamina,
    required this.mentality,
    required this.yellowCards,
    required this.redCards,
  });

  final String userSide;
  final int stamina;
  final String mentality;
  final int yellowCards;
  final int redCards;

  factory TeamTickInfo.fromJson(Map<String, dynamic> json) {
    return TeamTickInfo(
      userSide: json['user_side'] as String,
      stamina: json['stamina'] as int,
      mentality: json['mentality'] as String,
      yellowCards: json['yellow_cards'] as int,
      redCards: json['red_cards'] as int,
    );
  }
}

class DirectivesInfo {
  const DirectivesInfo({
    required this.effort,
    required this.aggression,
    required this.focus,
  });

  final int effort;
  final int aggression;
  final String? focus;

  factory DirectivesInfo.fromJson(Map<String, dynamic> json) {
    return DirectivesInfo(
      effort: json['effort'] as int,
      aggression: json['aggression'] as int,
      focus: json['focus'] as String?,
    );
  }
}

/// Feed'deki tek bir olay satırı (§4.2). `text` motorun/API katmanının
/// ürettiği son haldir — FE hiçbir şablonlama yapmaz, olduğu gibi çizer.
class TickEventDto {
  const TickEventDto({
    required this.eventId,
    required this.side,
    required this.text,
    required this.isGoal,
    required this.eventType,
  });

  final String eventId;

  /// `home` | `away` | `neutral`.
  final String side;
  final String text;
  final bool isGoal;

  /// 26 değerlik katalogdan biri (§4.5); FE bilmediği bir değeri ikonsuz
  /// çizer ve çökmez (ileri uyumluluk, [İ-15]).
  final String eventType;

  factory TickEventDto.fromJson(Map<String, dynamic> json) {
    return TickEventDto(
      eventId: json['event_id'] as String,
      side: json['side'] as String,
      text: json['text'] as String,
      isGoal: json['is_goal'] as bool,
      eventType: json['event_type'] as String,
    );
  }
}

/// SSE `event: tick` zarfı (§3.1) — bir dakikalık maç durumunun tamamı.
class TickFrame {
  const TickFrame({
    required this.seq,
    required this.matchId,
    required this.minute,
    required this.finished,
    required this.situation,
    required this.score,
    required this.possession,
    required this.team,
    required this.directives,
    required this.events,
    this.resolvedIntervention,
  });

  final int seq;
  final String matchId;
  final int minute;
  final bool finished;

  /// 8 değerlik `fsm_state` katalogundan biri (§3.3).
  final String situation;
  final ScoreInfo score;
  final PossessionInfo possession;
  final TeamTickInfo team;
  final DirectivesInfo directives;

  /// Bu tick'te üretilen yeni olaylar — tüm geçmiş değil, sadece bu dakika.
  final List<TickEventDto> events;

  /// Dolu ise bu tick, kabul edilmiş bir müdahaleyi çözümledi (§3.1). Diğer
  /// her tick'te `null` — düz tick'lerde ve reddedilen tekliflerde hiç yazılmaz.
  final ResolvedInterventionDto? resolvedIntervention;

  factory TickFrame.fromJson(Map<String, dynamic> json) {
    return TickFrame(
      seq: json['seq'] as int,
      matchId: json['match_id'] as String,
      minute: json['minute'] as int,
      finished: json['finished'] as bool,
      situation: json['situation'] as String,
      score: ScoreInfo.fromJson(json['score'] as Map<String, dynamic>),
      possession:
          PossessionInfo.fromJson(json['possession'] as Map<String, dynamic>),
      team: TeamTickInfo.fromJson(json['team'] as Map<String, dynamic>),
      directives:
          DirectivesInfo.fromJson(json['directives'] as Map<String, dynamic>),
      events: (json['events'] as List<dynamic>)
          .map((e) => TickEventDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      resolvedIntervention: json['resolved_intervention'] == null
          ? null
          : ResolvedInterventionDto.fromJson(
              json['resolved_intervention'] as Map<String, dynamic>),
    );
  }
}

/// `GET /matches/{id}/summary` (E9) yanıtı — bkz. `API_CONTRACT.md` §8.3.
///
/// `stats` career_engine'in M2'sine **olduğu gibi** iletilecek şekilde ham
/// `Map` olarak tutulur (13 anahtarlık taraf başına istatistik, §7.3) — FE
/// içeriğini yorumlamaz, sadece taşır.
class MatchSummaryResponse {
  const MatchSummaryResponse({
    required this.score,
    required this.stats,
    required this.finalPossessionHome,
  });

  final ScoreInfo score;
  final Map<String, dynamic> stats;
  final double finalPossessionHome;

  factory MatchSummaryResponse.fromJson(Map<String, dynamic> json) {
    return MatchSummaryResponse(
      score: ScoreInfo.fromJson(json['score'] as Map<String, dynamic>),
      stats: json['stats'] as Map<String, dynamic>,
      finalPossessionHome: (json['final_possession_home'] as num).toDouble(),
    );
  }
}
