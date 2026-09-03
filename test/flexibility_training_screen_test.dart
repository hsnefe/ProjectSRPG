import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/flexibility_game.dart';
import 'package:project_srpg/screens/flexibility_training_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

Widget _wrap(Widget home) => PlayerScope(
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: home,
      ),
    );

void main() {
  /// Canlı bir GameWidget sonsuza kadar kare planlar, o yüzden pumpAndSettle
  /// yerine tek tek pump ediyoruz.
  testWidgets('başlık ve başlangıç ipucu görünür', (tester) async {
    await tester.pumpWidget(_wrap(const FlexibilityTrainingScreen()));
    await tester.pump();

    expect(find.text('Esneklik & Toparlanma'), findsOneWidget);
    expect(find.text('Başlamak için ekrana dokun'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ekrana dokunmak deseni göstermeye başlar', (tester) async {
    await tester.pumpWidget(_wrap(const FlexibilityTrainingScreen()));
    // Flame'in async onLoad'u oturması için — tek pump yetmiyor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tapAt(
      tester.getCenter(find.byType(GameWidget<FlexibilityGame>)),
    );
    // `_onGameState`'in post-frame rebuild hilesi bir kare daha istiyor;
    // ayrıca çift-tıklama tanıyıcısının zamanlayıcısı akmadan söküme
    // geçilirse test çatısı bunu bekleyen zamanlayıcı olarak yakalıyor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Deseni izle'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
