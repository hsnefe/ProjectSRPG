import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';

/// Her senaryoyu tek tek, **tam kadroyla** oynayan test.
///
/// `shot_scenarios_test.dart` kataloğu kurallara karşı doğruluyor: kim nerede
/// duruyor, nişan menzile sığıyor mu, hedef tablosu tutarlı mı. Oradaki oynama
/// testleri sahayı kasten boşaltıyor — bir alıcının *ulaşılabilir* olduğunu
/// göstermek için. Ama bir durumun "çalışması" bu değil: rakipler sahadayken
/// de oynanabilmesi.
///
/// Buradaki her `test` bir senaryo. Senaryonun kendi kadrosuyla, oyunun kendi
/// vuruş mekaniğiyle yüzlerce atış yapıp şunu soruyor:
///
/// 1. Adı konmuş her seçenek gerçekten bulunabiliyor mu — savunmacı önünde
///    dururken bile?
/// 2. Kale sayan durumlarda kaleciyi geçen bir şut var mı?
/// 3. Durum bedava mı — gelişigüzel atılan top da sayılıyor mu?
/// 4. Hedefin vaat ettiği her kademe (başarısız / başarılı / çok başarılı)
///    gerçekten sahada çıkıyor mu?
///
/// Bu test yazıldığında dokuz senaryo çakıldı, sekizi aynı sebeptendi:
/// savunmacı pas ya da şut hattının tam üstünde duruyordu. İkisinde kaleye
/// hiçbir şut ulaşmıyordu ("RAKİP KESTİ", 75 vuruşun 75'i), üçünde "çok
/// başarılı" hiç alınamıyordu. Dokuzuncusunun tek alıcısı vardı, yani
/// "başarılı" ile "çok başarılı" arasında seçilecek bir şey yoktu. Hiçbiri
/// koordinatlara bakarak görülebilecek şeyler değildi.
const _size = Size(360, 600);

PitchProjector _projector(ShotScene scene) => PitchProjector(
      size: _size,
      cameraAngle: scene.startAngle,
      origin: scene.origin,
    );

/// Vuruşun oyundaki hâli.
///
/// `ShotGame._strike` bir dokunuşu üç sayıya çeviriyor: topun neresine
/// vurulduğu (normX/normY) ve halkanın zamanlaması. Burada aynı formül
/// tekrarlanıyor, çünkü test bir *dokunuş* üretemez ama ürettiği şeyin
/// oyuncunun gerçekten yapabileceği bir vuruş olması gerekiyor — gelişigüzel
/// bir power/spin/loft üçlüsü, oyunda karşılığı olmayan bir atışı "mümkün"
/// gösterirdi.
ShotGame _strike(
  ShotScenario scenario, {
  required double lateral,
  required double depth,
  required double normX,
  required double normY,
  required double timing,
}) {
  final game = ShotGame(
    mode: scenario.kind.mode,
    scene: scenario.scene,
    onStateChanged: () {},
  );
  final offCenter = math.min(1.0, math.sqrt(normX * normX + normY * normY));
  game
    ..aimLateral = lateral
    ..aimDepth = depth
    ..power = (0.62 + 0.38 * timing) * (1 - 0.25 * offCenter)
    ..spin = -normX
    ..loft = normY.clamp(0.0, 1.0)
    ..launch();
  game.finishFlight();
  return game;
}

/// Topun neresine vurulabileceği ve halkanın nerede yakalanabileceği: bir
/// oyuncunun elinin altındaki bütün vuruşların kaba bir ızgarası.
const _normX = [-0.9, -0.45, 0.0, 0.45, 0.9];
const _normY = [-0.5, 0.0, 0.3, 0.6, 0.9];
const _timing = [0.45, 0.8, 1.0];

/// Bir taramadan çıkanlar: ham etiketlerin dökümü ve görülen kademeler.
///
/// Kademe yeniden hesaplanmıyor, oyundan okunuyor ([ShotGame.lastGrade]) —
/// "PAS TUTTU"nun `başarılı` mı `çok başarılı` mı olduğuna topu kimin aldığı
/// karar veriyor, ve bunu testin yeniden türetmesi ölçtüğü şeyi taklit etmek
/// olurdu.
typedef _Outcomes = ({Map<String, int> labels, Set<ShotGrade> grades});

/// Tek bir noktaya nişan alıp elin altındaki bütün vuruşları deneyen tarama.
_Outcomes _allStrikesAt(ShotScenario scenario, GroundPoint target) {
  final p = _projector(scenario.scene);
  final labels = <String, int>{};
  final grades = <ShotGrade>{};
  for (final normX in _normX) {
    for (final normY in _normY) {
      for (final timing in _timing) {
        final game = _strike(
          scenario,
          lateral: p.lateralOf(target.x, target.y),
          depth: p.depthOf(target.x, target.y),
          normX: normX,
          normY: normY,
          timing: timing,
        );
        labels[game.result!] = (labels[game.result!] ?? 0) + 1;
        grades.add(game.lastGrade);
      }
    }
  }
  return (labels: labels, grades: grades);
}

