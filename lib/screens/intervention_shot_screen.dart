import 'package:flutter/material.dart';

import 'package:project_srpg/game/match_scenarios.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/widgets/fullscreen_game.dart';

/// Bir müdahale teklifinin FE kontrolündeki sonucu — `outcomeKey` motora
/// giden anahtar (§7.4/Ek B), `rawLabel` `minigame_result` alanına giden ham
/// etiket (şut mini-oyununun ürettiği 9 etiketten biri, ör. `"GOL!"`).
typedef InterventionShotResult = ({String outcomeKey, String rawLabel});

/// `shot_game.dart`'ın ham sonuç etiketi → `outcome_key` eşlemesi (§7.3
/// minigame sonuç tablosu, `graded4` şeması: great/asist/good/bad).
///
/// Kaleye giden gol `great`; kaleye şut çekmek yerine son anda boştaki bir
/// arkadaşa ulaşan pas `asist` — bu ayrım oyunun kendi mekaniğinden geliyor:
/// sahnede hem kale hem bir alıcı varsa ikisi de aynı nişan mekaniğiyle açık.
/// Kalecinin çeldiği/direğe çarpan şutlar `good`; geri kalan her şey `bad`.
///
/// Tablo sahneden bağımsız: hangi senaryo açılırsa açılsın ham etiket aynı
/// dokuz değerden biri, dolayısıyla §7.3 eşlemesi senaryolar geldiğinde de
/// aynen geçerli kalıyor.
@visibleForTesting
const Map<String, String> outcomeKeyForLabel = {
  'GOL!': 'great',
  'PAS TUTTU': 'asist',
  'KURTARIŞ': 'good',
  'DİREK': 'good',
  'AUT': 'bad',
  'ÜSTTEN AUT': 'bad',
  'BOŞLUĞA': 'bad',
  'PAS KAÇTI': 'bad',
  'RAKİP KESTİ': 'bad',
};

/// Bir `resolution:"minigame"` teklifinin tam ekran karar ekranı (§7.2).
///
/// Hangi sahnede oynandığına teklifin `action_key`'i karar veriyor
/// ([MatchScenarios]): güç şutu yakın mesafeden, placeli şut açıdan, uzaktan
/// şut ceza sahası dışından. Eskiden hepsi tek bir sabit sahneydi
/// (`ShotScene.full`), yani doksan dakikanın her müdahalesi aynı yerden
/// çekiliyordu.
///
/// `ShotMode.free` korunuyor: o mod deneme saymıyor ve pusulayı serbest
/// bırakıyor, dolayısıyla ekran tek atışlık kalıyor. Notlandırma da
/// senaryonun kendi [ShotObjective]'ine değil, aşağıdaki [outcomeKeyForLabel]
/// tablosuna bağlı — motora giden anahtar sözleşmenin tanımladığı şey, oyunun
/// antrenman tarafındaki üç kademesi değil.
///
/// **Tek deneme, geri alma yok** — canlı bir maç kararı pratikte tekrar
/// denenemez; ilk sonuç ne çıkarsa `Navigator.pop` ile döner.
///
/// **Çıkışı yoktur (§0 v1.7).** Geri oku çizilmez (`showBack: false`) ve
/// `PopScope(canPop:false)` sistem geri hareketini yutar — kullanıcı hiç
/// atış yapmadan bu ekrandan ayrılamaz. Ekranın kendi kapanmayan tek yolu
/// `match_screen.dart::_dismissMinigameScreen`'dir: sunucunun 180 sn'lik
/// emniyet süresi dolup teklifi kendiliğinden `decline` ettiğinde, çağıran
/// bu ekranı `removeRoute` ile kapatır ve hiç POST atmaz (teklif zaten
/// kapalı; bir POST 409 `offer_closed` alırdı).
class InterventionShotScreen extends StatefulWidget {
  const InterventionShotScreen({
    super.key,
    required this.offer,
    this.scenario,
  });

  final InterventionOfferFrame offer;

  /// Testlerin sahneyi sabitleyebilmesi için; uygulamada boş bırakılır ve
  /// teklifin `action_key`'inden seçilir.
  final ShotScenario? scenario;

  @override
  State<InterventionShotScreen> createState() => _InterventionShotScreenState();
}

class _InterventionShotScreenState extends State<InterventionShotScreen> {
  /// Bu teklifin oynanacağı durum. Tanınmayan bir `action_key` gelirse null
  /// kalır ve oyun eski sabit sahnede oynanır — ileri uyumluluk: motorun
  /// ekleyeceği yeni bir aksiyon akışı kırmamalı.
  late final ShotScenario? _scenario =
      widget.scenario ?? MatchScenarios.pick(widget.offer.actionKey);

  late final ShotGame _game = ShotGame(
    mode: ShotMode.free,
    scene: _scenario?.scene ?? ShotScene.full,
    onStateChanged: _onGameState,
  );

  /// Sonuç bir kez yakalanıp ekran kapatılınca tekrar tetiklenmesin diye.
  bool _handled = false;
  bool _rebuildScheduled = false;

  /// Oyun döngüsü Flutter'ın build fazının içinden haber verebiliyor
  /// (`skill_exam_screen.dart`'taki aynı desen) — bildirimler tek bir
  /// post-frame rebuild'e toplanır.
  void _onGameState() {
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (!mounted) return;
      setState(() {});
      _maybeFinish();
    });
  }

  /// `phase == result` olduğu anda (ilk ve tek kez) sonucu yakalayıp
  /// `outcome_key`'e çevirir ve ekranı kapatır. Buradan pop etmek
  /// `skill_exam_screen.dart`'ın `onFinished`'ının aksine güvenli — bu
  /// çağrı `update()`'in içinden değil, post-frame callback'ten geliyor.
  void _maybeFinish() {
    if (_handled) return;
    final rawLabel = _game.result;
    if (_game.phase != ShotPhase.result || rawLabel == null) return;
    _handled = true;
    // Bitiriş aksiyonlarında anahtar ham etiketten geliyor (§7.3); pas
    // aksiyonlarında senaryonun kendi notundan, çünkü aynı "PAS TUTTU"nun
    // hangi kademe olduğuna topu kimin aldığı karar veriyor.
    final outcomeKey =
        MatchScenarios.passActionKeys.contains(widget.offer.actionKey)
            ? MatchScenarios.outcomeKeyForGrade(_game.lastGrade)
            : outcomeKeyForLabel[rawLabel] ?? 'bad';
    Navigator.of(context)
        .pop<InterventionShotResult>((outcomeKey: outcomeKey, rawLabel: rawLabel));
  }

  @override
  Widget build(BuildContext context) {
    // §0 v1.7 · zorunlu mini oyun, çıkışı yok — sistem geri hareketi burada
    // yutulur.
    return PopScope(
      canPop: false,
      child: FullscreenGame(game: _game, top: const []),
    );
  }
}
