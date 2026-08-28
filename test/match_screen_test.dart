import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/net/match_sse_client.dart';
import 'package:project_srpg/screens/intervention_shot_screen.dart';
import 'package:project_srpg/screens/match_screen.dart';
import 'package:project_srpg/screens/request_screen.dart';
import 'package:project_srpg/state/match_controller.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/intervention_offer_modal.dart';

/// A stream source the test drives by hand instead of relying on real HTTP.
class _FakeSseClient implements MatchStreamSource {
  final controller = StreamController<MatchStreamMessage>();

  @override
  Stream<MatchStreamMessage> connect(Uri uri) => controller.stream;
}

TickFrame _tick({
  required int minute,
  bool finished = false,
  int homeScore = 0,
  int awayScore = 0,
  int stamina = 90,
  List<TickEventDto> events = const [],
  ResolvedInterventionDto? resolvedIntervention,
}) {
  return TickFrame(
    seq: minute,
    matchId: 'm_test',
    minute: minute,
    finished: finished,
    situation: 'balanced',
    score: ScoreInfo(home: homeScore, away: awayScore),
    possession: const PossessionInfo(home: 55, away: 45),
    team: TeamTickInfo(
      userSide: 'home',
      stamina: stamina,
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
  int minute = 10,
  String actionKey = 'counter_attack',
  String prompt = 'Rakip savunması dağınık, hızlı çıkış fırsatı var',
  String? riskHint,
  int timeoutSeconds = 20,
}) {
  return InterventionOfferFrame(
    seq: minute,
    matchId: 'm_test',
    offerId: offerId,
    minute: minute,
    resolution: 'engine',
    actionKey: actionKey,
    prompt: prompt,
    riskHint: riskHint,
    timeoutSeconds: timeoutSeconds,
    onTimeout: 'decline',
  );
}

InterventionOfferFrame _minigameOffer({
  String offerId = 'off_1',
  int minute = 63,
  String actionKey = 'finish_power',
  String prompt = 'Forvet ceza sahasında topla buluştu',
}) {
  return InterventionOfferFrame(
    seq: minute,
    matchId: 'm_test',
    offerId: offerId,
    minute: minute,
    resolution: 'minigame',
    minigame: 'shot',
    actionKey: actionKey,
    prompt: prompt,
    riskHint: null,
    timeoutSeconds: 20,
    onTimeout: 'decline',
    outcomeKeys: const [
      OutcomeKeyOption(key: 'great', label: 'Ağlara gitti', tone: 'positive'),
      OutcomeKeyOption(key: 'asist', label: 'Arkadaşına pas', tone: 'positive'),
      OutcomeKeyOption(key: 'good', label: 'Kaleci çeldi', tone: 'neutral'),
      OutcomeKeyOption(key: 'bad', label: 'Kaleyle alakasız', tone: 'negative'),
    ],
  );
}

MatchController _buildController(
  _FakeSseClient source, {
  List<http.Request>? recordedRequests,
  int? startCondition,
}) {
  // The speed button now POSTs to /speed, so every screen test needs a stubbed
  // HTTP client - otherwise the tap would attempt a real socket connection.
  // /intervention (E5) gets its own 200 JSON body; everything else (only
  // /speed today) keeps the bare 204 the speed tests expect.
  final mock = MockClient((request) async {
    recordedRequests?.add(request);
    if (request.url.path.endsWith('/intervention')) {
      return http.Response(
        jsonEncode({'accepted': true, 'reason': null}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('', 204);
  });

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
    startCondition: startCondition,
    apiClient: MatchApiClient(httpClient: mock, baseUrl: 'http://test'),
    streamSource: source,
  );
}

Future<void> _pumpMatchScreen(
  WidgetTester tester,
  MatchController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(home: MatchScreen(controller: controller)),
  );
  await tester.pump();
}

/// Emits a tick and pumps twice: once to let the stream's microtask
/// delivery reach the controller's listener and call `notifyListeners`,
/// and once more so the resulting rebuild is reflected in the tree.
Future<void> _emitTick(
  WidgetTester tester,
  _FakeSseClient source,
  TickFrame tick,
) async {
  source.controller.add(MatchTickMessage(tick));
  await tester.pump();
  await tester.pump();
}

/// Emits an intervention offer and pumps three times: once for the stream's
/// microtask delivery, once for the frame whose post-frame callback opens
/// the dialog (`_MatchScreenState._openOfferDialog`), and once more so the
/// pushed route actually builds its content.
Future<void> _emitOffer(
  WidgetTester tester,
  _FakeSseClient source,
  InterventionOfferFrame offer,
) async {
  source.controller.add(MatchInterventionMessage(offer));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'kondisyon barı oyuncunun kendi kondisyonundan başlar ve onunla erir',
    (tester) async {
      final source = _FakeSseClient();
      final controller = _buildController(source, startCondition: 64);
      await _pumpMatchScreen(tester, controller);

      // İlk tick yalnızca sayacı kurar — motorun 100'ü oyuncunun 64'ünü
      // ezmez (D38: aynı eğri, farklı başlangıç).
      await _emitTick(tester, source, _tick(minute: 1, stamina: 100));
      expect(find.text('64/100'), findsOneWidget);

      // 100 -> 82: 18 puanlık erime oyuncunun sayacına birebir yansır.
      await _emitTick(tester, source, _tick(minute: 45, stamina: 82));
      expect(find.text('46/100'), findsOneWidget);
      expect(controller.playerCondition, 46);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('kondisyon barı tabanın altına inmez', (tester) async {
    final source = _FakeSseClient();
    final controller = _buildController(source, startCondition: 40);
    await _pumpMatchScreen(tester, controller);

    await _emitTick(tester, source, _tick(minute: 1, stamina: 100));
    await _emitTick(tester, source, _tick(minute: 90, stamina: 36));
    expect(controller.playerCondition, 35);  // StaminaCatalog.floor

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows an empty state before any tick arrives', (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    expect(find.text('Maç başlıyor…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders a home event in the accent tint', (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    await _emitTick(
      tester,
      source,
      _tick(
        minute: 5,
        events: const [
          TickEventDto(
            eventId: 'e_5_0',
            side: 'home',
            text: 'Efe Kaan topu kazandı.',
            isGoal: false,
            eventType: 'foul',
          ),
        ],
      ),
    );

    expect(find.textContaining('Efe Kaan topu kazandı'), findsOneWidget);
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.textContaining('Efe Kaan topu kazandı'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0x33228BFF));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders an away event in the danger tint', (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    await _emitTick(
      tester,
      source,
      _tick(
        minute: 6,
        events: const [
          TickEventDto(
            eventId: 'e_6_0',
            side: 'away',
            text: 'Deniz SK topu kesti.',
            isGoal: false,
            eventType: 'foul',
          ),
        ],
      ),
    );

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.textContaining('Deniz SK topu kesti'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0x33E85D5D));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('updates the scoreboard when a goal event arrives',
      (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    expect(find.text('0'), findsNWidgets(2));

    await _emitTick(
      tester,
      source,
      _tick(
        minute: 27,
        homeScore: 1,
        events: const [
          TickEventDto(
            eventId: 'e_27_0',
            side: 'home',
            text: 'GOL! Efe Kaan attı.',
            isGoal: true,
            eventType: 'goal',
          ),
        ],
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cycles the feed speed through three steps on tap',
      (tester) async {
    final source = _FakeSseClient();
    final requests = <http.Request>[];
    await _pumpMatchScreen(
      tester,
      _buildController(source, recordedRequests: requests),
    );

    final arrows = find.byIcon(Icons.play_arrow_rounded);
    final minuteButton = find.ancestor(
      of: find.byIcon(Icons.directions_run_outlined),
      matching: find.byType(OutlinedButton),
    );

    expect(arrows, findsNothing); // yavaş

    await tester.tap(minuteButton);
    await tester.pump();
    expect(arrows, findsOneWidget); // orta

    await tester.tap(minuteButton);
    await tester.pump();
    expect(arrows, findsNWidgets(2)); // hızlı

    await tester.tap(minuteButton);
    await tester.pump();
    expect(arrows, findsNothing); // üçüncü basışta başa döner

    // Her basış sunucuya bildirilir — tempo client'ta değil backend'de uygulanır.
    expect(requests.map((r) => r.body).toList(), [
      '{"speed":"medium"}',
      '{"speed":"fast"}',
      '{"speed":"slow"}',
    ]);
    expect(requests.first.url.path, '/matches/m_test/speed');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancels the stream subscription on dispose', (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    expect(source.controller.hasListener, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(source.controller.hasListener, isFalse);
  });

  testWidgets('pops back and shows a message on a connection error',
      (tester) async {
    final source = _FakeSseClient();
    final controller = _buildController(source);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Geri ekran'))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => MatchScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    source.controller.addError(
      MatchStreamException(404, code: 'match_not_found'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('match_not_found'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(find.text('Geri ekran'), findsOneWidget);
  });

  group('müdahale teklifi modalı', () {
    testWidgets('opens with the prompt, risk hint and two buttons',
        (tester) async {
      final source = _FakeSseClient();
      await _pumpMatchScreen(tester, _buildController(source));

      await _emitOffer(tester, source, _offer(
        prompt: 'Forvet ceza sahasında topla buluştu',
        riskHint: 'Kötü zamanlama doğrudan kırmızı kart getirir.',
      ));

      // Prompt metni artık yorum akışındaki kalıcı satırda ve
      // `_WaitingBanner`de de görünür (aynı `pendingOfferPrompt`'tan
      // besleniyor) - bu yüzden arama modalın kendisiyle sınırlanıyor.
      final modal = find.byType(InterventionOfferModal);
      expect(
        find.descendant(
          of: modal,
          matching: find.textContaining('Forvet ceza sahasında topla buluştu'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: modal,
          matching:
              find.textContaining('Kötü zamanlama doğrudan kırmızı kart getirir.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Müdahale et'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);

      // Zamanlayıcı `dispose()`'da iptal edilir - kapatmadan unmount etmek
      // yeterli, "Timer still pending" hatası oluşmaz.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Müdahale et closes the dialog and posts action:intervene',
        (tester) async {
      final source = _FakeSseClient();
      final requests = <http.Request>[];
      await _pumpMatchScreen(
        tester,
        _buildController(source, recordedRequests: requests),
      );

      await _emitOffer(tester, source, _offer());

      await tester.tap(find.text('Müdahale et'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Müdahale et'), findsNothing); // panel kapandı
      final intervention =
          requests.singleWhere((r) => r.url.path.endsWith('/intervention'));
      final body = jsonDecode(intervention.body) as Map<String, dynamic>;
      expect(body['offer_id'], 'off_1');
      expect(body['action'], 'intervene');
      expect(body['outcome_key'], isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    // Zaman aşımı (20 sn geri sayımın dolması) `test/intervention_offer_modal_test.dart`
    // içinde `InterventionOfferModal.debugNow` kancasıyla test ediliyor -
    // `flutter_test`'in FakeAsync tabanlı `pump(duration)`'ı `Timer`'ı
    // sanallaştırır ama gerçek `DateTime.now()`'ı ilerletmez, bu yüzden bu
    // ekranın kendi entegrasyon testinde 20 sn'lik gerçek zaman aşımını
    // tetiklemenin güvenilir bir yolu yok. `_openOfferDialog`'un `timeout`
    // dalı zaten `decline` dalıyla birebir aynı switch kolunu paylaşıyor
    // (bkz. match_screen.dart) - yukarıdaki "Müdahale et" testi o anahtarlama
    // mekanizmasını `intervene` koluyla kanıtlıyor.

    testWidgets(
        'a stream error while the dialog is open closes the dialog and the screen',
        (tester) async {
      final source = _FakeSseClient();
      final controller = _buildController(source);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Geri ekran'))),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => MatchScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await _emitOffer(tester, source, _offer());
      expect(find.text('Müdahale et'), findsOneWidget);

      // Regresyon testi: `_handleConnectionError` panel açıkken çağrılırsa
      // `maybePop` yalnızca paneli kapatıp kullanıcıyı çıkışsız bir ekranda
      // bırakmamalı - önce panel, sonra ekran kapanmalı.
      source.controller.addError(
        MatchStreamException(404, code: 'match_not_found'),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Müdahale et'), findsNothing); // panel kapandı

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text('Geri ekran'), findsOneWidget);
    });

    testWidgets('Müdahale et on a minigame offer opens the shot screen, not a POST',
        (tester) async {
      final source = _FakeSseClient();
      final requests = <http.Request>[];
      await _pumpMatchScreen(
        tester,
        _buildController(source, recordedRequests: requests),
      );

      await _emitOffer(tester, source, _minigameOffer());

      await tester.tap(find.text('Müdahale et'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // push geçişi

      expect(find.byType(InterventionShotScreen), findsOneWidget);
      // Sonuç henüz gelmedi - motora hiçbir POST atılmamalı.
      expect(requests.where((r) => r.url.path.endsWith('/intervention')), isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('abandoning the shot screen (back button) posts nothing',
        (tester) async {
      final source = _FakeSseClient();
      final requests = <http.Request>[];
      await _pumpMatchScreen(
        tester,
        _buildController(source, recordedRequests: requests),
      );

      await _emitOffer(tester, source, _minigameOffer());
      await tester.tap(find.text('Müdahale et'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(InterventionShotScreen), findsOneWidget);

      // Geri tuşuna gerçek bir dokunuşla değil (GameWidget kendi Flame
      // ticker'ını sürekli çalıştırdığı için hem `pumpAndSettle` hiç oturmaz
      // hem de gesture hedefleme GameWidget'ın kendi InputLayer'ıyla
      // çakışabiliyor - bkz. intervention_shot_screen_test.dart'taki aynı
      // ekranın izole testinde bu çakışma yok, oradaki tap güvenilir çalışıyor)
      // doğrudan Navigator üzerinden pop ederek - `GameHeaderBar`'ın kendi
      // `onPressed`'inin yaptığı ile birebir aynı çağrı.
      Navigator.of(tester.element(find.byType(InterventionShotScreen))).pop();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(InterventionShotScreen), findsNothing);
      expect(requests.where((r) => r.url.path.endsWith('/intervention')), isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('keeps the directive buttons while the match is running',
      (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    await _emitTick(tester, source, _tick(minute: 40));

    expect(find.text('Efor'), findsOneWidget);
    expect(find.text('Rol'), findsOneWidget);
    expect(find.text('Sertlik'), findsOneWidget);
    expect(find.text('İlerle'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('replaces the directive buttons with İlerle when the match ends',
      (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    await _emitTick(tester, source, _tick(minute: 90, finished: true));

    expect(find.text('Efor'), findsNothing);
    expect(find.text('Rol'), findsNothing);
    expect(find.text('Sertlik'), findsNothing);
    expect(find.text('İlerle'), findsOneWidget);
    // Kondisyon barı maç sonunda da görünür kalır.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('İlerle replaces the match screen with the request screen',
      (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    await _emitTick(tester, source, _tick(minute: 90, finished: true));
    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    expect(find.byType(RequestScreen), findsOneWidget);
    expect(find.byType(MatchScreen), findsNothing);
    // pushReplacement, MatchScreen.dispose'u tetikler: abonelik kapanmalı.
    expect(source.controller.hasListener, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'İlerle bir kariyer fikstürüne bağlıyken E9 özetini M2\'ye taşır',
    (tester) async {
      final source = _FakeSseClient();
      final matchRequests = <http.Request>[];
      final matchMock = MockClient((request) async {
        matchRequests.add(request);
        if (request.url.path == '/matches/m_test/summary') {
          return http.Response(
            jsonEncode({
              'score': {'home': 2, 'away': 1},
              'stats': {
                'home': {
                  'goals': 2, 'shots': 10, 'shots_on_target': 5, 'corners': 3,
                  'dangerous_attacks': 20, 'total_attacks': 40,
                  'yellow_cards': 1, 'red_cards': 0, 'penalties': 0,
                  'penalty_goals': 0, 'fouls': 8, 'substitutions': 2,
                  'possession_ticks': 55,
                },
                'away': {
                  'goals': 1, 'shots': 7, 'shots_on_target': 3, 'corners': 2,
                  'dangerous_attacks': 15, 'total_attacks': 35,
                  'yellow_cards': 2, 'red_cards': 0, 'penalties': 0,
                  'penalty_goals': 0, 'fouls': 10, 'substitutions': 3,
                  'possession_ticks': 45,
                },
              },
              'final_possession_home': 55.0,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('', 204);
      });

      final careerRequests = <http.Request>[];
      final careerMock = MockClient((request) async {
        careerRequests.add(request);
        if (request.url.path == '/careers') {
          return http.Response(
            jsonEncode({
              'careers': [
                {
                  'career_id': 'car_test', 'player_name': 'Efe Kaan',
                  'season_id': '25/26', 'current_date': '2026-08-19',
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/careers/car_test/matches/f_1/result') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          // `interventions`, controller'ın tick'lerin `resolved_intervention`
          // bloğundan biriktirdiği defterdir (§3.1) - burada tek bir kabul
          // edilmiş müdahale besleniyor ve M2 gövdesine üç alanla geçiyor.
          expect(body['interventions'], [
            {'minute': 63, 'action_key': 'finish_power', 'outcome_key': 'great'},
          ]);
          // final_condition maç öncesi değerden büyük olamaz.
          // D38: 70'ten başladı, maç boyunca 22 puan eridi (100 -> 78).
          expect(body['final_condition'], 48);
          return http.Response(
            jsonEncode({
              'career_state': {
                'current_date': '2026-08-19', 'season_id': '25/26',
                'money': 48200, 'condition': 48, 'day_budget': {'time': 720.0},
              },
              'fixture': {
                'fixture_id': 'f_1', 'status': 'played',
                'score': {'home': 2, 'away': 1},
              },
              'other_results': const [],
              'standing_delta': {'rank_before': 3, 'rank_after': 2},
              'player_stat_delta': {
                'appearances': 1, 'goals': 0, 'assists': 1, 'minutes': 95,
              },
              'relationship_changes': [
                {
                  'relationship_id': 'coach', 'before': 70, 'after': 74,
                  'delta': 4,
                },
                {
                  'relationship_id': 'team', 'before': 50, 'after': 52,
                  'delta': 2,
                },
                {
                  'relationship_id': 'fans', 'before': 40, 'after': 45,
                  'delta': 5,
                },
                {
                  'relationship_id': 'media', 'before': 10, 'after': 11,
                  'delta': 1,
                },
              ],
              'ledger_entries': const [],
              'news_created': ['n_1'],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('unexpected ${request.url}', 404);
      });

      final controller = _buildController(source, startCondition: 70);
      final careerSession = CareerSession(
        client: CareerApiClient(httpClient: careerMock, baseUrl: 'http://test'),
      );

      await tester.pumpWidget(PlayerScope(
        child: MaterialApp(
          home: MatchScreen(
            controller: controller,
            careerSession: careerSession,
            fixtureId: 'f_1',
            preMatchCondition: 70,
            matchApiClient:
                MatchApiClient(httpClient: matchMock, baseUrl: 'http://test'),
          ),
        ),
      ));
      await tester.pump();

      await _emitTick(tester, source, _tick(minute: 1, stamina: 100));
      await _emitTick(tester, source, _tick(
        minute: 63,
        stamina: 90,
        resolvedIntervention: const ResolvedInterventionDto(
          offerId: 'off_1', actionKey: 'finish_power', outcomeKey: 'great',
        ),
      ));
      await _emitTick(tester, source, _tick(minute: 90, stamina: 78, finished: true));
      await tester.tap(find.text('İlerle'));
      await tester.pumpAndSettle();

      expect(find.byType(RequestScreen), findsOneWidget);
      // Gerçek skor ve puan durumu değişimi M2'den geldi.
      expect(find.textContaining('2 - 1'), findsOneWidget);
      expect(find.textContaining('3. → 2.'), findsOneWidget);
      expect(
        careerRequests.any((r) => r.url.path.endsWith('/matches/f_1/result')),
        isTrue,
      );
      // `_advance()`, E9'un `stats[userSide]`'ını (userSide: 'home')
      // `RequestScreen`'e `userStats` olarak taşıdı - istatistik tablosu
      // gerçek motor verisiyle dolu.
      expect(find.text('20'), findsOneWidget); // dangerous_attacks
      expect(find.text('5/10'), findsOneWidget); // shots_on_target/shots
      // İlişki bar'ları da M2'nin `relationship_changes`'inden geldi.
      expect(find.textContaining('Antrenör'), findsOneWidget);
      expect(find.textContaining('Taraftarlar'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
