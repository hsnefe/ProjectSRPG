import 'package:project_srpg/game/formations.g.dart';

/// Formasyon slotlarının, oyuncunun kendi yerini bulmakta ve etiketlenmekte
/// kullanılan saf yardımcıları. Widget'tan ayrı duruyorlar ki kural bir saha
/// çizmeden sınanabilsin.

/// Slot grubundan mevkiye. `career_engine/worlddata/positions.py`'nin her role
/// verdiği `group` kolonunun bu taraftaki karşılığı; anahtar kümesi oradaki
/// yedi grupla birebir aynı olmalı (test/formations_test.dart bunu bekler).
///
/// Değerler `PlayerProfile.position` / `CareerHub.playerPosition` ile aynı üç
/// Türkçe dizge — positions.py'de kaleci yok, burada da yok.
const kGroupToPosition = <String, String>{
  'DC': 'Defans',
  'DL/DR': 'Defans',
  'DM': 'Orta saha',
  'MC': 'Orta saha',
  'AMC': 'Orta saha',
  'Kanat': 'Orta saha',
  'ST': 'Forvet',
};

/// Oyuncunun sarı daireyi hak ettiği slotun indeksi; o mevkide slot yoksa null.
///
/// Kural **yalnızca mevki**: rol (`slot.roleId`) bilerek işe karışmıyor, çünkü
/// bir formasyondaki slot rolleri o dizilişin kendi tercihleri — oyuncunun
/// kariyer rolüyle çakışmadığında onu hattının dışına atardı. Aynı hatta
/// birden fazla slot varsa en merkezdeki (x'i 0.5'e en yakın) seçilir:
/// tercihsiz bir kural gerektiğinde merkez, kanattan daha az keyfîdir.
/// Eşitlikte küçük indeks kazanır, böylece seçim deterministik kalır.
int? userSlotIndex(Formation formation, String position) {
  int? best;
  var bestDistance = double.infinity;
  for (var i = 0; i < formation.slots.length; i++) {
    final slot = formation.slots[i];
    if (kGroupToPosition[slot.group] != position) continue;
    final distance = (slot.x - 0.5).abs();
    // Tolerans şart: 0.3 ile 0.7 merkeze eşit uzaklıkta ama ikili tabanda
    // (0.7 - 0.5) kılpayı küçük çıkıyor, yani çıplak `<` simetrik iki slottan
    // sağdakini seçerdi. Pay, aynı noktadaki iki slotu eşit sayıp sıraya
    // bırakır.
    if (distance < bestDistance - _centreTolerance) {
      best = i;
      bestDistance = distance;
    }
  }
  return best;
}

/// Saha genişliğinin milyonda biri — gerçek slotlar arasındaki en küçük fark
/// (0.0019, 4-4-2 diamond'un iki stoperi) bunun kat kat üstünde.
const _centreTolerance = 1e-6;

/// Dairenin altına yazılan kısaltma. Grup kodunun kendisi, tek istisnası
/// 'DL/DR': iki bek de aynı grubu paylaştığı için hangisinin sol hangisinin
/// sağ olduğunu ancak slotun x'i söyleyebilir.
String slotAbbreviation(FormationSlot slot) {
  if (slot.group == 'DL/DR') return slot.x < 0.5 ? 'DL' : 'DR';
  return slot.group ?? '?';
}
