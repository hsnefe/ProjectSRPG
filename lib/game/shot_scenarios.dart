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
library;

import 'dart:math' as math;

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';

/// Kendi yarı sahasında geçen durumların çizdirdiği saha derinliği.
///
/// Varsayılan arka sınır orta saha çizgisi; geriden kurulumda oyuncu zaten
/// onun gerisinde duruyor, dolayısıyla saha kendi kalemize kadar açılıyor.
const _deepBack = PitchLines.ownGoalLineY;

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

// --- Kadro kısayolları ------------------------------------------------------
//
// Bir durumun okunabilirliği, alıcıların yerini yazarken ne kadar az gürültü
// olduğuna bağlı. Bu üç yardımcı ShotTarget'ı tek satıra indiriyor: kim orada
// duruyor, kim hattı kırıyor, kim karşı takımda.

ShotTarget _mate(String label, double x, double y) =>
    ShotTarget(label: label, x: x, y: y);

/// Durumun asıl cevabı: bulunduğunda notu tavana çıkaran adam.
ShotTarget _key(String label, double x, double y) =>
    ShotTarget(label: label, x: x, y: y, isKey: true);

ShotTarget _foe(String label, double x, double y) =>
    ShotTarget(label: label, x: x, y: y, isRival: true);

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
class ShotScenarios {
  const ShotScenarios._();

  static const _aimShot = '1) Sürükle: kalede bir nokta seç, bırak';
  static const _aimPass = '1) Sürükle: topu bırakacağın noktayı seç, bırak';

  // -------------------------------------------------------------------------
  // Şut: aynı kale, on altı ayrı açı.
  // -------------------------------------------------------------------------

