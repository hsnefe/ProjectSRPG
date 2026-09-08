import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';

/// Katalog testi.
///
/// Kırk iki durum elle yazıldı ve her biri sahanın başka bir noktasında
/// geçiyor: koordinatlar okuyarak doğrulanabilecek bir şey değil. O yüzden
/// buradaki testler kataloğu *oynuyor* — her durumda asıl seçeneğe nişan alıp
/// topu gerçekten fırlatıyor ve beklenen sonucun çıktığına bakıyor. Bir
/// alıcıyı menzil dışına ya da kameranın arkasına koyan bir düzenleme, tekrar
/// çalıştırmadan burada patlar.
const _size = Size(360, 600);

PitchProjector _projector(ShotScene scene) => PitchProjector(
      size: _size,
      cameraAngle: scene.startAngle,
      origin: scene.origin,
    );

/// Bir durumu bir kez oynar: verilen dünya noktasına nişan alır, vurur ve
/// sonucu döndürür.
///
/// [scene] sahnenin kendisi değil bir kopyası olabilir — geometriyi rakiplerden
/// bağımsız sınamak için kadroyu boşaltıp aynı atışı yapıyoruz.
ShotGame _play(
  ShotScene scene,
  GroundPoint at, {
  double loft = 0,
  double spin = 0,
  double power = 1.0,
}) {
  final game = ShotGame(
    mode: scene.scoresGoals ? ShotMode.shot : ShotMode.pass,
    scene: scene,
    onStateChanged: () {},
  );
  final p = _projector(scene);
  game
    ..aimLateral = p.lateralOf(at.x, at.y)
    ..aimDepth = p.depthOf(at.x, at.y)
    ..power = power
    ..spin = spin
    ..loft = loft
    ..launch();
  game.finishFlight();
  return game;
}

/// Sahnenin karşı takımı ve kalecisi olmadan hâli. Bir alıcının *ulaşılabilir*
/// olması ile *ulaşılmasının kolay* olması ayrı şeyler; katalog birincisini
/// garanti eder, ikincisi zaten oyunun kendisi.
ShotScene _empty(ShotScene scene) =>
    scene.copyWith(rivals: const [], hasKeeper: false);

