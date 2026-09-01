import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/calendar_screen.dart';
import 'package:project_srpg/widgets/month_calendar.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _ykz = {
  'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
  'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
};
const _dnz = {
  'team_id': 't_dnz', 'name': 'Deniz SK', 'short_name': 'DNZ',
  'color_primary': '#0B2E5B', 'color_secondary': '#E8EAED',
};

Map<String, Object?> _august() => {
      'from': '2026-08-01',
      'to': '2026-08-31',
      'today': '2026-08-19',
      'season': {
        'season_id': '25/26',
        'starts_on': '2026-08-01',
        'ends_on': '2027-05-31',
      },
      'days': [
        {
          'date': '2026-08-08',
          'marks': [
            {
              'kind': 'match',
              'ref_id': 'f_1',
              'competition': {
                'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig',
              },
              'round_no': 1,
              'kickoff_at': '2026-08-08T20:00:00+03:00',
              'home': _ykz, 'away': _dnz,
              'status': 'scheduled', 'score': null, 'is_user_match': true,
            }
          ],
        },
        {
          'date': '2026-08-10',
          'marks': [{'kind': 'wage', 'ref_id': null}],
        },
      ],
    };

Map<String, Object?> _september() => {
      'from': '2026-09-01',
      'to': '2026-09-30',
      'today': '2026-08-19',
      'season': null,
      'days': [
        {
          'date': '2026-09-02',
          'marks': [
            {
              'kind': 'cup_round', 'ref_id': 'c_kupa',
              'round_no': 1, 'stage': 'r32', 'drawn': false,
            }
          ],
        },
      ],
    };

/// Her test kendi isteklerini biriktirir; sorgu parametrelerini doğrulamak
/// çizilen metni doğrulamaktan daha güçlü bir iddiadır.
class _Backend {
  _Backend({this.status = 200, this.body});

  final int status;
  final Map<String, Object?>? body;
  final List<Map<String, String>> requests = [];
  int calls = 0;

  CareerSession session() {
    final mock = MockClient((request) async {
      if (request.url.path == '/careers') {
        return _json({'careers': [
          {'career_id': 'car_1', 'created_at': '2026-08-01T00:00:00+03:00',
           'season_id': '25/26', 'current_date': '2026-08-01',
           'player_name': 'Efe Kaan', 'team': _ykz}
        ]});
      }
      if (request.url.path == '/careers/car_1/calendar') {
        calls++;
        requests.add(request.url.queryParameters);
        if (status != 200) {
          return _json({'code': 'server_error', 'message': 'patladı'},
              status: status);
        }
        final from = request.url.queryParameters['from'];
        if (from != null && from.startsWith('2026-09')) {
          return _json(_september());
        }
        return _json(body ?? _august());
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    return CareerSession(
      client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'),
    );
  }
}

Widget _wrap(Widget home) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    );

void main() {
  testWidgets('açılışta sınır göndermez — hangi ayda olduğumuzu BE söyler',
      (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    expect(backend.requests.single, isEmpty);
    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('› komşu ayı sınırlarıyla ister', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cal-next')));
    await tester.pumpAndSettle();

    expect(backend.requests.last, {'from': '2026-09-01', 'to': '2026-09-30'});
    expect(find.text('Eylül 2026'), findsOneWidget);
  });

  testWidgets('geri dönülen ay önbellekten gelir, yeni istek atılmaz',
      (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cal-next')));
    await tester.pumpAndSettle();
    expect(backend.calls, 2);

    await tester.tap(find.byKey(const ValueKey('cal-prev')));
    await tester.pumpAndSettle();

    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(backend.calls, 2, reason: 'önbellekten geldi');
  });

  testWidgets('işaretli güne dokununca detay dolar', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    expect(find.text('Bir güne dokun.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calDay:8')));
    await tester.pumpAndSettle();

    expect(find.text('8 Ağustos 2026'), findsOneWidget);
    expect(find.text('YKZ – DNZ'), findsOneWidget);
    expect(find.text('1. Lig · Cumartesi, 20:00'), findsOneWidget);
  });

  testWidgets('maaş günü kendi etiketiyle görünür', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calDay:10')));
    await tester.pumpAndSettle();

    expect(find.text('Maaş günü'), findsOneWidget);
  });

  testWidgets('kurası çekilmemiş kupa turu rakipsiz gösterilir',
      (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cal-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calDay:2')));
    await tester.pumpAndSettle();

    expect(find.text('Kupa turu'), findsOneWidget);
    expect(find.text('Kura henüz çekilmedi'), findsOneWidget);
  });

  testWidgets('işaretsiz gün boş metin gösterir', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calDay:14')));
    await tester.pumpAndSettle();

    expect(find.text('Bu günde bir şey yok.'), findsOneWidget);
  });

  testWidgets('oynanmış maç skoruyla görünür', (tester) async {
    final played = _august();
    (((played['days'] as List)[0] as Map)['marks'] as List)[0] = {
      'kind': 'match', 'ref_id': 'f_1',
      'competition': {'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig'},
      'round_no': 1, 'kickoff_at': '2026-08-08T20:00:00+03:00',
      'home': _ykz, 'away': _dnz,
      'status': 'played', 'score': {'home': 2, 'away': 1}, 'is_user_match': true,
    };
    final backend = _Backend(body: played);
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calDay:8')));
    await tester.pumpAndSettle();

    expect(find.text('YKZ 2-1 DNZ'), findsOneWidget);
  });

  testWidgets('hata PanelError gösterir, Tekrar dene yeniden çeker',
      (tester) async {
    final backend = _Backend(status: 500);
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(backend.calls, 1);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(backend.calls, 2);
  });

  testWidgets('tanınmayan bir işaret türü ekranı bozmaz', (tester) async {
    // §5.0 · BE yeni bir mark kind ekleyebilir.
    final future = _august();
    (future['days'] as List).add({
      'date': '2026-08-20',
      'marks': [{'kind': 'transfer_window', 'ref_id': null}],
    });
    final backend = _Backend(body: future);
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calDay:20')));
    await tester.pumpAndSettle();

    // Gün başlığı çizilir, tanınmayan satır sessizce atlanır.
    expect(find.text('20 Ağustos 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('MonthCalendar.isoDate ekranın istediği biçimi verir', () {
    expect(MonthCalendar.isoDate(DateTime(2026, 9, 5)), '2026-09-05');
  });
}
