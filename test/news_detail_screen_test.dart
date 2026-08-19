import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/news_detail_screen.dart';

const _newsIds = ['n_1', 'n_2'];

const _newsById = {
  'n_1': {
    'news_id': 'n_1', 'published_at': '2026-08-19T18:00:00+03:00',
    'category': 'Transfer', 'title': 'Birinci haber', 'source': 'Spor Manşet',
    'excerpt': 'Birinci haberin gövdesi.', 'fixture_id': null,
    'body': 'Birinci haberin gövdesi.',
  },
  'n_2': {
    'news_id': 'n_2', 'published_at': '2026-08-18T20:00:00+03:00',
    'category': 'Maç', 'title': 'İkinci haber', 'source': 'Lig Ajansı',
    'excerpt': 'İkinci haberin gövdesi.', 'fixture_id': null,
    'body': 'İkinci haberin gövdesi.',
  },
};

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

CareerSession _newsSession() {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test', 'player_name': 'Efe Kaan',
            'season_id': '25/26', 'current_date': '2026-08-19',
          }
        ],
      });
    }
    final match = RegExp(r'^/careers/car_test/news/(.+)$')
        .firstMatch(request.url.path);
    if (match != null) {
      final item = _newsById[match.group(1)];
      if (item == null) return http.Response('not found', 404);
      return _json(item);
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

Widget _wrap(Widget home) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: home,
  );
}

void main() {
  testWidgets('hero, kategori pili ve sayaç görünür', (tester) async {
    await tester.pumpWidget(_wrap(NewsDetailScreen(
      newsIds: _newsIds,
      initialIndex: 0,
      session: _newsSession(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Haber'), findsOneWidget);
    expect(find.text('Birinci haber'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.textContaining('Spor Manşet ·'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('pager haberler arasında gezinir', (tester) async {
    await tester.pumpWidget(_wrap(NewsDetailScreen(
      newsIds: _newsIds,
      initialIndex: 0,
      session: _newsSession(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sonraki haber'));
    await tester.pumpAndSettle();

    expect(find.text('İkinci haber'), findsOneWidget);
    expect(find.text('Birinci haber'), findsNothing);
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Önceki haber'));
    await tester.pumpAndSettle();

    expect(find.text('Birinci haber'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('uçlarda pager pasif kalır', (tester) async {
    await tester.pumpWidget(_wrap(NewsDetailScreen(
      newsIds: _newsIds,
      initialIndex: 0,
      session: _newsSession(),
    )));
    await tester.pumpAndSettle();

    // İlk haberde geriye gidilemez.
    await tester.tap(find.byTooltip('Önceki haber'));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);

    // Son haberde ileri gidilemez.
    await tester.tap(find.byTooltip('Sonraki haber'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sonraki haber'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('backend hatasında uyarı gösterir', (tester) async {
    final mock = MockClient((request) async {
      if (request.url.path == '/careers') {
        return _json({
          'careers': [
            {
              'career_id': 'car_test', 'player_name': 'Efe Kaan',
              'season_id': '25/26', 'current_date': '2026-08-19',
            }
          ],
        });
      }
      return http.Response('boom', 500);
    });
    final session =
        CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));

    await tester.pumpWidget(_wrap(NewsDetailScreen(
      newsIds: _newsIds,
      initialIndex: 0,
      session: session,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Haber alınamadı.'), findsOneWidget);
  });
}
