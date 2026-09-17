/// Şut ve pas mini oyununun durum kataloğu.
///
/// Oyun bir zamanlar tek bir yerde oynanıyordu: top orta noktada, kale
/// karşıda, her deneme bir öncekinin aynısı. Buradaki her kayıt onun yerine
/// **bir durum** tarif ediyor — sahanın neresinde durduğun, hangi yöne
/// baktığın, yanında kimin, karşında kimin olduğu ve senden ne beklendiği.
///
/// Katalog dört aileye ayrılıyor ([ShotScenarioKind]):
///
/// * **Şut** — aynı kale, her seferinde başka bir açı ve mesafe. Penaltı
///   noktasından dar açıya, ceza sahası dışından kaleciyle karşı karşıyaya.
/// * **Geriden kurulum** — kendi yarı sahanda ilk pas. Güvenli olan yana,
///   riskli olan ileri gider; ikisi de tutar, biri oyunu ilerletir.
/// * **Geçiş** — topu kazandığın an. Bir saniyen var: ya emniyete alırsın ya
///   da rakip düzenini toplamadan hattı geçersin.
/// * **Son bölge** — son otuz metre. Ortalar, arkaya sarkan koşular, geri
///   çevirmeler ve bitirmek ile bitirtmek arasındaki seçim.
///
/// ## Notlandırma
///
/// Her durumun kendi [ShotObjective]'i var, yani "başarılı" ile "çok
/// başarılı"nın ne demek olduğuna kural değil durum karar veriyor. Üç
/// kademeli olanlarda tavan ya golün kendisi ya da [ShotTarget.isKey]
/// işaretli adam: aynı "PAS TUTTU" güvenli adama giderse `başarılı`, hattı
/// kıran adama giderse `çok başarılı`. İki kademeli olanlar (penaltı, basit
/// bir emniyet pası) [ShotObjective.great]'i boş bırakır — orada ya olur ya
/// olmaz.
///
/// ## Koordinatlar
///
/// Dünya birimi sahanın yarı genişliği üzerinden: 1 birim ≈ 21.25 m.
/// Rakip kale çizgisi `y = 1.0`, orta saha `y ≈ -1.47`, kendi kale çizgimiz
/// `y ≈ -3.94`, taç çizgileri `x = ±1.6`. Oyuncu [ShotScene.origin]'de durur
/// ve [ShotScene.lookAt]'e bakar; nişan menzili `maxAimDepth` kadar (en fazla
/// ~1.25 birim ≈ 26 m), o yüzden her alıcı kameranın önünde ve menzil içinde
/// olmak zorunda. Bunu elle takip etmiyoruz: `test/shot_scenarios_test.dart`
/// katalogdaki her kaydı bu kurallara karşı doğruluyor ve her durumu bir kez
/// gerçekten oynuyor.
///
/// ## Durumlar nereden geliyor
///
/// Kayıtların kendisi bu dosyada değil, `shot_scenarios.g.dart`'ta —
/// **üretilen** bir dosya, elle düzenlenmiyor. Kaynağı `../scenario_creator`:
/// sahayı üstten gösteren, adamları sürükleyip yerleştirdiğin ve buradaki
/// kuralları canlı doğrulayan bir editör. Kırk iki durum elle yazılmıştı ve
/// koordinatları gözle doğrulamak mümkün değildi; bir durumu değiştirmenin
/// yolu artık editörü açmak.
///
/// Bu dosyada kalan şey kayıtların *yorumu*: [_scene] kadrodan bakış açısını,
/// nişanın açılış noktasını ve menzili türetiyor. O hesap burada duruyor,
/// üretilen dosyada değil — bir kaydın içinde "kamera 37 derece" yazsaydı
/// adamı bir santim oynatmak onu sessizce yalan hâline getirirdi.
library;

import 'dart:math' as math;

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.g.dart';

