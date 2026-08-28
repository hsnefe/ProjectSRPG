import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/screens/intervention_shot_screen.dart';

const _size = Size(360, 600);

/// `intervention_shot_screen.dart` sarmalıyor ama motoru bu haliyle
/// kullanıyor - bu turda oynanabilir tüm şut testleri (shot_mode_test.dart,
/// skill_exam_scene_test.dart) `ShotGame`'i ekransız/başsız (widget ağacına
/// hiç mount etmeden) sürüyor. Aynı desen izleniyor: gerçek fiziği ekrandan
/// bağımsız doğrula, ekranın kendisini yalnızca ince bir sarmalayıcı olarak
/// (header/prompt/geri tuşu) test et.
ShotGame _game() => ShotGame(
      mode: ShotMode.free,
      scene: ShotScene.full,
      onStateChanged: () {},
    );

/// Takes one attempt at an absolute world point and resolves it. Aynı desen:
/// shot_mode_test.dart'taki `_attempt` yardımcısıyla birebir.
void _attempt(
  ShotGame game,
  double wx,
  double wy, {
  double spin = 0,
  double loft = 0,
}) {
  if (game.phase == ShotPhase.result) game.reset();

  final p = PitchProjector(size: _size, cameraAngle: game.cameraAngle);
  game
    ..aimLateral = p.lateralOf(wx, wy)
    ..aimDepth = p.depthOf(wx, wy)
    ..power = 1.0
    ..spin = spin
    ..loft = loft
    ..launch();
  game.finishFlight();
}

void _goalAttempt(ShotGame game) =>
    _attempt(game, 0.30, PitchLines.goalLineY, spin: 0.5);

void _missAttempt(ShotGame game) =>
    _attempt(game, ShotWorld.goalHalfWidth + 0.5, PitchLines.goalLineY);

void _catchablePassAttempt(ShotGame game) => _attempt(
      game,
      ShotTarget.leftWing.x,
      ShotTarget.leftWing.y,
      loft: 0.6,
    );

InterventionOfferFrame _offer() => const InterventionOfferFrame(
      seq: 1,
      matchId: 'm_test',
      offerId: 'off_1',
      minute: 63,
      resolution: 'minigame',
      actionKey: 'finish_power',
      prompt: 'Forvet ceza sahasında topla buluştu',
      riskHint: null,
      timeoutSeconds: 20,
      onTimeout: 'decline',
      minigame: 'shot',
      outcomeKeys: [
        OutcomeKeyOption(key: 'great', label: 'Ağlara gitti', tone: 'positive'),
        OutcomeKeyOption(key: 'asist', label: 'Arkadaşına pas', tone: 'positive'),
        OutcomeKeyOption(key: 'good', label: 'Kaleci çeldi', tone: 'neutral'),
        OutcomeKeyOption(key: 'bad', label: 'Kaleyle alakasız', tone: 'negative'),
      ],
    );

void main() {
  group('outcomeKeyForLabel (§7.3 minigame sonuç tablosu)', () {
    test('has exactly the 9 raw shot_game labels', () {
      expect(outcomeKeyForLabel.keys.toSet(), {
        'GOL!', 'PAS TUTTU', 'KURTARIŞ', 'DİREK',
        'AUT', 'ÜSTTEN AUT', 'BOŞLUĞA', 'PAS KAÇTI', 'RAKİP KESTİ',
      });
    });

    test('maps to the 4 graded4 tiers correctly', () {
      expect(outcomeKeyForLabel['GOL!'], 'great');
      expect(outcomeKeyForLabel['PAS TUTTU'], 'asist');
      expect(outcomeKeyForLabel['KURTARIŞ'], 'good');
      expect(outcomeKeyForLabel['DİREK'], 'good');
      for (final bad in ['AUT', 'ÜSTTEN AUT', 'BOŞLUĞA', 'PAS KAÇTI', 'RAKİP KESTİ']) {
        expect(outcomeKeyForLabel[bad], 'bad', reason: bad);
      }
    });
  });

  group('ShotMode.free + ShotScene.full (ekranın kullandığı kurulum)', () {
    test('a goal produces GOL! -> great', () {
      final game = _game();
      _goalAttempt(game);
      expect(outcomeKeyForLabel[game.result], 'great');
    });

    test('squaring it to a team mate produces PAS TUTTU -> asist', () {
      final game = _game();
      _catchablePassAttempt(game);
      expect(outcomeKeyForLabel[game.result], 'asist');
    });

    test('a wide miss produces a bad-tier label', () {
      final game = _game();
      _missAttempt(game);
      expect(outcomeKeyForLabel[game.result], 'bad');
    });

    test('free mode never fires onFinished, so a single attempt is safe to read',
        () {
      // Tek denemelik ekranın dayandığı garanti: session muhasebesi (3
      // deneme, onFinished) hiç devreye girmiyor - sonucu doğrudan
      // `game.result`'tan okumak güvenli.
      var finishedCalls = 0;
      final game = ShotGame(
        mode: ShotMode.free,
        scene: ShotScene.full,
        onStateChanged: () {},
        onFinished: (_) => finishedCalls++,
      );
      _goalAttempt(game);
      expect(finishedCalls, 0);
    });
  });

  group('InterventionShotScreen (ince sarmalayıcı)', () {
    testWidgets('shows the offer prompt as its header title', (tester) async {
      await tester.pumpWidget(MaterialApp(home: InterventionShotScreen(offer: _offer())));
      await tester.pump();

      expect(find.text('Forvet ceza sahasında topla buluştu'), findsOneWidget);
    });

    testWidgets('back button pops null (no attempt taken)', (tester) async {
      InterventionShotResult? result = (outcomeKey: 'unset', rawLabel: 'unset');
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<InterventionShotResult>(
                MaterialPageRoute(builder: (_) => InterventionShotScreen(offer: _offer())),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // push geçişi

      await tester.tap(find.byType(IconButton).first); // GameHeaderBar'ın geri oku
      await tester.pump();

      expect(result, isNull);
    });

    testWidgets('a resolved goal pops with (outcomeKey: great, rawLabel: GOL!)',
        (tester) async {
      InterventionShotResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<InterventionShotResult>(
                MaterialPageRoute(builder: (_) => InterventionShotScreen(offer: _offer())),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // push geçişi

      // Ekranın gerçekten sahip olduğu ShotGame örneğini widget ağacından
      // alıp, headless testlerdekiyle (shot_mode_test.dart) aynı şekilde
      // sürüyoruz - jest simülasyonu yok, doğrudan durum yönlendirmesi.
      final game =
          tester.widget<GameWidget<ShotGame>>(find.byType(GameWidget<ShotGame>)).game!;
      _goalAttempt(game);
      // finishFlight() onStateChanged()'i senkron çağırır, o da bir
      // postFrameCallback zamanlar - bir pump bunu tetikler ve ekranı kapatır.
      await tester.pump();

      expect(result, (outcomeKey: 'great', rawLabel: 'GOL!'));
    });
  });
}
