import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/request_screen.dart';

void main() {
  testWidgets('renders the stub content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RequestScreen()));

    expect(find.text('Talepler'), findsOneWidget);
    expect(find.text('Maç sonrası talepler yakında.'), findsOneWidget);
    expect(find.text('Kariyer Merkezi'), findsOneWidget);
  });

  testWidgets('the career button pops back to the career center already in '
      'the stack', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Giriş ekranı'))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    // CareerCenterScreen'in kendisi PlayerScope istiyor; popUntil davranışı
    // yalnızca route adına baktığı için burada aynı adı taşıyan sade bir
    // yer tutucu yeterli.
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Kariyer merkezi')),
        settings: const RouteSettings(name: CareerCenterScreen.routeName),
      ),
    );
    await tester.pumpAndSettle();

    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Maç'))),
    );
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const RequestScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kariyer Merkezi'));
    await tester.pumpAndSettle();

    expect(find.text('Kariyer merkezi'), findsOneWidget);
    expect(find.byType(RequestScreen), findsNothing);
    expect(find.text('Maç'), findsNothing);
  });

  testWidgets('falls back to the first route when no career center is in the '
      'stack', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Giriş ekranı'))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const RequestScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kariyer Merkezi'));
    await tester.pumpAndSettle();

    expect(find.text('Giriş ekranı'), findsOneWidget);
  });
}