/// Nişanın gidebildiği her yere, her vuruşla atılan topların kademe dökümü.
///
/// "Bu durum bedava mı" sorusunun cevabı burada. Izgara sahanın tamamını
/// tarıyor, dolayısıyla atışların çoğu hiçbir şeye gitmiyor: başarısız oranının
/// yüksek olması beklenen şey, *düşük* olması durumun kendiliğinden
/// kazanıldığı anlamına gelir.
Map<ShotGrade, int> _sweep(ShotScenario scenario) {
  final p = _projector(scenario.scene);
  final tally = <ShotGrade, int>{};
  for (var di = 0; di <= 6; di++) {
    final depth = ShotWorld.minAimDepth +
        (scenario.scene.maxAimDepth - ShotWorld.minAimDepth) * di / 6;
    final limit =
        math.min(ShotWorld.maxAimLateral, p.visibleLateral(depth) * 0.97);
    for (var li = -5; li <= 5; li++) {
      for (final normX in _normX) {
        for (final normY in _normY) {
          final game = _strike(
            scenario,
            lateral: limit * li / 5,
            depth: depth,
            normX: normX,
            normY: normY,
            timing: 1,
          );
          tally[game.lastGrade] = (tally[game.lastGrade] ?? 0) + 1;
        }
      }
    }
  }
  return tally;
}

/// Bir alıcıya nişan alındığında 75 vuruşun en az kaçının topu ona
/// ulaştırması gerektiği. Bir seçeneğin "var" olması, tek bir imkânsız
/// vuruşla bulunabilmesi değil.
const _minStrikesThatWork = 3;

/// Kaleye nişan alındığında (dokuz nokta × 75 vuruş) beklenen en az gol
/// sayısı. Kataloğun en zoru olan tam karşıdan serbest vuruşta bu 675'te ~45;
/// eşik onun çok altında, çünkü test zorluğu değil *imkânı* ölçüyor.
const _minGoals = 5;

/// Gelişigüzel atılan topların en az bu kadarı sayılmamalı.
const _minFailRate = 0.5;

void main() {
  for (final scenario in ShotScenarios.all) {
    test('${scenario.id} — ${scenario.title}', () {
      final objective = scenario.objective;
      final reached = <ShotGrade>{};

      // 1) Adı konmuş her seçenek bulunabiliyor mu. Bir savunmacının tamamen
      //    kapattığı seçenek, seçenek değildir.
      for (final receiver in scenario.scene.receivers) {
        final out = _allStrikesAt(scenario, (x: receiver.x, y: receiver.y));
        final caught = out.labels[ShotLabel.passCaught] ?? 0;
        expect(
          caught,
          greaterThanOrEqualTo(_minStrikesThatWork),
          reason: '${scenario.id}: "${receiver.label}" adamına pas çıkmıyor '
              '(75 vuruşta $caught). Sonuçlar: ${out.labels}',
        );
        reached.addAll(out.grades);
      }

      // 2) Kale sayıyorsa, kaleciyi geçen bir şut var mı. Aynı tarama şutun
      //    "başarılı" kademesini de üretiyor: kurtarış ve direk oradan gelir.
      if (scenario.scene.scoresGoals) {
        var goals = 0;
        final labels = <String, int>{};
        for (var i = -4; i <= 4; i++) {
          final x = ShotWorld.goalHalfWidth * 0.85 * i / 4;
          final out = _allStrikesAt(scenario, (x: x, y: PitchLines.goalLineY));
          goals += out.labels[ShotLabel.goal] ?? 0;
          out.labels.forEach((k, v) => labels[k] = (labels[k] ?? 0) + v);
          reached.addAll(out.grades);
        }
        expect(
          goals,
          greaterThanOrEqualTo(_minGoals),
          reason: '${scenario.id}: kaleye gol atılamıyor (675 vuruşta $goals). '
              'Sonuçlar: $labels',
        );
      }

      // 3) Durum bedava değil: topu ıskalamak mümkün, hatta kolay.
      final sweep = _sweep(scenario);
      final total = sweep.values.reduce((a, b) => a + b);
      final failed = sweep[ShotGrade.fail] ?? 0;
      expect(
        failed / total,
        greaterThan(_minFailRate),
        reason: '${scenario.id}: gelişigüzel atılan topların yüzde '
            '${(100 - failed / total * 100).round()} kadarı sayılıyor — durum '
            'kendiliğinden kazanılıyor',
      );
      reached.addAll(sweep.keys);

      // 4) Hedefin vaat ettiği bütün kademeler sahada gerçekten çıkıyor mu.
      //    Bir durumun "üç sonucu var" demesi, üçünün de alınabilmesi demek —
      //    tek alıcılı bir sahne "çok başarılı" vaat edemez.
      expect(
        reached,
        {
          ShotGrade.fail,
          ShotGrade.good,
          if (objective.tiers == 3) ShotGrade.great,
        },
        reason: '${scenario.id}: ${objective.tiers} kademe vaat ediyor ama '
            'sahada ${reached.map((g) => g.name).toList()..sort()} çıkıyor',
      );
    });
  }

  test('katalogun dengesi', () {
    // Yukarıdaki testler durumları tek tek koruyor; bu, kataloğu bir bütün
    // olarak koruyor. İki kademeli durumlar istisna kalmalı — "çok başarılı"
    // yaygın olarak kaybolursa senaryolar yeniden birer antrenman tekrarına
    // dönüşür.
    final twoTier = ShotScenarios.all
        .where((s) => s.objective.tiers == 2)
        .map((s) => s.id)
        .toList();
    expect(twoTier.length, lessThan(ShotScenarios.all.length * 0.25));
    expect(twoTier, isNotEmpty, reason: 'iki kademeli durum hiç kalmamış');
  });
}
