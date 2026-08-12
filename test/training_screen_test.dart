import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/shot_game.dart' show ShotMode;
import 'package:project_srpg/screens/ball_training_screen.dart';
import 'package:project_srpg/screens/conditioning_training_screen.dart';
import 'package:project_srpg/screens/strength_training_screen.dart';
import 'package:project_srpg/screens/training_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

Widget _wrap(Widget home) => PlayerScope(
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: home,
      ),
    );

/// Kart widget'ı ekrana özel ve private, o yüzden tip adından bulunuyor.
final _card = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_TrainingCard',
);

/// Antrenman kartındaki butonu başlığından bulur.
Finder _startButton(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: _card),
      matching: find.byType(OutlinedButton),
    );

OutlinedButton _button(WidgetTester tester, String title) =>
    tester.widget<OutlinedButton>(_startButton(title));

/// Antrenman kartının butonunu tıklanabilir hale getirir. Listenin sonundaki
/// kartlar ekrana yarım sığdığı için başlığı görmek yetmiyor — butonun
/// kendisini görünür alana çekmek gerekiyor.
Future<void> _scrollTo(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(_startButton(title));
  await tester.pump();
}

void main() {
  group('mini-oyunu olmayan kartlar', () {
    testWidgets('Esneklik ve Dribling Yakında yazar ve pasiftir',
        (tester) async {
      await tester.pumpWidget(_wrap(const TrainingScreen()));

      for (final title in ['Esneklik & Toparlanma', 'Dribling']) {
        await _scrollTo(tester, title);
        expect(_button(tester, title).onPressed, isNull, reason: title);
      }

      expect(find.text('Yakında'), findsNWidgets(2));
    });

    testWidgets('diğer dördü Başla yazar ve tıklanabilir', (tester) async {
      await tester.pumpWidget(_wrap(const TrainingScreen()));

      for (final title in ['Kondisyon Koşusu', 'Güç Antrenmanı', 'Şut', 'Pas']) {
        await _scrollTo(tester, title);
        expect(_button(tester, title).onPressed, isNotNull, reason: title);
      }
    });
  });

  group('mini-oyunları açmak', () {
    testWidgets('Kondisyon koşu ekranını açar', (tester) async {
      await tester.pumpWidget(_wrap(const TrainingScreen()));
      await _scrollTo(tester, 'Kondisyon Koşusu');

      await tester.tap(_startButton('Kondisyon Koşusu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConditioningTrainingScreen), findsOneWidget);

      // Canlı bir GameWidget kaldığı için test bitmeden söküyoruz.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Güç bench press ekranını açar', (tester) async {
      await tester.pumpWidget(_wrap(const TrainingScreen()));
      await _scrollTo(tester, 'Güç Antrenmanı');

      await tester.tap(_startButton('Güç Antrenmanı'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StrengthTrainingScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Şut ve Pas aynı ekranı farklı modla açar', (tester) async {
      for (final (title, mode) in [
        ('Şut', ShotMode.shot),
        ('Pas', ShotMode.pass),
      ]) {
        await tester.pumpWidget(_wrap(const TrainingScreen()));
        await _scrollTo(tester, title);

        await tester.tap(_startButton(title));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final screen = tester.widget<BallTrainingScreen>(
          find.byType(BallTrainingScreen),
        );
        expect(screen.mode, mode, reason: title);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
