import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/character_portrait.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';

PortraitTraits _forId(String id) =>
    PortraitTraits.forId(id, tint: AppColors.accent);

void main() {
  group('PortraitTraits.forId', () {
    test('aynı kimlik her seferinde aynı yüzü verir', () {
      final a = _forId('coach');
      final b = _forId('coach');

      expect(a.skin, b.skin);
      expect(a.hair, b.hair);
      expect(a.hairStyle, b.hairStyle);
      expect(a.build, b.build);
      expect(a.accessory, b.accessory);
    });

    test('altı ilişki tek bir görünüşe çökmüyor', () {
      const ids = ['coach', 'team', 'media', 'fans', 'partner', 'family'];
      final signatures = ids
          .map(_forId)
          .map((t) => '${t.skin}-${t.hair}-${t.hairStyle}-${t.build}-${t.accessory}')
          .toSet();

      // Altı kimliğin altısının da ayrı çıkması karma fonksiyonuna fazla
      // güvenmek olur; aranan şey "hepsi aynı değil", yani portrenin gerçekten
      // kişiye göre değiştiği.
      expect(signatures.length, greaterThan(3));
    });

    test('kıyafet ilişkinin renginden türer', () {
      final accent = PortraitTraits.forId('coach', tint: AppColors.accent);
      final danger = PortraitTraits.forId('coach', tint: AppColors.danger);

      expect(accent.outfit, isNot(danger.outfit));
      // Geri kalanı kimlikten geldiği için ton değişince sabit kalmalı.
      expect(accent.skin, danger.skin);
      expect(accent.hairStyle, danger.hairStyle);
    });

    test('türetilen değerler tanımlı aralıkta', () {
      for (final id in ['coach', 'team', 'media', 'fans', 'partner', 'family', '']) {
        final t = _forId(id);
        expect(t.hairStyle, inInclusiveRange(0, 3));
        expect(t.accessory, inInclusiveRange(0, 3));
        expect(t.build, inInclusiveRange(0.85, 1.18));
      }
    });
  });

  group('çizim', () {
    testWidgets('portre hata vermeden çizilir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 260,
            child: CharacterPortrait(traits: _forId('coach')),
          ),
        ),
      );
      expect(find.byType(CharacterPortrait), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // §1.2 · imageAsset null olduğunda (bugün her ilişki için durum bu)
    // CustomPaint'e düşmeli, Image.asset denemeye kalkmamalı — CustomPaint
    // bir dosya aramaz, bu yüzden bu dal hatasızlığın en ucuz kanıtı.
    testWidgets('imageAsset null ise prosedürel büste düşer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 260,
            child: CharacterPortrait(traits: _forId('coach'), imageAsset: null),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // Asset yolu verilmiş ama dosya yoksa (henüz eklenmediği için) yine
    // sessizce prosedürel büste düşmeli — errorBuilder'ın işi bu.
    testWidgets('bulunamayan bir imageAsset hata vermeden geri düşer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 260,
            child: CharacterPortrait(
              traits: _forId('coach'),
              imageAsset: 'assets/images/portraits/coach.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('altı sahnenin hepsi çizilir', (tester) async {
      for (final scene in DialogueScene.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 300,
              height: 260,
              child: DialogueBackdrop(scene: scene, tint: AppColors.accent),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$scene çizilemedi');
      }
    });
  });
}
