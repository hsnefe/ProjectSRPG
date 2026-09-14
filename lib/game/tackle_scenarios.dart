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
library;

import 'dart:math' as math;

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

  /// Baskı: rakip henüz kurmaya çalışıyor, sen yukarıdasın.
  static const press = [
    TackleScenario(
      id: 'press_centre_back_dwell',
      kind: TackleScenarioKind.press,
      title: 'Stoper topu fazla tuttu',
      brief: 'Rakip stoper topu ayağında uyuttu. Ağır adam, önü açık — '
          'yetişmek kolay, mesele ne zaman dalacağın.',
      closeScale: 1.25,
      windowScale: 1.1,
    ),
    TackleScenario(
      id: 'press_back_pass',
      kind: TackleScenarioKind.press,
      title: 'Kaleciye dönen top',
      brief: 'Top geriye, kaleciye gidiyor. Uzun bir koşu; tempoyu bozmazsan '
          'ceza sahasına girmeden yetişirsin.',
      closeScale: 0.80,
      windowScale: 1.15,
    ),
    TackleScenario(
      id: 'press_touchline_trap',
      kind: TackleScenarioKind.press,
      title: 'Bek çizgiye sıkıştı',
      brief: 'Bek taç çizgisine yaslandı, çıkacak yeri yok. Dar alanda topu '
          'gövdesiyle saklıyor, aralık küçük.',
      closeScale: 1.10,
      windowScale: 0.85,
    ),
  ];

  /// Tutma: orta saha, adam henüz dönmedi ya da yeni dönüyor.
  static const contain = [
    TackleScenario(
      id: 'contain_pivot_turn',
      kind: TackleScenarioKind.contain,
      title: 'Pivot dönmek üzere',
      brief: 'Ön libero topu aldı, omzunun üstünden baktı. Dönerse hat '
          'kırılır — teknik adam, top ayağından hiç ayrılmıyor.',
      closeScale: 1.00,
      windowScale: 0.80,
    ),
    TackleScenario(
      id: 'contain_carry_centre',
      kind: TackleScenarioKind.contain,
      title: 'Ortadan taşıyor',
      brief: 'Topu alıp merkezden ilerliyor, kimse yardıma gelmiyor. Ne çok '
          'hızlı ne çok yavaş: düz bir ikili mücadele.',
      closeScale: 1.00,
      windowScale: 1.00,
    ),
    TackleScenario(
      id: 'contain_switch_to_wing',
      kind: TackleScenarioKind.contain,
      title: 'Top kanada açıldı',
      brief: 'Oyun tek pasla karşı kanada geçti. Uzun bir yatay koşu; adam '
          'topu kontrol etmeden üstüne varman gerek.',
      closeScale: 0.75,
      windowScale: 1.10,
    ),
  ];

  /// Dönüş: kendi sahan, arkanda az adam ya da hiç kimse.
  static const recovery = [
    TackleScenario(
      id: 'recovery_last_man',
      kind: TackleScenarioKind.recovery,
      title: 'Son adam sensin',
      brief: 'Arkanda kaleciden başka kimse yok. Temiz topa gitmek '
          'zorundasın — aralık dar ve hatanın affı yok.',
      closeScale: 0.90,
      windowScale: 0.80,
    ),
    TackleScenario(
      id: 'recovery_shoulder_duel',
      kind: TackleScenarioKind.recovery,
      title: 'Omuz omuza',
      brief: 'Forvetle yan yana koşuyorsunuz. Güçlü ama ağır bir adam; '
          'yetişirsin, devirmeden ayırman lazım.',
      closeScale: 1.20,
      windowScale: 0.90,
    ),
    TackleScenario(
      id: 'recovery_cover_the_cross',
      kind: TackleScenarioKind.recovery,
      title: 'Ortayı kapatmaya',
      brief: 'Kanat dışarıdan açtı, ortayı yapmadan kapatman gerek. Hızlı '
          'adam, mesafe uzun — koşuyu erken başlat.',
      closeScale: 0.78,
      windowScale: 1.05,
    ),
  ];

  /// Katalogun tamamı, aile sırasıyla.
  static const all = [...press, ...contain, ...recovery];

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
