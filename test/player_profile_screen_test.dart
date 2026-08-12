import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/player_profile_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/value_scatter_chart.dart';

Widget _wrap(Widget home) {
  return PlayerScope(
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    ),
  );
}

/// Hap seçicilerden birini açıp verilen seçeneğe basar.
Future<void> _pick(
  WidgetTester tester,
  String filterKey,
  String option,
) async {
  await tester.tap(find.byKey(ValueKey(filterKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profil ekranı kimlik satırını ve bu sezonun istatistiklerini '
      'gösterir', (tester) async {
    await tester.pumpWidget(_wrap(const PlayerProfileScreen()));

    expect(find.text('Yaş: 21'), findsOneWidget);
    expect(find.text('Efe Kaan'), findsOneWidget);
    expect(find.text('FK Yıldız'), findsOneWidget);
    expect(find.text('Oynanan dakika'), findsOneWidget);

    // Çıplak sayılar satırlar arasında çakıştığı için kesire assert ediyoruz.
    expect(find.text('609/698'), findsOneWidget);
    expect(find.text('Başarılı pas: %87'), findsOneWidget);
  });

  testWidgets('müsabaka filtresi istatistikleri daraltır', (tester) async {
    await tester.pumpWidget(_wrap(const PlayerProfileScreen()));

    await _pick(tester, 'competitionFilter', 'Kupa');

    expect(find.text('88/101'), findsOneWidget);
    expect(find.text('Başarılı pas: %87'), findsOneWidget);
    expect(find.text('609/698'), findsNothing);
  });

  testWidgets('Tümü seçimi bütün sezonları toplar', (tester) async {
    await tester.pumpWidget(_wrap(const PlayerProfileScreen()));

    await _pick(tester, 'seasonFilter', 'Tümü');

    // 1527/1778 tohum tablosunda hiç geçmiyor; toplamanın hesaplandığını
    // (hardcode edilmediğini) kanıtlayan değer bu.
    expect(find.text('76'), findsOneWidget);
    expect(find.text('1527/1778'), findsOneWidget);
    expect(find.text('Başarılı pas: %86'), findsOneWidget);
  });

  testWidgets('iki filtre birlikte çalışır', (tester) async {
    await tester.pumpWidget(_wrap(const PlayerProfileScreen()));

    await _pick(tester, 'seasonFilter', 'Tümü');
    await _pick(tester, 'competitionFilter', 'Lig');

    expect(find.text('61'), findsOneWidget);
    expect(find.text('1197/1394'), findsOneWidget);
    expect(find.text('Başarılı pas: %86'), findsOneWidget);
  });

  testWidgets('değer tablosu grafiği filtrelerden etkilenmez', (tester) async {
    await tester.pumpWidget(_wrap(const PlayerProfileScreen()));

    expect(find.byType(ValueScatterChart), findsOneWidget);
    expect(find.text('Kariyer boyunca piyasa değeri'), findsOneWidget);

    final before =
        tester.widget<ValueScatterChart>(find.byType(ValueScatterChart)).points;

    await _pick(tester, 'competitionFilter', 'Kupa');

    final after =
        tester.widget<ValueScatterChart>(find.byType(ValueScatterChart)).points;
    expect(identical(before, after), isTrue);
  });

  testWidgets('Sözleşme butonu sözleşme ekranını açar', (tester) async {
    await tester.pumpWidget(_wrap(const PlayerProfileScreen()));

    await tester.tap(find.text('Sözleşme'));
    await tester.pumpAndSettle();

    expect(find.text('Serbest kalma bedeli'), findsOneWidget);
    expect(find.text('₺12.000.000'), findsOneWidget);
  });

  testWidgets('kariyer merkezinde isme basınca profil açılır', (tester) async {
    await tester.pumpWidget(_wrap(const CareerCenterScreen()));

    await tester.tap(find.text('Efe Kaan'));
    await tester.pumpAndSettle();

    // Kariyer merkezi alttaki rotada mount kaldığı için 'Efe Kaan' iki kez
    // bulunur; profile özgü olan 'Yaş: 21'e assert ediyoruz.
    expect(find.text('Yaş: 21'), findsOneWidget);
  });
}