  static final List<ShotScenario> shots = [
    ShotScenario(
      id: 'shot_penalty',
      kind: ShotScenarioKind.shot,
      title: 'Penaltı',
      brief: 'Nokta, kaleci ve sen. Köşeyi seç; kaleci senin gittiğin yere '
          'gidiyor.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: 0, y: PitchLines.penaltySpotY),
        objective: ShotObjective.goalOnly,
      ),
    ),
    ShotScenario(
      id: 'shot_box_centre',
      kind: ShotScenarioKind.shot,
      title: 'Ceza sahası içi, tam karşı',
      brief: 'Altı pasın hemen önü. Kaleci açıyı daralttı: yerden köşe ya da '
          'üstten.',
      aimHint: _aimShot,
      scene: _shotScene(origin: (x: 0.06, y: 0.36)),
    ),
    ShotScenario(
      id: 'shot_box_left',
      kind: ShotScenarioKind.shot,
      title: 'Ceza sahası, sol taraf',
      brief: 'Soldan içeri kestin. Uzak direk açık, yakın direği kaleci '
          'kapatmış.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: -0.62, y: 0.46),
        rivals: [_foe('Stoper', -0.34, 0.66)],
      ),
    ),
    ShotScenario(
      id: 'shot_box_right',
      kind: ShotScenarioKind.shot,
      title: 'Ceza sahası, sağ taraf',
      brief: 'Sağdan içeri katıp durdun. Kavisle uzak köşeye çevirebilirsin.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: 0.66, y: 0.44),
        rivals: [_foe('Stoper', 0.34, 0.66)],
      ),
    ),
    ShotScenario(
      id: 'shot_edge_d',
      kind: ShotScenarioKind.shot,
      title: 'Ceza yayı üstü',
      brief: 'Yayın hemen üstünde boşluk buldun. Önünde kimse yok, '
          'uzaklık var.',
      aimHint: _aimShot,
      scene: _shotScene(origin: (x: 0, y: 0.16)),
    ),
    ShotScenario(
      id: 'shot_edge_left',
      kind: ShotScenarioKind.shot,
      title: 'Sol yarı alandan',
      brief: 'Sol yarı alanda topla döndün. Klasik: uzak köşeye kavisli şut.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: -0.68, y: 0.22),
        rivals: [_foe('Yakın direği kapatan', -0.67, 0.81)],
      ),
    ),
    ShotScenario(
      id: 'shot_edge_right',
      kind: ShotScenarioKind.shot,
      title: 'Sağ yarı alandan',
      brief: 'Sağ yarı alan. Kaleci yakın direği kapatır, uzak köşe senindir.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: 0.70, y: 0.22),
        rivals: [_foe('Yakın direği kapatan', 0.68, 0.81)],
      ),
    ),
    ShotScenario(
      id: 'shot_tight_left',
      kind: ShotScenarioKind.shot,
      title: 'Dar açı, sol',
      brief: 'Dip çizgiye yakınsın, açı neredeyse kapalı. Yakın direk ya da '
          'geri çevir.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: -0.95, y: 0.70),
        receivers: [_key('Penaltı noktasındaki', 0.02, 0.48)],
        objective: ShotObjective.finishOrLayoff,
      ),
    ),
    ShotScenario(
      id: 'shot_tight_right',
      kind: ShotScenarioKind.shot,
      title: 'Dar açı, sağ',
      brief: 'Sağ dipten. Kaleci yakın direğine yapıştı; içeride bekleyen var.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: 0.98, y: 0.68),
        receivers: [_key('Ortada bekleyen', -0.05, 0.50)],
        objective: ShotObjective.finishOrLayoff,
      ),
    ),
    ShotScenario(
      id: 'shot_one_on_one',
      kind: ShotScenarioKind.shot,
      title: 'Kaleciyle karşı karşıya',
      brief: 'Savunmayı geçtin, kaleci üstüne geliyor. Yerden köşe mi, aşırtma '
          'mı?',
      aimHint: _aimShot,
      scene: _shotScene(origin: (x: -0.08, y: 0.55)),
    ),
    ShotScenario(
      id: 'shot_long_range',
      kind: ShotScenarioKind.shot,
      title: 'Uzaktan şut',
      brief: 'Yirmi beş metre. Kimse üstüne gelmiyor, çünkü buradan atacağını '
          'sanmıyorlar.',
      aimHint: _aimShot,
      scene: _shotScene(origin: (x: 0.24, y: -0.06)),
    ),
    ShotScenario(
      id: 'shot_through_traffic',
      kind: ShotScenarioKind.shot,
      title: 'Kalabalığın arasından',
      brief: 'Önünde iki gövde var. Ya aralarından bulacaksın ya üstlerinden.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: -0.10, y: 0.02),
        rivals: [
          _foe('Blok yapan', -0.24, 0.32),
          _foe('Blok yapan', 0.16, 0.34),
        ],
      ),
    ),
    ShotScenario(
      id: 'shot_cutback_first_time',
      kind: ShotScenarioKind.shot,
      title: 'Geri çevirmeden ilk vuruş',
      brief: 'Top dipten geri geldi, üstüne koştun. Vakit yok; sadece isabet.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: 0.22, y: 0.36),
        rivals: [_foe('Geri dönen stoper', 0.10, 0.62)],
      ),
    ),
    ShotScenario(
      id: 'shot_volley_far_post',
      kind: ShotScenarioKind.shot,
      title: 'Uzak direkte vole',
      brief: 'Orta uzak direğe düştü. Yükseklik sende; topu yere indirmen '
          'gerek.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: 0.80, y: 0.56),
        rivals: [_foe('Uzak direkteki stoper', 0.66, 0.88)],
      ),
    ),
    ShotScenario(
      id: 'shot_free_kick_left',
      kind: ShotScenarioKind.shot,
      title: 'Serbest vuruş, soldan',
      brief: 'Baraj kurulu, ceza yayının solundasın. Barajın kenarından çevir.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: -0.45, y: 0.02),
        rivals: [
          _foe('Baraj', -0.30, 0.28),
          _foe('Baraj', -0.16, 0.30),
        ],
      ),
    ),
    ShotScenario(
      id: 'shot_free_kick_central',
      kind: ShotScenarioKind.shot,
      title: 'Serbest vuruş, tam karşı',
      brief: 'Barajın tam karşısı. Üstünden aşırtacaksın, altından değil.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: 0.08, y: -0.06),
        rivals: [
          _foe('Baraj', 0.10, 0.26),
          _foe('Baraj', 0.24, 0.26),
        ],
      ),
    ),
  ];

  // -------------------------------------------------------------------------
  // Geriden oyun kurulumu: kendi yarı sahandan çıkan ilk top.
  // -------------------------------------------------------------------------

  static final List<ShotScenario> buildUp = [
    ShotScenario(
      id: 'build_keeper_short',
      kind: ShotScenarioKind.buildUp,
      title: 'Kaleden kısa çıkış',
      brief: 'Ceza sahasının içindesin, rakip forvet üstüne geliyor. '
          'Yan stoper güvenli; ön libero hattı kırar.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.42, y: -3.30),
        receivers: [
          _mate('Yan stoper', 0.62, -3.26),
          _key('Ön libero', -0.02, -2.48),
        ],
        rivals: [_foe('Baskı yapan forvet', -0.05, -2.92)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'build_centre_back_split',
      kind: ShotScenarioKind.buildUp,
      title: 'Stoperden ilk pas',
      brief: 'Topu stoperde aldın. Bek yanında bekliyor; orta saha aralığa '
          'sarktı.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.30, y: -3.00),
        receivers: [
          _mate('Sağ bek', 1.18, -2.84),
          _key('Ön orta saha', 0.14, -2.10),
        ],
        rivals: [_foe('Kanattan kapatan', 0.84, -2.58)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'build_press_escape',
      kind: ShotScenarioKind.buildUp,
      title: 'Baskıdan çıkış',
      brief: 'İki rakip birden üstüne geldi. Geriye emniyet var, ileride tek '
          'pas.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.10, y: -2.80),
        receivers: [
          // Emniyet seçeneği fazla geride durunca kamera onunla ileri pasın
          // ortasına, yani neredeyse yana bakıyordu; ikinci baskıcı da o
          // yüzden kadrajın dışında kalıyordu.
          _mate('Geri çıkan stoper', -0.85, -2.55),
          _key('Hattı geçen sekizli', 0.10, -1.92),
        ],
        rivals: [
          _foe('Baskı 1', -0.32, -2.42),
          _foe('Baskı 2', 0.30, -2.26),
        ],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'build_full_back_line',
      kind: ShotScenarioKind.buildUp,
      title: 'Bekten hat boyu',
      brief: 'Sol bektesin, taç çizgisi arkanda. Stoper açık, kanat ileride.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -1.32, y: -2.60),
        receivers: [
          _mate('Stoper', -0.50, -2.76),
          _key('Sol kanat', -1.30, -1.64),
        ],
        rivals: [_foe('Sağ bek', -1.12, -2.16)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'build_pivot_turn',
      kind: ShotScenarioKind.buildUp,
      title: 'Altılıda dönüş',
      brief: 'Ortada topu aldın ve döndün. Arkanda kimse yok, önünde iki '
          'seçenek.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.05, y: -2.30),
        receivers: [
          _mate('Yan açılan sekizli', 0.85, -1.95),
          _key('Ayağa gelen forvet', -0.05, -1.42),
        ],
        rivals: [_foe('Rakip sekizli', 0.32, -1.76)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'build_goal_kick_switch',
      kind: ShotScenarioKind.buildUp,
      title: 'Kale vuruşunda yön değiştir',
      brief: 'Rakip bir tarafa yüklendi. Boş taraf uzakta, ama boş.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.55, y: -3.15),
        receivers: [
          _mate('Yakın stoper', -0.18, -3.22),
          _key('Boş taraftaki bek', -0.40, -2.42),
        ],
        // Tek baskıcı, ilerletici hattın üstünde. İki kişiydi ve biri
        // kadrajın dışında kalıyordu: iki seçenek de sola gidiyor, dolayısıyla
        // topun sağında duran hiç kimse görünmüyor. Tarifin söylediği de bu —
        // rakip bir tarafa yüklendi, boş taraf boş.
        rivals: [_foe('Baskı', 0.29, -2.50)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'build_third_man',
      kind: ShotScenarioKind.buildUp,
      title: 'Üçüncü adam',
      brief: 'Duvar pası oynandı, top sana döndü. Şimdi asıl koşuyu '
          'bulacaksın.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.55, y: -2.45),
        receivers: [
          _mate('Duvar yapan', -0.25, -2.60),
          _key('Boşluğa koşan sekizli', 0.15, -1.64),
        ],
        rivals: [_foe('Rakip altılı', 0.0, -2.40)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'build_safe_reset',
      kind: ShotScenarioKind.buildUp,
      title: 'Oyunu yeniden kur',
      brief: 'İleri yol kapalı. Bu topun tek işi kaybolmamak — güvenli olanı '
          'bul.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.75, y: -2.55),
        receivers: [_mate('Geri açılan stoper', 0.05, -3.05)],
        // Baskıcılar önce ileride duruyordu; geriye dönen kamerada ikisi de
        // ekranın arkasında kalıyor, yani "yol kapalı" diyen bir sahnede
        // kapatan kimse görünmüyordu. Şimdi geri pasın iki yanından
        // kovalıyorlar: yavaş bir top hâlâ kesilebilir.
        rivals: [
          _foe('Baskı', 0.21, -2.57),
          _foe('Kapatan kanat', 0.45, -2.40),
        ],
        objective: ShotObjective.passOnly,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'build_line_break',
      kind: ShotScenarioKind.buildUp,
      title: 'Hattın arasından',
      brief: 'İki rakip arasında bir koridor açıldı. Ya oradan geçer ya '
          'kesilir.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.05, y: -2.62),
        receivers: [
          _mate('Yan destek', -0.92, -2.50),
          _key('Aralıktaki on numara', 0.05, -1.70),
        ],
        rivals: [
          _foe('Rakip sekizli', -0.36, -2.20),
          _foe('Rakip sekizli', 0.22, -1.90),
        ],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
  ];

  // -------------------------------------------------------------------------
  // Geçiş başlatma: topu kazandığın andaki ilk karar.
  // -------------------------------------------------------------------------

  static final List<ShotScenario> transitions = [
    ShotScenario(
      id: 'trans_win_and_go',
      kind: ShotScenarioKind.transition,
      title: 'Topu kaptın',
      brief: 'Orta sahada topu kestin, rakip düzensiz. Yan emniyet, ileri '
          'kumar.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.20, y: -1.60),
        receivers: [
          _mate('Yanındaki sekizli', -1.00, -1.42),
          _key('Öne kopan forvet', 0.10, -0.74),
        ],
        rivals: [_foe('Geri dönen orta saha', -0.34, -1.09)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'trans_counter_centre',
      kind: ShotScenarioKind.transition,
      title: 'Kontra başlıyor',
      brief: 'Önünde saha var, yanında iki koşu. Uzak olan daha tehlikeli.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.05, y: -1.35),
        receivers: [
          _mate('Yanındaki kanat', -0.95, -0.95),
          _key('Ortadan kopan', 0.20, -0.36),
        ],
        rivals: [_foe('Son adam', 0.02, -0.74)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'trans_switch_wide',
      kind: ShotScenarioKind.transition,
      title: 'Uzun yön değiştirme',
      brief: 'Bütün rakip bir tarafta. Karşı kanat yapayalnız duruyor.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.62, y: -1.15),
        receivers: [
          _mate('Ortadaki sekizli', -0.12, -1.05),
          _key('Karşı kanat', 0.52, -0.80),
        ],
        rivals: [
          _foe('Baskı', -0.24, -0.82),
          _foe('Kapatan', 0.02, -0.68),
        ],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'trans_release_winger',
      kind: ShotScenarioKind.transition,
      title: 'Kanadı serbest bırak',
      brief: 'Kanat bekin arkasına koşuyor. Ayağına mı, koştuğu boşluğa mı?',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.15, y: -1.00),
        receivers: [
          _mate('Ayağa gelen kanat', 1.05, -0.86),
          _key('Bek arkasındaki boşluk', 1.06, -0.26),
        ],
        rivals: [_foe('Sol bek', 0.98, -0.52)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'trans_second_ball',
      kind: ShotScenarioKind.transition,
      title: 'İkinci top',
      brief: 'Hava topu düştü, önce sen ulaştın. İki rakip hâlâ dönüyor.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.35, y: -1.45),
        receivers: [
          _mate('Destek veren', -1.05, -1.30),
          _key('Aralığa sarkan on numara', 0.05, -0.72),
        ],
        rivals: [
          _foe('Dönen orta saha', -0.44, -1.06),
          _foe('Dönen orta saha', -0.34, -0.78),
        ],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'trans_keep_it',
      kind: ShotScenarioKind.transition,
      title: 'Topu koru',
      brief: 'İleri yol kapalı, kontra tutmuyor. Bu top sadece bizde kalmalı.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.60, y: -1.30),
        receivers: [_mate('Geri destek', -0.05, -1.85)],
        rivals: [
          _foe('Baskı', 0.11, -1.37),
          // Az önce sırtını döndüğün adam: ileride duruyor, o yüzden görünüyor
          // ve geri pasa yetişemiyor.
          _foe('Kapatan', 0.40, -0.95),
        ],
        objective: ShotObjective.passOnly,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'trans_break_the_press',
      kind: ShotScenarioKind.transition,
      title: 'Baskıyı ters çevir',
      brief: 'Rakip öne çıktı ve arkası boş kaldı. Bir pas seni oraya götürür.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.05, y: -1.75),
        receivers: [
          _mate('Yan çıkan bek', 1.02, -1.60),
          _key('Arkalarındaki forvet', -0.10, -0.88),
        ],
        rivals: [
          _foe('Öne çıkan altılı', -0.12, -1.11),
          _foe('Öne çıkan sekizli', 0.32, -1.30),
        ],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'trans_carry_then_slide',
      kind: ShotScenarioKind.transition,
      title: 'Sürükle ve bırak',
      brief: 'Topu taşıdın, savunma sana kaydı. Şimdi bıraktığın yer belli '
          'olmalı.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.30, y: -0.85),
        // İki seçenek 126 derecelik bir yelpazeyle ayrılıyordu: kamera hangi
        // yöne dönerse dönsün ikisi de kadrajın kenarında kalıyor, nişan da
        // ikisine de uzakta başlıyordu. Yelpaze daraltıldı.
        receivers: [
          _mate('Geriden gelen', -0.85, -0.40),
          _key('Boşalan sağ kanat', 0.55, -0.30),
        ],
        rivals: [_foe('Kayan stoper', 0.01, -0.27)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
    ShotScenario(
      id: 'trans_outlet_from_corner',
      kind: ShotScenarioKind.transition,
      title: 'Korner sonrası çıkış',
      brief: 'Kornerden top döndü, herkes ileride. Uzun bir çıkışın var.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.90, y: -1.55),
        receivers: [
          _mate('Yan destek', 0.15, -1.42),
          _key('Tek başına kalan forvet', 0.35, -0.56),
        ],
        rivals: [_foe('Geri dönen bek', 0.64, -1.14)],
        objective: ShotObjective.pass,
        backY: _deepBack,
      ),
    ),
  ];

  // -------------------------------------------------------------------------
  // Son bölge: son otuz metre, son pas.
  // -------------------------------------------------------------------------

  static final List<ShotScenario> finalThird = [
    ShotScenario(
      id: 'final_through_ball',
      kind: ShotScenarioKind.finalThird,
      title: 'Arkaya sarkan top',
      brief: 'Forvet savunmanın arkasına koştu. Ayağına mı, arkasına mı?',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.05, y: -0.10),
        receivers: [
          _mate('Ayağa gelen on numara', -0.75, -0.05),
          _key('Arkaya koşan forvet', 0.15, 0.62),
        ],
        rivals: [_foe('Son stoper', -0.15, 0.34)],
        objective: ShotObjective.pass,
      ),
    ),
    ShotScenario(
      id: 'final_cutback',
      kind: ShotScenarioKind.finalThird,
      title: 'Dipten geri çevirme',
      brief: 'Dip çizgiye indin. Penaltı noktasına gelen var, uzak direkte de.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -1.00, y: 0.80),
        receivers: [
          _mate('Uzak direkteki', 0.25, 0.82),
          _key('Penaltı noktasına gelen', -0.02, 0.45),
        ],
        rivals: [_foe('Geri dönen stoper', -0.44, 0.72)],
        objective: ShotObjective.pass,
      ),
    ),
    ShotScenario(
      id: 'final_cross_far_post',
      kind: ShotScenarioKind.finalThird,
      title: 'Uzak direğe orta',
      brief: 'Sağ kanattan orta. Yakın direk kalabalık, uzak direk boş.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 1.05, y: 0.50),
        receivers: [
          _mate('Yakın direkteki', 0.45, 0.72),
          _key('Uzak direğe sarkan', -0.10, 0.84),
        ],
        rivals: [_foe('Ortadaki stoper', 0.18, 0.90)],
        objective: ShotObjective.pass,
      ),
    ),
    ShotScenario(
      id: 'final_half_space_slip',
      kind: ShotScenarioKind.finalThird,
      title: 'Yarı alandan aralık pası',
      brief: 'Bek ile stoper arası açıldı. Küçük bir top, büyük bir fark.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.55, y: 0.05),
        receivers: [
          _mate('Geri destek', -0.15, -0.05),
          _key('Aralığa dalan kanat', 0.95, 0.62),
        ],
        rivals: [_foe('Bek', 0.68, 0.66)],
        objective: ShotObjective.pass,
      ),
    ),
    ShotScenario(
      id: 'final_layoff_and_shoot',
      kind: ShotScenarioKind.finalThird,
      title: 'Bitir ya da bitirt',
      brief: 'Kale açık gibi, ama yanında daha iyi durumda biri var. Karar '
          'senin.',
      aimHint: _aimShot,
      scene: _shotScene(
        origin: (x: 0.42, y: 0.30),
        receivers: [_key('Boştaki arkadaş', -0.46, 0.54)],
        rivals: [_foe('Blok yapan', 0.30, 0.58)],
        objective: ShotObjective.assistOrFinish,
      ),
    ),
    ShotScenario(
      id: 'final_wall_pass',
      kind: ShotScenarioKind.finalThird,
      title: 'Ceza sahası önünde duvar',
      brief: 'İki savunmacı arasında duvar oynanacak. Kısa ve sert olmalı.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: -0.25, y: -0.25),
        receivers: [
          _mate('Yan açılan', -0.95, -0.15),
          _key('Sırtı dönük forvet', -0.05, 0.36),
        ],
        rivals: [
          _foe('Altılı', -0.32, 0.08),
          _foe('Stoper', 0.20, 0.42),
        ],
        objective: ShotObjective.pass,
      ),
    ),
    ShotScenario(
      id: 'final_byline_square',
      kind: ShotScenarioKind.finalThird,
      title: 'Dipten yatay',
      brief: 'Kaleci yakın direğe çıktı, altı pas boş. Yatay bir top yeter.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.95, y: 0.85),
        receivers: [_mate('Altı pasta bekleyen', -0.18, 0.86)],
        rivals: [_foe('Geri dönen stoper', 0.42, 0.90)],
        objective: ShotObjective.passOnly,
      ),
    ),
    ShotScenario(
      id: 'final_pull_back_edge',
      kind: ShotScenarioKind.finalThird,
      title: 'İçeri kat, ortadakine bırak',
      brief: 'Sağ yarı alandan içeri kestin. Dışarıdan bindiren var, ortaya '
          'sarkan var.',
      aimHint: _aimPass,
      scene: _scene(
        origin: (x: 0.62, y: 0.24),
        receivers: [
          _mate('Dışarıdan bindiren', 1.15, 0.45),
          _key('Ortaya sarkan', -0.15, 0.70),
        ],
        rivals: [_foe('Geri dönen orta saha', 0.40, 0.75)],
        objective: ShotObjective.pass,
      ),
    ),
  ];

  /// Katalogun tamamı, aile sırasıyla.
  static final List<ShotScenario> all = [
    ...shots,
    ...buildUp,
    ...transitions,
    ...finalThird,
  ];

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
