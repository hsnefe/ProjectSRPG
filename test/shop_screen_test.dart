import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/screens/lifestyle_screen.dart';
import 'package:project_srpg/screens/shop_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/shop_item_card.dart';

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
    await tester.pumpWidget(_wrap(const ShopScreen()));

    expect(find.text('Alışveriş'), findsOneWidget);
    expect(find.text('₺48.200'), findsOneWidget);
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
    await tester.pumpWidget(_wrap(const ShopScreen()));

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
    expect(find.text('₺42.000'), findsOneWidget);

    // Kart artık sahip olarak işaretli ve tekrar alınamıyor.
    expect(find.text('Sahip'), findsOneWidget);

    await tester.tap(_card('Kulaklık'));
    await tester.pumpAndSettle();
    expect(find.text('Sahipsin'), findsOneWidget);
    expect(find.text('Satın Al'), findsNothing);
  });

  testWidgets('bakiye yetmeyen ürün alınamaz', (tester) async {
    await tester.pumpWidget(_wrap(const ShopScreen()));

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

    expect(find.text('₺48.200'), findsOneWidget);
  });

  testWidgets('Yaşam Tarzı header\'ındaki butondan açılır', (tester) async {
    await tester.pumpWidget(_wrap(const LifestyleScreen()));

    await tester.tap(find.byTooltip('Alışveriş'));
    await tester.pumpAndSettle();

    expect(find.text('Alışveriş'), findsOneWidget);
    expect(find.text('Gayrimenkul'), findsOneWidget);
  });
}
