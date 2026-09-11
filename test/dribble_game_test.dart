import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/dribble_game.dart';
import 'package:project_srpg/game/training_result.dart';

/// Kural katmanı `size` okumadığı için oyun widget'sız kurulabiliyor: aşağıda
/// hiçbir test `pumpWidget` çağırmıyor, hepsi [DribbleGame.swipe] ve
/// [DribbleGame.advance]'ı doğrudan sürüyor (`shot_aim_test.dart` ile aynı
/// politika).
DribbleGame _game() => DribbleGame(onStateChanged: () {}, onFinished: (_) {});

const _up = Offset(0, 1);
const _down = Offset(0, -1);
const _right = Offset(1, 0);

void main() {
  group('kaydırma fiziği', () {
    test('ilk kaydırma topu fırlatır ve yönü belirler', () {
      final game = _game();
      expect(game.phase, DribblePhase.ready);
      expect(game.speed, 0);

      game.swipe(_up);

      expect(game.phase, DribblePhase.running);
      expect(game.speed, DribbleGame.launchSpeed);
      expect(game.heading.dy, closeTo(1, 1e-9));
    });

    test('aynı yöne devam etmek hızı üst üste artırır', () {
      final game = _game()..swipe(_up);
      final afterLaunch = game.speed;

      game.swipe(_up);
      final afterOne = game.speed;
      game.swipe(_up);
      final afterTwo = game.speed;

      expect(afterOne, greaterThan(afterLaunch));
      expect(afterTwo, greaterThan(afterOne));
      // Birikim gerçekten birikim: her kaydırma sabit bir miktar ekliyor.
      expect(afterOne - afterLaunch, closeTo(DribbleGame.swipeAccel, 1e-9));
    });

    test('hız tavanı aşılamaz', () {
      final game = _game()..swipe(_up);
      for (var i = 0; i < 40; i++) {
        game.swipe(_up);
      }
      expect(game.speed, DribbleGame.maxSpeed);
    });

    test('tam ters yöne kaydırmak frenler, yönü çevirmez', () {
      final game = _game()..swipe(_up);
      game.swipe(_up);
      final before = game.speed;
      final headingBefore = game.heading;

      game.swipe(_down);

      expect(game.speed, closeTo(before * DribbleGame.brakeFactor, 1e-9));
      expect(game.speed, lessThan(before));
      // Fren geri gitmek değil: top hâlâ ileri bakıyor.
      expect(game.heading.dy, closeTo(headingBefore.dy, 1e-9));
      expect(game.heading.dx, closeTo(headingBefore.dx, 1e-9));
    });

    test('farklı bir yöne kaydırmak topu o yöne çevirir', () {
      final game = _game()..swipe(_up);
      game.swipe(_up);
      final before = game.speed;

      game.swipe(_right);

      expect(game.heading.dx, closeTo(1, 1e-9));
      expect(game.heading.dy, closeTo(0, 1e-9));
      // Hızın bir kısmı korunur — keskin dönüş bedelli ama sıfırlamıyor.
      expect(game.speed, closeTo(before * DribbleGame.turnRetention, 1e-9));
      expect(game.speed, greaterThan(0));
    });

    test('hızlanırken yön kaydırmaya doğru kayar', () {
      final game = _game()..swipe(_up);
      // 45°: eşiğin (0.5) üstünde bir hizalanma, yani hızlandıran dal.
      final diagonal = const Offset(1, 1);
      game.swipe(diagonal);

      expect(game.speed, greaterThan(DribbleGame.launchSpeed));
      // Yön tamamen çapraza gitmedi ama yukarıdan da ayrıldı.
      expect(game.heading.dx, greaterThan(0));
      expect(game.heading.dy, greaterThan(game.heading.dx));
    });

    test('kaydırmanın büyüklüğü değil yalnızca yönü okunur', () {
      final small = _game()..swipe(_up);
      final large = _game()..swipe(const Offset(0, 900));
      expect(small.speed, large.speed);
      expect(small.heading, large.heading);
    });

    test('sıfır uzunluklu kaydırma yok sayılır', () {
      final game = _game()..swipe(_up);
      final before = game.speed;
      game.swipe(Offset.zero);
      expect(game.speed, before);
      expect(game.phase, DribblePhase.running);
    });
  });

  group('koşu', () {
    test('sürtünme kaydırma kesilince topu durdurur', () {
      final game = _game()..swipe(_up);
      for (var i = 0; i < 200; i++) {
        game.advance(1 / 60);
      }
      expect(game.speed, 0);
    });

    test('ileri kaydırmak mesafe kazandırır', () {
      final game = _game()..swipe(_up);
      game.advance(0.5);
      expect(game.distance, greaterThan(0));
    });

    test('mesafe eksiye düşmez', () {
      final game = _game()..swipe(_down);
      for (var i = 0; i < 30; i++) {
        game.advance(1 / 60);
      }
      expect(game.distance, greaterThanOrEqualTo(0));
    });

    test('duvara çarpmak temas sayar, frenler ve topu içeri çevirir', () {
      final game = _game()..swipe(_right);
      // Sağ duvara ulaşana kadar sür.
      for (var i = 0; i < 120 && game.hits == 0; i++) {
        game.swipe(_right);
        game.advance(1 / 60);
      }

      expect(game.hits, 1);
      expect(game.ballX, lessThanOrEqualTo(0.5 + DribbleGame.corridorHalfWidth));
      // İçeri, yani sola çevrildi.
      expect(game.heading.dx, lessThan(0));
    });

    test('süre dolunca antrenman başarısız biter', () {
      TrainingResult? reported;
      final game = DribbleGame(
        onStateChanged: () {},
        onFinished: (r) => reported = r,
      )..swipe(_up);

      for (var i = 0; i < 60 * 25 && !game.finished; i++) {
        game.advance(1 / 60);
      }

      expect(game.finished, isTrue);
      expect(game.succeeded, isFalse);
      expect(reported, isNotNull);
      expect(reported!.drill, TrainingDrill.dribble);
      expect(reported!.outcome, TrainingOutcome.failure);
      expect(reported!.detail, 'Süre doldu');
    });

    test('bitişe varmak başarıdır ve sonucu bir kez raporlar', () {
      var calls = 0;
      final game = DribbleGame(
        onStateChanged: () {},
        onFinished: (_) => calls++,
      )..swipe(_up);

      // Konilerin arasından değil, yalnızca hızlanarak: bu test bitişi
      // ölçüyor, kurs ustalığını değil — koniye çarpsa bile üç hak var.
      for (var i = 0; i < 60 * 20 && !game.finished; i++) {
        game.swipe(_up);
        game.advance(1 / 60);
      }

      expect(game.finished, isTrue);
      expect(game.distance, greaterThanOrEqualTo(DribbleGame.courseLength));
      expect(calls, 1);
    });

    test('oyun bittikten sonra kaydırma bir şeyi değiştirmez', () {
      final game = _game()..swipe(_up);
      for (var i = 0; i < 60 * 25 && !game.finished; i++) {
        game.advance(1 / 60);
      }
      final distance = game.distance;

      game.swipe(_up);

      expect(game.speed, 0);
      expect(game.distance, distance);
    });
  });
}
