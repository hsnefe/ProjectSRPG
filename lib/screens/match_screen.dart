import 'package:flutter/material.dart';
import 'package:project_srpg/game/match_feed.dart';
import 'package:project_srpg/game/match_labels.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/screens/intervention_shot_screen.dart';
import 'package:project_srpg/screens/intervention_tackle_screen.dart';
import 'package:project_srpg/screens/request_screen.dart';
import 'package:project_srpg/state/match_controller.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/intervention_offer_modal.dart';

/// Her iki mini oyun ekranının da döndürdüğü şekil: motora giden anahtar ve
/// `minigame_result` alanına giden ham etiket. Dart kayıtları yapısal olduğu
/// için `InterventionShotResult` ile `InterventionTackleResult` bununla aynı
/// tip — tek bir push ikisini de karşılıyor.
typedef _MinigameAnswer = ({String outcomeKey, String rawLabel});

class MatchScreen extends StatefulWidget {
  MatchScreen({
    super.key,
    required this.controller,
    this.careerSession,
    this.fixtureId,
    this.preMatchCondition,
    MatchApiClient? matchApiClient,
  }) : _matchApiClient = matchApiClient ?? MatchApiClient();

  /// Ekran, taze oluşturulmuş bir controller alır; bağlanma ve `dispose`
  /// yaşam döngüsünün tamamına burada sahip çıkılır.
  final MatchController controller;

  /// M2 (career_engine) çağrısı için — maç bittiğinde `_advance()` bunu
  /// kullanır. Üçü birlikte gelir; herhangi biri eksikse (örn. testler, ya da
  /// ileride bir kariyer fikstürüne bağlı olmayan bir dostluk maçı) M2 hiç
  /// çağrılmaz, ekran doğrudan ilerler — eski davranışın aynısı.
  final CareerSession? careerSession;
  final String? fixtureId;

  /// M1'in `engine_payload.user_condition`'ı (D38/D39) — maçın başladığı
  /// kondisyon. Ekrandaki çubuk buradan başlar ve controller'ın
  /// [MatchController.playerCondition] sayacıyla erir; M2'ye yazılan
  /// `final_condition` o sayacın son değeridir.
  final int? preMatchCondition;

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final MatchApiClient _matchApiClient;

  static const _warning = Color(0xFFE8B93D);

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final ScrollController _scroll = ScrollController();

  /// Skorbordun dakika butonu tarafından döngülenen akış hızı. Tempoyu sunucu
  /// uygular: her değişiklik `POST /matches/{id}/speed` ile bildirilir (E10),
  /// bu yüzden buradaki değer yalnızca butonun görünümünü değil gerçek SSE
  /// temposunu da yönetir. Backend'in varsayılanı da `slow`.
  final ValueNotifier<MatchSpeed> _speed = ValueNotifier(MatchSpeed.slow);

  int _lastEventCount = 0;
  bool _handledConnectionError = false;
  bool _reporting = false;

  /// Açık kalan teklifin `offer_id`'si — sunucu aynı anda en fazla bir açık
  /// teklife izin verdiği için `Set` değil tek değer yeterli. `_openOffer`'ın
  /// aynı teklif için iki kez ekran/panel açmasını önler.
  String? _shownOfferId;
  bool _offerDialogOpen = false;

  /// `_resolveViaMinigame`'in push ettiği route — `null` değilse bir mini
  /// oyun ekranı açık demektir. Route'un kendisini (yalnızca bir bayrağı
  /// değil) tutmak `_dismissMinigameScreen`'in **doğru** route'u hedeflemesini
  /// sağlar: `Navigator.pop()` her zaman tepedekini kapatır, oysa oyun
  /// kendini pop ettiği an ile `await push`'un çözülmesi arasındaki dar
  /// pencerede bir tick gelip ikinci bir "kapat" tetiklerse, ambient bir pop
  /// yanlışlıkla `MatchScreen`'in kendisini kapatabilirdi (§0 v1.7: sunucunun
  /// 180 sn'lik emniyet süresi artık ulaşılabilir bir yol, bu pencere artık
  /// olası). `route.isActive` bu yarışı kapatır.
  MaterialPageRoute<_MinigameAnswer>? _minigameRoute;

