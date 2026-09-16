import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:project_srpg/game/match_scenarios.dart';
import 'package:project_srpg/game/shot_objective.dart';
import 'package:project_srpg/game/tackle_game.dart';
import 'package:project_srpg/game/tackle_scenarios.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/game_chrome.dart';
import 'package:project_srpg/widgets/tackle_controls.dart';

/// Bir müdahale teklifinin FE kontrolündeki sonucu — `outcomeKey` motora giden
/// anahtar (§7.4/Ek B), `rawLabel` `minigame_result` alanına giden ham etiket.
///
/// Şeklen `InterventionShotResult` ile aynı; Dart kayıtları yapısal olduğu
/// için `match_screen.dart` ikisini tek bir tip parametresiyle karşılıyor.
typedef InterventionTackleResult = ({String outcomeKey, String rawLabel});

/// Oyunun kademesi → tekliften dönen cevap.
///
/// Savunma aksiyonlarının `graded` şeması oyunun üç kademesiyle birebir aynı,
/// o yüzden çeviri tek satır. `minigame_result` alanına kademenin kendi
/// etiketi gidiyor: denetim kaydı için ayrı bir ham etiket tablosu uydurmak
/// yerine, ekranda da görünen sözcüğü göndermek daha dürüst.
/// (`intervention_shot_screen.dart`'ın [outcomeKeyForLabel] tablosuyla aynı
/// konumda ve aynı gerekçeyle testlere açık.)
@visibleForTesting
InterventionTackleResult tackleResultOf(ShotGrade grade) => (
      outcomeKey: MatchScenarios.outcomeKeyForGrade(grade),
      rawLabel: grade.label,
    );

/// `minigame:"tackle"` bir teklifin tam ekran karar ekranı (§7.2).
///
/// Savunma aksiyonlarının şeması `graded` (great/good/bad) ve oyunun kendi üç
/// kademesiyle **birebir aynı** — dolayısıyla pas aksiyonlarında olduğu gibi
/// senaryonun notu doğrudan motorun anahtarı oluyor
/// ([MatchScenarios.outcomeKeyForGrade]); bitiriş tarafındaki ham etiket
/// tablosuna burada gerek yok.
///
/// Hangi durumda oynandığına teklifin `action_key`'i karar veriyor:
/// `high_press` baskı ailesine, `tackle_hard` tutma ve dönüş ailelerine
/// düşüyor ([MatchScenarios.pickTackle]). Tanınmayan bir anahtar null döner ve
/// oyun nötr çarpanlarla oynanır — motorun ileride ekleyeceği bir aksiyon
/// akışı kırmamalı.
///
/// **Tek deneme, geri alma yok** — oyunun kendisi zaten tek karşılaşmalık,
/// antrenman kartıyla aynı sınıf hiçbir uyarlama olmadan kullanılıyor.
///
/// **Çıkışı yoktur (§0 v1.7).** Geri oku çizilmez (`showBack: false`) ve
/// `PopScope(canPop:false)` sistem geri hareketini yutar. Ekranın kendi
/// kapanmayan tek yolu `match_screen.dart::_dismissMinigameScreen`'dir:
/// sunucunun 180 sn'lik emniyet süresi dolup teklifi kendiliğinden `decline`
/// ettiğinde, çağıran bu ekranı `removeRoute` ile kapatır ve hiç POST atmaz.
class InterventionTackleScreen extends StatefulWidget {
  const InterventionTackleScreen({
    super.key,
    required this.offer,
    this.scenario,
  });

  final InterventionOfferFrame offer;

  /// Testlerin durumu sabitleyebilmesi için; uygulamada boş bırakılır ve
  /// teklifin `action_key`'inden seçilir.
  final TackleScenario? scenario;

  @override
  State<InterventionTackleScreen> createState() =>
      _InterventionTackleScreenState();
}

class _InterventionTackleScreenState extends State<InterventionTackleScreen> {
  late final TackleScenario? _scenario =
      widget.scenario ?? MatchScenarios.pickTackle(widget.offer.actionKey);

  late final TackleGame _game = TackleGame(
    onStateChanged: _onGameState,
    onFinished: (_) => _onGameState(),
    closeScale: _scenario?.closeScale ?? 1,
    windowScale: _scenario?.windowScale ?? 1,
  );

  /// Sonuç bir kez yakalanıp ekran kapatılınca tekrar tetiklenmesin diye.
  bool _handled = false;
  bool _rebuildScheduled = false;

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

  /// Oyun bittiği anda (ilk ve tek kez) dereceyi `outcome_key`'e çevirip
  /// ekranı kapatır. Buradan pop etmek güvenli — çağrı oyunun `update()`'inin
  /// içinden değil, post-frame callback'ten geliyor
  /// (`intervention_shot_screen.dart`'taki aynı gerekçe).
  void _maybeFinish() {
    if (_handled || !_game.finished) return;
    _handled = true;
    Navigator.of(context)
        .pop<InterventionTackleResult>(tackleResultOf(_game.grade!));
  }

  String get _hint {
    switch (_game.phase) {
      case TacklePhase.ready:
        return 'Koşmaya başlamak için SOL ya da SAĞ — tek deneme.';
      case TacklePhase.closing:
        return 'Tempoyu tuttur · pencere o kadar genişler';
      case TacklePhase.window:
        return 'Şimdi!';
      case TacklePhase.done:
        return 'Sonuç işleniyor…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _game.phase == TacklePhase.window;

    // §0 v1.7 · zorunlu mini oyun, çıkışı yok — sistem geri hareketi burada
    // yutulur; `showBack: false` de aynı sözü başlık çubuğunda tekrarlar.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface1,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        // Başlık motorun kendi cümlesi (§7.2 `prompt`) — maçta o
                        // an ne olduğunu söyleyen tek yetkili metin. Durumun
                        // tarifi onun altında, çünkü o yalnızca sahneyi anlatıyor.
                        GameHeaderBar(
                          title: widget.offer.prompt,
                          showBack: false,
                          leading: MinigameMinuteChip(minute: widget.offer.minute),
                        ),
                        // §7.5 · `tackle_hard`ın kırmızı kart uyarısı modaldan
                        // buraya taşındı (§0 v1.7) — burada gösterilmesi daha
                        // isabetli: modalda kararın ÖNCESİNDEydi ("müdahale
                        // etmeli miyim"), burada kararın SIRASINDA — tam olarak
                        // oyunun ölçtüğü zamanlama penceresi hakkında bir uyarı.
                        if (widget.offer.riskHint case final hint?)
                          GameRiskBar(text: hint),
                        if (_scenario case final scenario?)
                          GameBriefBar(
                            title: scenario.title,
                            text: scenario.brief,
                          ),
                        TackleGauges(game: _game),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: GameWidget(game: _game),
                            ),
                          ),
                        ),
                        TackleControls(game: _game, windowOpen: open),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                          child: Text(
                            _hint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