/// Kameranın oyun yönünden (rakip kaleye doğru) sapabileceği en büyük açı.
///
/// Seçeneklerin açı ortasına bakmak tek başına yetmiyordu: güvenli adam
/// geride, hattı kıran adam ileride olunca orta nokta yana — bazen tam
/// geriye — düşüyordu. On altı durum yana ya da arkaya bakıyordu ve saha
/// çizgileri çapraz gidince görüntü kuşbakışı bir haritaya dönüşüyordu.
///
/// Altmış derece, futbolcunun topu alırken gerçekten çevirebileceği kadar bir
/// pay bırakıyor; ötesi "sahayı ters seyretmek" oluyor. Seçenekler bu koninin
/// dışında kalıyorsa çözüm kamerayı çevirmek değil, adamı doğru yere koymak —
/// katalog testi bunu zorluyor.
const _maxTurn = 60 * math.pi / 180;

/// Bir durumun sahnesini kuran yardımcı: bakış açısını, nişanın açılış
/// noktasını ve menzili **kadrodan türetir**.
///
/// Elle yazılan tek şey kimin nerede durduğu. Kameranın nereye bakacağı bir
/// tercih değil, sonuç: bütün seçeneklerin (ve sayıyorsa kalenin) yönleri
/// arasındaki açı yelpazesinin tam ortası. İlk elle yazıldığında yarım düzine
/// durumda "güvenli" adam kameranın arkasında kalmıştı — nişan alınamayan bir
/// seçenek seçenek değil, ve bunu gözle yakalamak mümkün değil.
///
/// Nişan da ortada başlıyor: seçeneklerin ortalama derinliğinde. Doğrudan
/// anahtar adamın üstünde başlasa oyun kendi cevabını söylemiş olurdu.
ShotScene _scene({
  required GroundPoint origin,
  required List<ShotTarget> receivers,
  required ShotObjective objective,
  List<ShotTarget> rivals = const [],
  GroundPoint? bearingAt,
  bool hasKeeper = false,
  bool scoresGoals = false,
  double backY = PitchLines.backY,
}) {
  final targets = <GroundPoint>[
    for (final r in receivers) (x: r.x, y: r.y),
    if (scoresGoals) (x: 0.0, y: PitchLines.goalLineY),
  ];
  assert(targets.isNotEmpty, 'bir durumun en az bir seçeneği olmalı');

  // Yelpazenin ortası, ilk seçeneğe göre ölçülüp geri eklenerek: ham açıların
  // ortalaması ±180°'yi kesen bir yelpazede (sağda duran adam ile arkada duran
  // adam) tam ters yönü verirdi.
  final reference =
      math.atan2(targets.first.x - origin.x, targets.first.y - origin.y);
  final offsets = [
    for (final t in targets)
      ShotGame.shortestAngle(
        math.atan2(t.x - origin.x, t.y - origin.y) - reference,
      ),
  ];
  // Yelpazenin ortası, ya da bir durum kendi bakış noktasını dayatıyorsa o.
  // Şut durumları dayatıyor: şut çeken adam kaleye bakar, kale ile yanındaki
  // arkadaşının ortasına değil — yoksa kale kadrajın kenarına kayıyor ve
  // nişan alınacak şey ekranda görünmüyor.
  final aimed = bearingAt != null
      ? math.atan2(bearingAt.x - origin.x, bearingAt.y - origin.y)
      : reference + (offsets.reduce(math.min) + offsets.reduce(math.max)) / 2;
  // Nereye bakmak *istediğin* ile nereye bakman *gerektiği* ayrı: oyuncu
  // sahayı oyun yönünde görür, dip çizgide bile.
  final angle = aimed.clamp(-_maxTurn, _maxTurn);

  double depthOf(GroundPoint t) =>
      (t.x - origin.x) * math.sin(angle) + (t.y - origin.y) * math.cos(angle);
  double lateralOf(GroundPoint t) =>
      (t.x - origin.x) * math.cos(angle) - (t.y - origin.y) * math.sin(angle);

  final depths = [for (final t in targets) depthOf(t)];
  final reach = depths.reduce(math.max);
  // Menzil en uzak seçeneğin biraz ötesinde biter; nişanın oynanacak bir şeyin
  // olmadığı yere uzanması yalnızca hedefi tutturmayı zorlaştırır.
  final maxDepth = math.min(1.25, reach + 0.18);
  final aim = (depths.reduce((a, b) => a + b) / depths.length)
      .clamp(ShotWorld.minAimDepth + 0.02, maxDepth);
  // Nişan seçeneklerin ortasında başlıyor — derinlikte de, yanda da. Kamera
  // oyun yönüne sabitlendiğinden bu artık "tam karşı" ile aynı şey değil.
  final laterals = [for (final t in targets) lateralOf(t)];
  final aimLateral = (laterals.reduce((a, b) => a + b) / laterals.length)
      .clamp(-ShotWorld.maxAimLateral, ShotWorld.maxAimLateral);

  return ShotScene(
    receivers: receivers,
    rivals: rivals,
    // Bakılan nokta, hesaplanan yön üzerinde nişanın başladığı yer:
    // [ShotScene.startAngle] onu buradan okuyor.
    // Bakılan nokta hesaplanan yönün *üzerinde*: [ShotScene.startAngle] açıyı
    // buradan okuyor, dolayısıyla yanal kayma buraya karışamaz.
    lookAt: (
      x: origin.x + math.sin(angle) * aim,
      y: origin.y + math.cos(angle) * aim,
    ),
    origin: origin,
    hasKeeper: hasKeeper,
    scoresGoals: scoresGoals,
    objective: objective,
    defaultAimDepth: aim,
    defaultAimLateral: aimLateral,
    maxAimDepth: maxDepth,
    backY: backY,
  );
}

