import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/training_result.dart';

/// Hangi yetenek sınavının oynanabilir bir mini oyunu var.
///
/// Katalogdaki sınav (`exam_id`) ile oyun tarafındaki sahne arasındaki tek
/// bağ burası. Bir sınavın oyunu yoksa [forExamId] `null` döner ve sihirbaz
/// o kartı elle notlatmaya devam eder — yani yeni bir mini oyun eklemek, bu
/// enum'a bir satır yazmak demek.
enum SkillExamGame {
  /// Penaltı noktasından boş kaleye üç şut.
  shooting(
    examId: 'shooting',
    title: 'Şut Sınavı',
    mode: ShotMode.shot,
    scene: ShotScene.shotExam,
    brief: 'Penaltı noktasından boş kaleye üç şut. Her gol notunu yükseltir.',
    aimHint: '1) Sürükle: kalede bir nokta seç, bırak',
    unit: 'gol',
  ),

  /// Yerinde duran tek bir takım arkadaşına üç pas.
  passing(
    examId: 'passing',
    title: 'Pas Sınavı',
    mode: ShotMode.pass,
    scene: ShotScene.passExam,
    brief: 'Yerinde duran takım arkadaşına üç pas. Tutan her pas notunu '
        'yükseltir.',
    aimHint: '1) Sürükle: arkadaşını hedefle, bırak',
    unit: 'isabetli pas',
  ),

  /// Dribling koridoru: antrenmandaki aynı koşu, skoru nota çevrilir.
  dribbling(
    examId: 'dribbling',
    title: 'Dribling Sınavı',
    brief:
        'Koridorda konilere çarpmadan bitişe var. Temiz ve hızlı koşu '
        'notunu yükseltir.',
    unit: 'skor',
    drill: TrainingDrill.dribble,
  ),

  /// Tek denemelik müdahale: antrenmandaki aynı baskı, kademesi nota çevrilir.
  tackling(
    examId: 'tackling',
    title: 'Müdahale Sınavı',
    brief:
        'Rakibe yetiş, açılan pencerede müdahale et. Zamanlaman notunu '
        'belirler.',
    unit: 'skor',
    drill: TrainingDrill.tackling,
  );

  const SkillExamGame({
    required this.examId,
    required this.title,
    this.mode,
    this.scene,
    required this.brief,
    this.aimHint = '',
    required this.unit,
    this.drill,
  });

  /// `catalog/skill_exams.py` içindeki `exam_id`.
  final String examId;

  final String title;

  /// Şut/pas sınavlarının (ShotGame) kipi ve sahnesi; diğer sınavlarda null.
  final ShotMode? mode;
  final ShotScene? scene;

  /// Şut/pas dışındaki sınavlar antrenman ekranını çalıştırır; hangisi
  /// olduğunu bu söyler. Null ise sınav [SkillExamScreen]'de oynanır.
  final TrainingDrill? drill;

  /// Antrenman ekranlarının verdiği 0..1 skoru katalogdaki 1–5 notuna çevirir.
  static int gradeOfResult(TrainingResult result) =>
      (1 + (result.score * 4).round()).clamp(1, 5);

  /// Sınav başlamadan önce ekranda duran tek satırlık açıklama.
  final String brief;

  /// Nişan fazının ipucu — hedef sınavdan sınava değiştiği için burada.
  final String aimHint;

  /// Sonuç dökümünde sayılan şeyin adı ('2/3 gol').
  final String unit;

  /// Bu sınavın oyunu varsa onu, yoksa null döndürür.
  static SkillExamGame? forExamId(String examId) {
    for (final exam in values) {
      if (exam.examId == examId) return exam;
    }
    return null;
  }
}
