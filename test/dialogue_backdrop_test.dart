import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/screens/activity_event_screen.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';

void main() {
  group('backdropAssetFor', () {
    test('saat yalnızca gün ışığı giren sahnelerin adına eklenir', () {
      expect(
        backdropAssetFor(DialogueScene.cafe, time: BackdropTime.night),
        'assets/images/backgrounds/cafe_night.jpg',
      );
      // Pencere­siz oda: saat verilse de tek dosya.
      expect(
        backdropAssetFor(DialogueScene.lockerRoom, time: BackdropTime.night),
        'assets/images/backgrounds/locker_room.jpg',
      );
    });

    test('ev ve stadyum durumuna göre ayrı dosya seçer', () {
      expect(
        backdropAssetFor(DialogueScene.home,
            time: BackdropTime.day, status: BackdropStatus.lean),
        'assets/images/backgrounds/home_modest_day.jpg',
      );
      expect(
        backdropAssetFor(DialogueScene.home,
            time: BackdropTime.day, status: BackdropStatus.thriving),
        'assets/images/backgrounds/home_luxury_day.jpg',
      );
      expect(
        backdropAssetFor(DialogueScene.stadium,
            time: BackdropTime.night, status: BackdropStatus.lean),
        'assets/images/backgrounds/stadium_empty_night.jpg',
      );
    });

    test('durum başka sahnelerde yok sayılır', () {
      expect(
        backdropAssetFor(DialogueScene.gym,
            time: BackdropTime.day, status: BackdropStatus.thriving),
        'assets/images/backgrounds/gym_day.jpg',
      );
    });

    test('verilmeyen saat ve durum sahnenin doğal varsayılanına düşer', () {
      expect(backdropAssetFor(DialogueScene.stadium),
          'assets/images/backgrounds/stadium_full_night.jpg');
      expect(backdropAssetFor(DialogueScene.home),
          'assets/images/backgrounds/home_modest_dusk.jpg');
      expect(backdropAssetFor(DialogueScene.trainingGround),
          'assets/images/backgrounds/training_ground_day.jpg');
    });

    // Blender betiği (tools/blender/build_dialogue_backdrops.py) ile buradaki
    // ad kuralı birbirinden bağımsız yazıldı; bu test ikisinin aynı şeyi
    // anlattığını sabitliyor — biri değişirse diyalog sessizce eski siluete düşer.
    test('her sahne / saat / durum birleşiminin render dosyası diskte var', () {
      final missing = <String>[];
      for (final scene in DialogueScene.values) {
        for (final time in BackdropTime.values) {
          for (final status in BackdropStatus.values) {
            final path = backdropAssetFor(scene, time: time, status: status);
            if (!File(path).existsSync()) missing.add(path);
          }
        }
      }
      expect(missing, isEmpty);
    });
  });

  group('DialogueBackdrop', () {
    testWidgets('her sahne, zaman ve durumla çizilir', (tester) async {
      for (final scene in DialogueScene.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 600,
              height: 260,
              child: DialogueBackdrop(
                scene: scene,
                tint: Colors.blue,
                time: BackdropTime.night,
                status: BackdropStatus.thriving,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$scene');
      }
    });
  });

  group('sceneForActivity', () {
    test('koşu ve bisiklet parkta, yoga / sauna / yüzme salonda geçer', () {
      expect(sceneForActivity('fiz-kosu'), DialogueScene.park);
      expect(sceneForActivity('fiz-bisiklet'), DialogueScene.park);
      expect(sceneForActivity('fiz-yoga'), DialogueScene.gym);
      expect(sceneForActivity('fiz-sauna'), DialogueScene.gym);
      expect(sceneForActivity('fiz-yuzme'), DialogueScene.gym);
    });

    test('bilinen önekler eskisi gibi kalır', () {
      expect(sceneForActivity('ev-film'), DialogueScene.home);
      expect(sceneForActivity('sos-taraftar'), DialogueScene.stadium);
      expect(sceneForActivity('sos-kafe'), DialogueScene.cafe);
    });
  });
}
