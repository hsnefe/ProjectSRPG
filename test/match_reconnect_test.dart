import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/boot/python_host.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/net/match_sse_client.dart';
import 'package:project_srpg/state/match_controller.dart';

/// Her `connect` yeni bir akış açar ve `Last-Event-ID`'yi kaydeder.
class _Source implements MatchStreamSource {
  final connects = <String?>[];
  final streams = <StreamController<MatchStreamMessage>>[];

  StreamController<MatchStreamMessage> get current => streams.last;

  @override
  Stream<MatchStreamMessage> connect(Uri uri, {String? lastEventId}) {
    connects.add(lastEventId);
    final controller = StreamController<MatchStreamMessage>();
    streams.add(controller);
    return controller.stream;
  }
}

TickFrame _tick(int seq, {int minute = 10, bool finished = false}) => TickFrame(
  seq: seq,
  matchId: 'm_test',
  minute: minute,
  finished: finished,
  situation: 'balanced',
  score: const ScoreInfo(home: 0, away: 0),
  possession: const PossessionInfo(home: 50, away: 50),
  team: const TeamTickInfo(
    userSide: 'home',
    stamina: 90,
    mentality: 'balanced',
    yellowCards: 0,
    redCards: 0,
  ),
  directives: const DirectivesInfo(effort: 50, aggression: 50, focus: null),
  events: const [],
);

class _Api {
  _Api({this.resumeStatus = 204});

  final calls = <String>[];
  int resumeStatus;

  MatchApiClient get client => MatchApiClient(
    httpClient: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      calls.add('${request.url.path} ${body['reason']}');
      final status = request.url.path.endsWith('/resume') ? resumeStatus : 204;
      return http.Response(
        status == 204 ? '' : jsonEncode({'code': 'match_not_found'}),
        status,
      );
    }),
    baseUrl: 'http://test',
  );
}

MatchController _build(
  _Source source, {
  _Api? api,
  PythonHost? host,
  List<Duration> delays = const [Duration.zero, Duration.zero],
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
    directiveOptions: const DirectiveOptions(
      effort: [],
      aggression: [],
      focus: [],
    ),
    apiClient: (api ?? _Api()).client,
    streamSource: source,
    host: host ?? PythonHost(embedded: false),
    reconnectDelays: delays,
  );
}

