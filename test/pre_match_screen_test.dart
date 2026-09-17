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
import 'package:project_srpg/widgets/formation_board.dart';

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

Map<String, dynamic> _m1Body({
  String fixtureId = 'f_1',
  Map<String, dynamic>? coachInstruction,
}) =>
    {
      'fixture_id': fixtureId,
      'competition': {
        'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig',
      },
      'kickoff_at': '2026-08-22T20:00:00+03:00', // bir Cumartesi
      'user_side': 'home',
      'formation_id': '4-2-3-1',
      // §12.10 · opsiyonel: eski şekilli bir gövdenin hâlâ ayrıştığını
      // kanıtlamak için varsayılan `_m1Body()` çağrıları bunu hiç eklemiyor.
      if (coachInstruction != null) 'coach_instruction': coachInstruction,
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

Map<String, dynamic> _hubBodyWithDaysUntil(int daysUntil) => {
      'career_id': 'car_test',
      'career_state': {
        'current_date': '2026-08-19', 'season_id': '25/26',
        'money': 48200, 'condition': 64, 'day_budget': {'time': 720.0},
      },
      'player': {
        'name': 'Efe Kaan', 'position': 'Orta saha', 'age': 21,
        'role': 'oyun_kurucu', 'role_name': 'Oyun Kurucu',
        'team': {
          'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
          'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
        },
      },
      'next_fixture': {
        'fixture_id': 'f_1',
        'competition': {
          'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig',
        },
        'round_no': 3,
        'kickoff_at': '2026-08-22T20:00:00+03:00',
        'home': {
          'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
          'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
        },
        'away': {
          'team_id': 't_dnz', 'name': 'Deniz SK', 'short_name': 'DNZ',
          'color_primary': '#0B2C6F', 'color_secondary': '#FFFFFF',
        },
        'user_side': 'home',
        'days_until': daysUntil,
      },
      'standing_summary': null,
      'news_preview': const [],
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
      if (request.url.path == '/careers/car_test') {
        return _json(_hubBodyWithDaysUntil(0));
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
    // Bireysel rol artık sabit değil, C3'ten geliyor.
    expect(find.text('Oyun Kurucu'), findsOneWidget);
    // M1'in bildirdiği diziliş çizilir — 4-2-3-1'in on slotu.
    final board = tester.widget<FormationBoard>(find.byType(FormationBoard));
    expect(board.formation.id, '4-2-3-1');
    expect(find.byType(FormationBoard), findsOneWidget);
  });

  testWidgets(
      'M1 coach_instruction kartta gösterilir, rol adı hub\'ınkinin önüne geçer',
      (tester) async {
    _useTallView(tester);
    final careerMock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/matches/next') {
        return _json(_m1Body(coachInstruction: {
          'focus': 'tactical', 'label': 'Taktik',
          'role_id': 'regista', 'role_name': 'Regista',
          'position': 'Orta saha', 'source': 'role',
        }));
      }
      // C3 hâlâ çağrılıyor (bu turda kaldırılmıyor — bkz. plan'ın opsiyonel
      // temizlik commit'i); yalnızca kartın gösterdiği rol adı artık onun
      // 'Oyun Kurucu'suna değil M1'in 'Regista'sına bağlı.
      if (request.url.path == '/careers/car_test') {
        return _json(_hubBodyWithDaysUntil(0));
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

    expect(find.text('Bugün beklenen'), findsOneWidget);
    expect(find.text('Taktik'), findsOneWidget);
    expect(find.text('Regista'), findsOneWidget);
    expect(find.text('Oyun Kurucu'), findsNothing);
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
      if (request.url.path == '/careers/car_test') {
        return _json(_hubBodyWithDaysUntil(0));
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
      if (request.url.path == '/careers/car_test') {
        return _json(_hubBodyWithDaysUntil(0));
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

  testWidgets(
      '/start govdesi M1 position_group degerini motora oldugu gibi tasir',
      (tester) async {
    // §12.14 / API_CONTRACT §6.8 — maç senaryolarının oyuncunun mevkisine
    // benzemesini sağlayan tek alan. FE onu türetmiyor, yalnızca iletiyor.
    _useTallView(tester);
    Map<String, dynamic>? startBody;
    final careerMock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/matches/next') {
        return _json(_m1Body(coachInstruction: {
          'focus': 'defend',
          'label': 'Savunma',
          'role_id': 'stoper',
          'role_name': 'Stoper',
          'position': 'Defans',
          'position_group': 'dc',
          'source': 'role',
        }));
      }
      if (request.url.path == '/careers/car_test') {
        return _json(_hubBodyWithDaysUntil(0));
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    final matchMock = MockClient((request) async {
      if (request.url.path == '/matches') return _json(_e11Body, status: 201);
      if (request.url.path == '/matches/m_test/start') {
        startBody = jsonDecode(request.body) as Map<String, dynamic>;
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

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    await tester.pump();

    expect(startBody, isNotNull);
    expect(startBody!['position'], 'dc');
    // focus ile birlikte gider, onun yerine değil: ikisi motorda ayrı
    // çarpanlar (§6.8).
    expect(startBody!.containsKey('focus'), isTrue);

    await tester.pump(const Duration(milliseconds: 1000));
  });

  testWidgets(
      'position_group yoksa /start position: null gönderir',
      (tester) async {
    // Eski şekilli bir M1 gövdesi (alan hiç yok) motoru eğilimsiz bırakır —
    // §6.8'in "null -> tam nötr" kuralının FE tarafındaki ayağı.
    _useTallView(tester);
    Map<String, dynamic>? startBody;
    final careerMock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/matches/next') {
        return _json(_m1Body());
      }
      if (request.url.path == '/careers/car_test') {
        return _json(_hubBodyWithDaysUntil(0));
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    final matchMock = MockClient((request) async {
      if (request.url.path == '/matches') return _json(_e11Body, status: 201);
      if (request.url.path == '/matches/m_test/start') {
        startBody = jsonDecode(request.body) as Map<String, dynamic>;
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

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    await tester.pump();

    expect(startBody, isNotNull);
    expect(startBody!['position'], isNull);

    await tester.pump(const Duration(milliseconds: 1000));
  });

  testWidgets('409 not_match_day geri sayım gösterir, hata göstermez',
      (tester) async {
    _useTallView(tester);
    var e11Called = false;
    final careerMock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/matches/next') {
        return _json(
          {
            'code': 'not_match_day',
            'message': 'next match is on 2026-08-22, 3 day(s) away',
          },
          status: 409,
        );
      }
      if (request.url.path == '/careers/car_test') {
        return _json(_hubBodyWithDaysUntil(3));
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    final matchMock = MockClient((request) async {
      e11Called = true;
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

    expect(find.text('Maça 3 gün var.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsNothing);
    // Maç günü olmadan motora hiç maç kurulmaz.
    expect(e11Called, isFalse);
  });

  testWidgets('C3 çökerse maça çıkış durmaz: varsayılan diziliş, mevki rolü',
      (tester) async {
    _useTallView(tester);
    final careerMock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/matches/next') {
        // Diziliş bilmeyen bir career_engine sürümü: formation_id yok.
        final body = _m1Body()..remove('formation_id');
        return _json(body);
      }
      if (request.url.path == '/careers/car_test') {
        return http.Response('boom', 500);
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
    expect(find.text('Tekrar dene'), findsNothing);
    // formation_id gelmedi -> varsayılana düşülür, boş kutuya değil.
    final board = tester.widget<FormationBoard>(find.byType(FormationBoard));
    expect(board.formation.id, '4-4-2-duz');
    // Rol adı okunamadı -> PlayerState'in mevkisi yazılır.
    expect(board.playerPosition, 'Orta saha');
    expect(find.text('Oyun Kurucu'), findsNothing);
  });
}
