import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/calendar_screen.dart';
import 'package:project_srpg/screens/pre_match_screen.dart';
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
  _Backend({this.status = 200, this.body, this.playerTeam = _ykz});

  final int status;
  final Map<String, Object?>? body;

  /// P1'in döneceği takım — `_dayMarks`'ın "rakip kim" hesabının girdisi.
  final Map<String, Object?> playerTeam;
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
      if (request.url.path == '/careers/car_1/player') {
        return _json({
          'player_id': 'p_user', 'name': 'Efe Kaan', 'position': 'Orta saha',
          'birth_date': '2004-08-19', 'age': 21, 'team': playerTeam,
          'career_state': {
            'current_date': '2026-08-19', 'season_id': '25/26',
            'money': 48200, 'condition': 80, 'day_budget': {'time': 720.0},
          },
          'attributes': const <dynamic>[], 'tactics': const <dynamic>[],
          'fame': const <dynamic>[],
        });
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
      if (request.url.path == '/careers/car_1/matches/next') {
        return _json({
          'fixture_id': 'f_1',
          'competition': {'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig'},
          'kickoff_at': '2026-08-19T20:00:00+03:00', 'user_side': 'home',
          'engine_payload': {
            'teams': {
              'home': {'name': 'FK Yıldız', 'attack': 63.0, 'midfield': 65.0,
                       'defense': 61.0, 'goalkeeper': 64.0, 'mentality': 'balanced'},
              'away': {'name': 'Deniz SK', 'attack': 68.0, 'midfield': 66.0,
                       'defense': 65.0, 'goalkeeper': 67.0, 'mentality': 'attacking'},
            },
            'user_side': 'home', 'user_condition': 70, 'client_seed': 1,
          },
        });
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

  testWidgets('maç günü hücresi rakip rozetiyle dolar', (tester) async {
    final backend = _Backend(); // playerTeam varsayılan _ykz — ev sahibi
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calCrest:8')), findsOneWidget);
    // Kullanıcı ev sahibi (_ykz), rakip deplasmandaki DNZ olmalı.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calCrest:8')),
        matching: find.text('DNZ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('kullanıcı deplasmandaysa rozet ev sahibini gösterir',
      (tester) async {
    final backend = _Backend(playerTeam: _dnz);
    await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calCrest:8')),
        matching: find.text('YKZ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('P1 çağrısı başarısız olursa takvim yine de çalışır',
      (tester) async {
    // _loadUserTeam sessizce vazgeçer; opponent hesaplaması ev sahibini
    // varsayarak devam eder (eski davranış).
    final mock = MockClient((request) async {
      if (request.url.path == '/careers') {
        return _json({'careers': [
          {'career_id': 'car_1', 'created_at': '2026-08-01T00:00:00+03:00',
           'season_id': '25/26', 'current_date': '2026-08-01',
           'player_name': 'Efe Kaan', 'team': _ykz}
        ]});
      }
      if (request.url.path == '/careers/car_1/calendar') {
        return _json(_august());
      }
      return http.Response('boom', 500);
    });
    final session =
        CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));

    await tester.pumpWidget(_wrap(CalendarScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calCrest:8')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('§6.1 D57 · "Maça çık" satırı', () {
    Map<String, Object?> augustWithTodayMatch({String status = 'scheduled'}) {
      final page = _august();
      (page['days'] as List).add({
        'date': '2026-08-19',
        'marks': [
          {
            'kind': 'match', 'ref_id': 'f_today',
            'competition': {'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig'},
            'round_no': 2, 'kickoff_at': '2026-08-19T20:00:00+03:00',
            'home': _ykz, 'away': _dnz,
            'status': status,
            'score': status == 'played' ? {'home': 1, 'away': 0} : null,
            'is_user_match': true,
          }
        ],
      });
      return page;
    }

    testWidgets('bugünün oynanmamış maçında görünür ve maç ekranını açar',
        (tester) async {
      final backend = _Backend(body: augustWithTodayMatch());
      final session = backend.session();
      // `onGoToMatch` karta bağlı olmayan düz bir MaterialPageRoute kullanır
      // (`_MatchPreviewSection` ile aynı gerekçe), bu yüzden `PreMatchScreen`
      // `CareerSession.instance`'a düşer — sanctioned test geçici override'ı
      // (`career_session.dart`'ın kendi doc comment'i).
      final previousInstance = CareerSession.instance;
      CareerSession.instance = session;
      addTearDown(() => CareerSession.instance = previousInstance);

      await tester.pumpWidget(_wrap(CalendarScreen(session: session)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('calDay:19')));
      await tester.pumpAndSettle();

      expect(find.text('Maça çık →'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('calGoToMatch')));
      await tester.pumpAndSettle();
      expect(find.byType(PreMatchScreen), findsOneWidget);
    });

    testWidgets('bugün değilse görünmez', (tester) async {
      final backend = _Backend(); // yalnız 8 Ağustos'ta maç, bugün 19'u
      await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('calDay:8')));
      await tester.pumpAndSettle();

      expect(find.text('Maça çık →'), findsNothing);
    });

    testWidgets('bugünün maçı zaten oynandıysa görünmez', (tester) async {
      final backend = _Backend(body: augustWithTodayMatch(status: 'played'));
      await tester.pumpWidget(_wrap(CalendarScreen(session: backend.session())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('calDay:19')));
      await tester.pumpAndSettle();

      expect(find.text('Maça çık →'), findsNothing);
    });
  });
}