  /// Arka plana geçişte maçı sunucuda duraklatır, dönüşte sürdürür
  /// (`MatchController.handleAppLifecycle`).
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.connect();
    _lifecycle = AppLifecycleListener(
      onStateChange: widget.controller.handleAppLifecycle,
    );
  }

  void _cycleSpeed() {
    final next = _speed.value.next;
    setState(() => _speed.value = next);
    // Ateşle-ve-unut: `sendSpeed` kendi hatalarını yutar, buton her koşulda
    // duyarlı kalır.
    widget.controller.sendSpeed(next);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.controller.events.length > _lastEventCount) {
      _lastEventCount = widget.controller.events.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
    final offer = widget.controller.activeOffer;
    if (offer != null && _shownOfferId != offer.offerId) {
      _shownOfferId = offer.offerId;
      // notifyListeners bir build'in içinden gelebilir; mevcut kaydırma
      // bloğuyla aynı idiom kullanılıyor.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openOffer(offer));
    } else if (offer == null) {
      // activeOffer, bizim yanıtımız DIŞINDA bir yolla temizlendi - sunucunun
      // 180 sn emniyet zaman aşımı devreye girdi (ya da maç bitti). Açık olan
      // ne varsa kapatılır; hiçbir POST atılmaz, karar zaten verilmiş. §0
      // v1.7 ile mini oyun ekranı da bu yola girdi: FE'nin artık geri sayımı
      // olmadığı için bu emniyet süresi ulaşılabilir bir yol haline geldi.
      // İkisi de no-op olduğunda çağırmak zararsız.
      _dismissMinigameScreen();
      _dismissOfferDialog();
    }

    final error = widget.controller.connectionError;
    if (error != null && !_handledConnectionError) {
      _handledConnectionError = true;
      _handleConnectionError(error);
    }
  }

  /// Teklifi çözüm yoluna göre yönlendirir (§7.2, §0 v1.7).
  /// `engine` → karar paneli (geri sayım, risk_hint, iki buton, §7.2 [İ-A2]).
  /// `minigame` → panel YOK, ilgili mini oyun doğrudan açılır ve çıkışı yoktur.
  Future<void> _openOffer(InterventionOfferFrame offer) async {
    if (!mounted) return;
    // Kare arasında bir tick gelip teklifi kapatmış olabilir (sunucunun kendi
    // emniyet zaman aşımı) - ölü bir panel/ekran açmayalım.
    if (widget.controller.activeOffer?.offerId != offer.offerId) return;

    if (offer.resolution == 'minigame') {
      await _resolveViaMinigame(offer);
    } else {
      await _openOfferDialog(offer);
    }
  }

  /// `intervention_offer` teklifini modalla gösterir ve dönen karara göre
  /// `MatchController`'ı yanıtlar (§7.2). Yalnızca `resolution:"engine"`
  /// teklifleri için çağrılır — `minigame` teklifleri `_openOffer` tarafından
  /// buraya hiç uğratılmadan `_resolveViaMinigame`'e yönlendirilir.
  Future<void> _openOfferDialog(InterventionOfferFrame offer) async {
    if (!mounted) return;

    _offerDialogOpen = true;
    final choice = await showInterventionOffer(context, offer: offer);
    _offerDialogOpen = false;
    if (!mounted) return;

    switch (choice) {
      case InterventionChoice.intervene:
        await widget.controller.acceptOffer();
      case InterventionChoice.decline:
        await widget.controller.declineOffer(reason: 'user');
      case InterventionChoice.timeout:
        await widget.controller.declineOffer(reason: 'timeout');
      case null:
        // Programatik kapatma (akış koptu) - POST atılmaz, teklif sunucuda
        // açık kalır ve 180 sn'de `decline` edilir. Zaten ekrandan çıkıyoruz.
        break;
    }
  }

  /// `resolution:"minigame"` bir teklif geldiğinde teklifin `minigame`
  /// alanına göre ilgili tam ekran oyunu açar, sonucu bekler, dönen
  /// `outcome_key`/`minigame_result` ile controller'ı yanıtlar.
  ///
  /// **Mini oyunun çıkışı yoktur (§0 v1.7)** — ekranların kendisi hiçbir
  /// zaman `null` döndürmez, `_maybeFinish` daima dolu bir kayıt pop'lar.
  /// `result == null` yalnızca `_dismissMinigameScreen`'in bu ekranı
  /// **bizim tarafımızdan** kapattığı anlamına gelir (sunucunun 180 sn'lik
  /// emniyet süresi doldu, ya da akış koptu) — teklif o noktada zaten kapalı
  /// olduğundan bir POST 409 `offer_closed` alırdı, o yüzden atılmaz. "Bizim
  /// tarafımızdan kapatma" ile "normal bitiş" ayrımı bir bayrakla değil, pop
  /// değerinin kendisiyle yapılıyor: ekranların `_maybeFinish`'i dışında
  /// hiçbir yer pop çağırmıyor.
  ///
  /// Tanınmayan bir `minigame` değeri şut ekranına düşer: §7.2 alanı serbest
  /// bir string olarak tanımlıyor ve motorun ileride ekleyeceği bir değer
  /// yüzünden teklifi açıkta bırakmak akışı kırmak olurdu.
  Future<void> _resolveViaMinigame(InterventionOfferFrame offer) async {
    if (!mounted) return;
    final route = MaterialPageRoute<_MinigameAnswer>(
      builder: (_) => offer.minigame == 'tackle'
          ? InterventionTackleScreen(offer: offer)
          : InterventionShotScreen(offer: offer),
    );
    _minigameRoute = route;
    final result = await Navigator.of(context).push(route);
    _minigameRoute = null;
    if (!mounted || result == null) return;
    await widget.controller.acceptOffer(
      outcomeKey: result.outcomeKey,
      minigameResult: result.rawLabel,
    );
  }

  /// Açık teklif panelini programatik olarak kapatır (`null` döndürerek —
  /// böylece hiçbir E5 POST'u atılmaz).
  void _dismissOfferDialog() {
    if (!_offerDialogOpen) return;
    _offerDialogOpen = false;
    Navigator.of(context).pop();
  }

  /// Açık mini-oyun ekranını programatik olarak kapatır. `Navigator.pop()`
  /// yerine tutulan route'u hedefleyerek: oyun kendini pop ettiği an ile
  /// `_resolveViaMinigame`'in `await push`'unun çözülmesi arasında dar bir
  /// pencere var, o pencerede bir tick gelirse `route.isActive` artık
  /// `false`'dur ve bu çağrı no-op'a düşer — tepedeki (olabilecek başka)
  /// route'u yanlışlıkla kapatmaz.
  void _dismissMinigameScreen() {
    final route = _minigameRoute;
    if (route == null || !route.isActive) return;
    _minigameRoute = null;
    Navigator.of(context).removeRoute(route);
  }

  /// SSE akışı koptuğunda/404 döndüğünde (reconnect bu turda yok, §9.1) —
  /// kullanıcıya mesajı gösterip bir önceki ekrana döner.
  ///
  /// ⚠️ Açık bir müdahale paneli/mini oyun ekranı varken önce onları kapatmak
  /// şart: ikisi de `PopScope(canPop:false)` ile sistem geri hareketini
  /// yutuyor (panel §7.2, mini oyun §0 v1.7) ve mini oyun ayrıca kendi
  /// push'lu route'unda; aşağıdaki `maybePop` bunlardan biri üstteyken
  /// çağrılırsa ekranı değil o route'u kapatır ve kullanıcı canlı bir SSE
  /// hatasıyla çıkışsız bir ekranda kalır. Sıra önemli: önce mini oyun, sonra
  /// panel — ikisi aynı anda açık olamaz ama kod bu varsayıma dayanmıyor.
  void _handleConnectionError(String message) {
    _dismissMinigameScreen();
    _dismissOfferDialog();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maç akışı kesildi: $message'),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  /// Maç bitti — M2'ye (career_engine) sonucu yazar, sonra canlı ekranın
  /// yerini maç sonrası akışı alır. `pushReplacement` olduğu için
  /// `MatchScreen.dispose` çalışır: controller ve SSE aboneliği kapanır, geri
  /// tuşu bitmiş maça dönmez.
  ///
  /// `interventions`, controller'ın tick'lerin `resolved_intervention`
  /// bloğundan biriktirdiği defterdir (`MatchController.interventions`,
  /// §3.1) — `outcome_key` zarını sunucu attığı için tek doğruluk kaynağı
  /// odur. career_engine D13 bireysel gol sayısını buradan türetir: şut
  /// aksiyonlarının en iyi dalı bir goldür.
  ///
  /// `final_condition`, controller'ın maç boyunca eritilmiş
  /// [MatchController.playerCondition] sayacıdır (D38, CONTRACT §6.6):
  /// maç öncesi kondisyondan başlar, motorun bildirdiği erime kadar düşer.
  /// `final_condition ≤ pre_match_condition` bu yüzden yapısal olarak
  /// sağlanır — sayaç yalnızca düşer.
  Future<void> _advance() async {
    final careerSession = widget.careerSession;
    final fixtureId = widget.fixtureId;
    final preMatchCondition = widget.preMatchCondition;
    if (careerSession == null || fixtureId == null || preMatchCondition == null) {
      _goToRequestScreen(null);
      return;
    }

    setState(() => _reporting = true);
    MatchResultResponse? result;
    try {
      final summary = await widget._matchApiClient
          .fetchSummary(widget.controller.matchId);
      final body = {
        'match_id': widget.controller.matchId,
        'score': {'home': summary.score.home, 'away': summary.score.away},
        'stats': summary.stats,
        'final_possession_home': summary.finalPossessionHome,
        'final_condition':
            widget.controller.playerCondition.clamp(35, preMatchCondition),
        // §12.2 · ne kadarını gerçekten oynadığı. İlk 11'de başlayıp 95'e
        // kadar kalmak eski varsayımın aynısı; yedek girmek ya da oyundan
        // çıkarılmak artık sezon istatistiğine doğru yansıyor.
        'started': widget.controller.started,
        'minutes_played': widget.controller.minutesPlayed,
        // M2 · oyuncunun **kendi** disiplini — `stats` bloğundaki kart
        // sayıları takımın tamamına ait, kullanıcıya değil. v1'de motor kartı
        // isimsiz bir savunmacıya yazıyor ve kimin gördüğünü tel üzerinde
        // taşımıyor, yani kullanıcı kart göremez; alan sıfır kalır. Motor
        // kartı sahiplendirdiği gün doldurulacak yer burası.
        'user_cards': const {'yellow': 0, 'red': 0},
        'interventions': widget.controller.interventions
            .map((e) => {
                  'minute': e.minute,
                  'action_key': e.actionKey,
                  'outcome_key': e.outcomeKey,
                })
            .toList(),
        // §12.10 · yalnızca ölçülebildiyse. Sahaya hiç çıkmadıysa ya da
        // talimat "farketmez" ise `null` döner ve alan hiç gönderilmez;
        // BE yokluğu "ölçülmedi" sayar, "tam uydu" değil.
        if (widget.controller.tacticalCompliance case final compliance?)
          'tactical_compliance': compliance,
      };
      final careerId = await careerSession.resolve();
      result = await careerSession.client.reportMatchResult(
        careerId,
        fixtureId,
        body,
      );
      if (!mounted) return;
      PlayerScope.of(context).applyServerUpdate(careerState: result.careerState);
    } catch (_) {
      // §6.4'ün bilinen riski: sonuç yazılamazsa fikstür 'in_progress' kalır,
      // bir sonraki M1 çağrısı bunu M3 ile kurtarır (pre_match_screen.dart).
      // Kullanıcıyı burada tıkanık bırakmıyoruz — maç zaten bitti, ilerlemek
      // tek makul seçenek.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maç sonucu kaydedilemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
    if (!mounted) return;
    _goToRequestScreen(result);
  }

  void _goToRequestScreen(MatchResultResponse? result) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RequestScreen(
          result: result,
          userStats: widget.controller.userMatchStats,
          homeTeamName: widget.controller.teams.home.name,
          awayTeamName: widget.controller.teams.away.name,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.dispose();
    _speed.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final panelHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        24;

    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: panelHeight,
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
                        _MatchBar(
                          home: controller.teams.home.name,
                          away: controller.teams.away.name,
                          homeGoals: controller.score.home,
                          awayGoals: controller.score.away,
                          minute: controller.minute,
                          speed: _speed.value,
                          onSpeedTap: _cycleSpeed,
                        ),
                        _PhaseStrip(situation: controller.situation),
                        _PossessionBar(possession: controller.possession),
                        _TeamStatusRow(team: controller.team),
                        Expanded(
                          child: _CommentaryFeed(
                            events: controller.events,
                            controller: _scroll,
                            pendingOfferPrompt: controller.pendingOfferPrompt,
                          ),
                        ),
                        _ActionBar(
                          controller: controller,
                          onAdvance: _advance,
                          advancing: _reporting,
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

class _MatchBar extends StatelessWidget {
  const _MatchBar({
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.minute,
    required this.speed,
    required this.onSpeedTap,
  });

  final String home;
  final String away;
  final int homeGoals;
  final int awayGoals;
  final int minute;
  final MatchSpeed speed;

  /// Dakika butonu: her basışta hızı bir kademe ilerletir.
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: _ScoreChip(
                    tint: AppColors.accent,
                    tintBg: AppColors.accentBg,
                    child: Text(
                      home,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ScoreChip(
                  minWidth: 30,
                  child: Text(
                    '$homeGoals',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ScoreChip(
                  minWidth: 30,
                  child: Text(
                    '$awayGoals',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ScoreChip(
                    tint: AppColors.danger,
                    tintBg: AppColors.dangerBg,
                    child: Text(
                      away,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Tooltip(
              message: 'Akış hızı: ${speed.label}',
              child: OutlinedButton(
                onPressed: onSpeedTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: AppColors.surface1,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_run_outlined, size: 16),
                        for (var i = 0; i < speed.arrows; i++)
                          const Icon(Icons.play_arrow_rounded, size: 12),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$minute'",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skorbordun altındaki ince, ortalanmış maç durumu şeridi. İlk tick
/// gelene kadar sabit "Kick Off" gösterir; sonrasında `situation`'ın
/// Türkçe karşılığını çizer (§3.3).
class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip({required this.situation});

  final String? situation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        situation == null ? 'Kick Off' : situationLabel(situation!),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// İki takımın top hakimiyeti yüzdesini yatay iki segment olarak çizer.
/// İlk tick gelene kadar 50/50 nötr bir çizgi gösterir.
class _PossessionBar extends StatelessWidget {
  const _PossessionBar({required this.possession});

  final PossessionInfo? possession;

  @override
  Widget build(BuildContext context) {
    final home = possession?.home ?? 50;
    final away = possession?.away ?? 50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '%$home',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Text(
                'Top hakimiyeti',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              const Spacer(),
              Text(
                '%$away',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: home,
                    child: const ColoredBox(color: AppColors.accent),
                  ),
                  Expanded(
                    flex: away,
                    child: const ColoredBox(color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kullanıcının takımının anlık duruşu: mentalite etiketi + sarı/kırmızı
/// kart sayaçları (§3.2, takım toplamı — bireysel oyuncu katmanı yok).
class _TeamStatusRow extends StatelessWidget {
  const _TeamStatusRow({required this.team});

  final TeamTickInfo? team;

  @override
  Widget build(BuildContext context) {
    final mentality = team == null ? '—' : mentalityLabel(team!.mentality);
    final yellow = team?.yellowCards ?? 0;
    final red = team?.redCards ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_outlined,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            mentality,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          if (yellow > 0) _CardBadge(color: MatchScreen._warning, count: yellow),
          if (yellow > 0 && red > 0) const SizedBox(width: 8),
          if (red > 0) _CardBadge(color: AppColors.danger, count: red),
        ],
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.child,
    this.minWidth,
    this.tint,
    this.tintBg,
  });

  final Widget child;
  final double? minWidth;
  final Color? tint;
  final Color? tintBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tintBg ?? AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
        border: tint == null ? null : Border.all(color: tint!, width: 0.5),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Kayan maç yorumu akışı. Ekranın boş sahne yer tutucusunun yerini alır.
///
/// Bir teklif geldiği anda `MatchController` onun `prompt`'unu bu akışa da
/// normal bir satır olarak ekler (`touch_app_outlined` ikonuyla) — modal
/// kapandıktan sonra da kullanıcı o anın ne olduğunu feed'de görsün diye.
/// Bu yüzden bir teklif varken `events` artık asla boş değildir; boş durum
/// yalnızca ilk tick hiç gelmemişken görülür.
///
/// Karar beklenen ANDA gösterilen şey `InterventionOfferModal`'dır (§7.2) —
/// `pendingOfferPrompt` onun **dışındaki** üç durum için kullanılır: (1)
/// yanıtımız gönderildikten sonra bir sonraki tick'i bekleme, (2) POST'ta ağ
/// hatası (teklif sunucuda açık kalır, 180 sn'de kendiliğinden çözülür), (3)
/// modal gösterilemezken gelen bir teklif. Bu üçünde de akış geçici olarak
/// durur — kullanıcıya bağlantının donmadığını gösterir.
class _CommentaryFeed extends StatelessWidget {
  const _CommentaryFeed({
    required this.events,
    required this.controller,
    required this.pendingOfferPrompt,
  });

  final List<MatchEvent> events;
  final ScrollController controller;
  final String? pendingOfferPrompt;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'Maç başlıyor…',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        if (pendingOfferPrompt != null) _WaitingBanner(prompt: pendingOfferPrompt!),
        Expanded(
          child: ListView.separated(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _EventCard(event: events[index]),
          ),
        ),
      ],
    );
  }
}

/// Akışta olaylar zaten varken araya bir teklif girdiğinde gösterilen ince
/// üst şerit.
class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.accentBg,
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              prompt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final side = event.side;
    final isNeutral = side == MatchSide.neutral;
    final tint = side == MatchSide.home
        ? AppColors.accent
        : side == MatchSide.away
            ? AppColors.danger
            : AppColors.textMuted;
    final tintBg = side == MatchSide.home
        ? AppColors.accentBg
        : side == MatchSide.away
            ? AppColors.dangerBg
            : AppColors.surface1;
    final alignment = side == MatchSide.home
        ? Alignment.centerLeft
        : side == MatchSide.away
            ? Alignment.centerRight
            : Alignment.center;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tintBg,
        borderRadius: BorderRadius.circular(8),
        border: event.isGoal ? Border.all(color: tint, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${event.minute}'",
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (event.icon != null) ...[
            Icon(event.icon, size: 14, color: tint),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              event.text,
              style: TextStyle(
                color: event.isGoal ? tint : AppColors.textPrimary,
                fontSize: event.isGoal ? 13 : 12,
                fontWeight: event.isGoal ? FontWeight.w700 : FontWeight.w400,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isNeutral
              ? double.infinity
              : MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: isNeutral ? SizedBox(width: double.infinity, child: card) : card,
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.controller,
    required this.onAdvance,
    this.advancing = false,
  });

  final MatchController controller;

  /// Maç bittiğinde direktif butonlarının yerini alan "İlerle" eylemi —
  /// M2'ye sonucu yazar, bu yüzden `VoidCallback` değil async.
  final Future<void> Function() onAdvance;

  /// M2 çağrısı sürerken "İlerle" butonu pasifleşir ve dönen bir gösterge
  /// gösterir — çift tıkla iki kez rapor edilmesin.
  final bool advancing;

  void _showNote(BuildContext context, String? note) {
    if (note == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(note),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _closestIndex(List<int> values, int? current) {
    final target = current ?? 50;
    var bestIndex = 0;
    var bestDiff = 1 << 30;
    for (var i = 0; i < values.length; i++) {
      final diff = (values[i] - target).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  /// `projected_end_stamina` motorun tablosunda daima 100'den başlayan bir
  /// maç varsayar (§8.1); oyuncu kendi kondisyonundan başladığı için aynı
  /// erime miktarı onun başlangıcına uygulanır — formül aynı, girdi farklı
  /// (CONTRACT §6.6).
  int _projectedEndCondition(EffortOption option) {
    final drain = controller.staminaCatalog.ceiling - option.projectedEndStamina;
    return (controller.startCondition - drain)
        .clamp(controller.staminaCatalog.floor, controller.startCondition);
  }

  Future<void> _openEffortSheet(BuildContext context) async {
    final options = controller.directiveOptions.effort;
    if (options.isEmpty) return;
    var index = _closestIndex(
      options.map((o) => o.value).toList(),
      controller.directives?.effort,
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selected = options[index];
            return _DirectiveSheet(
              title: 'Efor',
              valueLabel: selected.label,
              detailLabel: 'Maç başına ~${selected.offersPerMatch} teklif · '
                  'Kondisyon çarpanı ×${selected.staminaMultiplier.toStringAsFixed(2)} · '
                  'Tahmini bitiş kondisyonu ${_projectedEndCondition(selected)}',
              sliderIndex: index,
              sliderMax: options.length - 1,
              onSliderChanged: (v) => setSheetState(() => index = v),
              onConfirm: () async {
                Navigator.of(sheetContext).pop();
                await controller.sendDirective(effort: selected.value);
                if (context.mounted) {
                  _showNote(context, controller.lastDirectiveNote);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openAggressionSheet(BuildContext context) async {
    final options = controller.directiveOptions.aggression;
    if (options.isEmpty) return;
    var index = _closestIndex(
      options.map((o) => o.value).toList(),
      controller.directives?.aggression,
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selected = options[index];
            return _DirectiveSheet(
              title: 'Sertlik',
              valueLabel: selected.label,
              detailLabel: 'Faul çarpanı ×${selected.foulMultiplier.toStringAsFixed(2)}',
              sliderIndex: index,
              sliderMax: options.length - 1,
              onSliderChanged: (v) => setSheetState(() => index = v),
              onConfirm: () async {
                Navigator.of(sheetContext).pop();
                await controller.sendDirective(aggression: selected.value);
                if (context.mounted) {
                  _showNote(context, controller.lastDirectiveNote);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openFocusSheet(BuildContext context) async {
    final options = controller.directiveOptions.focus;
    if (options.isEmpty) return;
    final currentFocus = controller.directives?.focus;
    var index = options.indexWhere((o) => o.value == currentFocus);
    if (index < 0) index = options.indexWhere((o) => o.value == null);
    if (index < 0) index = 0;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return _FocusSheet(
              options: options,
              selectedIndex: index,
              onSelected: (v) => setSheetState(() => index = v),
              onConfirm: () async {
                final selected = options[index];
                Navigator.of(sheetContext).pop();
                await controller.sendDirective(focus: selected.value);
                if (context.mounted) {
                  _showNote(context, controller.lastDirectiveNote);
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          _ConditionBar(
            condition: controller.playerCondition,
            catalog: controller.staminaCatalog,
          ),
          const SizedBox(height: 14),
          // Maç bitince direktif göndermenin anlamı kalmaz — üç buton tek bir
          // ileri adımla değişir, kondisyon barı son değeriyle görünür kalır.
          if (controller.finished)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: advancing ? null : () => onAdvance(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  disabledForegroundColor: AppColors.textMuted,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                icon: advancing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward, size: 16),
                label: const Text('İlerle'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _MatchActionButton(
                    icon: Icons.bolt_outlined,
                    label: 'Efor',
                    onPressed: () => _openEffortSheet(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MatchActionButton(
                    icon: Icons.track_changes_outlined,
                    label: 'Rol',
                    onPressed: () => _openFocusSheet(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MatchActionButton(
                    icon: Icons.shield_outlined,
                    label: 'Sertlik',
                    onPressed: () => _openAggressionSheet(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Oyuncunun kondisyon barı (D38) — maç ekranındaki kondisyon oyuncunun
/// kendi kondisyonudur, "takım kondisyonu" diye ayrı bir kavram yoktur.
/// Taban/tavan `StaminaCatalog`'dan gelir, hardcode edilmez (§6.4, §8.1).
class _ConditionBar extends StatelessWidget {
  const _ConditionBar({required this.condition, required this.catalog});

  final int condition;
  final StaminaCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final range = (catalog.ceiling - catalog.floor).clamp(1, 1 << 30);
    final frac = ((condition - catalog.floor) / range).clamp(0.0, 1.0);
    final color = frac >= 0.6
            ? AppColors.success
            : frac >= 0.3
                ? MatchScreen._warning
                : AppColors.danger;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kondisyon',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            Text(
              '$condition/${catalog.ceiling}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            backgroundColor: AppColors.surface1,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Efor/Sertlik sheet'lerinin ortak gövdesi: başlık, seçili etiket, ek
/// bilgi satırı, 5 kademeye snap eden slider ve onay butonu.
class _DirectiveSheet extends StatelessWidget {
  const _DirectiveSheet({
    required this.title,
    required this.valueLabel,
    required this.detailLabel,
    required this.sliderIndex,
    required this.sliderMax,
    required this.onSliderChanged,
    required this.onConfirm,
  });

  final String title;
  final String valueLabel;
  final String detailLabel;
  final int sliderIndex;
  final int sliderMax;
  final ValueChanged<int> onSliderChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            valueLabel,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detailLabel,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          Slider(
            value: sliderIndex.toDouble(),
            min: 0,
            max: sliderMax.toDouble(),
            divisions: sliderMax == 0 ? null : sliderMax,
            activeColor: AppColors.accent,
            onChanged: (v) => onSliderChanged(v.round()),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Uygula'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rol (focus) sheet'i — 4 seçenekli (hücum/savunma/taktik/farketmez)
/// segmented chip listesi.
class _FocusSheet extends StatelessWidget {
  const _FocusSheet({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    required this.onConfirm,
  });

  final List<FocusOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rol',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++)
                ChoiceChip(
                  label: Text(options[i].label),
                  selected: i == selectedIndex,
                  onSelected: (_) => onSelected(i),
                  selectedColor: AppColors.accentBg,
                  backgroundColor: AppColors.surface1,
                  labelStyle: TextStyle(
                    color: i == selectedIndex
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Uygula'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchActionButton extends StatelessWidget {
  const _MatchActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
