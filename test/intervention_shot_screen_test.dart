import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/match_scenarios.dart';
import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/screens/intervention_shot_screen.dart';
import 'package:project_srpg/widgets/game_chrome.dart';

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

  final p = PitchProjector(
    size: _size,
    cameraAngle: game.cameraAngle,
    origin: game.scene.origin,
  );
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

InterventionOfferFrame _offer({String actionKey = 'finish_power'}) =>
    InterventionOfferFrame(
      seq: 1,
      matchId: 'm_test',
      offerId: 'off_1',
      minute: 63,
      resolution: 'minigame',
      actionKey: actionKey,
      prompt: 'Forvet ceza sahasında topla buluştu',
      riskHint: null,
      timeoutSeconds: 20,
      onTimeout: 'decline',
      minigame: 'shot',
      outcomeKeys: const [
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

  // Eşleme sahneden bağımsız: ekran artık teklifin `action_key`'ine göre
  // katalogdan bir sahne açıyor (`MatchScenarios`), ama ham etiket kümesi her
  // sahnede aynı dokuz değer. Fizik burada hâlâ tam kadrolu `ShotScene.full`
  // üzerinde sınanıyor — üçünü de tek sahnede üretebilen tek sahne o.
  group('etiket → outcome_key eşlemesi', () {
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

      // Başlık motorun cümlesi kalıyor (§7.2 `prompt`) — sahne değişse de o
      // an maçta ne olduğunu söyleyen tek yetkili metin bu.
      expect(find.text('Forvet ceza sahasında topla buluştu'), findsOneWidget);
    });

    testWidgets('sahneyi teklifin action_key havuzundan seçer', (tester) async {
      await tester.pumpWidget(MaterialApp(home: InterventionShotScreen(offer: _offer())));
      await tester.pump();

      // `finish_power` havuzundan biri açılmış olmalı; hangisi olduğu
      // rastgele, ama havuzun dışından olamaz.
      final titles = [
        for (final s in MatchScenarios.poolFor('finish_power')) s.title,
      ];
      expect(
        titles.where((t) => find.text(t).evaluate().isNotEmpty),
        hasLength(1),
        reason: 'açılan sahne finish_power havuzunda değil',
      );
    });

    testWidgets('tanınmayan bir aksiyonda eski sabit sahneye düşer',
        (tester) async {
      // İleri uyumluluk: motorun ekleyeceği bir aksiyon ekranı kırmamalı.
      // Sahne brifingi olmadan açılır, teklif normal akışında oynanır.
      await tester.pumpWidget(MaterialApp(
        home: InterventionShotScreen(
          offer: _offer(actionKey: 'bir_gun_eklenecek_aksiyon'),
        ),
      ));
      await tester.pump();

      expect(find.byType(GameBriefBar), findsNothing);
      expect(find.text('Forvet ceza sahasında topla buluştu'), findsOneWidget);
    });

    testWidgets('geri tuşu yoktur, ekran terk edilemez (§0 v1.7)',
        (tester) async {
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

      // `GameHeaderBar(showBack: false)` — geri oku hiç çizilmez.
      expect(find.byType(IconButton), findsNothing);

      // Sistem geri hareketi de `PopScope(canPop:false)` tarafından yutulur.
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(InterventionShotScreen), findsOneWidget);
      expect(result, (outcomeKey: 'unset', rawLabel: 'unset')); // hiç değişmedi
    });

    testWidgets('a resolved goal pops with (outcomeKey: great, rawLabel: GOL!)',
        (tester) async {
      InterventionShotResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<InterventionShotResult>(
                MaterialPageRoute(
                  builder: (_) => InterventionShotScreen(
                    offer: _offer(),
                    // Sahne sabitleniyor: ekran normalde havuzdan rastgele
                    // seçiyor, aşağıdaki atış ise belli bir sahneye göre
                    // ayarlı — rastgelelik testi ara sıra düşürürdü.
                    scenario: ShotScenarios.byId('shot_box_centre'),
                  ),
                ),
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
