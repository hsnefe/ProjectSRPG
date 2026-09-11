import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/formation_pick.dart';
import 'package:project_srpg/game/formations.g.dart';

/// `lib/game/formations.g.dart` bu repo dışında (`../formation_creator/`)
/// üretilip elle kopyalanıyor, yani dosyayı derleyici dışında denetleyen
/// kimse yok. Bu testler o kopyanın maç önü ekranının varsaydığı şekilde
/// olduğunu doğrular: bozuk bir kopya sahayı sessizce yanlış çizerdi.
void main() {
  test('katalog boş değil ve id\'ler tekil', () {
    expect(kFormations, isNotEmpty);
    final ids = kFormations.map((f) => f.id).toSet();
    expect(ids.length, kFormations.length, reason: 'tekrar eden formasyon id');
    expect(kFormationsById.length, kFormations.length);
  });

  test('her formasyon tam 10 slot taşır', () {
    // Kaleci yok: positions.py'de kaleci rolü olmadığı için (v1) diziliş de
    // on kişilik. Sayı değişirse saha çizimi de gözden geçirilmeli.
    for (final formation in kFormations) {
      expect(formation.slots.length, 10, reason: formation.id);
    }
  });

  test('slot koordinatları normalize aralıkta', () {
    for (final formation in kFormations) {
      for (final slot in formation.slots) {
        expect(slot.x, inInclusiveRange(0.0, 1.0), reason: formation.id);
        expect(slot.y, inInclusiveRange(0.0, 1.0), reason: formation.id);
      }
    }
  });

  test('her slot grubu bir mevkiye çevrilebilir', () {
    // Tanınmayan bir grup, o slotun hiçbir oyuncuya sarı daire vermemesi
    // demek — sessiz bir kayıp, bu yüzden burada patlaması gerekir.
    for (final formation in kFormations) {
      for (final slot in formation.slots) {
        expect(
          kGroupToPosition[slot.group],
          isNotNull,
          reason: '${formation.id}: bilinmeyen grup ${slot.group}',
        );
      }
    }
  });

  test('her formasyonda üç mevkinin de en az bir slotu var', () {
    // Oyuncunun mevkisi ne olursa olsun sahada bir yeri olmalı.
    for (final formation in kFormations) {
      for (final position in const ['Defans', 'Orta saha', 'Forvet']) {
        expect(
          userSlotIndex(formation, position),
          isNotNull,
          reason: '${formation.id}: $position için slot yok',
        );
      }
    }
  });

  test('orta saha grupları derinlik sırasını bozmaz', () {
    // Bir slotun grubu ile sahadaki yeri çelişebilir ve bu yalnızca dairenin
    // altındaki kısaltmadan anlaşılır — 4-2-3-1'in on numarası bir süre 'DM'
    // yazdı. Kural sadece üç merkez grubu bağlar: DM iki kanadın değil, kendi
    // orta sahasının arkasında durur. DL/DR ve Kanat dışarıda: kanat bekler
    // 3-5-2'de orta saha hattına çıkar, bu doğru bir dizilişin parçası.
    for (final formation in kFormations) {
      double? deepestMc;
      double? highestMc;
      for (final slot in formation.slots) {
        if (slot.group != 'MC') continue;
        deepestMc = deepestMc == null ? slot.y : (slot.y < deepestMc ? slot.y : deepestMc);
        highestMc = highestMc == null ? slot.y : (slot.y > highestMc ? slot.y : highestMc);
      }
      if (deepestMc == null) continue;

      for (final slot in formation.slots) {
        if (slot.group == 'DM') {
          expect(
            slot.y,
            lessThanOrEqualTo(deepestMc),
            reason: '${formation.id}: DM orta sahanın önünde',
          );
        }
        if (slot.group == 'AMC') {
          expect(
            slot.y,
            greaterThanOrEqualTo(highestMc!),
            reason: '${formation.id}: AMC orta sahanın arkasında',
          );
        }
      }
    }
  });

  test('career_engine varsayılanı katalogda var', () {
    // worlddata/formations.py DEFAULT_FORMATION ile aynı olmalı.
    expect(kFormationsById['4-4-2-duz'], isNotNull);
  });
}
