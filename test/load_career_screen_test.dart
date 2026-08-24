import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/load_career_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _car1 = {
  'career_id': 'car_1',
  'player_name': 'Efe Kaan',
  'player_age': 21,
  'season_id': '25/26',
  'current_date': '2026-08-19',
  'team': {
    'team_id': 't_plm', 'name': 'Palamut SK', 'short_name': 'PLM',
    'color_primary': '#003049', 'color_secondary': '#F5A623',
  },
  'competition': null,
};

const _car2 = {
  'career_id': 'car_2',
  'player_name': 'Ali Veli',
  'player_age': 24,
  'season_id': '25/26',
  'current_date': '2026-08-19',
  'team': {
    'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
    'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
  },
  'competition': null,
};

Map<String, dynamic> _hubBody(String careerId) => {
      'career_id': careerId,
      'career_state': {
        'current_date': '2026-08-19', 'season_id': '25/26',
        'money': 100, 'condition': 100, 'day_budget': {'time': 720.0},
      },
      'player': {
        'name': 'Efe Kaan', 'first_name': 'Efe', 'last_name': 'Kaan',
        'nationality': 'TR', 'position': 'Orta saha', 'role': 'regista',
        'role_name': 'Regista', 'age': 21,
        'team': {
          'team_id': 't_plm', 'name': 'Palamut SK', 'short_name': 'PLM',
          'color_primary': '#003049', 'color_secondary': '#F5A623',
        },
        'target_team': null,
      },
      'next_fixture': null,
      'standing_summary': null,
      'news_preview': <dynamic>[],
    };

const _dayBody = {
  'career_state': {
    'current_date': '2026-08-19', 'season_id': '25/26',
    'money': 100, 'condition': 100, 'day_budget': {'time': 720.0},
  },
  'is_match_day': false,
  'events': <dynamic>[],
};

/// [initialCareers] `/careers`'ın döneceği başlangıç listesi — silinen
/// kimlikler bir sonraki `GET /careers`'te otomatik düşer.
CareerSession _loadCareerSession({
  List<Map<String, dynamic>> initialCareers = const [_car1, _car2],
  int? listStatus,
}) {
  final deleted = <String>{};
  final mock = MockClient((request) async {
    if (request.url.path == '/careers' && request.method == 'GET') {
      if (listStatus != null) {
        return _json({'code': 'boom', 'message': 'motor çöktü'}, status: listStatus);
      }
      final remaining =
          initialCareers.where((c) => !deleted.contains(c['career_id']));
      return _json({'careers': remaining.toList()});
    }
    final deleteMatch =
        RegExp(r'^/careers/([^/]+)$').firstMatch(request.url.path);
    if (deleteMatch != null && request.method == 'DELETE') {
      deleted.add(deleteMatch.group(1)!);
      return http.Response('', 204);
    }
    if (deleteMatch != null && request.method == 'GET') {
      return _json(_hubBody(deleteMatch.group(1)!));
    }
    final dayMatch =
        RegExp(r'^/careers/([^/]+)/day$').firstMatch(request.url.path);
    if (dayMatch != null) {
      return _json(_dayBody);
    }
    return http.Response('unexpected ${request.method} ${request.url}', 404);
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
  testWidgets('kartlarda oyuncu adı, takım ve yaş görünür', (tester) async {
    await tester.pumpWidget(
      _wrap(LoadCareerScreen(session: _loadCareerSession())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Efe Kaan'), findsOneWidget);
    expect(find.text('Palamut SK'), findsOneWidget);
    expect(find.text('21 yaş'), findsOneWidget);

    expect(find.text('Ali Veli'), findsOneWidget);
    expect(find.text('FK Yıldız'), findsOneWidget);
    expect(find.text('24 yaş'), findsOneWidget);
  });

  testWidgets('çöp kutusu Sil/Vazgeç gösterir; Vazgeç isteği iptal eder',
      (tester) async {
    await tester.pumpWidget(
      _wrap(LoadCareerScreen(session: _loadCareerSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Sil'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(find.text('Sil'), findsNothing);
    // Hiçbir DELETE atılmadığı için ikisi de listede kalır.
    expect(find.text('Efe Kaan'), findsOneWidget);
    expect(find.text('Ali Veli'), findsOneWidget);
  });

  testWidgets('Sil düğmesi kariyeri kaldırır ve listeyi tazeler',
      (tester) async {
    await tester.pumpWidget(
      _wrap(LoadCareerScreen(session: _loadCareerSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Efe Kaan'), findsNothing);
    expect(find.text('Ali Veli'), findsOneWidget);
  });

  testWidgets(
      'seçim olmadan alt buton pasif; seçilince etkin ve kariyer merkezine girer',
      (tester) async {
    final original = CareerSession.instance;
    final session = _loadCareerSession();
    CareerSession.instance = session;
    addTearDown(() => CareerSession.instance = original);

    // session: geçilmez — CareerCenterScreen()'in kendi iç navigasyonu da
    // parametresiz kurulduğu için ikisi aynı singleton'ı paylaşsın diye.
    await tester.pumpWidget(_wrap(const LoadCareerScreen()));
    await tester.pumpAndSettle();

    final loadButton = find.text('Kariyeri Yükle');
    expect(loadButton, findsOneWidget);

    final buttonBefore = tester.widget<Opacity>(
      find.ancestor(of: loadButton, matching: find.byType(Opacity)).first,
    );
    expect(buttonBefore.opacity, 0.4);

    await tester.tap(find.text('Efe Kaan'));
    await tester.pumpAndSettle();

    final buttonAfter = tester.widget<Opacity>(
      find.ancestor(of: loadButton, matching: find.byType(Opacity)).first,
    );
    expect(buttonAfter.opacity, 1);

    await tester.tap(loadButton);
    await tester.pumpAndSettle();

    expect(find.byType(CareerCenterScreen), findsOneWidget);
    expect(session.careerId, 'car_1');
  });

  testWidgets('liste yüklenemezse Tekrar dene görünür', (tester) async {
    await tester.pumpWidget(
      _wrap(LoadCareerScreen(session: _loadCareerSession(listStatus: 500))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
  });
}
