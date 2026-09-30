import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/lifestyle_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/activity_card.dart';

/// N3 `lifestyle` kataloğu — career_engine/catalog/lifestyle.py'nin 15
/// kaleminin (üç grup) aynısı.
const _lifestyleItems = [
  {
    'catalog_id': 'ev-uyku', 'title': 'Uyku', 'group': 'EV AKTİVİTELERİ',
    'description': 'Erken yatıp dokuz saat kesintisiz uyu. Kaslar toparlanır, '
        'ertesi güne kondisyonun tazelenmiş başlarsın.',
    'duration_label': 'Tüm gece',
    'costs': {'time': 540}, 'effects': {'condition': 14},
  },
  {
    'catalog_id': 'ev-yemek', 'title': 'Sağlıklı Yemek', 'group': 'EV AKTİVİTELERİ',
    'description': '…', 'duration_label': '1 saat',
    'costs': {'time': 60}, 'effects': {'condition': 6, 'money': -250},
  },
  {
    'catalog_id': 'ev-meditasyon', 'title': 'Meditasyon', 'group': 'EV AKTİVİTELERİ',
    'description': '…', 'duration_label': '30 dakika',
    'costs': {'time': 30}, 'effects': {'condition': 5},
  },
  {
    'catalog_id': 'ev-oyun', 'title': 'Video Oyunu', 'group': 'EV AKTİVİTELERİ',
    'description': '…', 'duration_label': '3 saat',
    'costs': {'time': 180}, 'effects': {'condition': -6},
  },
  {
    'catalog_id': 'ev-film', 'title': 'Film Gecesi', 'group': 'EV AKTİVİTELERİ',
    'description': '…', 'duration_label': '2 saat',
    'costs': {'time': 120}, 'effects': {'condition': 2},
  },
  {
    'catalog_id': 'fiz-kosu', 'title': 'Sabah Koşusu', 'group': 'FİZİKSEL AKTİVİTELER',
    'description': '…', 'duration_label': '45 dakika',
    'costs': {'time': 45}, 'effects': {'condition': -8},
  },
  {
    'catalog_id': 'fiz-yuzme', 'title': 'Yüzme', 'group': 'FİZİKSEL AKTİVİTELER',
    'description': '…', 'duration_label': '1 saat',
    'costs': {'time': 60}, 'effects': {'condition': 8, 'money': -180},
  },
  {
    'catalog_id': 'fiz-bisiklet', 'title': 'Bisiklet', 'group': 'FİZİKSEL AKTİVİTELER',
    'description': '…', 'duration_label': '1,5 saat',
    'costs': {'time': 90}, 'effects': {'condition': -4},
  },
  {
    'catalog_id': 'fiz-yoga', 'title': 'Yoga', 'group': 'FİZİKSEL AKTİVİTELER',
    'description': '…', 'duration_label': '50 dakika',
    'costs': {'time': 50}, 'effects': {'condition': 7, 'money': -200},
  },
  {
    'catalog_id': 'fiz-sauna', 'title': 'Sauna & Masaj', 'group': 'FİZİKSEL AKTİVİTELER',
    'description': '…', 'duration_label': '2 saat',
    'costs': {'time': 120}, 'effects': {'condition': 16, 'money': -950},
  },
  {
    'catalog_id': 'sos-arkadas', 'title': 'Arkadaş Buluşması', 'group': 'SOSYAL AKTİVİTELER',
    'description': '…', 'duration_label': '3 saat',
    'costs': {'time': 180}, 'effects': {'condition': -3, 'money': -400},
  },
  {
    'catalog_id': 'sos-kafe', 'title': 'Kafe', 'group': 'SOSYAL AKTİVİTELER',
    'description': '…', 'duration_label': '1 saat',
    'costs': {'time': 60}, 'effects': {'condition': 1, 'money': -150},
  },
  {
    'catalog_id': 'sos-aile', 'title': 'Aile Ziyareti', 'group': 'SOSYAL AKTİVİTELER',
    'description': '…', 'duration_label': 'Yarım gün',
    'costs': {'time': 360}, 'effects': {'condition': 4, 'relationship:family': 3},
  },
  {
    'catalog_id': 'sos-konser', 'title': 'Konser', 'group': 'SOSYAL AKTİVİTELER',
    'description': '…', 'duration_label': 'Tüm gece',
    'costs': {'time': 540}, 'effects': {'condition': -12, 'money': -1200},
  },
  {
    'catalog_id': 'sos-taraftar', 'title': 'Taraftar Etkinliği', 'group': 'SOSYAL AKTİVİTELER',
    'description': '…', 'duration_label': '2 saat',
    'costs': {'time': 120}, 'effects': {'condition': -2, 'fame:overall': null},
  },
];

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// [actionResponses] `catalog_id` → o eylem için T2'nin döneceği yeni
/// `career_state`. Yalnızca testin gerçekten tıkladığı kalemler için gerekir.
CareerSession _lifestyleSession({
  Map<String, Map<String, dynamic>> actionResponses = const {},
}) {
  final mock = MockClient((request) async {
    if (request.url.path == '/catalog/lifestyle') {
      return _json({'items': _lifestyleItems});
    }
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
    if (request.url.path == '/careers/car_test/actions') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final careerState = actionResponses[body['catalog_id']];
      if (careerState == null) {
        return http.Response('unexpected catalog_id ${body['catalog_id']}', 404);
      }
      return _json({
        'career_state': careerState,
        'applied_costs': const {},
        'applied_effects': const {},
        'attribute_changes': const [],
        'relationship_changes': const [],
        'ledger_entries': const [],
      });
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

/// D42 · `sos-taraftar`'a bir eşik takar ve oyuncunun cazibe seviyesini
/// [charismaLevel] yapar. Kilitli/açık kartın aynı ekranda nasıl göründüğünü
/// test etmenin tek yolu bu ikisini birlikte kurmak.
CareerSession _gatedLifestyleSession({
  required int charismaLevel,
  List<Map<String, dynamic>> actionAttributeChanges = const [],
}) {
  final items = [
    for (final item in _lifestyleItems)
      if (item['catalog_id'] == 'sos-taraftar')
        {...item, 'requires': const {'charisma': 8}}
      else
        item,
  ];
  final mock = MockClient((request) async {
    if (request.url.path == '/catalog/lifestyle') {
      return _json({'items': items});
    }
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
    if (request.url.path == '/careers/car_test/actions') {
      return _json({
        'career_state': _careerState(condition: 72, money: 48200),
        'applied_costs': const {},
        'applied_effects': const {},
        'attribute_changes': actionAttributeChanges,
        'relationship_changes': const [],
        'ledger_entries': const [],
      });
    }
    if (request.url.path == '/careers/car_test/player') {
      return _json({
        'player_id': 'p_user', 'name': 'Efe Kaan', 'position': 'Orta saha',
        'birth_date': '2004-08-19', 'age': 21,
        'team': {
          'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
          'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
        },
        'career_state': _careerState(condition: 72, money: 48200),
        'attributes': [
          {
            'key': 'charisma', 'family': 'kişi',
            'value': charismaLevel * 10.0, 'level': charismaLevel,
          },
        ],
        'tactics': const [],
        'fame': const [], 'market_value': null,
      });
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

Map<String, dynamic> _careerState({required int condition, required int money}) => {
      'current_date': '2026-08-05', 'season_id': '25/26',
      'money': money, 'condition': condition,
      'day_budget': {'time': 720.0},
    };

Widget _wrap(Widget home, {CareerSession? session}) {
  return PlayerScope(
    // Nitelik seviyeleri P1'den gelir; kilitli kartı test edebilmek için
    // PlayerState'in de sahte oturumu görmesi gerekiyor.
    session: session,
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    ),
  );
}

/// Kartın kendisine dokunur; metin, cam şeridin içinde olduğu için doğrudan
/// hedeflenmeye uygun değil.
Finder _card(String title) {
  return find.ancestor(
    of: find.text(title),
    matching: find.byType(ActivityCard),
  );
}

void main() {
  testWidgets('üç aktivite sırası ve kondisyon barı görünür', (tester) async {
    await tester.pumpWidget(
      _wrap(LifestyleScreen(session: _lifestyleSession())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kondisyon'), findsOneWidget);
    expect(find.text('72/100'), findsOneWidget);

    expect(find.text('EV AKTİVİTELERİ'), findsOneWidget);
    expect(find.text('FİZİKSEL AKTİVİTELER'), findsOneWidget);

    // Üçüncü sıra dikey listede aşağıda kalıyor. Ekranda birden fazla
    // scrollable olduğu için dıştaki dikey liste açıkça verilmeli.
    await tester.scrollUntilVisible(
      find.text('SOSYAL AKTİVİTELER'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SOSYAL AKTİVİTELER'), findsOneWidget);

    // Her sıra yatay kaydırılabilir olmalı.
    final rows = tester.widgetList<ListView>(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
    );
    expect(rows.length, 3);

    expect(find.byType(ActivityCard), findsWidgets);
    expect(find.byTooltip('Alışveriş'), findsOneWidget);
  });

  testWidgets('Grupsal sekmesi placeholder gösterir', (tester) async {
    await tester.pumpWidget(
      _wrap(LifestyleScreen(session: _lifestyleSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grupsal'));
    await tester.pumpAndSettle();

    expect(find.text('Grup aktiviteleri yakında.'), findsOneWidget);
    expect(find.text('EV AKTİVİTELERİ'), findsNothing);

    await tester.tap(find.text('Bireysel'));
    await tester.pumpAndSettle();

    expect(find.text('EV AKTİVİTELERİ'), findsOneWidget);
  });

  testWidgets('karta basınca detay açılır, Yap kondisyonu değiştirir',
      (tester) async {
    await tester.pumpWidget(_wrap(LifestyleScreen(
      session: _lifestyleSession(actionResponses: {
        'ev-uyku': _careerState(condition: 86, money: 48200),
      }),
    )));
    await tester.pumpAndSettle();

    await tester.tap(_card('Uyku'));
    await tester.pumpAndSettle();

    // Açıklama ve aksiyon butonu detayda görünür.
    expect(find.textContaining('dokuz saat'), findsOneWidget);
    expect(find.text('Yap'), findsOneWidget);
    expect(find.text('+14 kondisyon'), findsOneWidget);

    await tester.tap(find.text('Yap'));
    await tester.pumpAndSettle();

    // Detay kapandı ve header'daki bar güncellendi (72 + 14).
    expect(find.text('Yap'), findsNothing);
    expect(find.text('86/100'), findsOneWidget);
  });

  testWidgets('boşluğa basınca detay kapanır, kondisyon değişmez',
      (tester) async {
    await tester.pumpWidget(
      _wrap(LifestyleScreen(session: _lifestyleSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(_card('Uyku'));
    await tester.pumpAndSettle();
    expect(find.text('Yap'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Yap'), findsNothing);
    expect(find.text('72/100'), findsOneWidget);
  });

  testWidgets('kondisyon ve para diğer ekranlarla paylaşılır', (tester) async {
    // career_center_screen.dart iç navigasyonda LifestyleScreen()'i
    // parametresiz kurar — bu zincire sahte backend'i ancak paylaşılan
    // singleton üzerinden ulaştırabiliriz. Test sonunda geri alınır.
    final original = CareerSession.instance;
    CareerSession.instance = _lifestyleSession(actionResponses: {
      'fiz-yuzme': _careerState(condition: 80, money: 48020),
    });
    addTearDown(() => CareerSession.instance = original);

    await tester.pumpWidget(_wrap(const CareerCenterScreen()));
    await tester.pumpAndSettle();

    expect(find.text('%72'), findsOneWidget);
    expect(find.text('48.200 ₭'), findsOneWidget);

    // Kariyer merkezinden yaşam tarzına geç.
    await tester.scrollUntilVisible(find.text('Yaşam tarzı'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yaşam tarzı'));
    await tester.pumpAndSettle();
    expect(find.text('72/100'), findsOneWidget);

    // Ücretli bir aktivite yap: hem kondisyon hem para değişmeli.
    await tester.tap(_card('Yüzme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yap'));
    await tester.pumpAndSettle();
    expect(find.text('80/100'), findsOneWidget);

    // Geri dön: kariyer merkezi aynı değerleri gösterir.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('%80'), -200);
    expect(find.text('%80'), findsOneWidget);
    expect(find.text('48.020 ₭'), findsOneWidget);
  });

  testWidgets('eşiği tutulmayan aktivite kilitli görünür ve yapılamaz',
      (tester) async {
    final session = _gatedLifestyleSession(charismaLevel: 7);
    await tester.pumpWidget(
      _wrap(LifestyleScreen(session: session), session: session),
    );
    await tester.pumpAndSettle();

    // SOSYAL sırası dikey listede aşağıda; ayrıca 'Taraftar Etkinliği' o
    // sıranın yatay listesinde sonda duruyor.
    await tester.scrollUntilVisible(
      find.text('SOSYAL AKTİVİTELER'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Taraftar Etkinliği'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    final card = tester.widget<ActivityCard>(_card('Taraftar Etkinliği'));
    expect(card.activity.locked, isTrue);
    expect(card.activity.unmetRequirements, {'charisma': 8});

    // Kart yine de açılır — gerekçe detayda okunur, dokunup hiçbir şey
    // olmaması kartı bozuk gösterirdi.
    await tester.tap(_card('Taraftar Etkinliği'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lifestyle_requirement_badge')), findsOneWidget);
    expect(find.text('Karizma 8 gerekli'), findsOneWidget);
    expect(find.text('Kilitli'), findsOneWidget);
    expect(find.text('Yap'), findsNothing);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('eşik karşılanınca aynı aktivite açılır', (tester) async {
    final session = _gatedLifestyleSession(charismaLevel: 8);
    await tester.pumpWidget(
      _wrap(LifestyleScreen(session: session), session: session),
    );
    await tester.pumpAndSettle();

    // SOSYAL sırası dikey listede aşağıda; ayrıca 'Taraftar Etkinliği' o
    // sıranın yatay listesinde sonda duruyor.
    await tester.scrollUntilVisible(
      find.text('SOSYAL AKTİVİTELER'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Taraftar Etkinliği'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    final card = tester.widget<ActivityCard>(_card('Taraftar Etkinliği'));
    expect(card.activity.locked, isFalse);

    await tester.tap(_card('Taraftar Etkinliği'));
    await tester.pumpAndSettle();

    expect(find.text('Yap'), findsOneWidget);
    expect(find.byKey(const Key('lifestyle_requirement_badge')), findsNothing);
  });

  testWidgets('bir aktivite kilidi açınca kart aynı karede çözülür',
      (tester) async {
    // §5.5 · T2 yanıtındaki `level_after` tam olarak bunun için var: FE
    // ham değerden seviye türetmediği için, kapının açıldığını ancak
    // sunucu söylerse bilir — ve P1'i yeniden çekmeden bilmelidir.
    final session = _gatedLifestyleSession(
      charismaLevel: 7,
      actionAttributeChanges: const [
        {
          'key': 'charisma', 'before': 79.7, 'after': 80.0,
          'level_before': 7, 'level_after': 8,
        },
      ],
    );
    await tester.pumpWidget(
      _wrap(LifestyleScreen(session: session), session: session),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('SOSYAL AKTİVİTELER'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Taraftar Etkinliği'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ActivityCard>(_card('Taraftar Etkinliği')).activity.locked,
      isTrue,
    );

    // Karizmayı yükselten başka bir sosyal aktiviteyi yap. Yatay sıra az önce
    // sonuna kaydırıldığı için başa dönmek gerekiyor.
    await tester.scrollUntilVisible(
      find.text('Arkadaş Buluşması'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(_card('Arkadaş Buluşması'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yap'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Taraftar Etkinliği'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ActivityCard>(_card('Taraftar Etkinliği')).activity.locked,
      isFalse,
      reason: 'level_after 8 geldi, kart P1 tazelenmeden açılmalı',
    );
  });
}