/// Kaleye bakan bir şut sahnesi: kale sayılır ve kaleci yerindedir.
ShotScene _shotScene({
  required GroundPoint origin,
  List<ShotTarget> receivers = const [],
  List<ShotTarget> rivals = const [],
  ShotObjective objective = ShotObjective.finish,
  bool hasKeeper = true,
  double backY = PitchLines.backY,
}) =>
    _scene(
      origin: origin,
      receivers: receivers,
      rivals: rivals,
      objective: objective,
      bearingAt: (x: 0.0, y: PitchLines.goalLineY),
      hasKeeper: hasKeeper,
      scoresGoals: true,
      backY: backY,
    );

/// Katalogun tamamı ve ondan seans dizmenin yolu.
///
/// Durumların kendisi `shot_scenarios.g.dart`'ta: `scenario_creator/` editörü
/// üretiyor, elle düzenlenmiyor. Burada kalan iş onları sahneye çevirmek —
/// yani yukarıdaki [_scene] ile bakış açısını ve nişan menzilini türetmek —
/// ve seans dizmek.
class ShotScenarios {
  const ShotScenarios._();

  static const _kinds = <String, ShotScenarioKind>{
    'shot': ShotScenarioKind.shot,
    'buildUp': ShotScenarioKind.buildUp,
    'transition': ShotScenarioKind.transition,
    'finalThird': ShotScenarioKind.finalThird,
  };

  /// Hazır hedeflerin adları. Üretilen veri hedefi adıyla taşıyor; kendi
  /// etiket kümesini yazan bir durum `objectiveCustom` kullanıyor.
  static const _objectives = <String, ShotObjective>{
    'none': ShotObjective.none,
    'goalOnly': ShotObjective.goalOnly,
    'passOnly': ShotObjective.passOnly,
    'finish': ShotObjective.finish,
    'finishOrLayoff': ShotObjective.finishOrLayoff,
    'pass': ShotObjective.pass,
    'assistOrFinish': ShotObjective.assistOrFinish,
  };

