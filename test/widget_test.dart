import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/main.dart';

Future<void> _openCareerCenter(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.text('New Game'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('New Game navigates to Career Center', (WidgetTester tester) async {
    await _openCareerCenter(tester);

    expect(find.text('Efe Kaan'), findsOneWidget);
    expect(find.text('İlerleme'), findsOneWidget);
  });

  testWidgets('İlişkiler button navigates to RelationshipsScreen',
      (WidgetTester tester) async {
    await _openCareerCenter(tester);

    await tester.tap(find.text('İlişkiler'));
    await tester.pumpAndSettle();

    expect(find.text('Antrenör'), findsOneWidget);
    expect(find.text('Takım Arkadaşları'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
  });

  testWidgets('Match card navigates to PreMatchScreen',
      (WidgetTester tester) async {
    await _openCareerCenter(tester);

    await tester.tap(find.text('SONRAKİ MAÇ'));
    await tester.pumpAndSettle();

    expect(find.text('Maça Çıkış'), findsOneWidget);
    expect(find.text('Saha dizilişi (yakında)'), findsOneWidget);
    expect(find.text('Antrenörle konuş'), findsOneWidget);
  });

  testWidgets('Play button navigates to MatchScreen',
      (WidgetTester tester) async {
    await _openCareerCenter(tester);

    await tester.tap(find.text('SONRAKİ MAÇ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(find.text('Maç sahnesi (boş)'), findsOneWidget);
    expect(find.text('Efor'), findsOneWidget);
    expect(find.text('Sertlik'), findsOneWidget);
    expect(find.text("62'"), findsOneWidget);
  });
}
