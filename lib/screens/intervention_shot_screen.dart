import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/game_chrome.dart';

/// Bir müdahale teklifinin FE kontrolündeki sonucu — `outcomeKey` motora
/// giden anahtar (§7.4/Ek B), `rawLabel` `minigame_result` alanına giden ham
/// etiket (şut mini-oyununun ürettiği 9 etiketten biri, ör. `"GOL!"`).
typedef InterventionShotResult = ({String outcomeKey, String rawLabel});

/// `shot_game.dart`'ın ham sonuç etiketi → `outcome_key` eşlemesi (§7.3
/// minigame sonuç tablosu, `graded4` şeması: great/asist/good/bad).
///
/// Kaleye giden gol `great`; kaleye şut çekmek yerine son anda boştaki bir
/// arkadaşa ulaşan pas `asist` — bu ayrım oyunun kendi mekaniğinden geliyor
/// (`ShotTarget.goal` ile `ShotTarget.teamMates` arasında serbest seçim,
/// `ShotMode.free` + `ShotScene.full` zaten ikisini de açık tutuyor).
/// Kalecinin çeldiği/direğe çarpan şutlar `good`; geri kalan her şey `bad`.
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
/// `shot_game.dart`'a hiç dokunulmaz: `ShotMode.free` + `ShotScene.full`
/// zaten hem kaleye şut hem arkadaşa pas seçeneğini açık bir aim
/// mekaniğiyle sunuyor — "Gol" ile "Asist" ayrımı bu yüzden oyun mekaniğine
/// dokunmadan, yalnızca sonucun yorumlanma biçiminden geliyor.
///
/// **Tek deneme, geri alma yok** — canlı bir maç kararı pratikte tekrar
/// denenemez; ilk sonuç ne çıkarsa `Navigator.pop` ile döner. Kullanıcı hiç
/// atış yapmadan geri tuşuna basarsa `null` döner — çağıran
/// (`match_screen.dart`) bu durumda hiç POST atmaz, teklif sunucuda açık
/// kalır ve 180 sn'lik emniyet süresi sonunda kendiliğinden `decline` olur
/// (§7.2/§9.2 — kullanıcı minigame'i yarıda bırakırsa POST hiç atılmaz).
class InterventionShotScreen extends StatefulWidget {
  const InterventionShotScreen({super.key, required this.offer});

  final InterventionOfferFrame offer;

  @override
  State<InterventionShotScreen> createState() => _InterventionShotScreenState();
}

class _InterventionShotScreenState extends State<InterventionShotScreen> {
  late final ShotGame _game = ShotGame(
    mode: ShotMode.free,
    scene: ShotScene.full,
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
    final outcomeKey = outcomeKeyForLabel[rawLabel] ?? 'bad';
    Navigator.of(context)
        .pop<InterventionShotResult>((outcomeKey: outcomeKey, rawLabel: rawLabel));
  }

  String get _hint {
    switch (_game.phase) {
      case ShotPhase.aim:
        return 'Kaleye şut çek ya da boştaki bir arkadaşına pas ver — tek deneme.';
      case ShotPhase.strike:
        return '2) Topa vur: merkez = güç, kenar = kavis, alt = yükselt';
      case ShotPhase.flight:
        return 'Uçuşta…';
      case ShotPhase.result:
        return 'Sonuç işleniyor…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      GameHeaderBar(title: widget.offer.prompt),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GameWidget(game: _game),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
    );
  }
}
