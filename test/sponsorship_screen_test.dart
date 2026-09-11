import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/sponsorship_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

http.Response _json(Object? body, {int status = 200}) => http.Response(
      body == null ? 'null' : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _careerState = {
  'current_date': '2026-09-21',
  'season_id': '26/27',
  'season_phase': 'first_half',
  'money': 74,
  'condition': 80,
  'day_budget': {'time': 420.0, 'energy': 75.0},
};

Map<String, dynamic> _deal({
  required String id,
  String title = 'Kale Spor mağaza anlaşması',
  int income = 6,
  String status = 'offered',
  Map<String, dynamic>? obligation,
}) =>
    {
      'deal_id': id,
      'template_id': 'local_sports_shop',
      'brand': 'Kale Spor',
      'title': title,
      'body': 'Mahallenin spor mağazası formanı vitrine koymak istiyor.',
      'accept_label': 'İmzala',
      'decline_label': 'İlgilenmiyorum',
      'weekly_income': income,
      'seasons': 1,
      'requires': <String, dynamic>{},
      'obligation': obligation,
      'status': status,
      'signed_on': status == 'active' ? '2026-09-01' : null,
      'expires_on': status == 'active' ? '2027-06-05' : null,
      'obligations': <dynamic>[],
    };

class _Calls {
  final List<String> posts = [];
}

CareerSession _session(_Calls calls, Map<String, dynamic> state) {
  final mock = MockClient((request) async {
    final path = request.url.path;
    if (path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test',
            'player_name': 'Efe Kaan',
            'season_id': '26/27',
            'current_date': '2026-09-21',
          }
        ],
      });
    }
    if (path == '/careers/car_test/sponsorships') {
      return _json(state);
    }
    if (request.method == 'POST' &&
        path.startsWith('/careers/car_test/sponsorships/')) {
      calls.posts.add(path);
      return _json({'career_state': _careerState, 'deal': _deal(id: 'a')});
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
  await tester.pumpWidget(_wrap(SponsorshipScreen(session: session)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hiçbir şey yoksa bilgilendirme gösterilir', (tester) async {
    await _open(
      tester,
      _session(_Calls(), {
        'offers': <dynamic>[],
        'active': <dynamic>[],
        'pending_obligations': <dynamic>[],
      }),
    );

    expect(find.byKey(const Key('sponsorship_empty')), findsOneWidget);
  });

  testWidgets('yükümlülüğün bedeli imzadan önce görünür', (tester) async {
    await _open(
      tester,
      _session(_Calls(), {
        'offers': [
          _deal(
            id: 'a',
            title: 'Anadolu Bank reklam yüzü',
            income: 30,
            obligation: {
              'title': 'Reklam çekimi',
              'every_days': 30,
              'costs': {'time': 300.0, 'energy': 25.0},
              'condition': -8,
            },
          ),
        ],
        'active': <dynamic>[],
        'pending_obligations': <dynamic>[],
      }),
    );

    expect(find.textContaining('Reklam çekimi'), findsOneWidget);
    expect(find.textContaining('30 günde bir'), findsOneWidget);
    expect(find.text('30 ₭ / hafta'), findsOneWidget);
  });

  testWidgets('yükümlülüksüz anlaşma bunu açıkça söyler', (tester) async {
    await _open(
      tester,
      _session(_Calls(), {
        'offers': [_deal(id: 'a')],
        'active': <dynamic>[],
        'pending_obligations': <dynamic>[],
      }),
    );

    expect(find.text('Yükümlülük yok'), findsOneWidget);
  });

  testWidgets('imzalamak accept çağırır', (tester) async {
    final calls = _Calls();
    await _open(
      tester,
      _session(calls, {
        'offers': [_deal(id: 'a')],
        'active': <dynamic>[],
        'pending_obligations': <dynamic>[],
      }),
    );

    await tester.tap(find.byKey(const Key('accept_deal_a')));
    await tester.pumpAndSettle();

    expect(calls.posts.first, endsWith('/sponsorships/a/accept'));
  });

  testWidgets('bekleyen randevu katıl/gitme ile gösterilir', (tester) async {
    final calls = _Calls();
    await _open(
      tester,
      _session(calls, {
        'offers': <dynamic>[],
        'active': [
          _deal(
            id: 'a',
            status: 'active',
            obligation: {
              'title': 'Reklam çekimi',
              'every_days': 30,
              'costs': {'time': 300.0, 'energy': 25.0},
              'condition': -8,
            },
          ),
        ],
        'pending_obligations': [
          {'obligation_id': 'ob_1', 'deal_id': 'a', 'due_on': '2026-09-21'},
        ],
      }),
    );

    expect(find.byKey(const Key('obligation_ob_1')), findsOneWidget);
    expect(find.text('Katıl'), findsOneWidget);
    expect(find.text('Gitme'), findsOneWidget);
    // Bedelin ne olduğu yazıyor.
    expect(find.textContaining('anlaşma bozulur'), findsOneWidget);

    await tester.tap(find.byKey(const Key('attend_ob_1')));
    await tester.pumpAndSettle();
    expect(calls.posts.first, endsWith('/obligations/ob_1/attend'));
  });

  testWidgets('yürüyen anlaşmada buton yok, bilgi var', (tester) async {
    await _open(
      tester,
      _session(_Calls(), {
        'offers': <dynamic>[],
        'active': [_deal(id: 'a', status: 'active')],
        'pending_obligations': <dynamic>[],
      }),
    );

    expect(find.byKey(const Key('deal_a')), findsOneWidget);
    expect(find.byKey(const Key('accept_deal_a')), findsNothing);
    expect(find.text('6 ₭ / hafta'), findsOneWidget);
  });
}
