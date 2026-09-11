import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/formation_pick.dart';
import 'package:project_srpg/game/formations.g.dart';

Formation _formation(List<FormationSlot> slots) =>
    Formation(id: 'test', name: 'test', shape: 'test', slots: slots);

FormationSlot _slot(double x, String group) =>
    FormationSlot(x: x, y: 0.5, label: group, group: group);

void main() {
  group('userSlotIndex', () {
    test('oyuncuyu kendi hattına koyar', () {
      final formation = kFormationsById['4-3-3-duz']!;

      final defender = userSlotIndex(formation, 'Defans')!;
      final midfielder = userSlotIndex(formation, 'Orta saha')!;
      final forward = userSlotIndex(formation, 'Forvet')!;

      expect(kGroupToPosition[formation.slots[defender].group], 'Defans');
      expect(kGroupToPosition[formation.slots[midfielder].group], 'Orta saha');
      expect(kGroupToPosition[formation.slots[forward].group], 'Forvet');
    });

    test('aynı hatta birden fazla slot varsa merkezdekini seçer', () {
      final formation = _formation([
        _slot(0.14, 'MC'),
        _slot(0.48, 'MC'), // merkeze en yakın
        _slot(0.86, 'MC'),
      ]);

      expect(userSlotIndex(formation, 'Orta saha'), 1);
    });

    test('merkeze eşit uzaklıkta iki slotta küçük indeks kazanır', () {
      // Kural deterministik olmalı: aynı diziliş her açılışta aynı dairyi
      // sarıya boyamalı.
      final formation = _formation([_slot(0.3, 'DC'), _slot(0.7, 'DC')]);

      expect(userSlotIndex(formation, 'Defans'), 0);
    });

    test('o mevkide slot yoksa null döner', () {
      final formation = _formation([_slot(0.5, 'ST')]);

      expect(userSlotIndex(formation, 'Defans'), isNull);
    });

    test('bilinmeyen mevki null döner', () {
      expect(userSlotIndex(kFormationsById['4-2-3-1']!, 'Kaleci'), isNull);
    });
  });

  group('slotAbbreviation', () {
    test('grup kodunu yazar', () {
      expect(slotAbbreviation(_slot(0.5, 'MC')), 'MC');
      expect(slotAbbreviation(_slot(0.5, 'ST')), 'ST');
      expect(slotAbbreviation(_slot(0.5, 'Kanat')), 'Kanat');
    });

    test('iki bek grubu paylaştığı için DL/DR\'yi x ayırır', () {
      expect(slotAbbreviation(_slot(0.14, 'DL/DR')), 'DL');
      expect(slotAbbreviation(_slot(0.86, 'DL/DR')), 'DR');
    });
  });
}
