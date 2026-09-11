import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/formation_pick.dart';
import 'package:project_srpg/game/formations.g.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/formation_board.dart';

Widget _wrap(Widget board) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 320, height: 320, child: board),
        ),
      ),
    );

/// Sarı dairenin altındaki yazıyı bulur — daireler ayrı widget olmadığı için
/// testler onları etiketleri üzerinden tanır.
Color _dotColorUnder(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first
        .let((columnFinder) => find.descendant(
              of: columnFinder,
              matching: find.byType(Container),
            )),
  );
  return ((container.decoration! as BoxDecoration).color)!;
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

void main() {
  testWidgets('on slot çizilir, biri oyuncunun adını taşır', (tester) async {
    await tester.pumpWidget(_wrap(FormationBoard(
      formation: kFormationsById['4-2-3-1']!,
      playerName: 'Efe Kaan',
      playerPosition: 'Orta saha',
    )));

    // 10 daire = 10 etiket; biri oyuncunun adı, kalan dokuzu kısaltma.
    expect(find.text('Efe Kaan'), findsOneWidget);
    expect(find.byType(Container), findsNWidgets(10));
  });

  testWidgets('oyuncunun dairesi sarı, diğerleri mavi', (tester) async {
    final formation = kFormationsById['4-2-3-1']!;
    await tester.pumpWidget(_wrap(FormationBoard(
      formation: formation,
      playerName: 'Efe Kaan',
      playerPosition: 'Forvet',
    )));

    expect(_dotColorUnder(tester, 'Efe Kaan'), AppColors.warning);
    // 4-2-3-1'in stoperleri oyuncunun hattında değil, mavi kalırlar.
    expect(_dotColorUnder(tester, 'DC'), AppColors.accent);
  });

  testWidgets('mevki değişince sarı daire hat değiştirir', (tester) async {
    final formation = kFormationsById['4-3-3-duz']!;

    for (final position in const ['Defans', 'Orta saha', 'Forvet']) {
      await tester.pumpWidget(_wrap(FormationBoard(
        formation: formation,
        playerName: 'Efe Kaan',
        playerPosition: position,
      )));

      final index = userSlotIndex(formation, position)!;
      expect(
        kGroupToPosition[formation.slots[index].group],
        position,
        reason: '$position için seçilen slot yanlış hatta',
      );
      // Ad her seferinde tam bir kez görünür: iki daire birden sarı olmaz.
      expect(find.text('Efe Kaan'), findsOneWidget);
    }
  });

  testWidgets('mevki hiçbir slota uymazsa saha yine çizilir', (tester) async {
    // Sarı daire yok ama on mavi daire ve saha duruyor — ekran boşa düşmez.
    await tester.pumpWidget(_wrap(FormationBoard(
      formation: kFormationsById['4-2-3-1']!,
      playerName: 'Efe Kaan',
      playerPosition: 'Kaleci',
    )));

    expect(find.text('Efe Kaan'), findsNothing);
    expect(find.byType(Container), findsNWidgets(10));
  });
}
