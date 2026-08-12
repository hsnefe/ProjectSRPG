import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/screens/contract_screen.dart';

Widget _wrap(Widget home) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: home,
  );
}

void main() {
  testWidgets('sözleşme ekranı maaş, prim ve bitiş tarihini listeler',
      (tester) async {
    await tester.pumpWidget(_wrap(const ContractScreen()));

    expect(find.text('FK Yıldız'), findsOneWidget);
    expect(find.text('01.07.2024'), findsOneWidget);
    expect(find.text('30.06.2027'), findsOneWidget);
    expect(find.text('₺180.000'), findsOneWidget);
    expect(find.text('₺720.000'), findsOneWidget);
    expect(find.text('₺25.000'), findsOneWidget);
    expect(find.text('₺40.000'), findsOneWidget);
    expect(find.text('₺12.000.000'), findsOneWidget);
  });

  testWidgets('Sözleşme Uzat butonu yakında mesajı gösterir', (tester) async {
    await tester.pumpWidget(_wrap(const ContractScreen()));

    await tester.tap(find.text('Sözleşme Uzat'));
    await tester.pump();

    expect(find.text('Sözleşme uzatma yakında'), findsOneWidget);

    // SnackBar'ın 2 saniyelik kapanma timer'ını boşalt; yoksa teardown'da
    // "A Timer is still pending" hatası riski var.
    await tester.pump(const Duration(seconds: 3));
  });
}
