import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/career_list_screen.dart';
import 'package:project_srpg/screens/landing_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _ykz = {
  'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
  'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
};

const _careers = [
  {
    'career_id': 'car_2', 'player_name': 'Efe Kaan',
    'season_id': '25/26', 'current_date': '2026-08-19',
    'team': _ykz,
    'competition': {
      'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig',
    },
  },
  {
    'career_id': 'car_1', 'player_name': 'Deniz Ay',
    'season_id': '24/25', 'current_date': '2025-03-04',
  },
];

/// Kariyer merkezi seçilen kariyerin künyesini kendi başına çeker (C3 + T1);
/// tıklama testinde o iki uç da yanıtlanmalı.
Map<String, dynamic> _hubBody(String careerId) => {
      'career_id': careerId,
      'career_state': {
        'current_date': '2026-08-19', 'season_id': '25/26',
        'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
      },
      'player': {
        'name': 'Efe Kaan', 'position': 'Orta saha', 'age': 21,
        'team': _ykz,
      },
      'next_fixture': null,
      'standing_summary': null,
      'news_preview': const [],
    };

Map<String, dynamic> get _dayBody => {
      'career_state': {
        'current_date': '2026-08-19', 'season_id': '25/26',
        'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
      },
      'is_match_day': false,
      'events': const [],
    };

CareerSession _session({
  Object careers = const {'careers': _careers},
  int status = 200,
}) {
  final mock = MockClient((request) async {
    final path = request.url.path;
    if (path == '/careers') return _json(careers, status: status);
    if (path.endsWith('/day')) return _json(_dayBody);
    if (path.startsWith('/careers/')) {
      return _json(_hubBody(path.split('/').last));
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(
    client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'),
  );
}

Widget _wrap(Widget home) => PlayerScope(
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: home,
      ),
    );

void main() {
  testWidgets('kayıtlı kariyerler listelenir', (tester) async {
    await tester.pumpWidget(_wrap(CareerListScreen(session: _session())));
    await tester.pumpAndSettle();

    expect(find.text('KARİYERLER'), findsOneWidget);
    expect(find.text('Efe Kaan'), findsOneWidget);
    expect(find.text('FK Yıldız · 1. Lig'), findsOneWidget);
    expect(find.text('YKZ'), findsOneWidget);
    expect(find.text('25/26'), findsOneWidget);
    expect(find.text('19.08.2026'), findsOneWidget);

    // Kulübü olmayan kayıt da düşmez, satırı eksik alanı olmadan çizilir.
    expect(find.text('Deniz Ay'), findsOneWidget);
    expect(find.text('Kulüp atanmadı'), findsOneWidget);
  });

  testWidgets('kariyer yoksa boş durum gösterilir', (tester) async {
    await tester.pumpWidget(
      _wrap(CareerListScreen(session: _session(careers: const {'careers': []}))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Kayıtlı kariyer yok.'), findsOneWidget);
  });

  testWidgets('liste alınamazsa hata durumu ve yeniden deneme çıkar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        CareerListScreen(
          session: _session(
            careers: const {'code': 'server_error', 'message': 'olmadı'},
            status: 500,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kariyerler alınamadı.'), findsOneWidget);
    expect(find.text('olmadı'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsOneWidget);
  });

  testWidgets('satıra dokunmak kariyeri oturuma bağlar ve merkezi açar',
      (tester) async {
    // Kariyer merkezi kendi başına inşa edilir (session: geçilemez), bu yüzden
    // paylaşılan örnek geçici olarak sahte backend'e bağlanır.
    final original = CareerSession.instance;
    final session = _session();
    CareerSession.instance = session;
    addTearDown(() => CareerSession.instance = original);

    await tester.pumpWidget(_wrap(CareerListScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Efe Kaan'));
    await tester.pumpAndSettle();

    // Listenin ilki değil, dokunulan kayıt: C2 yeniden-eskiye sıralı geldiği
    // için ikisi karışırsa test sessizce geçerdi.
    expect(session.careerId, 'car_2');
    expect(find.byType(CareerCenterScreen), findsOneWidget);
    expect(find.byType(CareerListScreen), findsNothing);
  });

  testWidgets('Load Career açılıştan kariyer listesini açar', (tester) async {
    final original = CareerSession.instance;
    CareerSession.instance = _session();
    addTearDown(() => CareerSession.instance = original);

    await tester.pumpWidget(_wrap(const LandingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load Career'));
    await tester.pumpAndSettle();

    expect(find.byType(CareerListScreen), findsOneWidget);
    expect(find.text('Efe Kaan'), findsOneWidget);
  });
}
