import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/shot_objective.dart';
import 'package:project_srpg/game/tackle_scenarios.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/screens/intervention_tackle_screen.dart';
import 'package:project_srpg/widgets/game_chrome.dart';

/// `intervention_shot_screen_test.dart` ile aynı politika: oyunun gerçek
/// kuralları ekransız sürülüyor (`tackle_game_test.dart`,
/// `tackle_scenarios_test.dart`), burada yalnızca ekranın ince sarmalayıcı
/// işi sınanıyor — başlık, durum brifingi, geri çıkış ve kademeyi motorun
/// anahtarına çeviren tablo.

InterventionOfferFrame _offer({String actionKey = 'tackle_hard'}) =>
    InterventionOfferFrame(
      seq: 1,
      matchId: 'm_test',
      offerId: 'off_1',
      minute: 71,
      resolution: 'minigame',
      minigame: 'tackle',
      actionKey: actionKey,
      prompt: 'Rakip dikine çıkıyor, son savunmacı müdahaleye gidiyor',
      riskHint: 'Kötü zamanlama doğrudan kırmızı kart getirir.',
      timeoutSeconds: 20,
      onTimeout: 'decline',
      outcomeKeys: const [
        OutcomeKeyOption(key: 'great', label: 'Topa temiz temas', tone: 'positive'),
        OutcomeKeyOption(key: 'good', label: 'Faul, kart yok', tone: 'neutral'),
        OutcomeKeyOption(key: 'bad', label: 'Direkt kırmızı', tone: 'negative'),
      ],
    );

void main() {
  group('kademe → motor anahtarı', () {
    test('üç kademe de motorun graded şemasına birebir oturur', () {
      expect(tackleResultOf(ShotGrade.great).outcomeKey, 'great');
      expect(tackleResultOf(ShotGrade.good).outcomeKey, 'good');
      expect(tackleResultOf(ShotGrade.fail).outcomeKey, 'bad');
    });

    test('minigame_result kademenin kendi etiketini taşır', () {
      for (final grade in ShotGrade.values) {
        expect(tackleResultOf(grade).rawLabel, grade.label, reason: grade.name);
      }
    });
  });

  group('ekran', () {
    testWidgets('başlık motorun kendi cümlesi, altında durumun tarifi',
        (tester) async {
      const scenario = TackleScenario(
        id: 'test_durum',
        kind: TackleScenarioKind.recovery,
        title: 'Son adam sensin',
        brief: 'Arkanda kaleciden başka kimse yok.',
        closeScale: 1,
        windowScale: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InterventionTackleScreen(offer: _offer(), scenario: scenario),
        ),
      );
      await tester.pump();

      expect(
        find.text('Rakip dikine çıkıyor, son savunmacı müdahaleye gidiyor'),
        findsOneWidget,
      );
      expect(find.text('Son adam sensin'), findsOneWidget);
      expect(find.text('Arkanda kaleciden başka kimse yok.'), findsOneWidget);
      expect(find.text('MÜDAHALE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tanınmayan action_key brifingsiz ama çalışır ekran verir',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InterventionTackleScreen(
            offer: _offer(actionKey: 'henuz_olmayan_aksiyon'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GameBriefBar), findsNothing);
      expect(find.text('MÜDAHALE'), findsOneWidget);
      expect(find.text('SOL'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('risk_hint gösterilir (§7.5, panelden buraya taşındı)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: InterventionTackleScreen(offer: _offer())),
      );
      await tester.pump();

      // `_offer()`'ın varsayılan `riskHint`'i — `tackle_hard`ın kırmızı kart
      // uyarısı. Artık modalda değil bu ekranda, prompt'un hemen altında.
      expect(
        find.descendant(
          of: find.byType(GameRiskBar),
          matching:
              find.text('Kötü zamanlama doğrudan kırmızı kart getirir.'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('geri tuşu yoktur, ekran terk edilemez (§0 v1.7)',
        (tester) async {
      InterventionTackleResult? popped;
      var returned = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context)
                    .push<InterventionTackleResult>(
                  MaterialPageRoute(
                    builder: (_) => InterventionTackleScreen(offer: _offer()),
                  ),
                );
                returned = true;
              },
              child: const Text('aç'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(InterventionTackleScreen), findsOneWidget);

      // `GameHeaderBar(showBack: false)` — geri oku hiç çizilmez.
      expect(
        find.descendant(
          of: find.byType(GameHeaderBar),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );

      // Sistem geri hareketi de `PopScope(canPop:false)` tarafından yutulur.
      // Canlı bir GameWidget yüzünden pumpAndSettle asla oturmaz.
      await tester.binding.handlePopRoute();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(InterventionTackleScreen), findsOneWidget);
      expect(returned, isFalse);
      expect(popped, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
