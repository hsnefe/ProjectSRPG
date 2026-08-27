import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/skill_exam_game.dart';

const _size = Size(360, 600);

ShotGame _game(ShotMode mode, ShotScene scene) => ShotGame(
      mode: mode,
      scene: scene,
      onStateChanged: () {},
    );

/// Takes one attempt at an absolute world point and resolves it.
///
/// Same shape as the helper in shot_mode_test, with the scene's origin fed to
/// the projector — an exam that stands somewhere other than the world origin
/// would otherwise be aimed from the wrong place.
void _attempt(
  ShotGame game,
  double wx,
  double wy, {
  double spin = 0,
  double loft = 0,
  double power = 1.0,
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
    ..power = power
    ..spin = spin
    ..loft = loft
    ..launch();
  game.finishFlight();
}

void main() {
  group('şut sınavı sahnesi', () {
    test('kaleci yok: kalenin ortasına düz şut girer', () {
      final exam = _game(ShotMode.shot, ShotScene.shotExam);
      _attempt(exam, 0, PitchLines.goalLineY);
      expect(exam.result, 'GOL!');
    });

    test('aynı şut kalecili sahada kurtarılır', () {
      // Aynı topu tam sahaya atınca kaleci ortada duruyor ve kesiyor: yukarıdaki
      // golü sağlayan şey sahnenin boş kalesi, atışın kendisi değil.
      final drill = _game(ShotMode.shot, ShotScene.full);
      _attempt(drill, 0, PitchLines.goalLineY);
      expect(drill.result, 'KURTARIŞ');
    });

    test('sahada kimse yok', () {
      expect(ShotScene.shotExam.bodies, isEmpty);
      expect(ShotScene.shotExam.hasKeeper, isFalse);
    });

    test('oyuncu penaltı noktasında durur, kale bir penaltı ötededir', () {
      final exam = _game(ShotMode.shot, ShotScene.shotExam);
      expect(exam.scene.origin.y, PitchLines.penaltySpotY);

      final p = PitchProjector(size: _size, origin: exam.scene.origin);
      // Penaltı noktası ayağın altında, kale çizgisi tam bir penaltı mesafesi.
      expect(p.depthOf(0, PitchLines.penaltySpotY), closeTo(0, 1e-9));
      expect(
        p.depthOf(0, PitchLines.goalLineY),
        closeTo(PitchLines.penaltySpotDepth, 1e-9),
      );
    });

    test('nişan mesafesi kalenin biraz ötesinde biter', () {
      // Ceza sahasından atılan bir şutta nişanın orta sahaya uzanması, kaleyi
      // hedeflemeyi zorlaştırmaktan başka bir işe yaramaz.
      expect(ShotScene.shotExam.defaultAimDepth, PitchLines.penaltySpotDepth);
      expect(
        ShotScene.shotExam.maxAimDepth,
        greaterThan(PitchLines.penaltySpotDepth),
      );
      expect(ShotScene.shotExam.maxAimDepth, lessThan(ShotWorld.maxAimDepth));
    });
  });

  group('pas sınavı sahnesi', () {
    test('tek bir takım arkadaşı vardır, rakip yoktur', () {
      expect(ShotScene.passExam.receivers, [ShotTarget.leftWing]);
      expect(ShotScene.passExam.rivals, isEmpty);
    });

    test('yerdeki düz pas tutar — kesecek rakip yok', () {
      final exam = _game(ShotMode.pass, ShotScene.passExam);
      _attempt(exam, ShotTarget.leftWing.x, ShotTarget.leftWing.y);
      expect(exam.result, 'PAS TUTTU');
    });

    test('antrenman sahasında aynı pasın önünde rakipler durur', () {
      // Kesilip kesilmediği atışın kendisine bağlı, ama sahnede kesecek birinin
      // *olması* sınavla antrenmanın arasındaki farkın ta kendisi.
      final drill = _game(ShotMode.pass, ShotScene.passDrill);
      expect(drill.scene.rivals, isNotEmpty);
      expect(drill.scene.bodies.length, greaterThan(1));

      final exam = _game(ShotMode.pass, ShotScene.passExam);
      expect(exam.scene.bodies, [ShotTarget.leftWing]);
    });

    test('arkadaşın yanına düşen top pası kaçırır', () {
      final exam = _game(ShotMode.pass, ShotScene.passExam);
      _attempt(
        exam,
        ShotTarget.leftWing.x + ShotWorld.passCatchRadius * 1.6,
        ShotTarget.leftWing.y,
      );
      expect(exam.result, 'PAS KAÇTI');
    });

    test('kale çizgisini geçen top gol sayılmaz', () {
      // Kale hâlâ sahada duruyor; pas sınavında golün bir hükmü olmaması
      // scoresGoals'un işi.
      expect(ShotScene.passExam.scoresGoals, isFalse);

      final exam = _game(ShotMode.pass, ShotScene.passExam)
        ..cameraAngle = 0
        ..desiredAngle = 0;
      _attempt(exam, 0.30, PitchLines.goalLineY);
      expect(exam.result, isNot('GOL!'));
    });
  });

  group('sınav notu', () {
    test('isabet sayısı beşli skalaya oturur', () {
      expect(ShotGame.gradeByMade, [1, 2, 4, 5]);
      expect(ShotGame.gradeByMade.length, ShotGame.attemptsPerSession + 1);
    });

    test('üç golün notu tavandır', () {
      final exam = _game(ShotMode.shot, ShotScene.shotExam);
      for (var i = 0; i < ShotGame.attemptsPerSession; i++) {
        _attempt(exam, 0, PitchLines.goalLineY);
      }
      expect(exam.made, 3);
      expect(exam.examGrade, 5);
    });

    test('tek gol iki denemeyi kaçırınca not ikidir', () {
      final exam = _game(ShotMode.shot, ShotScene.shotExam);
      _attempt(exam, 0, PitchLines.goalLineY);
      _attempt(exam, ShotWorld.goalHalfWidth + 0.5, PitchLines.goalLineY);
      _attempt(exam, ShotWorld.goalHalfWidth + 0.5, PitchLines.goalLineY);
      expect(exam.made, 1);
      expect(exam.examGrade, 2);
    });

    test('hiç isabet yoksa not tabandır', () {
      final exam = _game(ShotMode.shot, ShotScene.shotExam);
      for (var i = 0; i < ShotGame.attemptsPerSession; i++) {
        _attempt(exam, ShotWorld.goalHalfWidth + 0.5, PitchLines.goalLineY);
      }
      expect(exam.made, 0);
      expect(exam.examGrade, 1);
    });

    test('restartSession notu sıfırdan başlatır', () {
      final exam = _game(ShotMode.shot, ShotScene.shotExam);
      for (var i = 0; i < ShotGame.attemptsPerSession; i++) {
        _attempt(exam, 0, PitchLines.goalLineY);
      }
      exam.restartSession();
      expect(exam.attempts, 0);
      expect(exam.examGrade, 1);
    });
  });

  group('sınav kataloğu', () {
    test('şut ve pas oynanır, diğerleri elle notlanır', () {
      expect(SkillExamGame.forExamId('shooting')?.scene, ShotScene.shotExam);
      expect(SkillExamGame.forExamId('passing')?.scene, ShotScene.passExam);
      expect(SkillExamGame.forExamId('dribbling'), isNull);
      expect(SkillExamGame.forExamId('tackling'), isNull);
    });

    test('her oyunun modu sahnesiyle uyumlu', () {
      expect(SkillExamGame.shooting.mode, ShotMode.shot);
      expect(SkillExamGame.passing.mode, ShotMode.pass);
    });
  });

  group('varsayılan sahneler', () {
    test('mod tek başına verildiğinde dünya eskisi gibi kurulur', () {
      final free = ShotGame(onStateChanged: () {});
      expect(free.scene, ShotScene.full);
      expect(free.facing, Facing.forward);

      final pass = ShotGame(mode: ShotMode.pass, onStateChanged: () {});
      expect(pass.scene, ShotScene.passDrill);
      expect(pass.facing, Facing.left);
      expect(pass.scene.rivals, ShotTarget.rivals);
      expect(pass.scene.hasKeeper, isTrue);
    });
  });
}