void main() {
  group('yeniden bağlanma', () {
    test(
      'kopan akış, son seq ile Last-Event-ID göndererek yeniden bağlanır',
      () async {
        final source = _Source();
        final controller = _build(source)..connect();
        addTearDown(controller.dispose);

        source.current.add(MatchTickMessage(_tick(1)));
        source.current.add(MatchTickMessage(_tick(5, minute: 20)));
        await pumpEventQueue();
        source.current.addError(StateError('socket reset'));
        await pumpEventQueue(times: 20);

        expect(source.connects, [null, '5']);
        expect(controller.connectionError, isNull);
        expect(controller.minute, 20);
      },
    );

    test(
      'yeniden bağlanan akıştan gelen zarflar işlenmeye devam eder',
      () async {
        final source = _Source();
        final controller = _build(source)..connect();
        addTearDown(controller.dispose);
        source.current.add(MatchTickMessage(_tick(3, minute: 3)));
        await pumpEventQueue();
        source.current.addError(StateError('x'));
        await pumpEventQueue(times: 20);

        source.current.add(MatchTickMessage(_tick(4, minute: 4)));
        await pumpEventQueue();

        expect(controller.minute, 4);
      },
    );

    test('akış hatasız kapansa da (maç bitmediyse) yeniden bağlanır', () async {
      final source = _Source();
      final controller = _build(source)..connect();
      addTearDown(controller.dispose);
      source.current.add(MatchTickMessage(_tick(2)));
      await pumpEventQueue();
      await source.current.close();
      await pumpEventQueue(times: 20);

      expect(source.connects, [null, '2']);
    });

    test('maç bittiyse kapanan akış yeniden bağlanmaz', () async {
      final source = _Source();
      final controller = _build(source)..connect();
      addTearDown(controller.dispose);
      source.current.add(MatchTickMessage(_tick(9, finished: true)));
      await pumpEventQueue();
      await source.current.close();
      await pumpEventQueue(times: 20);

      expect(source.connects, [null]);
      expect(controller.connectionError, isNull);
    });

    test('haklar tükenince connectionError dolar', () async {
      final source = _Source();
      final controller = _build(source)..connect();
      addTearDown(controller.dispose);

      for (var i = 0; i < 3; i++) {
        source.current.addError(StateError('down'));
        await pumpEventQueue(times: 20);
      }

      expect(source.connects.length, 3); // ilk + 2 yeniden deneme
      expect(controller.connectionError, 'Maç akışına bağlanılamadı.');
    });

    test('veri geldikçe hak sayacı sıfırlanır', () async {
      final source = _Source();
      final controller = _build(source)..connect();
      addTearDown(controller.dispose);

      for (var i = 1; i <= 5; i++) {
        source.current.add(MatchTickMessage(_tick(i)));
        await pumpEventQueue();
        source.current.addError(StateError('blip'));
        await pumpEventQueue(times: 20);
      }

      expect(controller.connectionError, isNull);
      expect(source.connects.length, 6);
    });

    for (final status in [400, 404, 410]) {
      test('$status yeniden denenmez, hemen hata olur', () async {
        final source = _Source();
        final controller = _build(source)..connect();
        addTearDown(controller.dispose);
        source.current.addError(
          MatchStreamException(status, code: 'match_finished'),
        );
        await pumpEventQueue(times: 20);

        expect(source.connects, [null]);
        expect(controller.connectionError, 'match_finished');
      });
    }

    test('5xx geçici sayılır ve yeniden denenir', () async {
      final source = _Source();
      final controller = _build(source)..connect();
      addTearDown(controller.dispose);
      source.current.addError(MatchStreamException(503));
      await pumpEventQueue(times: 20);

      expect(source.connects, [null, null]);
      expect(controller.connectionError, isNull);
    });

    test('dispose bekleyen yeniden bağlanmayı iptal eder', () async {
      final source = _Source();
      final controller = _build(
        source,
        delays: const [Duration(milliseconds: 30)],
      )..connect();
      source.current.addError(StateError('x'));
      await pumpEventQueue();
      expect(controller.isReconnecting, isTrue);

      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(source.connects, [null]);
    });
  });

  group('uygulama yaşam döngüsü', () {
    test(
      'hidden: maç sunucuda duraklatılır, akış hataları yok sayılır',
      () async {
        final source = _Source();
        final api = _Api();
        final controller = _build(source, api: api)..connect();
        addTearDown(controller.dispose);
        source.current.add(MatchTickMessage(_tick(7)));
        await pumpEventQueue();

        controller.handleAppLifecycle(AppLifecycleState.hidden);
        await pumpEventQueue();
        source.current.addError(StateError('iOS reclaimed the socket'));
        await pumpEventQueue(times: 20);

        expect(api.calls, ['/matches/m_test/pause app_backgrounded']);
        expect(controller.isBackgrounded, isTrue);
        expect(controller.connectionError, isNull);
        expect(source.connects, [null]); // arka planda yeniden bağlanma yok
      },
    );

    test(
      'resumed: resume atılır ve Last-Event-ID ile akış tazelenir',
      () async {
        final source = _Source();
        final api = _Api();
        final controller = _build(source, api: api)..connect();
        addTearDown(controller.dispose);
        source.current.add(MatchTickMessage(_tick(7)));
        await pumpEventQueue();

        controller.handleAppLifecycle(AppLifecycleState.hidden);
        await pumpEventQueue();
        controller.handleAppLifecycle(AppLifecycleState.resumed);
        await pumpEventQueue(times: 20);

        expect(api.calls, [
          '/matches/m_test/pause app_backgrounded',
          '/matches/m_test/resume app_backgrounded',
        ]);
        expect(source.connects, [null, '7']);
        expect(controller.isBackgrounded, isFalse);
      },
    );

    test('inactive geçicidir: duraklatma yok', () async {
      final source = _Source();
      final api = _Api();
      final controller = _build(source, api: api)..connect();
      addTearDown(controller.dispose);

      controller.handleAppLifecycle(AppLifecycleState.inactive);
      controller.handleAppLifecycle(AppLifecycleState.resumed);
      await pumpEventQueue(times: 20);

      expect(api.calls, isEmpty);
      expect(source.connects, [null]);
    });

    test('maç bittiyse arka plana geçerken duraklatılmaz', () async {
      final source = _Source();
      final api = _Api();
      final controller = _build(source, api: api)..connect();
      addTearDown(controller.dispose);
      source.current.add(MatchTickMessage(_tick(9, finished: true)));
      await pumpEventQueue();

      controller.handleAppLifecycle(AppLifecycleState.hidden);
      await pumpEventQueue();

      expect(api.calls, isEmpty);
    });

    test('dönüşte motorlar yanıt vermezse bağlantı hatası olur', () async {
      final source = _Source();
      final api = _Api();
      final host = PythonHost(
        embedded: true,
        starter: () async => null,
        probe: (_) async => false,
        healthUrls: [Uri.parse('http://127.0.0.1:1/health')],
        pollInterval: const Duration(milliseconds: 5),
        recoverTimeout: const Duration(milliseconds: 40),
      );
      final controller = _build(source, api: api, host: host)..connect();
      addTearDown(controller.dispose);

      controller.handleAppLifecycle(AppLifecycleState.hidden);
      await pumpEventQueue();
      controller.handleAppLifecycle(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(controller.connectionError, 'Oyun motoru yanıt vermiyor.');
      expect(api.calls, ['/matches/m_test/pause app_backgrounded']);
    });

    test('dönüşte sunucu maçı bilmiyorsa (404) bağlantı hatası olur', () async {
      final source = _Source();
      final api = _Api(resumeStatus: 404);
      final controller = _build(source, api: api)..connect();
      addTearDown(controller.dispose);

      controller.handleAppLifecycle(AppLifecycleState.hidden);
      await pumpEventQueue();
      controller.handleAppLifecycle(AppLifecycleState.resumed);
      await pumpEventQueue(times: 20);

      expect(controller.connectionError, 'Maç sunucuda bulunamadı.');
      expect(source.connects, [null]);
    });

    test('motor yeniden kalkana dek beklenir, sonra resume atılır', () async {
      final source = _Source();
      final api = _Api();
      var healthy = false;
      final host = PythonHost(
        embedded: true,
        starter: () async => null,
        probe: (_) async => healthy,
        healthUrls: [Uri.parse('http://127.0.0.1:1/health')],
        pollInterval: const Duration(milliseconds: 5),
        recoverTimeout: const Duration(seconds: 5),
      );
      final controller = _build(source, api: api, host: host)..connect();
      addTearDown(controller.dispose);

      controller.handleAppLifecycle(AppLifecycleState.hidden);
      await pumpEventQueue();
      controller.handleAppLifecycle(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(api.calls.length, 1); // henüz resume yok: motor kapalı

      healthy = true; // gözetmen soketi yeniden bağladı
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(api.calls.last, '/matches/m_test/resume app_backgrounded');
      expect(controller.connectionError, isNull);
    });
  });
}
