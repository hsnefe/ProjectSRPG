import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/match_scenarios.dart';
import 'package:project_srpg/game/tackle_scenarios.dart';
import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';
import 'package:project_srpg/screens/intervention_shot_screen.dart';

/// Maç müdahalesinin hangi sahnede oynandığını sınayan testler.
///
/// Havuzlar elle yazıldı ve tek sinyalimiz `action_key` — teklif payload'ında
/// saha bağlamı yok (§7.2). Bir havuza yanlış senaryo koymak sessizce
/// çalışmaya devam eder ve ancak maçta fark edilir: kalesi olmayan bir pas
/// sahnesi `graded4`'ün `great`'ini üretemez, alıcısı olmayan bir şut sahnesi
/// `asist`'i. Bu dosya ikisini de oynayarak kanıtlıyor.
const _size = Size(360, 600);

/// Sahneyi tam kadrosuyla kurar ve verilen dünya noktasına bir top gönderir.
ShotGame _play(
  ShotScene scene,
  GroundPoint at, {
  double loft = 0,
  ShotObjective? objective,
}) {
  final game = ShotGame(
    mode: ShotMode.free,
    // Kademe sahnenin hedefinden okunuyor; `_empty` kopyası onu taşıyor ama
    // testin hangi hedefe baktığı açıkça yazılsın diye geçirilebiliyor.
    scene: objective == null ? scene : scene.copyWith(objective: objective),
    onStateChanged: () {},
  );
  final p = PitchProjector(
    size: _size,
    cameraAngle: scene.startAngle,
    origin: scene.origin,
  );
  game
    ..aimLateral = p.lateralOf(at.x, at.y)
    ..aimDepth = p.depthOf(at.x, at.y)
    ..power = 1
    ..loft = loft
    ..launch();
  game.finishFlight();
  return game;
}

/// Rakipsiz/kalecisiz hâli: bir sonucun *ulaşılabilir* olduğunu göstermek
/// için, savunmayı yenmenin ne kadar kolay olduğunu değil.
ShotScene _empty(ShotScene scene) =>
    scene.copyWith(rivals: const [], hasKeeper: false);

