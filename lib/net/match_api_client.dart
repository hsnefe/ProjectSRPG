import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'match_models.dart';

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

/// `match_engine`'in REST uçlarını (E1, E2, E4) saran ince istemci.
/// SSE akışı (E3) ayrı bir sınıfta (`match_sse_client.dart`) ele alınır.
class MatchApiClient {
  MatchApiClient({http.Client? httpClient, String? baseUrl})
      : _client = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

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
  Future<StartMatchResponse> startMatch(
    String matchId, {
    required String userSide,
    required int effort,
    required int aggression,
    String? focus,
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
}
