import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/social_plan_screen.dart';
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
  'day_budget': {'time': 300.0, 'energy': 55.0},
};

Map<String, dynamic> _plan({
  String id = 'spl_1',
  String status = 'pending',
}) =>
    {
      'plan_id': id,
      'offer_id': 'so_1',
      'template_id': 'coach_extra_session',
      'relationship_id': 'coach',
      'title': 'Fazladan idman',
      'body': 'Antrenör Mert, yarın sabah antrenmandan önce seninle bire bir '
          'çalışmak istiyor.',
      'due_on': '2026-09-21',
      'status': status,
      'costs': {'time': 120.0, 'energy': 20.0},
      'relationship': {
        'relationship_id': 'coach',
        'kind': 'coach',
        'category': 'Antrenör',
        'score': 55,
        'person_name': 'Mert Aydın',
        'contact_name': 'Mert Hoca',
      },
    };

class _Calls {
  final List<String> posts = [];
}

CareerSession _session(_Calls calls, List<Map<String, dynamic>> plans) {
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
    if (path == '/careers/car_test/social/plans' && request.method == 'GET') {
      return _json({'plans': plans});
    }
    if (request.method == 'POST' &&
        path.startsWith('/careers/car_test/social/plans/')) {
      calls.posts.add(path);
      return _json({
        'career_state': _careerState,
        'plan': _plan(status: path.endsWith('/attend') ? 'done' : 'missed'),
        'relationship_changes': <dynamic>[],
        'attribute_changes': <dynamic>[],
        'ledger_entries': <dynamic>[],
      });
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
  await tester.pumpWidget(_wrap(SocialPlanScreen(session: session)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bekleyen plan yoksa bilgilendirme gösterilir', (tester) async {
    await _open(tester, _session(_Calls(), []));

    expect(find.byKey(const Key('social_plan_empty')), findsOneWidget);
  });

  testWidgets('bekleyen plan git/gitme ile gösterilir', (tester) async {
    final calls = _Calls();
    await _open(tester, _session(calls, [_plan()]));

    expect(find.byKey(const Key('plan_spl_1')), findsOneWidget);
    expect(find.textContaining('Fazladan idman'), findsOneWidget);
    expect(find.textContaining('2026-09-21'), findsOneWidget);
    expect(find.text('Git'), findsOneWidget);
    expect(find.text('Gitme'), findsOneWidget);
  });

  testWidgets('git attend çağırır', (tester) async {
    final calls = _Calls();
    await _open(tester, _session(calls, [_plan()]));

    await tester.tap(find.byKey(const Key('attend_spl_1')));
    await tester.pumpAndSettle();

    expect(calls.posts.single, endsWith('/social/plans/spl_1/attend'));
  });

  testWidgets('gitme skip çağırır', (tester) async {
    final calls = _Calls();
    await _open(tester, _session(calls, [_plan()]));

    await tester.tap(find.byKey(const Key('skip_spl_1')));
    await tester.pumpAndSettle();

    expect(calls.posts.single, endsWith('/social/plans/spl_1/skip'));
  });
}
