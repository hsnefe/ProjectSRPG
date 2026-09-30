import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/attribute_labels.dart';
import 'package:project_srpg/net/career_models.dart';

void main() {
  group('unmetRequirements', () {
    test('boş eşik hiçbir zaman kilitlemez', () {
      expect(unmetRequirements(const {}, (_) => 0), isEmpty);
    });

    test('yalnızca karşılanmayanları döner', () {
      final unmet = unmetRequirements(
        const {'charisma': 8, 'courage': 6},
        (key) => key == 'charisma' ? 7 : 6,
      );
      expect(unmet, {'charisma': 8});
    });

    test('tam eşikte kapı açıktır', () {
      // BE'nin denkliğiyle aynı: seviye N yeterlidir, N+1 değil (D43).
      expect(unmetRequirements(const {'charisma': 7}, (_) => 7), isEmpty);
      expect(unmetRequirements(const {'charisma': 8}, (_) => 7), {'charisma': 8});
    });

    test('bilinmeyen anahtar seviye 0 sayılır', () {
      expect(unmetRequirements(const {'speed': 1}, (_) => 0), {'speed': 1});
    });
  });

  group('requirementLabel', () {
    test('tek eşik', () {
      expect(requirementLabel(const {'courage': 6}), 'Cesaret 6 gerekli');
    });

    test('birden fazla eşik nokta ile ayrılır', () {
      expect(
        requirementLabel(const {'courage': 6, 'charisma': 8}),
        'Cesaret 6 · Karizma 8 gerekli',
      );
    });

    test('boş sözlük boş metin', () {
      expect(requirementLabel(const {}), '');
    });
  });

  group('levelLookup', () {
    test('P1 satırlarının level alanını okur, value türetmez', () {
      final lookup = levelLookup(const [
        PlayerAttribute(key: 'charisma', family: 'kişi', value: 74.0, level: 7),
      ]);
      expect(lookup('charisma'), 7);
      expect(lookup('empathy'), 0);
    });
  });

  test('etiketler on iki niteliğin hepsini kapsar', () {
    // D30: radar neyse model o — eksik bir etiket ekranda ham anahtarı
    // ('discipline') gösterirdi.
    expect(attributeLabels.length, 12);
    expect(attributeLabel('discipline'), 'Disiplin');
    expect(attributeLabel('bilinmeyen'), 'bilinmeyen');
  });
}
