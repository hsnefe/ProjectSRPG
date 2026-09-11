import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/contract_screen.dart';

http.Response _json(Object? body, {int status = 200}) => http.Response(
      body == null ? 'null' : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

CareerSession _sessionWithContract(Object? contractBody) {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test', 'player_name': 'Efe Kaan',
            'season_id': '25/26', 'current_date': '2026-08-05',
          }
        ],
      });
    }
    if (request.url.path == '/careers/car_test/player/contract') {
      return _json(contractBody);
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

const _contract = {
  'team': {
    'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
    'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
  },
  'signed_at': '2024-07-01',
  'expires_at': '2027-06-30',
  'weekly_wage': 180000,
  'appearance_bonus': 25000,
  'goal_bonus': 40000,
  'release_clause': 12000000,
  'days_until_expiry': 472,
};

void main() {
  testWidgets('sözleşme ekranı maaş, prim ve bitiş tarihini listeler',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ContractScreen(session: _sessionWithContract(_contract)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FK Yıldız'), findsOneWidget);
    expect(find.text('01.07.2024'), findsOneWidget);
    expect(find.text('30.06.2027'), findsOneWidget);
    expect(find.text('180.000 ₭'), findsOneWidget);
    // Aylık maaş türetilmiş: weekly_wage × 4 (§3.2), ayrı bir BE alanı değil.
    expect(find.text('720.000 ₭'), findsOneWidget);
    expect(find.text('25.000 ₭'), findsOneWidget);
    expect(find.text('40.000 ₭'), findsOneWidget);
    expect(find.text('12.000.000 ₭'), findsOneWidget);
  });

  testWidgets('Sözleşme Uzat butonu yakında mesajı gösterir', (tester) async {
    await tester.pumpWidget(_wrap(
      ContractScreen(session: _sessionWithContract(_contract)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sözleşme Uzat'));
    await tester.pump();

    expect(find.text('Sözleşme uzatma yakında'), findsOneWidget);

    // SnackBar'ın 2 saniyelik kapanma timer'ını boşalt; yoksa teardown'da
    // "A Timer is still pending" hatası riski var.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('sözleşme yoksa (BE null döner) bilgilendirme metni görünür',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ContractScreen(session: _sessionWithContract(null)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Henüz bir sözleşmen yok.'), findsOneWidget);
  });
}