void main() {
  group('havuzlar', () {
    test('motorun yedi minigame aksiyonunun da havuzu var', () {
      // `api/config.py`'deki MINIGAME_ACTION_KEYS ile birebir (§7.3):
      // dört bitiriş (graded4) + üç pas (graded).
      expect(
        MatchScenarios.byActionKey.keys.toSet(),
        {
          'finish_power',
          'finish_finesse',
          'long_shot',
          'counter_attack',
          'build_up_pass',
          'transition_pass',
          'final_ball',
        },
      );
      for (final entry in MatchScenarios.byActionKey.entries) {
        expect(MatchScenarios.poolFor(entry.key), isNotEmpty,
            reason: entry.key);
      }
    });

    test('her havuz kimliği katalogda gerçekten var', () {
      for (final entry in MatchScenarios.byActionKey.entries) {
        for (final id in entry.value) {
          expect(ShotScenarios.byId(id), isNotNull,
              reason: '${entry.key} → $id');
        }
      }
    });

    test('hiçbir senaryo iki havuzda birden değil', () {
      final seen = <String>{};
      for (final ids in MatchScenarios.byActionKey.values) {
        for (final id in ids) {
          expect(seen.add(id), isTrue, reason: '$id iki havuzda');
        }
      }
    });

    test('tanınmayan bir aksiyon akışı kırmaz', () {
      // Motorun ileride ekleyeceği bir aksiyon burada patlamamalı: ekran o
      // zaman eski sabit sahneye düşüyor, teklif 180 sn açıkta kalmıyor.
      expect(MatchScenarios.pick('bir_gun_eklenecek_aksiyon'), isNull);
      expect(MatchScenarios.poolFor('tackle_hard'), isEmpty);
    });

    test('seçim havuzun içinden gelir', () {
      for (final entry in MatchScenarios.byActionKey.entries) {
        for (var seed = 0; seed < 20; seed++) {
          final picked =
              MatchScenarios.pick(entry.key, random: math.Random(seed));
          expect(entry.value, contains(picked!.id), reason: entry.key);
        }
      }
      // Ve havuz gerçekten dolaşılıyor, hep aynısı gelmiyor.
      final drawn = {
        for (var seed = 0; seed < 40; seed++)
          MatchScenarios.pick('finish_power', random: math.Random(seed))!.id,
      };
      expect(drawn.length, greaterThan(1));
    });
  });

  group('müdahale havuzları', () {
    test('high_press yalnızca baskı ailesini çeker', () {
      expect(
        MatchScenarios.tacklePoolFor('high_press'),
        TackleScenarios.of(TackleScenarioKind.press),
      );
    });

    test('tackle_hard tutma ve dönüş ailelerini çeker', () {
      expect(
        MatchScenarios.tacklePoolFor('tackle_hard'),
        [
          ...TackleScenarios.of(TackleScenarioKind.contain),
          ...TackleScenarios.of(TackleScenarioKind.recovery),
        ],
      );
    });

    // §7.3'teki gerekçe mini oyunun yokluğu değil, aksiyonu kalecinin yapması.
    test('keeper_sweep havuzu yok', () {
      expect(MatchScenarios.tacklePoolFor('keeper_sweep'), isEmpty);
      expect(MatchScenarios.pickTackle('keeper_sweep'), isNull);
    });

    test('tanınmayan bir aksiyon akışı kırmaz', () {
      expect(MatchScenarios.pickTackle('henuz_olmayan_aksiyon'), isNull);
    });

    test('seçim havuzun içinden gelir', () {
      final pool = MatchScenarios.tacklePoolFor('tackle_hard');
      for (var seed = 0; seed < 25; seed++) {
        expect(
          pool,
          contains(
              MatchScenarios.pickTackle('tackle_hard', random: math.Random(seed))),
        );
      }
    });

    test('katalogdaki her durum bir aksiyondan erişilebilir', () {
      final reachable = {
        for (final key in MatchScenarios.tackleByActionKey.keys)
          ...MatchScenarios.tacklePoolFor(key).map((s) => s.id),
      };
      expect(reachable, TackleScenarios.all.map((s) => s.id).toSet());
    });

    test('hiçbir durum iki aksiyonda birden değil', () {
      final press = MatchScenarios.tacklePoolFor('high_press').map((s) => s.id);
      final hard = MatchScenarios.tacklePoolFor('tackle_hard').map((s) => s.id);
      expect(press.toSet().intersection(hard.toSet()), isEmpty);
    });
  });

  group('şema uyumu', () {
    test('bitiriş havuzlarındaki her sahnede gol atılabilir', () {
      // `great` graded4'ün tavanı; kalesi sayılmayan bir sahne o anahtarı
      // hiç üretemez ve motorun sonuç dağılımı sessizce kesilir.
      final finishing = MatchScenarios.byActionKey.entries
          .where((e) => !MatchScenarios.passActionKeys.contains(e.key));
      for (final entry in finishing) {
        for (final scenario in MatchScenarios.poolFor(entry.key)) {
          expect(scenario.scene.scoresGoals, isTrue,
              reason: '${entry.key} / ${scenario.id}');

          final game = _play(
            _empty(scenario.scene),
            (x: 0, y: PitchLines.goalLineY),
          );
          expect(game.result, ShotLabel.goal,
              reason: '${entry.key} / ${scenario.id}: gol atılamıyor');
          expect(outcomeKeyForLabel[game.result], 'great');
        }
      }
    });

    test('asist yalnızca kontra havuzunda çıkabilir', () {
      // Katalogda hem kaleyi sayan hem alıcısı olan üç durum var ve üçü de
      // kasten kontrada: sözleşme o aksiyonu zaten "sen mi bitirdin,
      // arkadaşına mı hazırladın" diye gerekçelendiriyor (§7.3).
      for (final scenario in MatchScenarios.poolFor('counter_attack')) {
        final receiver = scenario.scene.receivers.firstOrNull;
        expect(receiver, isNotNull,
            reason: '${scenario.id}: asist için alıcı yok');

        final game = _play(
          _empty(scenario.scene),
          (x: receiver!.x, y: receiver.y),
          loft: 0.25,
        );
        expect(game.result, ShotLabel.passCaught, reason: scenario.id);
        expect(outcomeKeyForLabel[game.result], 'asist');
      }
    });

    test('kalan üç havuzda asist çıkmaz — bilinçli daralma', () {
      // Bu bir kayıp değil, kayıt: asist seyrekleşiyor. Bir gün şut
      // sahnelerine lay-off adamı eklenirse bu test kasten düşecek.
      for (final key in ['finish_power', 'finish_finesse', 'long_shot']) {
        for (final scenario in MatchScenarios.poolFor(key)) {
          expect(scenario.scene.receivers, isEmpty,
              reason: '$key / ${scenario.id}');
        }
      }
    });

    test('pas havuzlarındaki her sahne üç kademeyi de üretebilir', () {
      // Pas aksiyonları `graded` (great/good/bad) ve anahtar senaryonun
      // notundan geliyor. İki kademeli bir durum `great` üretemez, yani
      // motorun en iyi dalı o tekliflerde hiç ateşlenmezdi — o yüzden
      // havuzların dışında tutuluyorlar.
      for (final key in MatchScenarios.passActionKeys) {
        final pool = MatchScenarios.poolFor(key);
        expect(pool, isNotEmpty, reason: key);
        for (final scenario in pool) {
          expect(scenario.objective.tiers, 3,
              reason: '$key / ${scenario.id}: iki kademeli');
          expect(scenario.scene.receivers.any((r) => r.isKey), isTrue,
              reason: '$key / ${scenario.id}: hattı kıran adam yok');
          expect(scenario.scene.scoresGoals, isFalse,
              reason: '$key / ${scenario.id}: pas sahnesi gol saymamalı');
        }
      }
    });

    test('pas notu doğrudan motorun anahtarına çevriliyor', () {
      // Katalogun üç kademesi ile motorun `graded` şeması birebir; ara bir
      // tablo yok, olsaydı ikisi birbirinden kayabilirdi.
      expect(MatchScenarios.outcomeKeyForGrade(ShotGrade.great), 'great');
      expect(MatchScenarios.outcomeKeyForGrade(ShotGrade.good), 'good');
      expect(MatchScenarios.outcomeKeyForGrade(ShotGrade.fail), 'bad');
    });

    test('bir pas senaryosu oynandığında beklenen anahtar çıkar', () {
      // Hattı kıran adam `great`, güvenli adam `good` — aynı ham etiketten
      // (`PAS TUTTU`) iki ayrı motor anahtarı.
      final scenario = ShotScenarios.byId('build_keeper_short')!;
      final key = scenario.scene.receivers.firstWhere((r) => r.isKey);
      final safe = scenario.scene.receivers.firstWhere((r) => !r.isKey);

      final toKey = _play(_empty(scenario.scene), (x: key.x, y: key.y),
          loft: 0.25, objective: scenario.objective);
      expect(toKey.result, ShotLabel.passCaught);
      expect(MatchScenarios.outcomeKeyForGrade(toKey.lastGrade), 'great');

      final toSafe = _play(_empty(scenario.scene), (x: safe.x, y: safe.y),
          loft: 0.25, objective: scenario.objective);
      expect(toSafe.result, ShotLabel.passCaught);
      expect(MatchScenarios.outcomeKeyForGrade(toSafe.lastGrade), 'good');
    });

    test('üretilen her etiketin bir motor anahtarı var', () {
      // Ekran bilinmeyen etiketi `bad`'e düşürüyor; tablonun eksik kalması
      // sessiz bir puan kaybı demek olurdu.
      expect(outcomeKeyForLabel.keys.toSet(), ShotLabel.all);
      expect(
        outcomeKeyForLabel.values.toSet(),
        {'great', 'asist', 'good', 'bad'},
      );
    });
  });
}
