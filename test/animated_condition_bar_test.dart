import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/animated_condition_bar.dart';

Widget _wrap(int condition) => MaterialApp(
      home: Scaffold(
        body: AnimatedConditionBar(condition: condition),
      ),
    );

LinearProgressIndicator _bar(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));

void main() {
  group('AnimatedConditionBar', () {
    testWidgets('ilk çizimde doğrudan verilen değeri gösterir, sıfırdan dolmaz',
        (tester) async {
      await tester.pumpWidget(_wrap(64));
      // Hiç ek pump yok — animasyon çalışıyor olsaydı bile ilk build'de
      // begin == end olduğu için ilk karede zaten hedef değerde olmalı.
      expect(find.text('64/100'), findsOneWidget);
      expect(_bar(tester).value, closeTo(0.64, 1e-9));
    });

    testWidgets('değer değişince ara karede eski ve yeni arasında bir değer gösterir',
        (tester) async {
      await tester.pumpWidget(_wrap(80));
      expect(find.text('80/100'), findsOneWidget);

      await tester.pumpWidget(_wrap(40));
      // Animasyonun ortasında bir yerde: ne 80 ne 40, arada bir şey.
      await tester.pump(const Duration(milliseconds: 350));
      final mid = _bar(tester).value;
      expect(mid, lessThan(0.80));
      expect(mid, greaterThan(0.40));

      await tester.pumpAndSettle();
      expect(find.text('40/100'), findsOneWidget);
      expect(_bar(tester).value, closeTo(0.40, 1e-9));
    });

    testWidgets('düşüş rozeti kısa süreliğine kırmızı "-N" gösterip kaybolur',
        (tester) async {
      await tester.pumpWidget(_wrap(70));
      await tester.pumpWidget(_wrap(62));
      await tester.pump(); // didUpdateWidget'ın setState'i işlensin

      expect(find.text('-8'), findsOneWidget);
      final badge = tester.widget<Text>(find.text('-8'));
      expect(badge.style?.color, AppColors.danger);

      // Rozet 1800ms sonra kayboluyor; biraz fazlasını bekleyip doğrula.
      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.text('-8'), findsNothing);
    });

    testWidgets('artış rozeti yeşil "+N" gösterir', (tester) async {
      await tester.pumpWidget(_wrap(50));
      await tester.pumpWidget(_wrap(54));
      await tester.pump();

      expect(find.text('+4'), findsOneWidget);
      final badge = tester.widget<Text>(find.text('+4'));
      expect(badge.style?.color, AppColors.success);
    });

    testWidgets('aynı değerle yeniden çizilmek rozet göstermez', (tester) async {
      await tester.pumpWidget(_wrap(70));
      await tester.pumpWidget(_wrap(70));
      await tester.pump();

      expect(find.textContaining('+'), findsNothing);
      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('özel etiket kullanılabilir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnimatedConditionBar(condition: 50, label: 'Enerji'),
        ),
      ));

      expect(find.text('Enerji'), findsOneWidget);
      expect(find.text('Kondisyon'), findsNothing);
    });
  });
}
