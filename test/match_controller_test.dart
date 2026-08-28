import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/game/match_feed.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/net/match_sse_client.dart';
import 'package:project_srpg/state/match_controller.dart';

class _FakeStreamSource implements MatchStreamSource {
  final controller = StreamController<MatchStreamMessage>();
  Uri? lastUri;

  @override
  Stream<MatchStreamMessage> connect(Uri uri) {
    lastUri = uri;
    return controller.stream;
  }
}

TickFrame _tick({
  required int seq,
  required int minute,
  bool finished = false,
  List<TickEventDto> events = const [],
  int homeScore = 0,
  int awayScore = 0,
  ResolvedInterventionDto? resolvedIntervention,
}) {
  return TickFrame(
    seq: seq,
    matchId: 'm_test',
    minute: minute,
    finished: finished,
    situation: 'balanced',
    score: ScoreInfo(home: homeScore, away: awayScore),
    possession: const PossessionInfo(home: 50, away: 50),
    team: const TeamTickInfo(
      userSide: 'home',
      stamina: 90,
      mentality: 'balanced',
      yellowCards: 0,
      redCards: 0,
    ),
    directives: const DirectivesInfo(effort: 50, aggression: 50, focus: null),
    events: events,
    resolvedIntervention: resolvedIntervention,
  );
}

InterventionOfferFrame _offer({
  String offerId = 'off_1',
  int seq = 1,
  int minute = 10,
  String actionKey = 'counter_attack',
  String prompt = 'Karşı atak fırsatı doğdu',
  String? riskHint,
}) {
  return InterventionOfferFrame(
    seq: seq,
    matchId: 'm_test',
    offerId: offerId,
    minute: minute,
    resolution: 'engine',
    actionKey: actionKey,
    prompt: prompt,
    riskHint: riskHint,
    timeoutSeconds: 20,
    onTimeout: 'decline',
  );
}

MatchController _buildController(
  _FakeStreamSource source, {
  MatchApiClient? apiClient,
}) {
  return MatchController(
    matchId: 'm_test',
    streamUrl: '/matches/m_test/stream',
    userSide: 'home',
    teams: const MatchTeams(
      home: TeamInfo(name: 'FK Yıldız'),
      away: TeamInfo(name: 'Deniz SK'),
    ),
    staminaCatalog: const StaminaCatalog(
      current: 100,
      floor: 35,
      ceiling: 100,
      substitutionBonus: 6,
    ),
    directiveOptions: const DirectiveOptions(effort: [], aggression: [], focus: []),
    apiClient: apiClient,
    streamSource: source,
  );
}

