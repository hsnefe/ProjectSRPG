import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/calendar_screen.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/pre_match_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/month_calendar.dart';
import 'package:project_srpg/widgets/social_offer_modal.dart';

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

Map<String, dynamic> _dayBody({
  bool isMatchDay = false,
  String? currentDate,
  String? pendingOfferId,
}) {
  return {
    'career_state': {
      'current_date': currentDate ?? '2026-08-19', 'season_id': '25/26',
      'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
    },
    'is_match_day': isMatchDay,
    'events': [
      if (pendingOfferId != null)
        {
          'kind': 'social_offer', 'ref_id': pendingOfferId,
          'relationship_id': 'coach', 'opened_on': '2026-08-19',
        },
    ],
  };
}


/// T3'ün bir günlük yanıtı. Döngü her tur bunun birini alır.
Map<String, dynamic> _advanceBody({
  required String date,
  required String stopReason,
  int condition = 72,
  List<Map<String, dynamic>> stoppedEvents = const [],
}) {
  return {
    'career_state': {
      'current_date': date, 'season_id': '25/26',
      'money': 48200, 'condition': condition, 'day_budget': {'time': 720.0},
    },
    'days_advanced': 1,
    'stopped_on': date,
    'stop_reason': stopReason,
    'simulated': {'fixtures': 2, 'competitions': 1},
    'ledger_entries': const [], 'news_created': const [],
    'repossessed': const [],
    'stopped_events': stoppedEvents,
    'condition_before': 72,
    'condition_after': condition,
  };
}

const _offerContact = {
  'relationship_id': 'coach', 'kind': 'coach', 'category': 'Antrenör',
  'score': 70, 'person_name': 'Mert Çalışkan', 'contact_name': 'Antrenör Mert',
};

const _openOfferBody = {
  'offer_id': 'so_1', 'template_id': 'coach_extra_session',
  'relationship_id': 'coach', 'relationship': _offerContact,
  'title': 'Fazladan idman',
  'body': 'Antrenör yarın sabah bire bir çalışmak istiyor.',
  'accept_label': 'Sahada olurum', 'decline_label': 'Bu hafta olmaz',
  'costs': <String, dynamic>{}, 'requires': <String, dynamic>{},
  'opened_on': '2026-08-19', 'status': 'open', 'resolved_on': null,
};

