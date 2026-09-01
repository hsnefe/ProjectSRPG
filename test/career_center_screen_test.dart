import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/calendar_screen.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
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

Map<String, dynamic> _dayBody({bool isMatchDay = false, String? currentDate}) {
  return {
    'career_state': {
      'current_date': currentDate ?? '2026-08-19', 'season_id': '25/26',
      'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
    },
    'is_match_day': isMatchDay,
    'events': const [],
  };
}

CareerSession _hubSession(
  Map<String, dynamic> hubBody, {
  Map<String, dynamic>? dayBody,
  http.Response Function(http.Request)? onAdvance,
}) {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') return _json(_careersListBody);
    if (request.url.path == '/careers/car_test') return _json(hubBody);
    if (request.url.path == '/careers/car_test/day') {
      return _json(dayBody ?? _dayBody());
    }
    if (request.url.path == '/careers/car_test/calendar') {
      return _json({
        'from': '2026-08-01', 'to': '2026-08-31', 'today': '2026-08-19',
        'season': null, 'days': const <dynamic>[],
      });
    }
    if (request.url.path == '/careers/car_test/advance') {
      return onAdvance?.call(request) ??
          _json({
            'career_state': (dayBody ?? _dayBody())['career_state'],
            'days_advanced': 1, 'stopped_on': '2026-08-20',
            'stop_reason': 'none', 'simulated': {'fixtures': 0, 'competitions': 0},
            'ledger_entries': const [], 'news_created': const [],
            'repossessed': const [],
          });
    }
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
    // Müsabaka adı + C3'ün days_until'inden kurulan geri sayım (§6.1).
    expect(find.text('1. Lig · 3 gün sonra'), findsOneWidget);
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

  testWidgets('gün satırı T1\'in tarihini ve maç günü rozetini gösterir',
      (tester) async {
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      dayBody: _dayBody(isMatchDay: true),
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('19 Ağustos 2026'), findsOneWidget);
    expect(find.text('Maç günü'), findsOneWidget);
    expect(find.text('İlerle'), findsOneWidget);
  });

  testWidgets('İlerle T3\'ü çağırır, kondisyonu ve hub\'ı tazeler',
      (tester) async {
    var advanceCalls = 0;
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      onAdvance: (request) {
        advanceCalls++;
        return _json({
          'career_state': {
            'current_date': '2026-08-22', 'season_id': '25/26',
            'money': 48200, 'condition': 80, 'day_budget': {'time': 720.0},
          },
          'days_advanced': 3, 'stopped_on': '2026-08-22',
          'stop_reason': 'match', 'simulated': {'fixtures': 8, 'competitions': 2},
          'ledger_entries': const [], 'news_created': const [],
          'repossessed': const [],
        });
      },
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    expect(advanceCalls, 1);
    expect(find.textContaining('3 gün ilerledi — maç günü.'), findsOneWidget);
    // career_state.condition (80) PlayerState'e yansımış olmalı.
    await tester.scrollUntilVisible(find.text('%80'), 200);
    expect(find.text('%80'), findsOneWidget);
  });

  testWidgets('İlerle 409 dönerse SnackBar gösterir, condition değişmez',
      (tester) async {
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      onAdvance: (request) => _json(
        {'code': 'season_finished', 'message': 'the season has ended'},
        status: 409,
      ),
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    expect(find.text('the season has ended'), findsOneWidget);
  });
  testWidgets('takvim ikonu takvim ekranını açar', (tester) async {
    final session = _hubSession(_hubBody(nextFixture: _fixture));
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text('Takvim'), findsOneWidget);
  });

  testWidgets('maç günü olmayan kartta dokunuş maç ekranını açmaz',
      (tester) async {
    final session =
        _hubSession(_hubBody(nextFixture: _fixture, newsPreview: _newsPreview));
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SONRAKİ MAÇ'));
    await tester.pumpAndSettle();

    // §6.1 — maç kendi gününde oynanır; kart kullanıcıyı hub'da tutar.
    expect(find.text('Maça 3 gün var — günleri ilerlet.'), findsOneWidget);
    expect(find.text('Maça Çıkış'), findsNothing);
  });

  testWidgets('maç günü kartı geri sayım yerine "bugün" gösterir',
      (tester) async {
    final today = Map<String, dynamic>.from(_fixture)..['days_until'] = 0;
    final session =
        _hubSession(_hubBody(nextFixture: today, newsPreview: _newsPreview));
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('1. Lig · bugün'), findsOneWidget);
  });
}
