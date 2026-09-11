import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/transfer_offers_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

http.Response _json(Object? body, {int status = 200}) => http.Response(
      body == null ? 'null' : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _careerState = {
  'current_date': '2027-06-10',
  'season_id': '27/28',
  'season_phase': 'summer_transfer_window',
  'money': 60,
  'condition': 88,
  'day_budget': {'time': 720.0, 'energy': 100.0},
};

Map<String, dynamic> _offer({
  required String id,
  required String team,
  int wage = 80,
  bool isRenewal = false,
  bool counterUsed = false,
}) =>
    {
      'offer_id': id,
      'team': {
        'team_id': 't_$id',
        'name': team,
        'short_name': team.substring(0, 3).toUpperCase(),
        'color_primary': '#1E6FD9',
        'color_secondary': '#FFFFFF',
      },
      'competition': {
        'competition_id': 'c_lig1',
        'kind': 'league',
        'name': 'Süper Lig',
        'country': 'TR',
        'tier': 1,
      },
      'weekly_wage': wage,
      'appearance_bonus': 12,
      'goal_bonus': 24,
      'release_clause': 1600,
      'length_seasons': 3,
      'expires_at': '2030-06-01',
      'status': 'open',
      'is_renewal': isRenewal,
      'counter_used': counterUsed,
    };

/// Gelen POST yollarını biriktirir.
class _Calls {
  final List<String> posts = [];
}

CareerSession _session(
  _Calls calls, {
  Map<String, dynamic>? offersBody,
  Map<String, dynamic>? acceptBody,
  Map<String, dynamic>? counterBody,
  Map<String, dynamic>? declineBody,
}) {
  final mock = MockClient((request) async {
    final path = request.url.path;
    if (path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test',
            'player_name': 'Efe Kaan',
            'season_id': '27/28',
            'current_date': '2027-06-10',
          }
        ],
      });
    }
    if (path == '/careers/car_test/transfer/offers') {
      return _json(offersBody);
    }
    if (request.method == 'POST' && path.startsWith('/careers/car_test/transfer/offers/')) {
      calls.posts.add(path);
      if (path.endsWith('/accept')) return _json(acceptBody);
      if (path.endsWith('/counter')) return _json(counterBody);
      if (path.endsWith('/decline')) return _json(declineBody);
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

Future<void> _open(WidgetTester tester, CareerSession session) async {
  await tester.pumpWidget(_wrap(TransferOffersScreen(session: session)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pencere kapalıyken bilgilendirme gösterilir', (tester) async {
    await _open(
      tester,
      _session(_Calls(), offersBody: {
        'window': null,
        'closes_on': null,
        'offers': <dynamic>[],
      }),
    );

    expect(find.byKey(const Key('transfer_window_closed')), findsOneWidget);
  });

  testWidgets('pencere açık ama teklif yoksa ayrı bir metin çıkar',
      (tester) async {
    await _open(
      tester,
      _session(_Calls(), offersBody: {
        'window': 'summer',
        'closes_on': '2027-08-20',
        'offers': <dynamic>[],
      }),
    );

    expect(find.byKey(const Key('transfer_no_offers')), findsOneWidget);
  });

  testWidgets('yenileme ve rakip teklifler aynı listede görünür',
      (tester) async {
    await _open(
      tester,
      _session(_Calls(), offersBody: {
        'window': 'summer',
        'closes_on': '2027-08-20',
        'offers': [
          _offer(id: 'a', team: 'FK Yıldız', wage: 60, isRenewal: true),
          _offer(id: 'b', team: 'Deniz SK', wage: 95),
        ],
      }),
    );

    expect(find.byKey(const Key('offer_a')), findsOneWidget);
    expect(find.byKey(const Key('offer_b')), findsOneWidget);
    expect(find.text('YENİLEME'), findsOneWidget);
    expect(find.textContaining('Sezon arası'), findsOneWidget);
    // Şartlar Kredi biçiminde.
    expect(find.text('60 ₭'), findsOneWidget);
    expect(find.text('95 ₭'), findsOneWidget);
  });

  testWidgets('karşı teklif hakkı yalnızca yenilemede var', (tester) async {
    await _open(
      tester,
      _session(_Calls(), offersBody: {
        'window': 'summer',
        'closes_on': '2027-08-20',
        'offers': [
          _offer(id: 'a', team: 'FK Yıldız', isRenewal: true),
          _offer(id: 'b', team: 'Deniz SK'),
        ],
      }),
    );

    expect(find.byKey(const Key('counter_a')), findsOneWidget);
    expect(find.byKey(const Key('counter_b')), findsNothing);
  });

  testWidgets('karşı teklif hakkı kullanılmışsa buton kaybolur',
      (tester) async {
    await _open(
      tester,
      _session(_Calls(), offersBody: {
        'window': 'summer',
        'closes_on': '2027-08-20',
        'offers': [
          _offer(id: 'a', team: 'FK Yıldız', isRenewal: true, counterUsed: true),
        ],
      }),
    );

    expect(find.byKey(const Key('counter_a')), findsNothing);
    expect(find.textContaining('bir kez görüşüldü'), findsOneWidget);
  });

  testWidgets('kabul S4\'ü çağırır ve ekranı kapatır', (tester) async {
    final calls = _Calls();
    await _open(
      tester,
      _session(
        calls,
        offersBody: {
          'window': 'summer',
          'closes_on': '2027-08-20',
          'offers': [_offer(id: 'b', team: 'Deniz SK')],
        },
        acceptBody: {
          'career_state': _careerState,
          'team': {
            'team_id': 't_b',
            'name': 'Deniz SK',
            'short_name': 'DNZ',
            'color_primary': '#1E6FD9',
            'color_secondary': '#FFFFFF',
          },
          'competition': null,
          'contract': {
            'signed_at': '2027-06-10',
            'expires_at': '2030-06-01',
            'weekly_wage': 80,
            'appearance_bonus': 12,
            'goal_bonus': 24,
            'release_clause': 1600,
          },
        },
      ),
    );

    await tester.tap(find.byKey(const Key('accept_b')));
    await tester.pumpAndSettle();

    expect(calls.posts.single, endsWith('/transfer/offers/b/accept'));
  });

  testWidgets('reddetmek teklifi listeden düşürür', (tester) async {
    final calls = _Calls();
    await _open(
      tester,
      _session(
        calls,
        offersBody: {
          'window': 'summer',
          'closes_on': '2027-08-20',
          'offers': [
            _offer(id: 'a', team: 'FK Yıldız', isRenewal: true),
            _offer(id: 'b', team: 'Deniz SK'),
          ],
        },
        declineBody: {
          'career_state': _careerState,
          'window': 'summer',
          'closes_on': '2027-08-20',
          'offers': [_offer(id: 'a', team: 'FK Yıldız', isRenewal: true)],
        },
      ),
    );

    await tester.tap(find.byKey(const Key('decline_b')));
    await tester.pumpAndSettle();

    expect(calls.posts.single, endsWith('/transfer/offers/b/decline'));
    expect(find.byKey(const Key('offer_b')), findsNothing);
    expect(find.byKey(const Key('offer_a')), findsOneWidget);
  });
}
