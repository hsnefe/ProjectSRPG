/// Müdahale mini oyununun durum kataloğu.
///
/// Oyun doğduğunda tek bir durumu vardı: adsız bir rakip, hep aynı mesafe, hep
/// aynı pencere. Buradaki her kayıt onun yerine **bir an** tarif ediyor —
/// sahanın neresinde geçtiği, karşındakinin ne tür bir oyuncu olduğu, ve bu
/// ikisinin müdahaleyi nasıl değiştirdiği.
///
/// Katalog üç aileye ayrılıyor ([TackleScenarioKind]) ve bölünme sahanın kendi
/// mantığını izliyor: rakip yarı sahada **baskı**, orta sahada **tutma**, kendi
/// sahanda **dönüş**. Aile yalnızca bir etiket değil — 3. aşamada maç motorunun
/// `high_press` teklifi baskı havuzuna, `tackle_hard` ise tutma ve dönüş
/// havuzlarına bağlanacak.
///
/// ## Durum kurallara ne yapıyor
///
/// `shot_scenarios.dart`'taki kalıbın aynısı: durum **kasıtlı olarak ince** ve
/// kurallar bir durumu asla okumuyor. [TackleGame] yalnızca iki çarpan alıyor,
/// katalog tipini hiç tanımıyor — host ekran çarpanları geçiriyor, kelimeleri
/// kendi brifing çubuğunda gösteriyor. Dokuz kayıtlık bir katalog böylece
/// oyunun içine sızmıyor.
///
/// İki çarpan oyunun ölçtüğü iki beceriye birebir oturuyor:
/// [TackleScenario.closeScale] kovalamanın uzunluğunu (hız),
/// [TackleScenario.windowScale] dalış aralığını (isabet) belirliyor. Zor bir
/// durum ikisini birden sıkar, kolay bir durum ikisini birden açar, ama
/// çoğu kayıt birini verip diğerini alır.
///
/// Kayıtların kendisi `tackle_scenarios.g.dart`'ta — **üretilen** bir dosya,
/// kaynağı `../scenario_creator` editörü. Bu dosyada kalan şey tipler ve
/// kayıt defteri: kimin hangi aileye düştüğü, havuzun nasıl bölündüğü.
library;

import 'dart:math' as math;

import 'package:project_srpg/game/tackle_scenarios.g.dart';

/// Durumun hangi aileye ait olduğu. Kurallara hiçbir şey yapmaz; brifing
/// başlığını yazar ve havuzu böler.
enum TackleScenarioKind {
  /// Rakip yarı sahası: topu yukarıda kazanma denemesi.
  press('Baskı'),

  /// Orta saha: adamı çevirtmeden, hattı kırdırmadan durdurma.
  contain('Tutma'),

  /// Kendi sahan: geriye koşu, son adam sorumluluğu.
  recovery('Dönüş');

  const TackleScenarioKind(this.label);

  final String label;
}

/// Tek bir yazılmış an: nerede geçtiği, kime karşı olduğu ve bunun müdahaleyi
/// nasıl değiştirdiği.
class TackleScenario {
  const TackleScenario({
    required this.id,
    required this.kind,
    required this.title,
    required this.brief,
    required this.closeScale,
    required this.windowScale,
  });

  /// Katalog boyunca benzersiz, sabit anahtar.
  final String id;

  final TackleScenarioKind kind;

  /// Brifing başlığı, ör. 'Son adam sensin'.
  final String title;

  /// İki satırlık durum tarifi — ne olduğu ve neye dikkat edileceği.
  final String brief;

  /// Yaklaşma hızı çarpanı. 1'in altı "adam senden hızlı, kovalaması uzun
  /// sürüyor", üstü "ağır bir adam, çabuk yetişirsin".
  final double closeScale;

  /// Pencere genişliği çarpanı. 1'in altı "top ayağına yapışık, aralık dar",
  /// üstü "topu uzağına attı, aralık geniş".
  final double windowScale;
}

class TackleScenarios {
  const TackleScenarios._();

  static const _kinds = <String, TackleScenarioKind>{
    'press': TackleScenarioKind.press,
    'contain': TackleScenarioKind.contain,
    'recovery': TackleScenarioKind.recovery,
  };

  /// Katalogun tamamı, aile sırasıyla — üretilen dosya zaten o sırada.
  static final List<TackleScenario> all = [
    for (final spec in kTackleSpecs)
      TackleScenario(
        id: spec.id,
        kind: _kinds[spec.kind] ?? TackleScenarioKind.press,
        title: spec.title,
        brief: spec.brief,
        closeScale: spec.closeScale,
        windowScale: spec.windowScale,
      ),
  ];

  static final List<TackleScenario> press =
      _family(TackleScenarioKind.press);
  static final List<TackleScenario> contain =
      _family(TackleScenarioKind.contain);
  static final List<TackleScenario> recovery =
      _family(TackleScenarioKind.recovery);

  static List<TackleScenario> _family(TackleScenarioKind kind) =>
      [for (final s in all) if (s.kind == kind) s];

  static List<TackleScenario> of(TackleScenarioKind kind) => switch (kind) {
        TackleScenarioKind.press => press,
        TackleScenarioKind.contain => contain,
        TackleScenarioKind.recovery => recovery,
      };

  static TackleScenario? byId(String id) {
    for (final scenario in all) {
      if (scenario.id == id) return scenario;
    }
    return null;
  }

  /// Bir antrenman oturumunun durumu — katalogdan rastgele biri.
  ///
  /// Oturum tek denemelik olduğu için `shot_scenarios.dart`'taki gibi bir
  /// çalma listesi kurmaya gerek yok: her açılışta tek bir an çekiliyor,
  /// tekrar oynanabilirlik de buradan geliyor.
  static TackleScenario pick({math.Random? random}) =>
      all[(random ?? math.Random()).nextInt(all.length)];
}
