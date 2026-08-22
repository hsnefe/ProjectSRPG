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

/// `career_engine`'in 25 ucunun tamamını saran ince istemci (CONTRACT.md §4).
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

  Future<Map<String, dynamic>> _post(
    String path, {
    Object? body,
    int expect = 200,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: const {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode != expect) throw _errorFrom(response);
    return _decode(response);
  }

  Future<void> _delete(String path, {int expect = 204}) async {
    final response = await _client.delete(_uri(path));
    if (response.statusCode != expect) throw _errorFrom(response);
  }

  /// C2 · `GET /careers` — kayıtlı kariyerler, yeniden eskiye.
  Future<List<CareerSummary>> listCareers() async {
    final body = await _get('/careers');
    return (body['careers'] as List<dynamic>)
        .map((e) => CareerSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// C0 · `GET /careers/options` — yeni kariyer formunun seçenekleri:
  /// milliyetler, pozisyon+rol katalogu ve hedef kulüpler.
  Future<CareerOptions> careerOptions() async {
    final body = await _get('/careers/options');
    return CareerOptions.fromJson(body);
  }

  /// C1 · `POST /careers` — yeni kariyer. Yanıt C3 ile aynı hub gövdesidir,
  /// olduğu gibi döndürülür: sihirbaz kariyer kimliğinin yanında atanan kulübü
  /// ve künyeyi de aynı yanıttan okur.
  ///
  /// Oynanacak kulüp istekte yok: D21/§3 uyarınca [nationality]'nin en alt
  /// liginden atanır. [targetTeamId] hedeflenen kulüptür, oynanan değil.
  Future<CareerHub> createCareer({
    required String firstName,
    required String lastName,
    required String nationality,
    required String position,
    required String role,
    required String targetTeamId,
    int? seed,
  }) async {
    final body = await _post('/careers', expect: 201, body: {
      'first_name': firstName,
      'last_name': lastName,
      'nationality': nationality,
      'position': position,
      'role': role,
      'target_team_id': targetTeamId,
      'seed': ?seed,
    });
    return CareerHub.fromJson(body);
  }

  /// C5 · `POST /careers/{cid}/skill-exams` — sınav notlarını nitelik puanına
  /// çevirir. Üç sınav **tek istekte** gider: gövde önce bütünüyle doğrulanır,
  /// bir not geçersizse veya sınav daha önce girilmişse (`409
  /// skill_exam_already_taken`) hiçbiri uygulanmaz.
  Future<List<SkillExamOutcome>> submitSkillExams(
    String careerId,
    Map<String, int> levelsByExamId,
  ) async {
    final body = await _post('/careers/$careerId/skill-exams', body: {
      'results': [
        for (final entry in levelsByExamId.entries)
          {'exam_id': entry.key, 'level': entry.value},
      ],
    });
    return (body['results'] as List<dynamic>)
        .map((e) => SkillExamOutcome.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// C4 · `DELETE /careers/{cid}` — kariyeri sil. INV-9: hiçbir satır kalmaz.
  Future<void> deleteCareer(String careerId) => _delete('/careers/$careerId');

  /// C3 · `GET /careers/{cid}` — kariyer merkezi. Tek çağrıda hub verisi;
  /// FE'nin ana ekranı bununla dolar.
  Future<CareerHub> hub(String careerId) async {
    final body = await _get('/careers/$careerId');
    return CareerHub.fromJson(body);
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

  // ---------------------------------------------------------------------
  // §5.2 Oyuncu — P1-P3
  // ---------------------------------------------------------------------

  /// P1 · `GET /careers/{cid}/player` — künye + on bir nitelik + kondisyon +
  /// para.
  Future<PlayerProfile> player(String careerId) async {
    final body = await _get('/careers/$careerId/player');
    return PlayerProfile.fromJson(body);
  }

  /// P2 · `GET /careers/{cid}/player/stats` — `season`/`competition`
  /// verilmezse BE ikisi için de `'all'` kullanır.
  Future<PlayerStats> playerStats(
    String careerId, {
    String? season,
    String? competition,
  }) async {
    final body = await _get('/careers/$careerId/player/stats', {
      'season': ?season,
      'competition': ?competition,
    });
    return PlayerStats.fromJson(body);
  }

  /// P3 · `GET /careers/{cid}/player/contract`. Hiç sözleşme yoksa BE `null`
  /// gövde döner.
  Future<PlayerContract?> playerContract(String careerId) async {
    final response = await _client.get(_uri('/careers/$careerId/player/contract'));
    if (response.statusCode != 200) throw _errorFrom(response);
    final text = utf8.decode(response.bodyBytes);
    if (text == 'null') return null;
    return PlayerContract.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------
  // §5.3 Dünya — W3-W4
  // ---------------------------------------------------------------------

  /// W3 · `GET /careers/{cid}/fixtures` — hepsi opsiyonel filtre + sayfalama.
  Future<FixturesPage> fixtures(
    String careerId, {
    String? competitionId,
    int? round,
    String? teamId,
    String? status,
    String? seasonId,
    int? limit,
    String? before,
  }) async {
    final body = await _get('/careers/$careerId/fixtures', {
      'competition': ?competitionId,
      'round': ?round?.toString(),
      'team_id': ?teamId,
      'status': ?status,
      'season': ?seasonId,
      'limit': ?limit?.toString(),
      'before': ?before,
    });
    return FixturesPage.fromJson(body);
  }

  /// W4 · `GET /careers/{cid}/teams/{tid}` — takım künyesi + renkler.
  Future<TeamDetail> team(String careerId, String teamId) async {
    final body = await _get('/careers/$careerId/teams/$teamId');
    return TeamDetail.fromJson(body);
  }

  // ---------------------------------------------------------------------
  // §5.4 İlişki — R1-R3
  // ---------------------------------------------------------------------

  /// R1 · `GET /careers/{cid}/relationships` — beş kart.
  Future<List<RelationshipCard>> relationships(String careerId) async {
    final body = await _get('/careers/$careerId/relationships');
    return (body['relationships'] as List<dynamic>)
        .map((e) => RelationshipCard.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// R2 · `GET /careers/{cid}/relationships/{rid}` — profil künyesi + son
  /// etkileşimler.
  Future<RelationshipProfile> relationship(
    String careerId,
    String relationshipId,
  ) async {
    final body =
        await _get('/careers/$careerId/relationships/$relationshipId');
    return RelationshipProfile.fromJson(body);
  }

  /// R3 · `POST /careers/{cid}/relationships/{rid}/interact` — diyalog
  /// sonucunu uygular. `choicePath`: geçilen düğüm ve seçenek kimlikleri.
  Future<InteractResult> interact(
    String careerId,
    String relationshipId, {
    required String dialogueId,
    required List<String> choicePath,
  }) async {
    final body = await _post(
      '/careers/$careerId/relationships/$relationshipId/interact',
      body: {'dialogue_id': dialogueId, 'choice_path': choicePath},
    );
    return InteractResult.fromJson(body);
  }

  // ---------------------------------------------------------------------
  // §5.5 Zaman — T1-T4
  // ---------------------------------------------------------------------

  /// T1 · `GET /careers/{cid}/day` — bugün: tarih, kalan aksiyon, bugünkü
  /// olaylar.
  Future<DayInfo> day(String careerId) async {
    final body = await _get('/careers/$careerId/day');
    return DayInfo.fromJson(body);
  }

  /// T2 · `POST /careers/{cid}/actions` — antrenman / yaşam aktivitesi
  /// uygular. `result`: yalnızca drill'i olan kalemlerde (minigame skoru).
  Future<ActionResult> postAction(
    String careerId, {
    required String catalogId,
    Map<String, dynamic>? result,
  }) async {
    final body = await _post('/careers/$careerId/actions', body: {
      'catalog_id': catalogId,
      'result': ?result,
    });
    return ActionResult.fromJson(body);
  }

  /// T3 · `POST /careers/{cid}/advance` — `to`: 'next_day' | 'next_event'.
  Future<AdvanceResult> advance(String careerId, {required String to}) async {
    final body = await _post('/careers/$careerId/advance', body: {'to': to});
    return AdvanceResult.fromJson(body);
  }

  /// T4 · `POST /careers/{cid}/purchases` — dükkândan satın alır.
  Future<PurchaseResult> purchase(String careerId, String catalogId) async {
    final body = await _post('/careers/$careerId/purchases', body: {
      'catalog_id': catalogId,
    });
    return PurchaseResult.fromJson(body);
  }

  // ---------------------------------------------------------------------
  // §5.6 Maç — M1-M3
  // ---------------------------------------------------------------------

  /// M1 · `GET /careers/{cid}/matches/next` — maç kurulumu, motora
  /// verilecek `engine_payload` dahil. Yarım kalan maç varsa BE
  /// `409 match_in_progress` döner (`code`'dan okunur, §6.4).
  Future<NextCareerMatch> nextMatch(String careerId) async {
    final body = await _get('/careers/$careerId/matches/next');
    return NextCareerMatch.fromJson(body);
  }

  /// M2 · `POST /careers/{cid}/matches/{fid}/result` — sonucu yazar + haftayı
  /// simüle eder. `body` motorun `/summary` yanıtı + kullanıcının müdahale
  /// kaydını taşır (§5.6) — katı doğrulanır, ihlalde `422 invalid_match_result`.
  Future<MatchResultResponse> reportMatchResult(
    String careerId,
    String fixtureId,
    Map<String, dynamic> body,
  ) async {
    final response = await _post(
      '/careers/$careerId/matches/$fixtureId/result',
      body: body,
    );
    return MatchResultResponse.fromJson(response);
  }

  /// M3 · `POST /careers/{cid}/matches/{fid}/abandon` — yarım kalan maçı
  /// kurtarır: fikstür `scheduled`'a döner (§6.4).
  Future<AbandonResult> abandonMatch(String careerId, String fixtureId) async {
    final body = await _post('/careers/$careerId/matches/$fixtureId/abandon');
    return AbandonResult.fromJson(body);
  }

  // ---------------------------------------------------------------------
  // §5.7 İçerik — N1-N3
  // ---------------------------------------------------------------------

  /// N1 · `GET /careers/{cid}/news`.
  Future<NewsFeed> news(
    String careerId, {
    int? limit,
    String? before,
    String? category,
  }) async {
    final body = await _get('/careers/$careerId/news', {
      'limit': ?limit?.toString(),
      'before': ?before,
      'category': ?category,
    });
    return NewsFeed.fromJson(body);
  }

  /// N2 · `GET /careers/{cid}/news/{nid}` — tam gövde.
  Future<NewsDetail> newsItem(String careerId, String newsId) async {
    final body = await _get('/careers/$careerId/news/$newsId');
    return NewsDetail.fromJson(body);
  }

  /// N3 · `GET /catalog/{kind}` — `training` | `lifestyle` | `shop`.
  /// Kariyerden bağımsız, salt okunur.
  Future<Catalog> catalog(String kind) async {
    final body = await _get('/catalog/$kind');
    return Catalog.fromJson(body);
  }

  void close() => _client.close();
}
