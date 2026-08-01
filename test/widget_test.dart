import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/main.dart';

void main() {
  testWidgets('New Game navigates to Kariyer Merkezi', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SRPG'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);

    await tester.tap(find.text('New Game'));
    await tester.pumpAndSettle();

    expect(find.text('Efe Kaan'), findsOneWidget);
    expect(find.text('İlerleme'), findsOneWidget);
  });
}