void main() {
  final catalog = ShotScenarios.all;

  group('katalog', () {
    test('kırk ile kırk beş arasında durum var', () {
      expect(catalog.length, inInclusiveRange(40, 45));
    });

    test('her ailede yeterince seçenek var', () {
      for (final kind in ShotScenarioKind.values) {
        expect(
          ShotScenarios.of(kind).length,
          greaterThanOrEqualTo(8),
          reason: '$kind bir seansı çeşitlendirecek kadar dolu olmalı',
        );
      }
      // Aileler toplamı kataloğun tamamı: hiçbir durum listelerin dışında
      // kalmıyor.
      expect(
        ShotScenarioKind.values
            .expand(ShotScenarios.of)
            .length,
        catalog.length,
      );
    });

    test('kimlikler benzersiz ve aranabilir', () {
      final ids = catalog.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final scenario in catalog) {
        expect(ShotScenarios.byId(scenario.id), same(scenario));
      }
      expect(ShotScenarios.byId('yok_böyle_bir_şey'), isNull);
    });

    test('her durumun başlığı ve tarifi var', () {
      for (final s in catalog) {
        expect(s.title, isNotEmpty, reason: s.id);
        expect(s.brief, isNotEmpty, reason: s.id);
        expect(s.aimHint, isNotEmpty, reason: s.id);
      }
    });
  });

  group('notlandırma', () {
    test('her durumun en az iki, çoğunun üç kademesi var', () {
      for (final s in catalog) {
        expect(s.objective.tiers, inInclusiveRange(2, 3), reason: s.id);
      }
      final threeTier = catalog.where((s) => s.objective.tiers == 3).length;
      expect(
        threeTier,
        greaterThan(catalog.length * 0.7),
        reason: 'üç kademe kural, iki kademe istisna olmalı',
      );
    });

    test('yalnızca oyunun ürettiği etiketlere puan veriliyor', () {
      for (final s in catalog) {
        expect(
          s.objective.scoredLabels.difference(ShotLabel.all),
          isEmpty,
          reason: '${s.id} var olmayan bir sonuca puan veriyor',
        );
        expect(
          s.objective.great.intersection(s.objective.good),
          isEmpty,
          reason: '${s.id} aynı etikete iki kademe veriyor',
        );
      }
    });

    test('üç kademeli her durumun ulaşılabilir bir tavanı var', () {
      for (final s in catalog.where((s) => s.objective.tiers == 3)) {
        final hasKeyMan = s.scene.receivers.any((r) => r.isKey);
        final scoresGoals =
            s.scene.scoresGoals && s.objective.great.contains(ShotLabel.goal);
        expect(
          hasKeyMan || scoresGoals,
          isTrue,
          reason: '${s.id}: "çok başarılı" hiçbir şekilde alınamıyor',
        );
        if (s.objective.keyPassIsGreat) {
          expect(hasKeyMan, isTrue, reason: '${s.id}: hattı kıran adam yok');
        }
      }
    });

    test('bir durumda en fazla bir tane anahtar alıcı var', () {
      for (final s in catalog) {
        expect(
          s.scene.receivers.where((r) => r.isKey).length,
          lessThanOrEqualTo(1),
          reason: s.id,
        );
      }
    });

    test('iki kademeli durumlar tavanı boş bırakır', () {
      for (final s in catalog.where((s) => s.objective.tiers == 2)) {
        expect(s.objective.great, isEmpty, reason: s.id);
        expect(s.objective.good, isNotEmpty, reason: s.id);
      }
    });
  });

  group('sahanın üstünde durmak', () {
    test('oyuncu sahanın içinde ve sahnesinin çizdiği alanda durur', () {
      for (final s in catalog) {
        final o = s.scene.origin;
        expect(o.x.abs(), lessThan(PitchLines.halfWidth), reason: s.id);
        expect(o.y, lessThanOrEqualTo(PitchLines.goalLineY), reason: s.id);
        expect(
          o.y,
          greaterThan(s.scene.backY),
          reason: '${s.id}: oyuncu çizilen sahanın gerisinde duruyor',
        );
      }
    });

    test('kendi yarı sahasındaki durumlar sahayı geriye doğru açar', () {
      for (final s in catalog) {
        if (s.scene.origin.y < PitchLines.halfwayY) {
          expect(
            s.scene.backY,
            lessThanOrEqualTo(PitchLines.ownGoalLineY + 0.01),
            reason: '${s.id}: orta sahanın gerisinde, ama saha orada bitiyor',
          );
        }
      }
    });

    test('kamera hep oyun yönüne bakar', () {
      // Sahayı ters seyretmek bir tercih değil, hata: çizgiler çapraz gidince
      // görüntü oyuncunun gözü olmaktan çıkıp kuşbakışı bir haritaya dönüyor.
      // Seçenekler bu koninin dışına düşüyorsa çözüm kamerayı çevirmek değil,
      // adamı doğru yere koymak.
      const maxTurn = 60.5 * math.pi / 180;
      for (final s in catalog) {
        expect(
          s.scene.startAngle.abs(),
          lessThanOrEqualTo(maxTurn),
          reason: '${s.id}: '
              '${(s.scene.startAngle * 180 / math.pi).round()}° ile yana bakıyor',
        );
      }
    });

    test('herkes sahanın içinde', () {
      for (final s in catalog) {
        for (final body in s.scene.bodies) {
          expect(body.x.abs(), lessThanOrEqualTo(PitchLines.halfWidth),
              reason: '${s.id} / ${body.label}');
          expect(body.y, lessThanOrEqualTo(PitchLines.goalLineY),
              reason: '${s.id} / ${body.label}');
          expect(body.y, greaterThanOrEqualTo(s.scene.backY),
              reason: '${s.id} / ${body.label}');
        }
      }
    });

    test('durumlar sahaya dağılmış, tek bir noktada toplanmamış', () {
      final origins = catalog.map((s) => s.scene.origin).toList();
      // İki durum aynı yerde geçmesin: kataloğun varlık sebebi bu.
      for (var i = 0; i < origins.length; i++) {
        for (var j = i + 1; j < origins.length; j++) {
          final gap = math.sqrt(
            math.pow(origins[i].x - origins[j].x, 2) +
                math.pow(origins[i].y - origins[j].y, 2),
          );
          expect(
            gap,
            greaterThan(0.08),
            reason: '${catalog[i].id} ile ${catalog[j].id} neredeyse aynı yerde',
          );
        }
      }
      // Ve saha boyunca yayılmış olsunlar.
      final ys = origins.map((o) => o.y).toList()..sort();
      expect(ys.last - ys.first, greaterThan(3.0));
      final xs = origins.map((o) => o.x).toList()..sort();
      expect(xs.last - xs.first, greaterThan(2.0));
    });
  });

  group('nişan menzili', () {
    test('herkes kameranın önünde ve menzilin içinde', () {
      for (final s in catalog) {
        final p = _projector(s.scene);
        for (final r in s.scene.receivers) {
          final depth = p.depthOf(r.x, r.y);
          expect(
            depth,
            greaterThan(ShotWorld.minAimDepth),
            reason: '${s.id} / ${r.label} nişanın erişemeyeceği kadar yakın',
          );
          expect(
            depth,
            lessThanOrEqualTo(s.scene.maxAimDepth),
            reason: '${s.id} / ${r.label} menzilin dışında',
          );
          expect(
            p.lateralOf(r.x, r.y).abs(),
            lessThan(math.min(ShotWorld.maxAimLateral,
                p.visibleLateral(depth) * 0.97)),
            reason: '${s.id} / ${r.label} ekranın dışında kalıyor',
          );
        }
      }
    });

    test('kale sayan durumlarda kale de menzilde', () {
      for (final s in catalog.where((s) => s.scene.scoresGoals)) {
        final p = _projector(s.scene);
        expect(
          p.depthOf(0, PitchLines.goalLineY),
          lessThanOrEqualTo(s.scene.maxAimDepth),
          reason: '${s.id}: kaleye nişan alınamıyor',
        );
      }
    });

    test('kale sayan durumlarda kale kadrajın içinde duruyor', () {
      // Kale, iki direği de yakın düzlemin ötesinde olmadıkça hiç çizilmiyor
      // (`PitchComponent._paintGoal`). Dar açılı bir şutta bakış yönünü
      // seçeneklerin ortasına kaydırmak kaleyi kadrajdan çıkarıyordu: nişan
      // alınacak şeyin ekranda olması bir tercih değil, ön koşul.
      for (final s in catalog.where((s) => s.scene.scoresGoals)) {
        final p = _projector(s.scene);
        for (final post in const [-ShotWorld.goalHalfWidth, ShotWorld.goalHalfWidth]) {
          final depth = p.depthOf(post, PitchLines.goalLineY);
          expect(
            p.isVisible(depth),
            isTrue,
            reason: '${s.id}: direk (x: $post) çizilmiyor',
          );
          expect(
            p.lateralOf(post, PitchLines.goalLineY).abs(),
            lessThan(p.visibleLateral(depth)),
            reason: '${s.id}: direk (x: $post) ekranın dışında',
          );
        }
      }
    });

    test('şut mesafesi üst direği kadrajda tutar', () {
      // Kale ne kadar uzaktaysa ekranda o kadar yukarı çıkıyor; ~1.1 birimden
      // (23 m) sonra üst direk kadrajın üstünde kalıyor ve "üstten aut" göze
      // görünmeyen bir kurala dönüşüyor. Projeksiyonun kendi sınırı, sahnenin
      // değil — o yüzden şut durumları bu mesafenin içinde kalıyor.
      for (final s in catalog.where((s) => s.scene.scoresGoals)) {
        expect(
          _projector(s.scene).depthOf(0, PitchLines.goalLineY),
          lessThanOrEqualTo(1.10),
          reason: '${s.id}: kale çok uzakta, üst direk kesiliyor',
        );
      }
    });

    test('nişan seçeneklerin arasında başlar', () {
      // Kamera oyun yönüne sabitlendiğinden "tam karşı" artık seçeneklerin
      // ortası demek değil: nişan hedeflerin ortalamasında durmazsa oyuncu
      // her denemede reticle'ı uzaktan sürüklemek zorunda kalıyor.
      for (final s in catalog) {
        final p = _projector(s.scene);
        final targets = <GroundPoint>[
          for (final r in s.scene.receivers) (x: r.x, y: r.y),
          if (s.scene.scoresGoals) (x: 0.0, y: PitchLines.goalLineY),
        ];
        final nearest = targets
            .map((t) => math.sqrt(
                  math.pow(p.lateralOf(t.x, t.y) - s.scene.defaultAimLateral, 2) +
                      math.pow(p.depthOf(t.x, t.y) - s.scene.defaultAimDepth, 2),
                ))
            .reduce(math.min);
        expect(
          nearest,
          lessThan(0.75),
          reason: '${s.id}: nişan hiçbir seçeneğin yakınında başlamıyor',
        );
      }
    });

    test('açılıştaki nişan noktası menzilin içinde', () {
      for (final s in catalog) {
        expect(
          s.scene.defaultAimDepth,
          inInclusiveRange(ShotWorld.minAimDepth, s.scene.maxAimDepth),
          reason: s.id,
        );
        expect(s.scene.maxAimDepth, lessThanOrEqualTo(1.28), reason: s.id);
      }
    });

    test('menzil, oynanacak şeyin biraz ötesinde biter', () {
      // Ekranın yarısı boş kalıyorsa nişan gereksiz yere hassaslaşır.
      for (final s in catalog) {
        final p = _projector(s.scene);
        final furthest = [
          for (final r in s.scene.receivers) p.depthOf(r.x, r.y),
          if (s.scene.scoresGoals) p.depthOf(0, PitchLines.goalLineY),
        ].reduce(math.max);
        expect(
          s.scene.maxAimDepth - furthest,
          lessThan(0.45),
          reason: '${s.id}: nişan hiçbir şeyin olmadığı yere uzanıyor',
        );
      }
    });

    test('rakipler ekranda duruyor', () {
      // Kameranın arkasında kalan bir savunmacı ne görünüyor ne de topa
      // yetişebiliyor: sahne baskı vaat edip hiç uygulamıyor. Bir durumun
      // savunmacısını hattın dışına çekerken en kolay düşülen tuzak bu.
      for (final s in catalog) {
        final p = _projector(s.scene);
        for (final foe in s.scene.rivals) {
          final depth = p.depthOf(foe.x, foe.y);
          expect(
            depth,
            greaterThanOrEqualTo(PitchProjector.pointFadeDepth * 0.6),
            reason: '${s.id}: ${foe.label} kameranın arkasında ya da '
                'sönük kalıyor (derinlik $depth)',
          );
          expect(
            p.lateralOf(foe.x, foe.y).abs(),
            lessThan(p.visibleLateral(depth)),
            reason: '${s.id}: ${foe.label} ekranın dışında',
          );
        }
      }
    });

    test('rakipler bir alıcının üstüne dikilmemiş', () {
      // Üstünde adam duran bir seçenek seçenek değildir; rakip pas yolunu
      // kapatır, adamın kendisini değil.
      for (final s in catalog) {
        for (final r in s.scene.receivers) {
          for (final foe in s.scene.rivals) {
            final gap = math.sqrt(
              math.pow(r.x - foe.x, 2) + math.pow(r.y - foe.y, 2),
            );
            expect(
              gap,
              greaterThan(ShotWorld.passCatchRadius),
              reason: '${s.id}: ${foe.label}, ${r.label} üstünde duruyor',
            );
          }
        }
      }
    });
  });

  group('her durum gerçekten oynanabiliyor', () {
    test('boş sahada her alıcıya atılan pas tutar', () {
      for (final s in catalog) {
        for (final r in s.scene.receivers) {
          final game = _play(
            _empty(s.scene),
            (x: r.x, y: r.y),
            // Ceza sahasındaki kalabalıkta yerden bir top kendi arkadaşına
            // çarpabiliyor; hafif bir yükseklik alıcıyı tek başına sınıyor.
            loft: 0.25,
          );
          expect(
            game.result,
            ShotLabel.passCaught,
            reason: '${s.id}: ${r.label} nişan alındığı hâlde topu almıyor',
          );
        }
      }
    });

    test('anahtar adama giden pas tavan not verir', () {
      for (final s in catalog.where((s) => s.objective.keyPassIsGreat)) {
        final key = s.scene.receivers.firstWhere((r) => r.isKey);
        final game = ShotGame(
          mode: ShotScenarioKind.buildUp.mode,
          playlist: [
            ShotScenario(
              id: s.id,
              kind: s.kind,
              title: s.title,
              brief: s.brief,
              aimHint: s.aimHint,
              scene: _empty(s.scene),
            ),
          ],
          onStateChanged: () {},
        );
        final p = _projector(s.scene);
        game
          ..aimLateral = p.lateralOf(key.x, key.y)
          ..aimDepth = p.depthOf(key.x, key.y)
          ..power = 1
          ..loft = 0.25
          ..launch();
        game.finishFlight();

        expect(game.result, ShotLabel.passCaught, reason: s.id);
        expect(game.lastGrade, ShotGrade.great, reason: s.id);
        expect(game.attemptLog.single.scenarioId, s.id);
      }
    });

    test('güvenli adama giden pas sayılır ama tavan değildir', () {
      for (final s in catalog.where((s) => s.objective.keyPassIsGreat)) {
        final safe = s.scene.receivers.where((r) => !r.isKey);
        for (final r in safe) {
          final game = _play(_empty(s.scene), (x: r.x, y: r.y), loft: 0.25);
          expect(game.result, ShotLabel.passCaught, reason: '${s.id}/${r.label}');
          expect(
            s.objective.gradeOf(game.result!, keyReceiver: false),
            ShotGrade.good,
            reason: '${s.id}: ${r.label} güvenli seçenek olmalı',
          );
        }
      }
    });

    test('boş kaleye çekilen şut girer', () {
      for (final s in catalog.where((s) => s.scene.scoresGoals)) {
        final game = _play(_empty(s.scene), (x: 0, y: PitchLines.goalLineY));
        expect(
          game.result,
          ShotLabel.goal,
          reason: '${s.id}: boş kaleye bile atılamıyor',
        );
        expect(s.objective.gradeOf(game.result!).counts, isTrue, reason: s.id);
      }
    });

    test('topu kaybetmek hiçbir durumda sayılmaz', () {
      // Kaybedilen top her durumda başarısız — bir sahnenin kadrosunu ya da
      // hedefini değiştirirken en kolay bozulacak şey bu.
      for (final s in catalog) {
        for (final lost in const [
          ShotLabel.wide,
          ShotLabel.over,
          ShotLabel.intercepted,
          ShotLabel.passMissed,
          ShotLabel.intoSpace,
        ]) {
          expect(
            s.objective.gradeOf(lost, keyReceiver: true),
            ShotGrade.fail,
            reason: '${s.id}: "$lost" sayıldı',
          );
        }
      }
    });

    test('rakibin kestiği pas gerçekten de sayılmaz', () {
      // Yukarıdaki tablo testinin oynanan hâli: kadrosunda pas yolunu kapatan
      // biri olan bir durumda, o adamın üstüne atılan top kaybedilir.
      final blocked = catalog.firstWhere(
        (s) => s.scene.rivals.isNotEmpty && !s.scene.scoresGoals,
      );
      final foe = blocked.scene.rivals.first;
      final game = _play(blocked.scene, (x: foe.x, y: foe.y));

      expect(game.result, ShotLabel.intercepted);
      expect(blocked.objective.gradeOf(game.result!), ShotGrade.fail);
    });
  });

  group('seans dizmek', () {
    test('şut seansı üç farklı şut durumu verir', () {
      for (var seed = 0; seed < 25; seed++) {
        final session = ShotScenarios.shotSession(random: math.Random(seed));
        expect(session.length, ShotGame.attemptsPerSession);
        expect(session.map((s) => s.id).toSet().length, session.length);
        expect(session.every((s) => s.kind == ShotScenarioKind.shot), isTrue);
      }
    });

    test('pas seansı kurulumdan başlar, son bölgede biter', () {
      for (var seed = 0; seed < 25; seed++) {
        final session = ShotScenarios.passSession(random: math.Random(seed));
        expect(
          session.map((s) => s.kind).toList(),
          [
            ShotScenarioKind.buildUp,
            ShotScenarioKind.transition,
            ShotScenarioKind.finalThird,
          ],
        );
      }
    });

    test('seans denemeler arasında sahnesini değiştirir', () {
      final session = ShotScenarios.passSession(random: math.Random(7));
      final game = ShotGame(
        mode: ShotMode.pass,
        playlist: session,
        onStateChanged: () {},
      );

      for (var i = 0; i < ShotGame.attemptsPerSession; i++) {
        expect(game.scenario, same(session[i]), reason: 'deneme $i');
        expect(game.scene, same(session[i].scene), reason: 'deneme $i');
        expect(game.cameraAngle, closeTo(session[i].scene.startAngle, 1e-9));
        expect(game.aimDepth, session[i].scene.defaultAimDepth);

        // Bir denemeyi çöz: top havaya, sonuç ne olursa olsun sayaç ilerler.
        game
          ..aimDepth = game.scene.defaultAimDepth
          ..power = 1
          ..launch();
        game.finishFlight();
        expect(game.attempts, i + 1);
        // Sonuç ekranındayken dünya hâlâ atışın yapıldığı dünya olmalı.
        expect(game.scene, same(session[i].scene), reason: 'deneme $i sonucu');
        game.reset();
      }
    });

    test('baştan alınca ilk duruma döner', () {
      final session = ShotScenarios.shotSession(random: math.Random(3));
      final game = ShotGame(
        mode: ShotMode.shot,
        playlist: session,
        onStateChanged: () {},
      );
      for (var i = 0; i < ShotGame.attemptsPerSession; i++) {
        game
          ..power = 1
          ..launch();
        game.finishFlight();
        game.reset();
      }
      expect(game.scenario, same(session.last));

      game.restartSession();
      expect(game.attempts, 0);
      expect(game.scenario, same(session.first));
      expect(game.cameraAngle, closeTo(session.first.scene.startAngle, 1e-9));
    });

    test('liste seanstan kısaysa son durum tekrarlanır', () {
      final only = [ShotScenarios.shots.first];
      final game = ShotGame(
        mode: ShotMode.shot,
        playlist: only,
        onStateChanged: () {},
      );
      for (var i = 0; i < ShotGame.attemptsPerSession; i++) {
        expect(game.scenario, same(only.single));
        game
          ..power = 1
          ..launch();
        game.finishFlight();
        game.reset();
      }
    });
  });

  group('seans sonucu', () {
    test('çok başarılı denemeler puanı yükseltir', () {
      // Aynı sayıda "sayılan" deneme, farklı puan: üç kademeli bir durumda
      // güvenli topun tavanla aynı şeyi ödemesi kademeyi anlamsız kılardı.
      const objective = ShotObjective.pass;
      expect(objective.weightOf(ShotGrade.great), 1);
      expect(objective.weightOf(ShotGrade.good), lessThan(1));
      expect(objective.weightOf(ShotGrade.fail), 0);

      // İki kademelide "başarılı" zaten tavandır.
      expect(ShotObjective.passOnly.weightOf(ShotGrade.good), 1);
    });

    test('dökümde çok başarılı sayısı görünür', () {
      final game = ShotGame(
        mode: ShotMode.pass,
        playlist: [
          for (final s in ShotScenarios.buildUp.take(1))
            ShotScenario(
              id: s.id,
              kind: s.kind,
              title: s.title,
              brief: s.brief,
              aimHint: s.aimHint,
              scene: _empty(s.scene),
            ),
        ],
        onStateChanged: () {},
      );
      final key = game.scene.receivers.firstWhere((r) => r.isKey);
      final p = _projector(game.scene);

      for (var i = 0; i < ShotGame.attemptsPerSession; i++) {
        game
          ..aimLateral = p.lateralOf(key.x, key.y)
          ..aimDepth = p.depthOf(key.x, key.y)
          ..power = 1
          ..loft = 0.25
          ..launch();
        game.finishFlight();
        game.reset();
      }

      expect(game.made, 3);
      expect(game.great, 3);
      expect(game.sessionResult.detail, contains('3 çok başarılı'));
      expect(game.sessionResult.score, 1.0);
    });
  });
}
