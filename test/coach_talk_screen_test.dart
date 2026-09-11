import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/coach_talk_screen.dart';

http.Response _json(Object? body, {int status = 200}) => http.Response(
      body == null ? 'null' : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _careerState = {
  'current_date': '2026-08-08',
  'season_id': '25/26',
  'money': 60,
  'condition': 88,
  'day_budget': {'time': 700.0, 'energy': 98.0},
};

/// Gelen M4 gövdelerini biriktirir; testler hangi `topic`/`value` çiftinin
/// gittiğini buradan doğruluyor.
class _Recorder {
  final List<Map<String, dynamic>> posts = [];
}

CareerSession _session(
  _Recorder recorder, {
  Map<String, dynamic>? response,
  int status = 200,
  Object? errorBody,
}) {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test',
            'player_name': 'Efe Kaan',
            'season_id': '25/26',
            'current_date': '2026-08-08',
          }
        ],
      });
    }
    if (request.url.path == '/careers/car_test/matches/f_1/coach-talk') {
      recorder.posts.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (status != 200) return _json(errorBody, status: status);
      return _json(response);
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(
    client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'),
  );
}

Map<String, dynamic> _result({
  String topic = 'philosophy_accept',
  bool? granted,
  double trustBefore = 50,
  double trustAfter = 56,
  int scoreDelta = 2,
  Map<String, dynamic>? player,
}) =>
    {
      'career_state': _careerState,
      'topic': topic,
      'granted': granted,
      'relationship_changes': [
        {
          'relationship_id': 'coach',
          'before': 70,
          'after': 70 + scoreDelta,
          'delta': scoreDelta,
        }
      ],
      'trait_changes': [
        {
          'key': 'trust',
          'before': trustBefore,
          'after': trustAfter,
          'delta': trustAfter - trustBefore,
        }
      ],
      'condition_after': null,
      'player': player,
    };

Widget _wrap(Widget home) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    );

Future<void> _openAndSettle(WidgetTester tester, CareerSession session) async {
  await tester.pumpWidget(_wrap(CoachTalkScreen(
    fixtureId: 'f_1',
    coachName: 'Antrenör Mert',
    currentPosition: 'Orta saha',
    currentRole: 'regista',
    session: session,
  )));
  // Daktilo efekti bitene kadar.
  await tester.pump(const Duration(seconds: 3));
}


