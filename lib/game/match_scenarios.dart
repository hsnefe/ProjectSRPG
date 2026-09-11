import 'dart:math' as math;

import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';

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

  /// Güç şutu: yakın mesafe, gövdeyle bitirme anları.
  static const finishPower = [
    'shot_box_centre',
    'shot_one_on_one',
    'shot_cutback_first_time',
    'shot_through_traffic',
    'shot_volley_far_post',
  ];

  /// Placeli şut: açı ve kavis isteyen yerler.
  static const finishFinesse = [
    'shot_box_left',
    'shot_box_right',
    'shot_edge_left',
    'shot_edge_right',
  ];

  /// Uzaktan: ceza sahası dışı ve duran toplar.
  static const longShot = [
    'shot_edge_d',
    'shot_long_range',
    'shot_free_kick_left',
    'shot_free_kick_central',
  ];

  /// Kontra: bitirmek ile bitirtmek arasındaki seçimin gerçekten var olduğu
  /// üç durum — katalogda `asist` üretebilen tek küme.
  static const counterAttack = [
    'shot_tight_left',
    'shot_tight_right',
    'final_layoff_and_shoot',
  ];

  // --- Pas aksiyonları (v1.5) ---------------------------------------------
  //
  // Motorun üç yeni aksiyonu: geriden kurulum, geçiş başlatma, son pas. Şeması
  // `graded` (great/good/bad) ve **katalogun kendi üç kademesiyle birebir
  // aynı** — pas senaryolarının notu doğrudan motorun anahtarı oluyor
  // ([outcomeKeyForGrade]). Bitiriş aksiyonlarında olduğu gibi ham etiket
  // tablosuna gerek yok; orada tavan "gol attın", burada "doğru topu buldun".
  //
  // İki kademeli durumlar (`build_safe_reset`, `trans_keep_it`,
  // `final_byline_square`) kasten dışarıda: `great` üretemedikleri için
  // motorun en iyi dalı o tekliflerde hiç ateşlenmezdi.

  static const buildUpPass = [
    'build_keeper_short',
    'build_centre_back_split',
    'build_press_escape',
    'build_full_back_line',
    'build_pivot_turn',
    'build_goal_kick_switch',
    'build_third_man',
    'build_line_break',
  ];

  static const transitionPass = [
    'trans_win_and_go',
    'trans_counter_centre',
    'trans_switch_wide',
    'trans_release_winger',
    'trans_second_ball',
    'trans_break_the_press',
    'trans_carry_then_slide',
    'trans_outlet_from_corner',
  ];

  /// `final_layoff_and_shoot` burada değil — o kaleyi sayan bir sahne ve
  /// [counterAttack] havuzunda asist üretmekle görevli.
  static const finalBall = [
    'final_through_ball',
    'final_cutback',
    'final_cross_far_post',
    'final_half_space_slip',
    'final_wall_pass',
    'final_pull_back_edge',
  ];

  static const byActionKey = <String, List<String>>{
    'finish_power': finishPower,
    'finish_finesse': finishFinesse,
    'long_shot': longShot,
    'counter_attack': counterAttack,
    'build_up_pass': buildUpPass,
    'transition_pass': transitionPass,
    'final_ball': finalBall,
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

  /// Senaryonun kademesi → motorun `graded` anahtarı. Üçe üç, birebir.
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
