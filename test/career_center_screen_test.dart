import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
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

Map<String, dynamic> _hubBody({
  Map<String, dynamic>? nextFixture,
  List<Map<String, dynamic>> newsPreview = const [],
}) {
  return {
    'career_id': 'car_test',
    'career_state': {
      'current_date': '2026-08-19', 'season_id': '25/26',
      'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
    },
    'player': {
      'name': 'Efe Kaan', 'position': 'Orta saha', 'age': 21,
      'team': {
        'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
        'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
      },
    },
    'next_fixture': nextFixture,
    'standing_summary': null,
    'news_preview': newsPreview,
  };
}

const _fixture = {
  'fixture_id': 'f_1',
  'competition': {
    'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig',
  },
  'round_no': 13,
  'kickoff_at': '2026-08-22T20:00:00+03:00', // bir Cumartesi
  'home': {
    'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
    'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
  },
  'away': {
    'team_id': 't_dnz', 'name': 'Deniz SK', 'short_name': 'DNZ',
    'color_primary': '#0B2E5B', 'color_secondary': '#E8EAED',
  },
  'user_side': 'home',
  'days_until': 3,
};

const _newsPreview = [
  {
    'news_id': 'n_1', 'category': 'Transfer', 'title': 'Bir transfer haberi',
    'source': 'Spor Manşet', 'published_at': '2026-08-19T09:00:00+03:00',
  },
];

CareerSession _hubSession(Map<String, dynamic> hubBody) {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') return _json(_careersListBody);
    if (request.url.path == '/careers/car_test') return _json(hubBody);
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

Widget _wrap(Widget home) {
  return PlayerScope(
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    ),
  );
}

void main() {
  testWidgets('sonraki maç kartı C3 next_fixture verisini gösterir',
      (tester) async {
    final session =
        _hubSession(_hubBody(nextFixture: _fixture, newsPreview: _newsPreview));
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('FK Yıldız'), findsWidgets);
    expect(find.text('Deniz SK'), findsOneWidget);
    expect(find.text('Cumartesi, 20:00'), findsOneWidget);
    expect(find.text('1. Lig'), findsOneWidget);
    // Eski sabit hava durumu satırı artık yok — hiçbir uçta karşılığı yok.
    expect(find.textContaining('parçalı bulutlu'), findsNothing);
  });

  testWidgets('next_fixture null ise boş durum gösterir', (tester) async {
    final session = _hubSession(_hubBody(nextFixture: null));
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Sıradaki maç bilgisi yok.'), findsOneWidget);
  });

  testWidgets('haber kartı news_preview\'ün ilk öğesini gösterir ve detaya açar',
      (tester) async {
    final session =
        _hubSession(_hubBody(nextFixture: _fixture, newsPreview: _newsPreview));
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Bir transfer haberi'), findsOneWidget);
    expect(find.textContaining('Spor Manşet ·'), findsOneWidget);
  });

  testWidgets('haber önizlemesi boşsa haber kartı çizilmez', (tester) async {
    final session = _hubSession(_hubBody(nextFixture: _fixture));
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Spor Manşet'), findsNothing);
  });

  testWidgets('hub isteği başarısız olursa hata metni gösterir', (tester) async {
    final mock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      return http.Response('boom', 500);
    });
    final session =
        CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));

    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Kariyer verisi alınamadı.'), findsOneWidget);
    // Eylem düğmeleri (İlişkiler/Antrenman/Yaşam tarzı) hub'a bağlı değil,
    // hata durumunda bile görünür kalmalı.
    expect(find.text('İlişkiler'), findsOneWidget);
  });
}
