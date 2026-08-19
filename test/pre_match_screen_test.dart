import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/screens/match_screen.dart';
import 'package:project_srpg/screens/pre_match_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _careersListBody = {
  'careers': [
    {
      'career_id': 'car_test', 'player_name': 'Efe Kaan',
      'season_id': '25/26', 'current_date': '2026-08-19',
    }
  ],
};

Map<String, dynamic> _m1Body({String fixtureId = 'f_1'}) => {
      'fixture_id': fixtureId,
      'competition': {
        'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig',
      },
      'kickoff_at': '2026-08-22T20:00:00+03:00', // bir Cumartesi
      'user_side': 'home',
      'engine_payload': {
        'teams': {
          'home': {
            'name': 'FK Yıldız', 'attack': 63.0, 'midfield': 65.0,
            'defense': 61.0, 'goalkeeper': 64.0, 'mentality': 'balanced',
          },
          'away': {
            'name': 'Deniz SK', 'attack': 68.0, 'midfield': 66.0,
            'defense': 65.0, 'goalkeeper': 67.0, 'mentality': 'attacking',
          },
        },
        'user_side': 'home', 'user_condition': 70, 'client_seed': 918273,
      },
    };

const _e11Body = {
  'match_id': 'm_test', 'kickoff_at': '2026-08-19T21:00:00+03:00',
  'user_side': 'home',
  'teams': {
    'home': {'name': 'FK Yıldız'}, 'away': {'name': 'Deniz SK'},
  },
  'team_tactic': {'code': 'balanced', 'label': 'Dengeli'},
  'stamina': {'current': 100, 'floor': 35, 'ceiling': 100, 'substitution_bonus': 6},
  'directive_options': {'effort': [], 'aggression': [], 'focus': []},
  'defaults': {'effort': 50, 'aggression': 50, 'focus': null},
};

Widget _wrap(Widget home) {
  return PlayerScope(
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    ),
  );
}

/// PreMatchScreen'in kolonu kaydırmasız, testin varsayılan 800×600 yüzeyine
/// sığmıyor — DialogScreen'in aynı sınıftan, bu ekranla ilgisiz taşma sorunu
/// (`dialog_screen_test.dart` içindeki not). Play butonuna gerçekten
/// dokunabilmek için yüzeyi büyütüyoruz.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('M1 + E11 köprüsü gerçek fikstür ve saati gösterir',
      (tester) async {
    _useTallView(tester);
    final careerMock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/matches/next') {
        return _json(_m1Body());
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    final matchMock = MockClient((request) async {
      if (request.url.path == '/matches') return _json(_e11Body, status: 201);
      return http.Response('unexpected ${request.url}', 404);
    });

    await tester.pumpWidget(_wrap(PreMatchScreen(
      session: CareerSession(
        client: CareerApiClient(httpClient: careerMock, baseUrl: 'http://test'),
      ),
      matchApiClient:
          MatchApiClient(httpClient: matchMock, baseUrl: 'http://test'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('FK Yıldız - Deniz SK'), findsOneWidget);
    // E11'in kendi dolgu kickoff_at'i değil, career_engine'in gerçek fikstür
    // saati gösterilir (§8.1a).
    expect(find.text('Cumartesi, 20:00'), findsOneWidget);
    expect(find.text('Dengeli'), findsOneWidget);
  });

  testWidgets('409 match_in_progress otomatik M3 ile kurtarılıp M1 tekrarlanır',
      (tester) async {
    _useTallView(tester);
    var nextCalls = 0;
    var abandonCalled = false;
    final careerMock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/matches/next') {
        nextCalls++;
        if (nextCalls == 1) {
          return _json(
            {
              'code': 'match_in_progress',
              'message': "fixture 'f_stale' has an unfinished match",
            },
            status: 409,
          );
        }
        return _json(_m1Body(fixtureId: 'f_2'));
      }
      if (request.url.path == '/careers/car_test/matches/f_stale/abandon') {
        abandonCalled = true;
        return _json({
          'career_state': {
            'current_date': '2026-08-19', 'season_id': '25/26',
            'money': 48200, 'condition': 70, 'day_budget': {'time': 720.0},
          },
          'fixture': {'fixture_id': 'f_stale', 'status': 'scheduled'},
        });
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    final matchMock = MockClient((request) async {
      if (request.url.path == '/matches') return _json(_e11Body, status: 201);
      return http.Response('unexpected ${request.url}', 404);
    });

    await tester.pumpWidget(_wrap(PreMatchScreen(
      session: CareerSession(
        client: CareerApiClient(httpClient: careerMock, baseUrl: 'http://test'),
      ),
      matchApiClient:
          MatchApiClient(httpClient: matchMock, baseUrl: 'http://test'),
    )));
    await tester.pumpAndSettle();

    expect(abandonCalled, isTrue);
    expect(nextCalls, 2);
    expect(find.text('FK Yıldız - Deniz SK'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsNothing);
  });

  testWidgets('Oyna butonu /start çağırıp MatchScreen açar', (tester) async {
    _useTallView(tester);
    final careerMock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/matches/next') {
        return _json(_m1Body());
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    final matchMock = MockClient((request) async {
      if (request.url.path == '/matches') return _json(_e11Body, status: 201);
      if (request.url.path == '/matches/m_test/start') {
        return _json(
          {'match_id': 'm_test', 'stream_url': '/matches/m_test/stream'},
          status: 201,
        );
      }
      return http.Response('unexpected ${request.url}', 404);
    });

    await tester.pumpWidget(_wrap(PreMatchScreen(
      session: CareerSession(
        client: CareerApiClient(httpClient: careerMock, baseUrl: 'http://test'),
      ),
      matchApiClient:
          MatchApiClient(httpClient: matchMock, baseUrl: 'http://test'),
    )));
    await tester.pumpAndSettle();

    // MatchScreen kendi SSE bağlantısını gerçek `ApiConfig.baseUrl`'e açmayı
    // dener (bu testin ilgi alanı değil, yalnızca "Oyna" navigasyonu) — bu
    // yüzden `pumpAndSettle` yerine sınırlı `pump`: bağlantı hatasının
    // 900ms'lik geri dönüş zamanlayıcısını da akıtıp "pending timer"
    // hatasından kaçınıyoruz.
    await tester.tap(find.byIcon(Icons.play_arrow));
    // Bir pump dokunuşu işler; ikincisi `_startMatch`'in beklediği (mock da
    // olsa asenkron) `/start` çağrısının tamamlanmasını ve push'un
    // gerçekleşmesini yakalar.
    await tester.pump();
    await tester.pump();
    expect(find.byType(MatchScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
  });
}
