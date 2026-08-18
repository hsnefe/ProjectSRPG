import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/conditioning_game.dart';
import 'package:project_srpg/screens/conditioning_training_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

Widget _wrap(Widget home) => PlayerScope(
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: home,
      ),
    );

/// Canlı bir GameWidget sonsuza kadar kare planlar, o yüzden pumpAndSettle
/// yerine tek tek pump ediyoruz.
Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('sol ve sağ butonları var', (tester) async {
    await tester.pumpWidget(_wrap(const ConditioningTrainingScreen()));

    expect(find.text('SOL'), findsOneWidget);
    expect(find.text('SAĞ'), findsOneWidget);
    expect(find.text('0 / ${ConditioningGame.targetSteps}'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dönüşümlü basmak adım sayacını artırır', (tester) async {
    await tester.pumpWidget(_wrap(const ConditioningTrainingScreen()));

    await _tap(tester, 'SOL');
    await _tap(tester, 'SAĞ');
    await _tap(tester, 'SOL');

    expect(find.text('3 / ${ConditioningGame.targetSteps}'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('aynı butona iki kez basmak saydırmaz', (tester) async {
    await tester.pumpWidget(_wrap(const ConditioningTrainingScreen()));

    await _tap(tester, 'SOL');
    await _tap(tester, 'SOL');

    expect(find.text('1 / ${ConditioningGame.targetSteps}'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('süre saniye olarak hiç yazılmaz', (tester) async {
    await tester.pumpWidget(_wrap(const ConditioningTrainingScreen()));

    await _tap(tester, 'SOL');
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('sn'), findsNothing);
    expect(find.textContaining(':'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
