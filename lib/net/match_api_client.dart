import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'match_models.dart';
import 'timeout_client.dart';

/// `match_engine` REST çağrılarından dönen 2xx-dışı yanıtları taşır.
///
/// `code`/`message`, backend'in `{code, message}` hata gövdesinden (§9.1)
/// gelir; gövde ayrıştırılamazsa `null` kalır ve çağıran ham durum koduna
/// göre karar verir.
class MatchApiException implements Exception {
  MatchApiException(this.statusCode, {this.code, this.message});

  final int statusCode;
  final String? code;
  final String? message;

  @override
  String toString() =>
      'MatchApiException($statusCode, code: $code, message: $message)';
}

/// `match_engine`'in REST uçlarını (E1, E2, E4, E5, E9, E11) saran ince
/// istemci. SSE akışı (E3) ayrı bir sınıfta (`match_sse_client.dart`) ele alınır.
class MatchApiClient {
  MatchApiClient({http.Client? httpClient, String? baseUrl})
      : _client = httpClient ??
            TimeoutClient(http.Client(), timeout: defaultTimeout),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Tek maç uçları milisaniyeler içinde döner; bu süre bir donmayı ayırır.
  static const defaultTimeout = Duration(seconds: 10);

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// `response.body` trusts the server's `charset=` header, which the
  /// backend doesn't always set explicitly; decoding `bodyBytes` as UTF-8
  /// ourselves avoids mangling Turkish characters (team names, feed text).
  Map<String, dynamic> _decode(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  MatchApiException _errorFrom(http.Response response) {
    try {
      final body = _decode(response);
      return MatchApiException(
        response.statusCode,
        code: body['code'] as String?,
        message: body['message'] as String?,
      );
    } catch (_) {
      return MatchApiException(
        response.statusCode,
        message: utf8.decode(response.bodyBytes),
      );
    }
  }

  /// `GET /matches/next` (E1). Sunucu tarafında yeni bir `match_id` rezerve
  /// eder — tüketilmezse (bkz. `startMatch`) boşta kalır.
  Future<NextMatchResponse> fetchNextMatch() async {
    final response = await _client.get(_uri('/matches/next'));
    if (response.statusCode != 200) throw _errorFrom(response);
    return NextMatchResponse.fromJson(_decode(response));
  }

  /// `POST /matches/{matchId}/start` (E2).
  ///
  /// [position] §6.8 · kullanıcının mevki grubu (career M1'in
  /// `coach_instruction.position_group`'u, olduğu gibi iletilir). Hangi
  /// senaryonun teklif edileceğini eğer; `null` = eğilim yok. [focus]'un
  /// aksine bir direktif **değil** — maç boyunca sabittir, `/directive` onu
  /// kabul etmez.
  Future<StartMatchResponse> startMatch(
    String matchId, {
    required String userSide,
    required int effort,
    required int aggression,
    String? focus,
    String? position,
    int? clientSeed,
  }) async {
    final response = await _client.post(
      _uri('/matches/$matchId/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_side': userSide,
        'effort': effort,
        'aggression': aggression,
        'focus': focus,
        'position': position,
        'client_seed': clientSeed,
      }),
    );
    if (response.statusCode != 201) throw _errorFrom(response);
    return StartMatchResponse.fromJson(_decode(response));
  }

