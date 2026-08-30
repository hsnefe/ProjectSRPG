import 'package:project_srpg/net/career_models.dart';

/// §1.3 — BE sayıyı verir, etiketi FE yazar. D30'un on iki nitelik anahtarının
/// Türkçe karşılıkları, tek yerde: bir `requires` eşiği hem diyalog ekranında
/// hem katalog kartlarında aynı adla okunmalı.
const attributeLabels = {
  'condition': 'Kondisyon',
  'strength': 'Güç',
  'flexibility': 'Esneklik',
  'shooting': 'Şut',
  'passing': 'Pas',
  'dribbling': 'Dribling',
  'tackling': 'Müdahale',
  'charisma': 'Cazibe',
  'politeness': 'Kibarlık',
  'confidence': 'Özgüven',
  'intelligence': 'Zeka',
  'resourcefulness': 'Beceriklilik',
};

String attributeLabel(String key) => attributeLabels[key] ?? key;

/// Bir `requires` haritasının (D42) karşılanmayan kısmı, oyuncunun **BE'den
/// gelen** seviyelerine göre. Boş dönüyorsa kapı açıktır.
///
/// [levelOf] doğrudan `PlayerAttribute.level`'ı okur; FE hiçbir yerde
/// `value`'dan seviye türetmez (D43 — formülün tek sahibi BE'dir).
Map<String, int> unmetRequirements(
  Map<String, int> requires,
  int Function(String key) levelOf,
) {
  if (requires.isEmpty) return const {};
  final unmet = <String, int>{};
  requires.forEach((key, needed) {
    if (levelOf(key) < needed) unmet[key] = needed;
  });
  return unmet;
}

/// Kilit rozetinin metni: 'Özgüven 6 gerekli', birden fazlaysa
/// 'Özgüven 6 · Cazibe 8 gerekli'. Karşılanmayanları listeler, hepsini değil —
/// oyuncunun eksiği neyse onu okur.
String requirementLabel(Map<String, int> unmet) {
  if (unmet.isEmpty) return '';
  final parts = [
    for (final entry in unmet.entries) '${attributeLabel(entry.key)} ${entry.value}',
  ];
  return '${parts.join(' · ')} gerekli';
}

/// [PlayerAttribute] listesinden seviye okuyan, [unmetRequirements]'a
/// geçirilebilir bir arama fonksiyonu. Bilinmeyen anahtar 0 döner — BE de
/// satırı olmayan niteliği seviye 0 sayar.
int Function(String) levelLookup(List<PlayerAttribute> attributes) {
  return (key) {
    for (final a in attributes) {
      if (a.key == key) return a.level;
    }
    return 0;
  };
}
