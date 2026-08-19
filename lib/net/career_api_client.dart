import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'career_models.dart';

/// `career_engine` REST çağrılarından dönen 2xx-dışı yanıtları taşır.
///
/// `code`/`message`, backend'in `{code, message}` hata gövdesinden
/// (CONTRACT.md §5.0) gelir; gövde ayrıştırılamazsa `null` kalır.
class CareerApiException implements Exception {
  CareerApiException(this.statusCode, {this.code, this.message});

  final int statusCode;
  final String? code;
  final String? message;

  @override
  String toString() =>
      'CareerApiException($statusCode, code: $code, message: $message)';
}

/// `career_engine`'in uçlarını saran ince istemci.
///
/// Şimdilik yalnızca **lig tablosunun ihtiyaç duyduğu** uçlar var:
/// C0/C1/C2 (kariyeri çözümlemek için) ve W1/W2 (müsabakalar ve puan durumu).
/// Kalan 18 uç sözleşmede tanımlı, burada henüz karşılıkları yok.
class CareerApiClient {
  CareerApiClient({http.Client? httpClient, String? baseUrl})
      : _client = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.careerBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  /// `response.body` sunucunun `charset=` başlığına güvenir, backend her zaman
  /// açıkça göndermez; `bodyBytes`'ı kendimiz UTF-8 çözerek Türkçe takım
  /// adlarının bozulmasını engelliyoruz (match_api_client.dart ile aynı).
  Map<String, dynamic> _decode(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

  CareerApiException _errorFrom(http.Response response) {
    try {
      final body = _decode(response);
      return CareerApiException(
        response.statusCode,
        code: body['code'] as String?,
        message: body['message'] as String?,
      );
    } catch (_) {
      return CareerApiException(
        response.statusCode,
        message: utf8.decode(response.bodyBytes),
      );
    }
  }

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final response = await _client.get(_uri(path, query));
    if (response.statusCode != 200) throw _errorFrom(response);
    return _decode(response);
  }

  /// C2 · `GET /careers` — kayıtlı kariyerler, yeniden eskiye.
  Future<List<CareerSummary>> listCareers() async {
    final body = await _get('/careers');
    return (body['careers'] as List<dynamic>)
        .map((e) => CareerSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// C0 · `GET /careers/options` — seçilebilir kulüpler (D21: yalnızca alt
  /// kademe) ve pozisyonlar.
  Future<List<ClubOption>> careerOptions() async {
    final body = await _get('/careers/options');
    return (body['clubs'] as List<dynamic>)
        .map((e) => ClubOption.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// C1 · `POST /careers` — yeni kariyer. Yanıt C3 ile aynı hub gövdesidir;
  /// buradaki tek ilgi alanı `career_id`.
  Future<String> createCareer({
    required String playerName,
    required String position,
    required String teamId,
    int? seed,
  }) async {
    final response = await _client.post(
      _uri('/careers'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'player_name': playerName,
        'position': position,
        'team_id': teamId,
        'seed': ?seed,
      }),
    );
    if (response.statusCode != 201) throw _errorFrom(response);
    return _decode(response)['career_id'] as String;
  }

  /// W1 · `GET /careers/{cid}/competitions` — piramit, paralel ligler, kupalar.
  Future<List<CompetitionRef>> competitions(String careerId) async {
    final body = await _get('/careers/$careerId/competitions');
    return (body['competitions'] as List<dynamic>)
        .map((e) => CompetitionRef.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// W2 · `GET /careers/{cid}/standings` — puan durumu. `season` boş
  /// bırakılırsa BE güncel sezonu kullanır. `kind='cup'` müsabakalarda BE
  /// `409 no_standings` döner.
  Future<Standings> standings(
    String careerId, {
    required String competitionId,
    String? seasonId,
  }) async {
    final body = await _get('/careers/$careerId/standings', {
      'competition': competitionId,
      'season': ?seasonId,
    });
    return Standings.fromJson(body);
  }

  void close() => _client.close();
}
