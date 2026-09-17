import 'dart:math' as math;

import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';
import 'package:project_srpg/game/tackle_scenarios.dart';

/// Maç motorunun `action_key`'i → o anı temsil eden senaryo havuzu.
///
/// Müdahale mini-oyunu doğduğundan beri tek bir sahnede oynanıyordu
/// (`ShotScene.full`): oyuncu doksan dakika boyunca hep aynı yerden şut
/// çekiyordu. Katalog artık kırk iki durum taşıyor, ama motor hangisinin
/// oynanacağını söyleyemez — **teklif payload'ında saha bağlamı yok**
/// (`API_CONTRACT.md` §7.2: `minute`, `action_key`, `prompt`, `risk_hint`;
/// bölge, konum, top taşıyan oyuncu diye bir şey yok, motorun kendisi de
/// takım düzeyinde çalışıyor). Elde kalan tek sinyal `action_key`, ve o
/// aslında yeterli: aksiyonun kendisi zaten "hangi tür an" olduğunu söylüyor.
///
/// ## `asist` nerede çıkabilir
///
/// `graded4` şeması dört sonucun da üretilebilmesini istiyor, ama `asist`
/// ([ShotLabel.passCaught]) yalnızca sahnede bir alıcı varsa mümkün. Katalogda
/// hem kaleyi sayan hem alıcısı olan üç durum var ve üçü de kasten
/// [counterAttack] havuzunda: sözleşme o aksiyonu zaten "bitiren kişi
/// belirsiz — sen mi bitirdin, arkadaşına mı hazırladın" diye gerekçelendiriyor
/// (§7.3). Kalan üç aksiyonda `asist` pratikte çıkmaz; bu bilinçli bir
/// daralma, sahnelere yapay bir lay-off adamı eklemektense.
class MatchScenarios {
  const MatchScenarios._();

  /// Motorun yedi minigame aksiyonu (`api/config.py`'deki
  /// MINIGAME_ACTION_KEYS, §7.3): dört bitiriş (`graded4`) + üç pas
  /// (`graded`). Sabit olan bu liste; hangi durumun hangisine düştüğü değil.
  static const minigameActionKeys = {
    'finish_power',
    'finish_finesse',
    'long_shot',
    'counter_attack',
    'build_up_pass',
    'transition_pass',
    'final_ball',
  };

  /// Aksiyon → o aksiyonda teklif edilebilecek durumların kimlikleri.
  ///
  /// Havuzlar bir zamanlar burada elle yazılıyordu: yedi liste, kırk iki
  /// kimlik, ve katalog her değiştiğinde ikisini elle aynı tutmak. Anahtar
  /// artık senaryonun kendisinde ([ShotScenario.actionKey]) ve havuz ondan
  /// türüyor — müdahale tarafının aile adıyla zaten yaptığı şeyin şut
  /// tarafındaki karşılığı (aşağıda [tackleByActionKey]).
  ///
  /// Bir aksiyona bağlanmamış durum hiçbir havuzda değildir: maçta çıkmaz,
  /// Senaryo Sahası'nda ve antrenmanda durur. Bu bir eksiklik değil, editörde
  /// verilen bir karar.
  static final byActionKey = <String, List<String>>{
    for (final key in minigameActionKeys)
      key: [
        for (final scenario in ShotScenarios.all)
          if (scenario.actionKey == key) scenario.id,
      ],
  };

  /// Sonucu ham etiketten değil senaryonun notundan okunan aksiyonlar.
  ///
  /// Bitiriş aksiyonlarında motora giden anahtar `outcomeKeyForLabel` ile ham
  /// etiketten türüyor (§7.3) — orada "gol mü, asist mi, isabet mi" sorusunun
  /// cevabı topun nereye gittiğidir. Pas aksiyonlarında ise soru "hangi adamı
  /// buldun": aynı `PAS TUTTU` güvenli adama giderse `good`, hattı kırana
  /// giderse `great`. Bunu ham etiket bilemez, senaryonun hedefi bilir.
  static const passActionKeys = {
    'build_up_pass',
    'transition_pass',
    'final_ball',
  };

  // --- Savunma aksiyonları -------------------------------------------------
  //
  // Şut tarafı havuzu senaryonun kendi `actionKey`'inden kuruyor; müdahale
  // katalogu ise zaten aksiyonun sorduğu soruya göre ailelere bölünmüş
  // (`tackle_scenarios.dart`), o yüzden burada aile adı yetiyor. İki tarafın
  // da ortak özelliği aynı: kataloğa yeni bir durum eklemek onu havuza da
  // sokuyor, elle bakılan ikinci bir liste yok.
  //
  // `keeper_sweep` dışarıda: §7.3'teki gerekçesi mini oyunun yokluğu değil,
  // aksiyonu oyuncunun değil kalecinin yapması.
  static const tackleByActionKey = <String, List<TackleScenarioKind>>{
    'high_press': [TackleScenarioKind.press],
    'tackle_hard': [TackleScenarioKind.contain, TackleScenarioKind.recovery],
  };

  static List<TackleScenario> tacklePoolFor(String actionKey) => [
        for (final kind
            in tackleByActionKey[actionKey] ?? const <TackleScenarioKind>[])
          ...TackleScenarios.of(kind),
      ];

  /// Bu müdahale teklifinde oynanacak durum; tanınmayan bir `action_key` için
  /// null — çağıran o zaman nötr çarpanlara düşer ([pick] ile aynı gerekçe).
  static TackleScenario? pickTackle(String actionKey, {math.Random? random}) {
    final pool = tacklePoolFor(actionKey);
    if (pool.isEmpty) return null;
    return pool[(random ?? math.Random()).nextInt(pool.length)];
  }

  /// Senaryonun kademesi → motorun `graded` anahtarı. Üçe üç, birebir.
  ///
  /// Müdahale oyunu da aynı [ShotGrade]'i kullandığı için bu tablo savunma
  /// aksiyonlarında da olduğu gibi geçerli.
  static String outcomeKeyForGrade(ShotGrade grade) => switch (grade) {
        ShotGrade.great => 'great',
        ShotGrade.good => 'good',
        ShotGrade.fail => 'bad',
      };

  /// Bu aksiyonun havuzu, ya da tanınmayan bir anahtar için boş liste.
  static List<ShotScenario> poolFor(String actionKey) => [
        for (final id in byActionKey[actionKey] ?? const <String>[])
          ShotScenarios.byId(id)!,
      ];

  /// Bu teklifte oynanacak durum.
  ///
  /// Tanınmayan bir `action_key` — motorun ileride ekleyeceği bir aksiyon —
  /// null döndürür; çağıran o zaman eski sabit sahneye düşer. Akışı bir
  /// isim yüzünden kırmak, teklifi 180 sn boyunca açıkta bırakmak demek
  /// olurdu (§7.2).
  static ShotScenario? pick(String actionKey, {math.Random? random}) {
    final pool = poolFor(actionKey);
    if (pool.isEmpty) return null;
    return pool[(random ?? math.Random()).nextInt(pool.length)];
  }
}