void main() {
  group('MatchController.connect', () {
    test('connects to the stream source at the resolved stream URL', () {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);

      controller.connect();

      expect(source.lastUri.toString(), endsWith('/matches/m_test/stream'));
    });
  });

  group('MatchController tick handling', () {
    test('applies minute/score/team/situation from a tick', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchTickMessage(_tick(seq: 1, minute: 12, homeScore: 1)));
      await pumpEventQueue();

      expect(controller.minute, 12);
      expect(controller.score.home, 1);
      expect(controller.team?.stamina, 90);
      expect(controller.situation, 'balanced');
    });

    test('accumulates events across ticks instead of replacing them', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchTickMessage(_tick(
        seq: 1,
        minute: 10,
        events: const [
          TickEventDto(
            eventId: 'e_1_0',
            side: 'home',
            text: 'İlk olay',
            isGoal: false,
            eventType: 'corner',
          ),
        ],
      )));
      await pumpEventQueue();
      source.controller.add(MatchTickMessage(_tick(
        seq: 2,
        minute: 11,
        events: const [
          TickEventDto(
            eventId: 'e_2_0',
            side: 'away',
            text: 'İkinci olay',
            isGoal: false,
            eventType: 'foul',
          ),
        ],
      )));
      await pumpEventQueue();

      expect(controller.events, hasLength(2));
      expect(controller.events.first.text, 'İlk olay');
      expect(controller.events.last.text, 'İkinci olay');
      expect(controller.events.last.side, MatchSide.away);
    });

    test('adds a synthetic end-of-match line when finished is true', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchTickMessage(
        _tick(seq: 1, minute: 95, finished: true, homeScore: 2, awayScore: 1),
      ));
      await pumpEventQueue();

      expect(controller.finished, isTrue);
      expect(controller.events.last.text, contains('Maç bitti'));
      expect(controller.events.last.text, contains('2-1'));
    });

    test('ignores unknown stream messages without affecting state', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      // `intervention_offer` artık tipli bir mesaja dönüşür (bkz. aşağıdaki
      // 'MatchController interventions' grubu) - burada gerçekten bilinmeyen
      // bir tür test ediliyor.
      source.controller.add(const MatchStreamIgnored('some_future_frame', {}));
      await pumpEventQueue();

      expect(controller.minute, 0);
      expect(controller.events, isEmpty);
      expect(controller.connectionError, isNull);
    });
  });

  group('MatchController interventions', () {
    test('an offer message fills activeOffer and pendingOfferPrompt', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(_offer(prompt: 'Karar an\'ı')));
      await pumpEventQueue();

      expect(controller.activeOffer?.offerId, 'off_1');
      expect(controller.pendingOfferPrompt, 'Karar an\'ı');
    });

    test('an offer also appends its prompt as a feed line, tinted to userSide',
        () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(
        _offer(minute: 42, prompt: 'Efe Kaan\'dan muazzam bir hat kırıcı pas'),
      ));
      await pumpEventQueue();

      expect(controller.events, hasLength(1));
      final line = controller.events.single;
      expect(line.minute, 42);
      expect(line.text, 'Efe Kaan\'dan muazzam bir hat kırıcı pas');
      expect(line.side, MatchSide.home); // _buildController userSide: 'home'
    });

    test('a resolved:true replay offer is not shown', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(InterventionOfferFrame(
        seq: 1, matchId: 'm_test', offerId: 'off_1', minute: 10,
        resolution: 'engine', actionKey: 'counter_attack', prompt: 'x',
        riskHint: null, timeoutSeconds: 20, onTimeout: 'decline', resolved: true,
      )));
      await pumpEventQueue();

      expect(controller.activeOffer, isNull);
      expect(controller.pendingOfferPrompt, isNull);
    });

    test('a plain tick clears activeOffer (server safety-timeout path)', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(_offer()));
      await pumpEventQueue();
      expect(controller.activeOffer, isNotNull);

      source.controller.add(MatchTickMessage(_tick(seq: 2, minute: 11)));
      await pumpEventQueue();
      expect(controller.activeOffer, isNull);
    });

    test('acceptOffer posts intervene with a null outcome_key and clears activeOffer',
        () async {
      final source = _FakeStreamSource();
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'accepted': true, 'reason': null}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final controller = _buildController(
        source,
        apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
      );
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(_offer()));
      await pumpEventQueue();

      await controller.acceptOffer();

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/matches/m_test/intervention');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['offer_id'], 'off_1');
      expect(body['action'], 'intervene');
      expect(body['outcome_key'], isNull);
      expect(controller.activeOffer, isNull);
    });

    test('declineOffer sends the given reason', () async {
      final source = _FakeStreamSource();
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'accepted': true, 'reason': null}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final controller = _buildController(
        source,
        apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
      );
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(_offer()));
      await pumpEventQueue();

      await controller.declineOffer(reason: 'timeout');

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['action'], 'decline');
      expect(body['reason'], 'timeout');
    });

    test('two acceptOffer calls for the same offer produce exactly one request',
        () async {
      final source = _FakeStreamSource();
      var callCount = 0;
      final mock = MockClient((request) async {
        callCount++;
        return http.Response(jsonEncode({'accepted': true, 'reason': null}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final controller = _buildController(
        source,
        apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
      );
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(_offer()));
      await pumpEventQueue();

      // İkinci çağrı senkron olarak no-op olmalı: ilk çağrı _activeOffer'ı
      // await'ten önce temizliyor.
      final first = controller.acceptOffer();
      final second = controller.acceptOffer();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test('a 409 offer_closed response does not throw and leaves the log empty',
        () async {
      final source = _FakeStreamSource();
      final mock = MockClient((request) async {
        return http.Response(jsonEncode({'accepted': false}), 409,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final controller = _buildController(
        source,
        apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
      );
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(_offer()));
      await pumpEventQueue();

      await expectLater(controller.acceptOffer(), completes);
      expect(controller.interventions, isEmpty);
    });

    test('a network failure sets an explanatory pendingOfferPrompt', () async {
      final source = _FakeStreamSource();
      final mock = MockClient((request) async {
        throw const SocketException('bağlantı yok');
      });
      final controller = _buildController(
        source,
        apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
      );
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchInterventionMessage(_offer()));
      await pumpEventQueue();

      await controller.acceptOffer();

      expect(controller.pendingOfferPrompt, contains('gönderilemedi'));
    });

    test('a tick carrying resolved_intervention appends a log entry', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.add(MatchTickMessage(_tick(
        seq: 2,
        minute: 11,
        resolvedIntervention: const ResolvedInterventionDto(
          offerId: 'off_1', actionKey: 'finish_power', outcomeKey: 'great',
        ),
      )));
      await pumpEventQueue();

      expect(controller.interventions, hasLength(1));
      expect(controller.interventions.single.minute, 11);
      expect(controller.interventions.single.actionKey, 'finish_power');
      expect(controller.interventions.single.outcomeKey, 'great');
    });

    test('a replayed tick with the same offer_id does not duplicate the log entry',
        () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      final tick = _tick(
        seq: 2,
        minute: 11,
        resolvedIntervention: const ResolvedInterventionDto(
          offerId: 'off_1', actionKey: 'finish_power', outcomeKey: 'great',
        ),
      );
      source.controller.add(MatchTickMessage(tick));
      await pumpEventQueue();
      source.controller.add(MatchTickMessage(tick));
      await pumpEventQueue();

      expect(controller.interventions, hasLength(1));
    });
  });

  group('MatchController error handling', () {
    test('sets connectionError when the stream emits MatchStreamException', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      addTearDown(controller.dispose);
      controller.connect();

      source.controller.addError(
        MatchStreamException(404, code: 'match_not_found'),
      );
      await pumpEventQueue();

      expect(controller.connectionError, 'match_not_found');
    });
  });

  group('MatchController.sendDirective', () {
    test('posts to the API and stores the returned note', () async {
      final source = _FakeStreamSource();
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'accepted': true,
            'note': 'sertlik 100\'e çekildi',
            'effective_from_minute': 1,
            'applied': {'effort': 90, 'aggression': 50, 'focus': null},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final controller = _buildController(
        source,
        apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
      );
      addTearDown(controller.dispose);

      await controller.sendDirective(effort: 90);

      expect(controller.lastDirectiveNote, contains('sertlik'));
    });
  });

  group('MatchController.sendSpeed', () {
    test('posts the wire name to /speed', () async {
      final source = _FakeStreamSource();
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      });
      final controller = _buildController(
        source,
        apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
      );
      addTearDown(controller.dispose);

      await controller.sendSpeed(MatchSpeed.fast);

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/matches/m_test/speed');
      expect(requests.single.body, '{"speed":"fast"}');
    });

    test('swallows a failed speed call so the match keeps running', () async {
      final source = _FakeStreamSource();
      final mock = MockClient((request) async => http.Response(
            jsonEncode({'code': 'match_not_found', 'message': 'yok'}),
            404,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final controller = _buildController(
        source,
        apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
      );
      addTearDown(controller.dispose);

      await expectLater(controller.sendSpeed(MatchSpeed.medium), completes);
      expect(controller.connectionError, isNull);
    });
  });

  group('MatchSpeed wire names', () {
    test('match the backend MatchSpeedLevel literal', () {
      // api/schemas/common.py: Literal["slow", "medium", "fast"]
      expect(
        MatchSpeed.values.map((s) => s.wire).toList(),
        ['slow', 'medium', 'fast'],
      );
    });
  });

  group('MatchController.dispose', () {
    test('cancels the underlying stream subscription', () async {
      final source = _FakeStreamSource();
      final controller = _buildController(source);
      controller.connect();
      await pumpEventQueue();

      expect(source.controller.hasListener, isTrue);
      controller.dispose();
      await pumpEventQueue();

      expect(source.controller.hasListener, isFalse);
    });
  });
}