  /// `POST /matches/{matchId}/directive` (E4). Toleranslıdır — geçerli bir
  /// `match_id` ile daima 200 döner (§6.1, §9.1).
  Future<DirectiveResponse> postDirective(
    String matchId, {
    required String clientRequestId,
    required int atMinute,
    int? effort,
    int? aggression,
    String? focus,
  }) async {
    final response = await _client.post(
      _uri('/matches/$matchId/directive'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_request_id': clientRequestId,
        'at_minute': atMinute,
        'effort': effort,
        'aggression': aggression,
        'focus': focus,
      }),
    );
    if (response.statusCode != 200) throw _errorFrom(response);
    return DirectiveResponse.fromJson(_decode(response));
  }

  /// `POST /matches/{matchId}/intervention` (E5, §6.5). Katı bir uçtur:
  /// `resolution:"engine"` tekliflerinde `outcomeKey` **null** olmalıdır,
  /// aksi halde 400 `outcome_key_not_allowed` döner. Bu turda motor hiç
  /// minigame teklifi üretmediği için her çağrı `outcomeKey: null` gönderir.
  ///
  /// ⚠️ Kapanmış bir teklife yanıt `409` döner ve gövdesi standart
  /// `{code, message}` hata şekli DEĞİL, `{"accepted": false}`'tur. [_errorFrom]
  /// bu gövdeyi başarıyla ayrıştırır ama `code`/`message` `null` kalır —
  /// çağıran bu durumu `statusCode == 409` ile tanımalı, `code` ile değil.
  Future<InterventionResponse> postIntervention(
    String matchId, {
    required String offerId,
    required String clientRequestId,
    required String action, // "intervene" | "decline"
    String? outcomeKey,
    String? minigameResult,
    String? reason, // "user" | "timeout" | "disconnected" | null
  }) async {
    final response = await _client.post(
      _uri('/matches/$matchId/intervention'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'offer_id': offerId,
        'client_request_id': clientRequestId,
        'action': action,
        'outcome_key': outcomeKey,
        'minigame_result': minigameResult,
        'reason': reason,
      }),
    );
    if (response.statusCode != 200) throw _errorFrom(response);
    return InterventionResponse.fromJson(_decode(response));
  }

  /// `POST /matches/{matchId}/speed` (E10). Yalnızca oynatma temposunu
  /// değiştirir — motorun simüle ettiğini etkilemez. Gövdesiz `204` döner.
  Future<void> postSpeed(String matchId, {required String speed}) async {
    final response = await _client.post(
      _uri('/matches/$matchId/speed'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'speed': speed}),
    );
    if (response.statusCode != 204) throw _errorFrom(response);
  }

  /// `POST /matches` (E11, v1.2) — career_engine köprüsü (D7). `enginePayload`
  /// career_engine'in M1 yanıtındaki `engine_payload`'ı olduğu gibi taşır; FE
  /// içeriğini yorumlamaz (career_engine CONTRACT.md §5.6). Yanıt zarfı E1
  /// ile birebir aynı, `NextMatchResponse` burada da geçerli.
  /// E6/E7 · `reason`: `"user_left"` | `"app_backgrounded"`. Sunucu tarafında
  /// duraklatmak bedelsiz: `run_loop` yalnızca bir sonraki tick'i istemeyi
  /// bırakır, maç durumu bellekte olduğu gibi kalır.
  Future<void> postPause(String matchId, {required String reason}) =>
      _postPauseResume(matchId, 'pause', reason);

  Future<void> postResume(String matchId, {required String reason}) =>
      _postPauseResume(matchId, 'resume', reason);

  Future<void> _postPauseResume(
    String matchId,
    String action,
    String reason,
  ) async {
    final response = await _client.post(
      _uri('/matches/$matchId/$action'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 204) throw _errorFrom(response);
  }

  Future<NextMatchResponse> createMatch(
    Map<String, dynamic> enginePayload,
  ) async {
    final response = await _client.post(
      _uri('/matches'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(enginePayload),
    );
    if (response.statusCode != 201) throw _errorFrom(response);
    return NextMatchResponse.fromJson(_decode(response));
  }

  /// `GET /matches/{matchId}/summary` (E9) — maç bittikten sonra career_engine
  /// M2'ye taşınacak skor/istatistik/hakimiyet.
  Future<MatchSummaryResponse> fetchSummary(String matchId) async {
    final response = await _client.get(_uri('/matches/$matchId/summary'));
    if (response.statusCode != 200) throw _errorFrom(response);
    return MatchSummaryResponse.fromJson(_decode(response));
  }
}
