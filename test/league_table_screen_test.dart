import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/league_table_screen.dart';

/// W1'in iki ligi: kullanıcı alt kademede (D21), Süper Lig'de gerçek takımlar.
const _competitions = {
  'competitions': [
    {
      'competition_id': 'c_lig1',
      'kind': 'league',
      'name': 'Süper Lig',
      'country': 'TR',
      'tier': 1,
      'format': 'double_round_robin',
      'team_count': 18,
      'user_participates': false,
    },
    {
      'competition_id': 'c_kupa',
      'kind': 'cup',
      'name': 'Ulusal Kupa',
      'country': 'TR',
      'tier': null,
      'format': 'single_elimination',
      'team_count': 32,
      'user_participates': true,
    },
    {
      'competition_id': 'c_lig2',
      'kind': 'league',
      'name': '1. Lig',
      'country': 'TR',
      'tier': 2,
      'format': 'double_round_robin',
      'team_count': 14,
      'user_participates': true,
    },
  ],
};

Map<String, dynamic> _standings(String competitionId) {
  final isTier1 = competitionId == 'c_lig1';
  return {
    'competition': {
      'competition_id': competitionId,
      'kind': 'league',
      'name': isTier1 ? 'Süper Lig' : '1. Lig',
      'country': 'TR',
      'tier': isTier1 ? 1 : 2,
    },
    'season_id': '25/26',
    'rows': [
      {
        'rank': 1,
        'team': {
          'team_id': isTier1 ? 't_gal' : 't_dnz',
          'name': isTier1 ? 'Galatasaray' : 'Deniz SK',
          'short_name': isTier1 ? 'GAL' : 'DNZ',
          'color_primary': '#E30613',
          'color_secondary': '#FDB913',
        },
        'played': 4,
        'won': 4,
        'drawn': 0,
        'lost': 0,
        'goals_for': 11,
        'goals_against': 2,
        'goal_difference': 9,
        'points': 12,
        'is_user_team': false,
      },
      {
        'rank': 2,
        'team': {
          'team_id': isTier1 ? 't_fen' : 't_ykz',
          'name': isTier1 ? 'Fenerbahçe' : 'FK Yıldız',
          'short_name': isTier1 ? 'FEN' : 'YKZ',
          'color_primary': '#FDB913',
          'color_secondary': '#0A2240',
        },
        'played': 4,
        'won': 3,
        'drawn': 1,
        'lost': 0,
        'goals_for': 8,
        'goals_against': 3,
        'goal_difference': 5,
        'points': 10,
        'is_user_team': !isTier1,
      },
    ],
    'promotion_slots': isTier1 ? 0 : 2,
    'relegation_slots': 2,
  };
}

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Kariyeri hazır (C2 bir kariyer döner) sahte bir career_engine.
CareerSession _session({
  void Function(http.BaseRequest request)? onRequest,
  http.Response? Function(http.Request request)? override,
}) {
  final mock = MockClient((request) async {
    onRequest?.call(request);
    final custom = override?.call(request);
    if (custom != null) return custom;

    final path = request.url.path;
    if (path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test',
            'player_name': 'Efe Kaan',
            'season_id': '25/26',
            'current_date': '2026-08-05',
            'team': {
              'team_id': 't_ykz',
              'name': 'FK Yıldız',
              'short_name': 'YKZ',
              'color_primary': '#1E6FD9',
              'color_secondary': '#FFFFFF',
            },
          },
        ],
      });
    }
    if (path == '/careers/car_test/competitions') return _json(_competitions);
    if (path == '/careers/car_test/standings') {
      return _json(_standings(request.url.queryParameters['competition']!));
    }
    return http.Response('unexpected ${request.url}', 404);
  });

  return CareerSession(
    client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'),
  );
}

Future<void> _pump(WidgetTester tester, CareerSession session) async {
  await tester.pumpWidget(
    MaterialApp(home: LeagueTableScreen(session: session)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('puan durumu backend\'den gelir, sabit liste kalmadı',
      (tester) async {
    await _pump(tester, _session());

    // Açılışta kullanıcının kendi ligi seçilidir (W1 user_participates).
    expect(find.text('FK Yıldız'), findsOneWidget);
    expect(find.text('Deniz SK'), findsOneWidget);
    // Başlık artık veriden geliyor: seçili ligin adı hem üstte hem sekmede.
    expect(find.text('Lig Tablosu'), findsNothing);
    expect(find.text('1. Lig'), findsNWidgets(2));
    expect(find.text('12'), findsOneWidget); // lider puanı
  });

  testWidgets('kupa sekmesi çizilmez, ligler arası geçiş çalışır',
      (tester) async {
    await _pump(tester, _session());

    // W1 kupayı da döner ama puan durumu yoktur (§5.3) — sekme yalnızca lig.
    expect(find.text('Ulusal Kupa'), findsNothing);
    expect(find.text('Süper Lig'), findsOneWidget);

    await tester.tap(find.text('Süper Lig'));
    await tester.pumpAndSettle();

    expect(find.text('Galatasaray'), findsOneWidget);
    expect(find.text('Fenerbahçe'), findsOneWidget);
    expect(find.text('FK Yıldız'), findsNothing);
  });

  testWidgets('seçili lig W2 sorgusuna competition olarak gider',
      (tester) async {
    final seen = <String>[];
    await _pump(
      tester,
      _session(onRequest: (request) {
        final competition = request.url.queryParameters['competition'];
        if (competition != null) seen.add(competition);
      }),
    );

    expect(seen, ['c_lig2']);

    await tester.tap(find.text('Süper Lig'));
    await tester.pumpAndSettle();

    expect(seen, ['c_lig2', 'c_lig1']);
  });

  testWidgets('backend kapalıysa hata durumu ve yeniden deneme gösterilir',
      (tester) async {
    var failCompetitions = true;
    final session = _session(
      override: (request) {
        if (request.url.path.endsWith('/competitions') && failCompetitions) {
          return http.Response(
            jsonEncode({'code': 'not_found', 'message': 'kariyer yok'}),
            404,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return null;
      },
    );

    await _pump(tester, session);

    expect(find.text('Lig verisi alınamadı.'), findsOneWidget);
    expect(find.text('kariyer yok'), findsOneWidget);

    failCompetitions = false;
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();

    expect(find.text('FK Yıldız'), findsOneWidget);
  });
}
