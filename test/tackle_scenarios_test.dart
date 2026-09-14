import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/conditioning_game.dart' show RunSide;
import 'package:project_srpg/game/shot_objective.dart';
import 'package:project_srpg/game/tackle_game.dart';
import 'package:project_srpg/game/tackle_scenarios.dart';
import 'package:project_srpg/screens/tackle_training_screen.dart';

/// Katalog testi.
///
/// Dokuz durumun tamamı elle yazıldı ve her biri kovalamayı ve pencereyi başka
/// bir yere çekiyor; çarpanlara bakarak "bu oynanabilir mi" sorusu
/// cevaplanamaz. O yüzden buradaki testler kataloğu *oynuyor* — her durumu
/// hedef tempoda koşturup pencerenin saat dolmadan açıldığına ve merkezinde
/// dalmanın tavan not verdiğine bakıyor. Bir durumu yetişilemez yapan bir
/// düzenleme, elle denemeye gerek kalmadan burada patlar.
/// (`shot_scenarios_test.dart` ile aynı politika.)

TackleGame _gameFor(TackleScenario scenario) => TackleGame(
      onStateChanged: () {},
      onFinished: (_) {},
      closeScale: scenario.closeScale,
      windowScale: scenario.windowScale,
    );

/// Durumu hedef tempoda, pencere açılana kadar oynar.
TackleGame _play(TackleScenario scenario) {
  final game = _gameFor(scenario);
  var i = 0;
  while (game.phase != TacklePhase.window && !game.finished && i < 600) {
    game.step(i.isEven ? RunSide.left : RunSide.right);
    game.advance(TackleGame.targetGap);
    i++;
  }
  return game;
}

void main() {
  const catalog = TackleScenarios.all;

  group('katalog', () {
    test('üç ailede üçer durum var', () {
      expect(catalog, hasLength(9));
      for (final kind in TackleScenarioKind.values) {
        final family = TackleScenarios.of(kind);
        expect(family, hasLength(3), reason: kind.name);
        expect(
          family.every((s) => s.kind == kind),
          isTrue,
          reason: kind.name,
        );
      }
    });

    test("id'ler benzersiz ve ailesinin önekini taşıyor", () {
      const prefix = {
        TackleScenarioKind.press: 'press_',
        TackleScenarioKind.contain: 'contain_',
        TackleScenarioKind.recovery: 'recovery_',
      };
      final seen = <String>{};
      for (final s in catalog) {
        expect(seen.add(s.id), isTrue, reason: 'yinelenen id: ${s.id}');
        expect(s.id, startsWith(prefix[s.kind]!), reason: s.id);
      }
    });

    test('byId katalogdakini bulur, olmayana null döner', () {
      expect(TackleScenarios.byId('recovery_last_man')?.title, 'Son adam sensin');
      expect(TackleScenarios.byId('yok_boyle_bir_durum'), isNull);
    });

    test('her durumun başlığı ve tarifi dolu', () {
      for (final s in catalog) {
        expect(s.title, isNotEmpty, reason: s.id);
        // Tek cümlelik bir tarif brifing çubuğunu doldurmuyor; her kayıt
        // ne olduğunu *ve* neye dikkat edileceğini söylemeli.
        expect(s.brief.length, greaterThan(60), reason: s.id);
      }
    });

    test('katalog gerçekten çeşitli: çarpanlar tek bir değere toplanmıyor', () {
      expect(catalog.map((s) => s.closeScale).toSet().length,
          greaterThanOrEqualTo(5));
      expect(catalog.map((s) => s.windowScale).toSet().length,
          greaterThanOrEqualTo(5));
    });

    test('çarpanlar makul aralıkta', () {
      for (final s in catalog) {
        expect(s.closeScale, inInclusiveRange(0.7, 1.3), reason: s.id);
        expect(s.windowScale, inInclusiveRange(0.7, 1.3), reason: s.id);
      }
    });
  });

  group('oynanabilirlik', () {
    test('her durumda hedef tempoda koşan pencereyi açar', () {
      for (final s in catalog) {
        final game = _play(s);
        expect(game.phase, TacklePhase.window, reason: s.id);
        expect(game.timedOut, isFalse, reason: s.id);
      }
    });

    test('en uzun kovalama bile saatin içine rahat sığar', () {
      for (final s in catalog) {
        // Payı olmayan bir durum, temposu biraz bozulan oyuncuyu hiç
        // yetişemez hâle getirirdi.
        expect(
          _play(s).elapsed,
          lessThan(TackleGame.runDuration * 0.75),
          reason: s.id,
        );
      }
    });

    test('her durumda pencerenin merkezi tavan not verir', () {
      for (final s in catalog) {
        final game = _play(s);
        game.windowElapsed = game.windowDuration * 0.5;
        game.commit();
        expect(game.grade, ShotGrade.great, reason: s.id);
      }
    });

    test('ritim sıfırken bile en dar pencere insanca genişlikte', () {
      for (final s in catalog) {
        // Oynayarak ölçülemez: hedef tempoda koşan zaten tam ritme çıkar.
        // Taban genişlik doğrudan çarpandan okunuyor.
        expect(
          TackleGame.minWindow * s.windowScale,
          greaterThanOrEqualTo(0.35),
          reason: s.id,
        );
      }
    });

    test('kolay durum zor durumdan hem geniş hem çabuk', () {
      final easy = _play(TackleScenarios.byId('press_centre_back_dwell')!);
      final hard = _play(TackleScenarios.byId('recovery_last_man')!);

      expect(easy.windowDuration, greaterThan(hard.windowDuration));
      expect(easy.elapsed, lessThan(hard.elapsed));
    });
  });

  group('seçim', () {
    test('pick tohumlu Random ile deterministik', () {
      expect(
        TackleScenarios.pick(random: math.Random(7)).id,
        TackleScenarios.pick(random: math.Random(7)).id,
      );
    });

    test('pick yeterince çekince katalogun tamamını gezer', () {
      final random = math.Random(1);
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        seen.add(TackleScenarios.pick(random: random).id);
      }
      expect(seen, hasLength(catalog.length));
    });
  });

  group('ekran', () {
    testWidgets('brifing çubuğu verilen durumu yazar', (tester) async {
      const scenario = TackleScenario(
        id: 'test_durum',
        kind: TackleScenarioKind.recovery,
        title: 'Son adam sensin',
        brief: 'Arkanda kimse yok.',
        closeScale: 1,
        windowScale: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(home: TackleTrainingScreen(scenario: scenario)),
      );
      // Canlı bir GameWidget sonsuza kadar kare planlıyor: pumpAndSettle asla
      // yerleşmez.
      await tester.pump();

      expect(find.text('Dönüş · Son adam sensin'), findsOneWidget);
      expect(find.text('Arkanda kimse yok.'), findsOneWidget);
      expect(find.text('MÜDAHALE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('durum verilmezse katalogdan biri çekilir', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TackleTrainingScreen()),
      );
      await tester.pump();

      final titles = [
        for (final s in TackleScenarios.all) '${s.kind.label} · ${s.title}',
      ];
      expect(
        titles.where((t) => find.text(t).evaluate().isNotEmpty),
        hasLength(1),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
