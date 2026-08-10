import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/screens/shot_prototype_screen.dart';

const _pitch = ValueKey('pitch');

Future<void> _pumpPrototype(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: ShotPrototypeScreen()),
  );
}

/// Completes the aim phase: a flick up and to the right.
Future<void> _aim(WidgetTester tester) async {
  await tester.drag(find.byKey(_pitch), const Offset(30, -90));
  await tester.pump();
}

/// Taps the ball's on-screen center (bottom-middle of the pitch).
Future<void> _strike(WidgetTester tester) async {
  final rect = tester.getRect(find.byKey(_pitch));
  await tester.tapAt(
    Offset(rect.center.dx, rect.top + rect.height * 0.90),
  );
  await tester.pump();
}

void main() {
  testWidgets('nişan aşamasıyla başlar', (tester) async {
    await _pumpPrototype(tester);

    expect(find.text('1) Sürükle: yön ve yükseklik seç, bırak'), findsOneWidget);
  });

  testWidgets('sürükleme bırakılınca vuruş aşamasına geçer', (tester) async {
    await _pumpPrototype(tester);
    await _aim(tester);

    expect(find.text('2) Topa vur: merkez = güç, kenar = kavis'), findsOneWidget);
  });

  testWidgets('topa vurunca uçuş başlar ve sonuçla biter', (tester) async {
    await _pumpPrototype(tester);
    await _aim(tester);
    await _strike(tester);

    expect(find.text('Uçuşta…'), findsOneWidget);

    // Flight duration is time-to-goal + 0.55s; pump plenty of frames.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.text('Tekrar denemek için sahaya dokun'), findsOneWidget);
  });

  testWidgets('sonuçtan sonra dokunmak nişana döner', (tester) async {
    await _pumpPrototype(tester);
    await _aim(tester);
    await _strike(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    await tester.tapAt(tester.getRect(find.byKey(_pitch)).center);
    await tester.pump();

    expect(find.text('1) Sürükle: yön ve yükseklik seç, bırak'), findsOneWidget);
  });
}