  static ShotObjective _objectiveOf(ShotSpec spec) {
    final custom = spec.objectiveCustom;
    if (custom != null) {
      return ShotObjective(
        great: custom.great.toSet(),
        good: custom.good.toSet(),
        keyPassIsGreat: custom.keyPassIsGreat,
      );
    }
    final preset = _objectives[spec.objective];
    assert(preset != null, '${spec.id}: bilinmeyen hedef ${spec.objective}');
    return preset ?? ShotObjective.none;
  }

  /// Bir kaydı oynanabilir bir duruma çevirir.
  ///
  /// Kaleyi sayan durumlar [_shotScene]'den geçiyor: bakış yönünü kaleye
  /// dayatmak bir tercih değil, dar açılı bir şutta kalenin kadrajda kalma
  /// koşulu.
  static ShotScenario _fromSpec(ShotSpec spec) {
    final origin = (x: spec.originX, y: spec.originY);
    final receivers = [
      for (final r in spec.receivers)
        ShotTarget(label: r.label, x: r.x, y: r.y, isKey: r.key),
    ];
    final rivals = [
      for (final r in spec.rivals)
        ShotTarget(label: r.label, x: r.x, y: r.y, isRival: true),
    ];
    final objective = _objectiveOf(spec);

    return ShotScenario(
      id: spec.id,
      kind: _kinds[spec.kind] ?? ShotScenarioKind.shot,
      title: spec.title,
      brief: spec.brief,
      aimHint: spec.aimHint,
      actionKey: spec.actionKey,
      scene: spec.scoresGoals
          ? _shotScene(
              origin: origin,
              receivers: receivers,
              rivals: rivals,
              objective: objective,
              hasKeeper: spec.hasKeeper,
              backY: spec.backY,
            )
          : _scene(
              origin: origin,
              receivers: receivers,
              rivals: rivals,
              objective: objective,
              hasKeeper: spec.hasKeeper,
              backY: spec.backY,
            ),
    );
  }

  /// Katalogun tamamı, aile sırasıyla — üretilen dosya zaten o sırada.
  static final List<ShotScenario> all = [
    for (final spec in kShotSpecs) _fromSpec(spec),
  ];

  static final List<ShotScenario> shots = _family(ShotScenarioKind.shot);
  static final List<ShotScenario> buildUp = _family(ShotScenarioKind.buildUp);
  static final List<ShotScenario> transitions =
      _family(ShotScenarioKind.transition);
  static final List<ShotScenario> finalThird =
      _family(ShotScenarioKind.finalThird);

  static List<ShotScenario> _family(ShotScenarioKind kind) =>
      [for (final s in all) if (s.kind == kind) s];

  static List<ShotScenario> of(ShotScenarioKind kind) => switch (kind) {
        ShotScenarioKind.shot => shots,
        ShotScenarioKind.buildUp => buildUp,
        ShotScenarioKind.transition => transitions,
        ShotScenarioKind.finalThird => finalThird,
      };

  static ShotScenario? byId(String id) {
    for (final scenario in all) {
      if (scenario.id == id) return scenario;
    }
    return null;
  }

  /// Bir şut seansının durumları: kataloğun şut ailesinden rastgele üçü,
  /// hiçbiri tekrar etmeden.
  static List<ShotScenario> shotSession({math.Random? random}) {
    final shuffled = [...shots]..shuffle(random ?? math.Random());
    return shuffled.take(ShotGame.attemptsPerSession).toList();
  }

  /// Bir pas seansının durumları — her aileden bir tane, sahanın kendi
  /// sırasıyla: geriden kur, geçişi başlat, son bölgede bitir.
  ///
  /// Rastgele üç pas durumu seçmek üç kurulum senaryosunu üst üste
  /// verebilirdi; aileleri sırayla dolaşmak seansı bir maçın kendi akışına
  /// benzetiyor.
  static List<ShotScenario> passSession({math.Random? random}) {
    final rng = random ?? math.Random();
    return [
      for (final kind in const [
        ShotScenarioKind.buildUp,
        ShotScenarioKind.transition,
        ShotScenarioKind.finalThird,
      ])
        of(kind)[rng.nextInt(of(kind).length)],
    ];
  }
}