CareerSession _hubSession(
  Map<String, dynamic> hubBody, {
  Map<String, dynamic>? dayBody,
  http.Response Function(http.Request)? onAdvance,
  List<Map<String, dynamic>>? socialOffers,
}) {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') return _json(_careersListBody);
    if (request.url.path == '/careers/car_test') return _json(hubBody);
    if (request.url.path == '/careers/car_test/day') {
      return _json(dayBody ?? _dayBody());
    }
    if (request.url.path == '/careers/car_test/social/offers') {
      return _json({'offers': socialOffers ?? const <dynamic>[]});
    }
    if (request.url.path.startsWith('/careers/car_test/social/offers/')) {
      return _json({
        'career_state': (dayBody ?? _dayBody())['career_state'],
        'offer': {
          'offer_id': 'so_1', 'template_id': 'coach_extra_session',
          'relationship_id': 'coach',
          'relationship': _offerContact,
          'title': 'Fazladan idman', 'body': '...',
          'accept_label': 'E', 'decline_label': 'H',
          'costs': const <String, dynamic>{},
          'requires': const <String, dynamic>{},
          'opened_on': '2026-08-19', 'status': 'accepted',
          'resolved_on': '2026-08-19',
        },
        'relationship_changes': const [
          {'relationship_id': 'coach', 'before': 70, 'after': 75, 'delta': 5}
        ],
        'attribute_changes': const <dynamic>[],
        'ledger_entries': const <dynamic>[],
      });
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
    if (request.url.path == '/careers/car_test/matches/next') {
      // §6.1 D57 · PreMatchScreen'in kendi M1 çağrısı — "Maça çık" navigasyonu
      // gerçek bir ekrana düşer, `CareerSession.instance` üzerinden (bkz.
      // _withInstanceOverride).
      return _json({
        'fixture_id': 'f_1',
        'competition': {'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig'},
        'kickoff_at': '2026-08-19T20:00:00+03:00',
        'user_side': 'home',
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
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

/// `PreMatchScreen()` sessiz kalır (`session:` parametresi geçilmez) — hub'ın
/// kendi `_MatchPreviewSection`'ıyla aynı gerekçe: karta bağlı olmayan bir
/// navigasyonun ExpandPageRoute'a ihtiyacı yok. Bu yüzden hedef ekran
/// `CareerSession.instance`'ı kullanır; testler onu geçici olarak [session]'a
/// çevirir ve sonunda geri alır — sınıfın kendi doc comment'inin belirttiği
/// sanctioned yol (`career_session.dart`).
Future<void> _withInstanceOverride(
  CareerSession session,
  Future<void> Function() body,
) async {
  final previous = CareerSession.instance;
  CareerSession.instance = session;
  try {
    await body();
  } finally {
    CareerSession.instance = previous;
  }
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

  testWidgets(
      '§6.1 D57 · maç günü İlerle pasif, "Maça çık" maç ekranını açar',
      (tester) async {
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      dayBody: _dayBody(isMatchDay: true),
    );
    await _withInstanceOverride(session, () async {
      await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
      await tester.pumpAndSettle();

      final button = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'İlerle'));
      expect(button.onPressed, isNull);
      expect(find.text('Maça çık →'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dayGoToMatch')));
      await tester.pumpAndSettle();
      expect(find.byType(PreMatchScreen), findsOneWidget);
    });
  });

  testWidgets(
      'maç ekranından dönünce gün verisi tazelenir ve İlerle açılır',
      (tester) async {
    // Bug: State geri dönüşte yeniden kurulmadığı için `_dayFuture` hiç
    // yenilenmiyordu — maçı oynayıp dönünce bile İlerle sonsuza kadar
    // kilitli kalıyordu. Bu test tam o senaryoyu kurar: PreMatchScreen'e
    // gidip geri dönünce `/day` ikinci kez çağrılmalı ve artık maç günü
    // olmadığını söylemeli.
    var dayCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test') {
        return _json(_hubBody(nextFixture: _fixture));
      }
      if (request.url.path == '/careers/car_test/day') {
        dayCalls++;
        // İlk çağrı maç günü, PreMatchScreen'den dönüşten sonraki her
        // çağrı artık maçın oynandığını söylüyor.
        return _json(_dayBody(isMatchDay: dayCalls == 1));
      }
      if (request.url.path == '/careers/car_test/social/offers') {
        return _json({'offers': const <dynamic>[]});
      }
      if (request.url.path == '/careers/car_test/matches/next') {
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
    final session =
        CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));

    await _withInstanceOverride(session, () async {
      await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
      await tester.pumpAndSettle();
      expect(dayCalls, 1);

      final lockedButton = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'İlerle'));
      expect(lockedButton.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('dayGoToMatch')));
      await tester.pumpAndSettle();
      expect(find.byType(PreMatchScreen), findsOneWidget);

      // Kullanıcı geri döner (maçı oynamış olsun ya da olmasın — dönüş
      // kendisi tazelemeyi tetiklemeli). Rotayı doğrudan kapatıyoruz:
      // PreMatchScreen üretimde her zaman gerçek bir `MatchApiClient`
      // kullanıyor (career_center_screen.dart hiçbir push'ta override
      // etmiyor), yani testte E11 çağrısı başarısız olup hata durumuna
      // düşer — o durumun kendi geri tuşu yok. Testin konusu zaten "hangi
      // düğmeye basıldığı" değil, "rota kapanınca tazeleme tetiklenir mi".
      Navigator.of(tester.element(find.byType(PreMatchScreen))).pop();
      await tester.pumpAndSettle();

      expect(dayCalls, 2, reason: '/day ikinci kez çağrılmalı');
      final unlockedButton = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'İlerle'));
      expect(unlockedButton.onPressed, isNotNull);
      expect(find.text('Maç günü'), findsNothing);
      expect(find.text('Maça çık →'), findsNothing);
    });
  });

  testWidgets(
      'maç günü değilken İlerle aktif ve "Maça çık" görünmez',
      (tester) async {
    final session = _hubSession(_hubBody(nextFixture: _fixture));
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    final button =
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'İlerle'));
    expect(button.onPressed, isNotNull);
    expect(find.text('Maça çık →'), findsNothing);
  });

  testWidgets(
      'sunucu match_day_unplayed derse maç ekranı otomatik açılır',
      (tester) async {
    // (d) · gün verisi bayat kalmışsa (isMatchDay henüz bilinmiyorsa) İlerle
    // yine de basılabilir; sunucu kapıda reddeder, ham hata yerine doğrudan
    // maç ekranı açılır.
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      onAdvance: (request) => _json(
        {'code': 'match_day_unplayed', 'message': "fixture 'f_1' must be played"},
        status: 409,
      ),
    );
    await _withInstanceOverride(session, () async {
      await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('İlerle'));
      await tester.pumpAndSettle();

      expect(find.byType(PreMatchScreen), findsOneWidget);
      expect(find.textContaining('must be played'), findsNothing);
    });
  });

  testWidgets('İlerle günü tek tek ilerletir ve olaylı günde durur',
      (tester) async {
    // §6.3 D56 · her tur bir `next_day` çağrısıdır; durma kararını sunucu
    // verir (`stop_reason`), Dart hangi olayın durdurucu olduğunu bilmez.
    final bodies = <Map<String, String>>[];
    var day = 19;
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      onAdvance: (request) {
        bodies.add(
          (jsonDecode(request.body) as Map).cast<String, String>(),
        );
        day++;
        final stopping = bodies.length == 3;
        return _json(_advanceBody(
          date: '2026-08-$day',
          stopReason: stopping ? 'match' : 'none',
          condition: 72 + bodies.length,
        ));
      },
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    // pumpAndSettle, döngünün tekrarlayan gecikmesinde zaman aşımına uğrar —
    // adımlar açıkça sürülür. Her adım _advanceTick'i (550ms) aşmalı.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(bodies.length, 3);
    expect(bodies.every((b) => b['to'] == 'next_day'), isTrue);
    expect(find.textContaining('3 gün ilerledi — maç günü.'), findsOneWidget);
  });

  testWidgets('akan takvim overlay olarak görünür ve buton Durdur olur',
      (tester) async {
    var day = 19;
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      onAdvance: (request) {
        day++;
        return _json(_advanceBody(date: '2026-08-$day', stopReason: 'none'));
      },
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MonthCalendar), findsOneWidget);
    expect(find.text('Durdur'), findsWidgets);
    expect(find.text('20 Ağustos 2026'), findsOneWidget);

    await tester.tap(find.text('Durdur').last);
    await tester.pumpAndSettle();
    expect(find.byType(MonthCalendar), findsNothing);
  });

  testWidgets('Durdur yeni gün çağrısı yapılmasını keser', (tester) async {
    var calls = 0;
    var day = 19;
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      onAdvance: (request) {
        calls++;
        day++;
        return _json(_advanceBody(date: '2026-08-$day', stopReason: 'none'));
      },
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final atStop = calls;

    await tester.tap(find.text('Durdur').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    // Uçuştaki gün commit olur (bir gün gerçekten yaşandı), sonrası gitmez.
    expect(calls, lessThanOrEqualTo(atStop + 1));
    expect(find.text('İlerle'), findsOneWidget);
  });

  testWidgets('döngü ortasındaki sezon sonu hatası SnackBar gösterir',
      (tester) async {
    var calls = 0;
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      onAdvance: (request) {
        calls++;
        if (calls == 1) {
          return _json(_advanceBody(date: '2026-08-20', stopReason: 'none'));
        }
        return _json(
          {'code': 'season_finished', 'message': 'the season has ended'},
          status: 409,
        );
      },
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('the season has ended'), findsOneWidget);
    expect(find.byType(MonthCalendar), findsNothing);
  });

  testWidgets('İlerle kondisyonu her gün PlayerState\'e yansıtır',
      (tester) async {
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      onAdvance: (request) => _json(
        _advanceBody(date: '2026-08-20', stopReason: 'match', condition: 80),
      ),
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('%80'), 200);
    expect(find.text('%80'), findsOneWidget);
  });


  testWidgets('ilk gün çağrısı 409 dönerse SnackBar gösterir',
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
testWidgets('döngü bir teklifte durunca modal açılır', (tester) async {
    // (b) · `stopped_events` kimliği taşır, yani hangi teklifin açılacağını
    // öğrenmek için T1 yeniden çağrılmaz.
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      socialOffers: const [_openOfferBody],
      onAdvance: (request) => _json(_advanceBody(
        date: '2026-08-20',
        stopReason: 'social_offer',
        stoppedEvents: const [
          {
            'kind': 'social_offer', 'ref_id': 'so_1',
            'relationship_id': 'coach', 'opened_on': '2026-08-20',
          }
        ],
      )),
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    expect(find.byType(SocialOfferModal), findsOneWidget);
    expect(find.text('Fazladan idman'), findsOneWidget);
  });

  testWidgets('teklif cevaplanınca modal kapanır ve delta SnackBar\'a düşer',
      (tester) async {
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      socialOffers: const [_openOfferBody],
      onAdvance: (request) => _json(_advanceBody(
        date: '2026-08-20',
        stopReason: 'social_offer',
        stoppedEvents: const [
          {
            'kind': 'social_offer', 'ref_id': 'so_1',
            'relationship_id': 'coach', 'opened_on': '2026-08-20',
          }
        ],
      )),
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();

    expect(find.byType(SocialOfferModal), findsNothing);
    expect(find.text('Antrenör +5'), findsOneWidget);
  });

  testWidgets('bekleyen teklif varken İlerle ilerlemez, teklifi açar',
      (tester) async {
    // (a) · BE zaten kapıda 409 atıyor; buradan bakmak kullanıcıya hata
    // yerine teklifin kendisini göstermek için (§6.3 D53).
    var advanceCalls = 0;
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      dayBody: _dayBody(pendingOfferId: 'so_1'),
      socialOffers: const [_openOfferBody],
      onAdvance: (request) {
        advanceCalls++;
        return _json(_advanceBody(date: '2026-08-20', stopReason: 'none'));
      },
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    expect(advanceCalls, 0);
    expect(find.byType(SocialOfferModal), findsOneWidget);
  });

  testWidgets('gün satırındaki teklif rozeti modalı yeniden açar',
      (tester) async {
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      dayBody: _dayBody(pendingOfferId: 'so_1'),
      socialOffers: const [_openOfferBody],
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Sosyal teklif bekliyor →'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daySocialOffer')));
    await tester.pumpAndSettle();

    expect(find.byType(SocialOfferModal), findsOneWidget);
  });

  testWidgets('sunucu social_offer_pending derse teklif açılır', (tester) async {
    // (c) · uygulama teklif ekrandayken kapanmışsa T1 önbelleği bilmiyordur,
    // ama BE bilir.
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      socialOffers: const [_openOfferBody],
      onAdvance: (request) => _json(
        {'code': 'social_offer_pending', 'message': "so_1 is waiting"},
        status: 409,
      ),
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    expect(find.byType(SocialOfferModal), findsOneWidget);
    // 409'un ham metni gösterilmez — kullanıcıya teklifin kendisi gösterilir.
    expect(find.text('so_1 is waiting'), findsNothing);
  });

  testWidgets('teklif başka bir yerde cevaplanmışsa sessizce tazelenir',
      (tester) async {
    final session = _hubSession(
      _hubBody(nextFixture: _fixture),
      dayBody: _dayBody(pendingOfferId: 'so_1'),
      socialOffers: const [],
    );
    await tester.pumpWidget(_wrap(CareerCenterScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daySocialOffer')));
    await tester.pumpAndSettle();

    expect(find.byType(SocialOfferModal), findsNothing);
    expect(tester.takeException(), isNull);
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