/// Seçenek listesi kaydırılabilir bir alanda; altı konu 800x600'ün altına
/// sığmıyor, o yüzden tıklamadan önce görünür kılınıyor — gerçek
/// kullanıcı da telefonda kaydırıyor.
Future<void> _tapChoice(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('altı konu da listelenir', (tester) async {
    final recorder = _Recorder();
    await _openAndSettle(tester, _session(recorder));

    expect(find.text('Oyun anlayışını kabul et'), findsOneWidget);
    expect(find.text('Oyun anlayışını reddet'), findsOneWidget);
    expect(find.text('Oyun tarzını kabul et'), findsOneWidget);
    expect(find.text('Oyun tarzını reddet'), findsOneWidget);
    expect(find.text('Pozisyon değişikliği iste'), findsOneWidget);
    expect(find.text('Rol değişikliği iste'), findsOneWidget);
  });

  testWidgets('kabul konusu değersiz gönderilir ve güven değişimini gösterir',
      (tester) async {
    final recorder = _Recorder();
    await _openAndSettle(tester, _session(recorder, response: _result()));

    await _tapChoice(tester, 'coach_topic_philosophy_accept');
    await tester.pump(const Duration(seconds: 3));

    expect(recorder.posts.single, {'topic': 'philosophy_accept'});
    expect(find.byKey(const Key('coach_trust_delta')), findsOneWidget);
    expect(find.text('50 → 56'), findsOneWidget);
    expect(find.text('+6'), findsOneWidget);
  });

  testWidgets('talep konusu önce hedef sorar, sonra değerle gönderir',
      (tester) async {
    final recorder = _Recorder();
    await _openAndSettle(
      tester,
      _session(
        recorder,
        response: _result(
          topic: 'request_position',
          granted: true,
          trustAfter: 45,
          scoreDelta: 0,
          player: {'position': 'Forvet', 'role': 'kanat'},
        ),
      ),
    );

    await _tapChoice(tester, 'coach_topic_request_position');

    // Mevcut pozisyon seçeneklerde olmamalı.
    expect(find.byKey(const Key('coach_target_Orta saha')), findsNothing);
    expect(find.byKey(const Key('coach_target_Forvet')), findsOneWidget);

    await _tapChoice(tester, 'coach_target_Forvet');
    await tester.pump(const Duration(seconds: 3));

    expect(recorder.posts.single, {'topic': 'request_position', 'value': 'Forvet'});
    expect(find.textContaining('Yeni görev'), findsOneWidget);
  });

  testWidgets('rol talebinde yalnızca mevcut pozisyonun rolleri gösterilir',
      (tester) async {
    final recorder = _Recorder();
    await _openAndSettle(tester, _session(recorder));

    await _tapChoice(tester, 'coach_topic_request_role');

    // Orta saha rolleri var, mevcut rol (regista) yok, defans rolü hiç yok.
    expect(find.byKey(const Key('coach_target_oyun_kurucu')), findsOneWidget);
    expect(find.byKey(const Key('coach_target_regista')), findsNothing);
    expect(find.byKey(const Key('coach_target_stoper')), findsNothing);
  });

  testWidgets('reddedilen talep kabul edilmiş gibi gösterilmez',
      (tester) async {
    final recorder = _Recorder();
    await _openAndSettle(
      tester,
      _session(
        recorder,
        response: _result(
          topic: 'request_role',
          granted: false,
          trustAfter: 48,
          scoreDelta: -2,
        ),
      ),
    );

    await _tapChoice(tester, 'coach_topic_request_role');
    await _tapChoice(tester, 'coach_target_oyun_kurucu');
    await tester.pump(const Duration(seconds: 3));

    expect(find.textContaining('Yeni görev'), findsNothing);
    // Reddedilen talep ikisini birden düşürüyor, o yüzden satırına bakılıyor:
    // düz find.text('-2') ikisini birden yakalardı.
    expect(
      find.descendant(
        of: find.byKey(const Key('coach_trust_delta')),
        matching: find.text('-2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('coach_score_delta')),
        matching: find.text('-2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sunucu hatası ekranda gösterilir, seçenekler açık kalır',
      (tester) async {
    final recorder = _Recorder();
    await _openAndSettle(
      tester,
      _session(
        recorder,
        status: 409,
        errorBody: {
          'code': 'coach_talk_already_done',
          'message': 'bu maç öncesi zaten konuşuldu',
        },
      ),
    );

    await _tapChoice(tester, 'coach_topic_style_accept');
    await tester.pump(const Duration(seconds: 3));

    expect(find.byKey(const Key('coach_talk_error')), findsOneWidget);
    expect(find.text('Oyun tarzını kabul et'), findsOneWidget);
  });

  testWidgets('pozisyon bilinmiyorsa talep seçenekleri gizlenir',
      (tester) async {
    final recorder = _Recorder();
    await tester.pumpWidget(_wrap(CoachTalkScreen(
      fixtureId: 'f_1',
      coachName: 'Antrenör Mert',
      session: _session(recorder),
    )));
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Oyun tarzını kabul et'), findsOneWidget);
    expect(find.text('Pozisyon değişikliği iste'), findsNothing);
    expect(find.text('Rol değişikliği iste'), findsNothing);
  });

  test('rolesForPosition bilinmeyen pozisyonda boş liste döner', () {
    expect(rolesForPosition(null), isEmpty);
    expect(rolesForPosition('Kaleci'), isEmpty);
    expect(rolesForPosition('Defans'), contains('stoper'));
  });
}
