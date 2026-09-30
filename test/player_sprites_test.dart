import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/player_sprites.dart';
import 'package:project_srpg/game/shot_game.dart';

void main() {
  group('viewRow', () {
    test('kamerayla aynı yöne bakan oyuncu sırtını gösterir', () {
      expect(PlayerSprites.viewRow(0, 0), 0);
      expect(PlayerSprites.viewRow(1.2, 1.2), 0);
    });

    test('kameraya dönük oyuncu ön yüzünü gösterir', () {
      expect(PlayerSprites.viewRow(math.pi, 0), 4);
      expect(PlayerSprites.viewRow(0, math.pi), 4);
    });

    test('ekranın sağına ve soluna bakmak iki ayrı satırdır', () {
      // Kamera kaleye bakarken (0) dünyanın +x'ine bakan oyuncu sağa gider.
      expect(PlayerSprites.viewRow(math.pi / 2, 0), 2);
      expect(PlayerSprites.viewRow(-math.pi / 2, 0), 6);
    });

    test('kamera dönünce aynı oyuncunun satırı da döner', () {
      // Oyuncu +x'e bakıyor; kamera sağa döndüğünde (pi/2) artık ona sırtı
      // dönük görünür, sola döndüğünde (-pi/2) karşıdan.
      expect(PlayerSprites.viewRow(math.pi / 2, math.pi / 2), 0);
      expect(PlayerSprites.viewRow(math.pi / 2, -math.pi / 2), 4);
    });

    test('açı sarması satırı bozmaz', () {
      expect(PlayerSprites.viewRow(2 * math.pi + 0.01, 0), 0);
      expect(PlayerSprites.viewRow(-0.01, 0), 0);
      expect(PlayerSprites.viewRow(-math.pi * 3 / 4, 0), 5);
    });
  });

  test('koşu döngüsü sütunları başa sarar', () {
    expect(PlayerSprites.outfieldRun.column(0), 1);
    expect(PlayerSprites.outfieldRun.column(7), 8);
    expect(PlayerSprites.outfieldRun.column(8), 1);
  });

  test('kod, Blender çıktısının layout.json dosyasıyla aynı sayıları taşır', () {
    final layout = jsonDecode(
      File('assets/images/sprites/players/layout.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(layout['directions'], PlayerSprites.directions);
    expect(layout['layers'], PlayerSprites.layers);

    void expectClip(String kind, String name, SpriteClip clip) {
      final c = (layout['kinds'][kind]['clips'] as Map)[name] as Map;
      expect(c['start'], clip.start, reason: '$kind/$name start');
      expect(c['count'], clip.count, reason: '$kind/$name count');
    }

    expectClip('outfield', 'idle', PlayerSprites.outfieldIdle);
    expectClip('outfield', 'run', PlayerSprites.outfieldRun);
    expectClip('keeper', 'ready', PlayerSprites.keeperReady);
    expectClip('keeper', 'diveL', PlayerSprites.keeperDiveLeft);
    expectClip('keeper', 'diveR', PlayerSprites.keeperDiveRight);
  });

  group('ShotGame.stanceOf', () {
    ShotGame game() => ShotGame(
          onStateChanged: () {},
          scene: const ShotScene(
            receivers: [ShotTarget.leftWing],
            rivals: [ShotTarget.rivalCentreBack],
          ),
        );

    test('duran oyuncular topun olduğu noktaya bakar', () {
      final g = game();
      final s = g.stanceOf(ShotTarget.leftWing, 0);
      expect(s.running, isFalse);
      expect(
        s.facing,
        closeTo(PitchProjector.angleToward(0.9, -0.55), 1e-9),
      );
    });

    test('ateşten önce rakip de yerinde durur', () {
      final s = game().stanceOf(ShotTarget.rivalCentreBack, 0.5);
      expect(s.running, isFalse);
    });
  });
}
