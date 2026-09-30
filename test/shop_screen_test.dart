import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/lifestyle_screen.dart';
import 'package:project_srpg/screens/shop_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/shop_item_card.dart';

/// N3 `shop` kataloğu — career_engine/catalog/shop.py'nin bir kesiti: her
/// kategoriden en az bir kalem. `category` alanı [ShopCategory]'nin isimleriyle
/// birebir eşleşir (§5.7); giyilebilir kalemler §14.2'nin `slot`/`grade`/`acquire`
/// alanlarını taşır.
const _shopItems = [
  {'catalog_id': 'cloth-tailored-suit', 'title': 'Takım elbise', 'category': 'clothing',
   'description': '…', 'price': 15400, 'upkeep_weekly': 0, 'note': 'Ismarlama',
   'slot': 'formal', 'grade': 3, 'acquire': 'shop'},
  {'catalog_id': 'acc-smart-watch', 'title': 'Akıllı saat', 'category': 'accessory',
   'description': '…', 'price': 9000, 'upkeep_weekly': 0, 'note': 'Uyku takibi',
   'slot': 'watch', 'grade': 2, 'acquire': 'shop'},
  {'catalog_id': 'acc-swiss-watch', 'title': 'İsviçre saati', 'category': 'accessory',
   'description': '…', 'price': 27500, 'upkeep_weekly': 0, 'note': 'Mekanik',
   'slot': 'watch', 'grade': 4, 'acquire': 'shop'},
  {'catalog_id': 'tech-earbuds', 'title': 'Kulaklık', 'category': 'tech',
   'description': '…', 'price': 6200, 'upkeep_weekly': 0, 'note': 'Gürültü engelleyici',
   'slot': 'earbuds', 'grade': 1, 'acquire': 'shop'},
  {'catalog_id': 'veh-scooter', 'title': 'Elektrikli scooter', 'category': 'vehicle',
   'description': '…', 'price': 9000, 'upkeep_weekly': 0, 'note': 'Sempatik',
   'slot': 'vehicle', 'grade': 1, 'acquire': 'shop'},
  {'catalog_id': 'home-coffee-machine', 'title': 'Kahve makinesi', 'category': 'living',
   'description': '…', 'price': 12500, 'upkeep_weekly': 0, 'note': 'Otomatik öğütücülü',
   'slot': 'kitchen', 'grade': 1, 'acquire': 'shop', 'daily_effects': {'energy': 3}},
  {'catalog_id': 'special-foundation', 'title': 'Hayır vakfı', 'category': 'special',
   'description': '…', 'price': 0, 'upkeep_weekly': 0, 'note': 'Bir olayla kazanılır',
   'slot': 'foundation', 'grade': 5, 'acquire': 'grant'},
  {'catalog_id': 'veh-hypercar', 'title': 'Hiper otomobil', 'category': 'vehicle',
   'description': '…', 'price': 12750000, 'upkeep_weekly': 0, 'note': 'Sınırlı üretim',
   'slot': 'vehicle', 'grade': 5, 'acquire': 'shop'},
  {'catalog_id': 'invest-gold', 'title': 'Altın', 'category': 'investment',
   'description': '…', 'price': 40000, 'upkeep_weekly': 0, 'note': '100 gram'},
];

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// [purchaseResponses] `catalog_id` → T4'ün döneceği yeni `career_state`.
/// Bir `catalog_id` haritada yoksa satın alma isteği `409 already_owned`
/// döner — "bakiye yetmeyen ürün" testi bunu kullanır.
CareerSession _shopSession({
  Map<String, int> purchaseResponses = const {},
  List<Map<String, dynamic>> inventory = const [],
}) {
  // §14.2 · sunucunun envanter durumu; equip/unequip uçları bunu değiştirir.
  final owned = [...inventory];
  Map<String, dynamic> careerState() => {
        'current_date': '2026-08-05', 'season_id': '25/26',
        'money': 48200, 'condition': 72,
        'day_budget': {'time': 720.0},
      };
  final mock = MockClient((request) async {
    if (request.url.path == '/catalog/shop') {
      return _json({'items': _shopItems});
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
    if (request.url.path == '/careers/car_test/inventory') {
      return _json({'items': owned});
    }
    final equipMatch = RegExp(r'^/careers/car_test/inventory/([\w-]+)/(equip|unequip)$')
        .firstMatch(request.url.path);
    if (equipMatch != null) {
      final id = equipMatch.group(1)!;
      final on = equipMatch.group(2) == 'equip';
      final slot = owned.firstWhere((i) => i['catalog_id'] == id)['slot'];
      for (final row in owned) {
        if (row['slot'] == slot) row['equipped'] = on && row['catalog_id'] == id;
      }
      return _json({
        'career_state': careerState(),
        'items': owned,
        'passive_bonus': const {},
        'condition_recovery': const {},
      });
    }
    if (request.url.path == '/careers/car_test/purchases') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final catalogId = body['catalog_id'] as String;
      final newMoney = purchaseResponses[catalogId];
      if (newMoney == null) {
        return _json(
          {'code': 'insufficient_funds', 'message': 'balance is too low'},
          status: 409,
        );
      }
      return _json({
        'career_state': {
          'current_date': '2026-08-05', 'season_id': '25/26',
          'money': newMoney, 'condition': 72,
          'day_budget': {'time': 720.0},
        },
        // §14.2 · yuvası boşken satın alınan giyilebilir kalem hemen giyilir.
        'item': {
          'catalog_id': catalogId, 'purchased_at': '2026-08-05',
          'price_paid': 48200 - newMoney, 'upkeep_weekly': 0,
          'slot': _shopItems.firstWhere((i) => i['catalog_id'] == catalogId)['slot'],
          'grade': _shopItems.firstWhere((i) => i['catalog_id'] == catalogId)['grade'],
          'equipped': true,
        },
        'ledger_entries': const [],
      });
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

/// Kartın kendisine dokunur; metin, cam şeridin içinde olduğu için doğrudan
/// hedeflenmeye uygun değil.
Finder _card(String title) {
  return find.ancestor(
    of: find.text(title),
    matching: find.byType(ShopItemCard),
  );
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
  testWidgets('kategori sekmeleri içeriği değiştirir', (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(session: _shopSession())));
    await tester.pumpAndSettle();

    expect(find.text('Alışveriş'), findsOneWidget);
    expect(find.text('48.200 ₭'), findsOneWidget);
    expect(find.byType(ShopItemCard), findsWidgets);
    // Varsayılan sekme Giyim.
    expect(find.text('Takım elbise'), findsOneWidget);
    // §14.2 · derece, kartın köşesinde.
    expect(find.text('3'), findsWidgets);

    await tester.tap(find.text('Araç'));
    await tester.pumpAndSettle();

    expect(find.text('Takım elbise'), findsNothing);
    expect(find.text('Hiper otomobil'), findsOneWidget);
    // §14.4 · gayrimenkul artık mağazada değil, Konut ekranında.
    expect(find.text('Gayrimenkul'), findsNothing);

    await tester.tap(find.text('Yatırım'));
    await tester.pumpAndSettle();

    expect(find.text('Altın'), findsOneWidget);
  });

  testWidgets('alınabilir ürün parayı düşürür ve sahiplenilir', (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(
      session: _shopSession(purchaseResponses: {'tech-earbuds': 42000}),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Teknoloji'));
    await tester.pumpAndSettle();

    await tester.tap(_card('Kulaklık'));
    await tester.pumpAndSettle();

    expect(find.text('Satın Al'), findsOneWidget);
    expect(find.textContaining('Gürültü engelleyici'), findsOneWidget);

    await tester.tap(find.text('Satın Al'));
    await tester.pumpAndSettle();

    // Detay kapandı, bakiye düştü (48.200 - 6.200).
    expect(find.text('Satın Al'), findsNothing);
    expect(find.text('42.000 ₭'), findsOneWidget);

    // Kart artık sahip olarak işaretli (yuva boştu: hemen giyildi) ve
    // tekrar alınamıyor; düğme Çıkar'a döndü.
    expect(find.text('Takılı'), findsOneWidget);

    await tester.tap(_card('Kulaklık'));
    await tester.pumpAndSettle();
    expect(find.text('Çıkar'), findsOneWidget);
    expect(find.text('Satın Al'), findsNothing);
  });

  testWidgets('§12.12 · sahip olununca canlı fayda rozeti belirir', (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(
      session: _shopSession(purchaseResponses: {'home-coffee-machine': 35700}),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ev'));
    await tester.pumpAndSettle();

    await tester.tap(_card('Kahve makinesi'));
    await tester.pumpAndSettle();

    // Henüz sahip değil: not rozeti var, canlı fayda rozeti yok.
    expect(find.textContaining('Otomatik öğütücülü'), findsOneWidget);
    expect(find.text('Günlük +3 enerji'), findsNothing);

    await tester.tap(find.text('Satın Al'));
    await tester.pumpAndSettle();

    await tester.tap(_card('Kahve makinesi'));
    await tester.pumpAndSettle();

    // Artık sahip: not hâlâ orada, ama ayrıca canlı fayda rozeti de var.
    expect(find.textContaining('Otomatik öğütücülü'), findsOneWidget);
    expect(find.text('Günlük +3 enerji'), findsOneWidget);
  });

  testWidgets('§14.2 · aynı yuvadaki iki saatten biri giyilir, Tak diğerini çıkarır',
      (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(
      session: _shopSession(inventory: [
        {'catalog_id': 'acc-smart-watch', 'slot': 'watch', 'grade': 2, 'equipped': true},
        {'catalog_id': 'acc-swiss-watch', 'slot': 'watch', 'grade': 4, 'equipped': false},
      ]),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aksesuar'));
    await tester.pumpAndSettle();

    // Sunucudaki envanter: biri giyili, biri dolapta.
    expect(find.text('Takılı'), findsOneWidget);
    expect(find.text('Sahip'), findsOneWidget);

    await tester.tap(_card('İsviçre saati'));
    await tester.pumpAndSettle();
    expect(find.text('Tak'), findsOneWidget);

    await tester.tap(find.text('Tak'));
    await tester.pumpAndSettle();

    // Düğme Çıkar'a döndü; yuvayı sunucu devretti.
    expect(find.text('Çıkar'), findsOneWidget);

    await tester.tap(find.text('Çıkar'));
    await tester.pumpAndSettle();
    expect(find.text('Tak'), findsOneWidget);
  });

  testWidgets('§14.2 · olayla kazanılan kalem satın alınamaz', (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(session: _shopSession())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();

    await tester.tap(_card('Hayır vakfı'));
    await tester.pumpAndSettle();

    expect(find.text('Bir olayla kazanılır'), findsWidgets);
    expect(find.text('Satın Al'), findsNothing);
    expect(find.text('Bakiye yetersiz'), findsNothing);
  });

  testWidgets('bakiye yetmeyen ürün alınamaz', (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(session: _shopSession())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Araç'));
    await tester.pumpAndSettle();

    await tester.tap(_card('Hiper otomobil'));
    await tester.pumpAndSettle();

    expect(find.text('Bakiye yetersiz'), findsOneWidget);

    // Pasif butona basmak hiçbir şeyi değiştirmez.
    await tester.tap(find.text('Bakiye yetersiz'));
    await tester.pumpAndSettle();
    expect(find.text('Bakiye yetersiz'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('48.200 ₭'), findsOneWidget);
  });

  testWidgets('Yaşam Tarzı header\'ındaki butondan açılır', (tester) async {
    // Kategorilere ait etiketler ShopCategory enum'undan gelir, kataloğun
    // kendisinden değil — bu yüzden ShopScreen'in iç navigasyonu (LifestyleScreen
    // tarafından parametresiz kurulur) sahte bir backend gerektirmez.
    await tester.pumpWidget(_wrap(const LifestyleScreen()));

    await tester.tap(find.byTooltip('Alışveriş'));
    await tester.pumpAndSettle();

    expect(find.text('Alışveriş'), findsOneWidget);
    expect(find.text('Yatırım'), findsOneWidget);
  });
}
