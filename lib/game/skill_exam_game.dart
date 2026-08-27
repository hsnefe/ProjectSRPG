import 'package:project_srpg/game/shot_game.dart';

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
  );

  const SkillExamGame({
    required this.examId,
    required this.title,
    required this.mode,
    required this.scene,
    required this.brief,
    required this.aimHint,
    required this.unit,
  });

  /// `catalog/skill_exams.py` içindeki `exam_id`.
  final String examId;

  final String title;
  final ShotMode mode;
  final ShotScene scene;

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
