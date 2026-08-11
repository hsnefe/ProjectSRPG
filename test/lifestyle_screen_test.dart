import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/lifestyle_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/activity_card.dart';

/// Kartın kendisine dokunur; metin, cam şeridin içinde olduğu için doğrudan
/// hedeflenmeye uygun değil.
Finder _card(String title) {
  return find.ancestor(
    of: find.text(title),
    matching: find.byType(ActivityCard),
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
  testWidgets('üç aktivite sırası ve kondisyon barı görünür', (tester) async {
    await tester.pumpWidget(_wrap(const LifestyleScreen()));

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
    await tester.pumpWidget(_wrap(const LifestyleScreen()));

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
    await tester.pumpWidget(_wrap(const LifestyleScreen()));

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
    await tester.pumpWidget(_wrap(const LifestyleScreen()));

    await tester.tap(_card('Uyku'));
    await tester.pumpAndSettle();
    expect(find.text('Yap'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Yap'), findsNothing);
    expect(find.text('72/100'), findsOneWidget);
  });

  testWidgets('kondisyon ve para diğer ekranlarla paylaşılır', (tester) async {
    await tester.pumpWidget(_wrap(const CareerCenterScreen()));

    expect(find.text('%72'), findsOneWidget);
    expect(find.text('₺48.200'), findsOneWidget);

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
    expect(find.text('₺48.020'), findsOneWidget);
  });
}
