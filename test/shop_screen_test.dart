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

/// N3 `shop` kataloğu — career_engine/catalog/shop.py'nin 14 kaleminin
/// (dört kategori) aynısı. `category` alanı [ShopCategory]'nin isimleriyle
/// birebir eşleşir (§5.7).
const _shopItems = [
  {'catalog_id': 'home-tv', 'title': 'Akıllı TV', 'category': 'home',
   'description': '…', 'price': 32000, 'upkeep_weekly': 0, 'note': '65 inç, 4K'},
  {'catalog_id': 'home-espresso', 'title': 'Espresso makinesi', 'category': 'home',
   'description': '…', 'price': 12500, 'upkeep_weekly': 0, 'note': 'Otomatik öğütücülü',
   'daily_effects': {'energy': 3}},
  {'catalog_id': 'home-console', 'title': 'Oyun konsolu', 'category': 'home',
   'description': '…', 'price': 18900, 'upkeep_weekly': 0, 'note': 'İki kollu'},
  {'catalog_id': 'home-treadmill', 'title': 'Koşu bandı', 'category': 'home',
   'description': '…', 'price': 41000, 'upkeep_weekly': 0, 'note': 'Eğimli, 20 km/s'},
  {'catalog_id': 'personal-watch', 'title': 'Kol saati', 'category': 'personal',
   'description': '…', 'price': 27500, 'upkeep_weekly': 0, 'note': 'Çelik kasa'},
  {'catalog_id': 'personal-boots', 'title': 'Krampon', 'category': 'personal',
   'description': '…', 'price': 8900, 'upkeep_weekly': 0, 'note': 'Kişiye özel kalıp'},
  {'catalog_id': 'personal-suit', 'title': 'Takım elbise', 'category': 'personal',
   'description': '…', 'price': 15400, 'upkeep_weekly': 0, 'note': 'Ismarlama'},
  {'catalog_id': 'personal-headphones', 'title': 'Kulaklık', 'category': 'personal',
   'description': '…', 'price': 6200, 'upkeep_weekly': 0, 'note': 'Gürültü engelleyici'},
  {'catalog_id': 'estate-studio', 'title': 'Stüdyo daire', 'category': 'realEstate',
   'description': '…', 'price': 1850000, 'upkeep_weekly': 800, 'note': '1+0, 55 m²'},
  {'catalog_id': 'estate-flat', 'title': 'Şehir merkezi daire', 'category': 'realEstate',
   'description': '…', 'price': 4600000, 'upkeep_weekly': 1800, 'note': '3+1, 120 m²'},
  {'catalog_id': 'estate-villa', 'title': 'Deniz manzaralı villa', 'category': 'realEstate',
   'description': '…', 'price': 12750000, 'upkeep_weekly': 4500, 'note': 'Havuzlu, 380 m²'},
  {'catalog_id': 'invest-bond', 'title': 'Devlet tahvili', 'category': 'investment',
   'description': '…', 'price': 25000, 'upkeep_weekly': 0, 'note': 'Yıllık %28 getiri'},
  {'catalog_id': 'invest-gold', 'title': 'Altın', 'category': 'investment',
   'description': '…', 'price': 40000, 'upkeep_weekly': 0, 'note': '100 gram'},
  {'catalog_id': 'invest-fund', 'title': 'Hisse portföyü', 'category': 'investment',
   'description': '…', 'price': 120000, 'upkeep_weekly': 0, 'note': 'Orta risk'},
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
}) {
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
        'item': {
          'catalog_id': catalogId, 'purchased_at': '2026-08-05',
          'price_paid': 48200 - newMoney, 'upkeep_weekly': 0,
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
    expect(find.text('Akıllı TV'), findsOneWidget);

    await tester.tap(find.text('Gayrimenkul'));
    await tester.pumpAndSettle();

    expect(find.text('Akıllı TV'), findsNothing);
    expect(find.text('Stüdyo daire'), findsOneWidget);

    await tester.tap(find.text('Yatırım'));
    await tester.pumpAndSettle();

    expect(find.text('Altın'), findsOneWidget);
  });

  testWidgets('alınabilir ürün parayı düşürür ve sahiplenilir', (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(
      session: _shopSession(purchaseResponses: {'personal-headphones': 42000}),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kişisel'));
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

    // Kart artık sahip olarak işaretli ve tekrar alınamıyor.
    expect(find.text('Sahip'), findsOneWidget);

    await tester.tap(_card('Kulaklık'));
    await tester.pumpAndSettle();
    expect(find.text('Sahipsin'), findsOneWidget);
    expect(find.text('Satın Al'), findsNothing);
  });

  testWidgets('§12.12 · sahip olununca canlı fayda rozeti belirir', (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(
      session: _shopSession(purchaseResponses: {'home-espresso': 35700}),
    )));
    await tester.pumpAndSettle();

    await tester.tap(_card('Espresso makinesi'));
    await tester.pumpAndSettle();

    // Henüz sahip değil: not rozeti var, canlı fayda rozeti yok.
    expect(find.textContaining('Otomatik öğütücülü'), findsOneWidget);
    expect(find.text('Günlük +3 enerji'), findsNothing);

    await tester.tap(find.text('Satın Al'));
    await tester.pumpAndSettle();

    await tester.tap(_card('Espresso makinesi'));
    await tester.pumpAndSettle();

    // Artık sahip: not hâlâ orada, ama ayrıca canlı fayda rozeti de var.
    expect(find.textContaining('Otomatik öğütücülü'), findsOneWidget);
    expect(find.text('Günlük +3 enerji'), findsOneWidget);
  });

  testWidgets('bakiye yetmeyen ürün alınamaz', (tester) async {
    await tester.pumpWidget(_wrap(ShopScreen(session: _shopSession())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gayrimenkul'));
    await tester.pumpAndSettle();

    await tester.tap(_card('Deniz manzaralı villa'));
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
    expect(find.text('Gayrimenkul'), findsOneWidget);
  });
}
