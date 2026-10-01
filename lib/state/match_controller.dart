import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;

import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../boot/python_host.dart';
import '../game/event_icons.dart';
import '../game/intervention_stats.dart';
import '../game/match_feed.dart';
import '../net/api_config.dart';
import '../net/match_api_client.dart';
import '../net/match_models.dart';
import '../net/match_sse_client.dart';

/// Bir maçın canlı durumunu tutan controller — `PlayerState`'in izlediği
/// `ChangeNotifier` idiomunu takip eder (Provider/Riverpod eklenmez).
///
/// `GET /matches/{id}/stream`'e bağlanır, her `tick` zarfını uygular ve
/// birikimli bir olay listesi tutar (her tick'in `events[]`'i geçmişin
/// tamamı değil, o dakikaya ait yeni satırlardır — §3.2). `intervention_offer`
/// zarfı [activeOffer]'ı doldurur — ekran bunu görünce bir modal açar ve
/// [acceptOffer]/[declineOffer] ile yanıtlar. Kabul edilen bir müdahalenin
/// sonucu (`outcome_key`) sunucu tarafından atıldığı için FE'ye yalnızca
/// çözümlendiği tick'in `resolved_intervention` bloğuyla ulaşır; bu blok
/// [interventions] defterine biriktirilir (§7.2/§3.1).
class MatchController extends ChangeNotifier {
  MatchController({
    required this.matchId,
    required this.streamUrl,
    required this.userSide,
    required this.teams,
    required this.staminaCatalog,
    required this.directiveOptions,
    this.squadStatus = 'first_eleven',
    this.coachInstruction,
    int? startCondition,
    MatchApiClient? apiClient,
    MatchStreamSource? streamSource,
    PythonHost? host,
    List<Duration>? reconnectDelays,
  })  : startCondition = startCondition ?? staminaCatalog.ceiling,
        _playerCondition = (startCondition ?? staminaCatalog.ceiling).toDouble(),
        _apiClient = apiClient ?? MatchApiClient(),
        _streamSource = streamSource ?? HttpMatchSseClient(),
        _host = host ?? PythonHost.instance,
        _reconnectDelays = reconnectDelays ?? defaultReconnectDelays;

  /// Akış koptuğunda yeniden bağlanma aralıkları (sırayla); hepsi tükenirse
  /// [connectionError] dolar. Toplam ~15 sn: gözetmenin soketi yeniden
  /// bağlaması (~2 sn) ve Python'un kalkması bunun çok altında kalır.
  static const defaultReconnectDelays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 700),
    Duration(milliseconds: 1500),
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 6),
  ];

  final String matchId;

  /// `/start`'ın döndürdüğü göreli yol (örn. `/matches/m_xxx/stream`).
  final String streamUrl;
  final String userSide;
  final MatchTeams teams;
  final StaminaCatalog staminaCatalog;
  final DirectiveOptions directiveOptions;

  /// §12.2 M1 · `first_eleven` | `bench`. `out` buraya hiç ulaşmaz — o
  /// fikstür M1'de teklif edilmiyor, arka plan simülasyonuna düşüyor.
  final String squadStatus;

  /// §12.10 · antrenörün bu maç için verdiği talimat — M1 `coach_instruction
  /// .focus`, wire'ın kendi ölçeğinde (`"attack"|"defend"|"tactical"|null`,
  /// `null` = "farketmez"). `null` iken uyum **ölçülmez**, 1.0 sayılmaz:
  /// aksi halde talimatı "farketmez" olan bir rol seçmek bedelsiz kalıcı bir
  /// +1 olurdu.
  final String? coachInstruction;

  /// Oyuncunun maça girdiği kondisyon — career_engine M1'in
  /// `engine_payload.user_condition`'ı (D38). Maç boyunca yalnızca bu sayı
  /// erir; kariyer merkezindeki çubukla aynı kavramdır.
  final int startCondition;

  final MatchApiClient _apiClient;
  final MatchStreamSource _streamSource;
  final PythonHost _host;
  final List<Duration> _reconnectDelays;

  /// Alınan en büyük zarf `seq`'i — yeniden bağlanırken `Last-Event-ID`.
  int _lastSeq = 0;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  /// Uygulama arka plandayken (`hidden`/`paused`) true: maç sunucuda
  /// duraklatıldı, akıştaki hatalar yok sayılır ve dönüşte tazelenir.
  bool _backgrounded = false;

  StreamSubscription<MatchStreamMessage>? _subscription;
  int _requestSeq = 0;

  int _minute = 0;
  bool _finished = false;
  ScoreInfo _score = const ScoreInfo(home: 0, away: 0);
  PossessionInfo? _possession;
  TeamTickInfo? _team;
  String? _situation;
  DirectivesInfo? _directives;
  final List<MatchEvent> _events = [];
  String? _connectionError;
  String? _lastDirectiveNote;
  String? _pendingOfferPrompt;

  double _playerCondition;
  int? _lastTickStamina;

  /// §12.2 · oyuncunun sahada olup olmadığı. İlk 11'de başlarsa baştan
  /// true, yedekte başlarsa antrenör kulübeye dönene kadar false.
  late bool _onPitch = squadStatus == 'first_eleven';

  /// Sahaya çıkılan ve sahadan çıkılan dakikalar. İkisi birlikte M2'nin
  /// `minutes_played`'ini veriyor.
  late int? _onMinute = squadStatus == 'first_eleven' ? 0 : null;
  int? _offMinute;

  /// §12.10 · uyum biriktiricisi. `_lastJudgedMinute`/`_lastJudgedFocus`/
  /// `_wasOnPitchAtLastTick` bir önceki tick'in "yargılanacak" durumunu
  /// taşır — bkz. [_accrueCompliance].
  int _compliantMinutes = 0;
  int _judgedMinutes = 0;
  int? _lastJudgedMinute;
  String? _lastJudgedFocus;
  bool _wasOnPitchAtLastTick = false;

  bool _disposed = false;
  InterventionOfferFrame? _activeOffer;
  final List<InterventionLogEntry> _interventions = [];
  final Set<String> _offeredIds = {};

  int get minute => _minute;
  bool get finished => _finished;
  ScoreInfo get score => _score;
  PossessionInfo? get possession => _possession;

  /// İlk tick gelene kadar `null` — zarfın kondisyon/kart sayaçları.
  TeamTickInfo? get team => _team;

  /// Oyuncunun o anki kondisyonu (D38): [startCondition]'dan başlar, her
  /// tick'te motorun bildirdiği erime kadar düşer, tabanda durur.
  ///
  /// Erimeyi motor hesaplıyor — hız `effort` direktifine bağlıdır (D39) —
  /// ama motorun sayacı daima 100'den başlar; oyuncununki kendi
  /// kondisyonundan. Bu yüzden mutlak değer değil, tick'ler arasındaki
  /// **fark** taşınır: aynı eğri, farklı başlangıç (CONTRACT §6.6). Maç
  /// sonunda bu değer M2'ye `final_condition` olarak yazılır.
  int get playerCondition => _playerCondition.round();
  String? get situation => _situation;
  DirectivesInfo? get directives => _directives;
  List<MatchEvent> get events => List.unmodifiable(_events);

  /// Dolu ise SSE bağlantısı kopup **yeniden bağlanma hakları da tükendi**
  /// (ya da 4xx döndü) — UI bu durumda ekrandan çıkıp mesaj göstermeli.
  String? get connectionError => _connectionError;

  /// Akış koptu, bir sonraki yeniden bağlanma denemesi bekleniyor.
  bool get isReconnecting => _reconnectTimer != null;

  /// Uygulama arka planda; maç sunucuda duraklatıldı.
  bool get isBackgrounded => _backgrounded;

  String? get lastDirectiveNote => _lastDirectiveNote;

  /// Dolu ise sunucu bir `intervention_offer` yayınladı ve karar (kullanıcı
  /// yanıtı ya da 180s güvenlik zaman aşımı) beklenirken bir sonraki tick
  /// gelmiyor — UI bu sırada boş/donmuş görünmesin diye kullanılır.
  String? get pendingOfferPrompt => _pendingOfferPrompt;

  /// Dolu ise sunucu bir teklif yayınladı ve hâlâ yanıt bekliyor — ekran
  /// bunu gördüğünde modalı açar. Bir tick geldiği anda (yanıtımızla ya da
  /// sunucunun 180 sn emniyet zaman aşımıyla) temizlenir.
  InterventionOfferFrame? get activeOffer => _activeOffer;

  /// M2'ye (`interventions[]`, D13) yazılacak defter. Girdiler yalnızca
  /// tick'lerin `resolved_intervention` bloğundan gelir: `outcome_key`
  /// zarını sunucu attığı için tek doğruluk kaynağı odur.
  List<InterventionLogEntry> get interventions => List.unmodifiable(_interventions);

  /// §12.2 · oyuncu şu anda sahada mı. Müdahale teklifleri yalnızca sahadayken
  /// kabul edilir — kulübeden top kapamazsın.
  bool get onPitch => _onPitch;

  /// M2'nin `started` alanı.
  bool get started => squadStatus == 'first_eleven';

  /// M2'nin `minutes_played`'i. Sahaya hiç çıkılmadıysa 0; çıkılıp
  /// çıkarıldıysa aradaki fark; sonuna kadar oynandıysa son dakikaya kadar.
  int get minutesPlayed {
    final on = _onMinute;
    if (on == null) return 0;
    final off = _offMinute ?? (_finished ? _minute : _minute);
    return (off - on).clamp(0, 95);
  }

  /// §12.10 · M2'nin `tactical_compliance`'ı, 0.0–1.0. Ölçülecek hiç dakika
  /// yoksa `null` — alan gövdeye **hiç yazılmaz**. Bu, "ölçülmedi" ile "tam
  /// uydu"yu ayırmak için: [coachInstruction] `null` olan ("farketmez") bir
  /// rol 1.0 raporlasaydı, o rolü seçmek bedelsiz bir +1 olurdu.
  double? get tacticalCompliance =>
      _judgedMinutes <= 0 ? null : _compliantMinutes / _judgedMinutes;

  /// Maç boyunca sunulan teklif sayısı — kabul/ret/zaman aşımı ayrımı
  /// yapılmaz, `offer_id`'ye göre tekilleştirilir (E8 replay'i aynı teklifi
  /// yeniden yayınlar). [interventions] yalnızca **kabul edilenleri**
  /// tuttuğu için ("decline" hiç `resolved_intervention` üretmez, §3.1) bu
  /// sayaç ayrı tutulmak zorunda.
  int get offerCount => _offeredIds.length;

  /// Maç sonu ekranının oyuncu satırları (fırsat/şut) — E9'un takım geneli
  /// sayaçlarından değil, oyuncunun kendi müdahale defterinden türetilir
  /// (bkz. `game/intervention_stats.dart`).
  UserMatchStats get userMatchStats {
    var shots = 0;
    var onTarget = 0;
    for (final entry in _interventions) {
      if (!isPlayerShot(entry.actionKey, entry.outcomeKey)) continue;
      shots++;
      if (isShotOnTarget(entry.actionKey, entry.outcomeKey)) onTarget++;
    }
    return UserMatchStats(
      opportunities: offerCount,
      shots: shots,
      shotsOnTarget: onTarget,
    );
  }

  void connect() => _open();

  /// (Yeniden) bağlanır; önceki abonelik kapatılır. Daha önce zarf alındıysa
  /// `Last-Event-ID` ile yalnızca eksik olanlar gelir.
  void _open() {
    _subscription?.cancel();
    final uri = Uri.parse('${ApiConfig.baseUrl}$streamUrl');
    _subscription = _streamSource
        .connect(uri, lastEventId: _lastSeq > 0 ? '$_lastSeq' : null)
        .listen(_onMessage, onError: _onStreamError, onDone: _onStreamDone);
  }

  /// Uygulama yaşam döngüsü (MatchScreen'in `AppLifecycleListener`'ından).
  ///
  /// Arka plana geçerken maç sunucuda duraklatılır: telefon içi Python da
  /// askıya alınır ya da soketleri geri alınır, canlı bir maç ise o sırada
  /// tick üretip kullanıcıdan gizlice ilerlemesin. `inactive` (bildirim
  /// gölgesi, çağrı) geçici olduğu için yok sayılır.
  void handleAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _goToBackground();
      case AppLifecycleState.resumed:
        _returnToForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _goToBackground() async {
    if (_backgrounded || _finished || _disposed) return;
    _backgrounded = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _apiClient.postPause(matchId, reason: 'app_backgrounded');
    } catch (_) {
      // Sunucu zaten ulaşılmazsa duraklatılacak bir şey de ilerlemiyordur;
      // dönüşte `resume` + yeniden bağlanma yine doğruyu kurar.
    }
  }

  Future<void> _returnToForeground() async {
    if (!_backgrounded || _disposed) return;
    // Önce motorlar: soketler geri alındıysa gözetmen yeniden bağlayana dek
    // beklenir, yoksa `resume` ilk istekte bağlantı hatası verirdi.
    final healthy = await _host.recover();
    if (_disposed) return;
    if (!healthy) {
      _failConnection('Oyun motoru yanıt vermiyor.');
      return;
    }
    _backgrounded = false;
    if (_finished) return;
    try {
      await _apiClient.postResume(matchId, reason: 'app_backgrounded');
    } on MatchApiException catch (e) {
      if (_disposed) return;
      if (e.statusCode == 404) {
        _failConnection('Maç sunucuda bulunamadı.');
        return;
      }
    } catch (_) {
      // Yeniden bağlanma kendi yeniden denemesiyle sürer.
    }
    if (_disposed) return;
    // Askıdan dönen TCP bağlantısı sessizce ölü olabilir (hata vermeden);
    // her dönüşte tazelenir. `Last-Event-ID` sayesinde boşluk/tekrar yok.
    _reconnectAttempt = 0;
    _open();
  }

  void _failConnection(String message) {
    _connectionError = message;
    notifyListeners();
  }

  /// Bir sonraki yeniden bağlanma denemesini kurar; hak kalmadıysa `false`.
  bool _scheduleReconnect() {
    if (_reconnectTimer != null) return true;
    if (_reconnectAttempt >= _reconnectDelays.length) return false;
    final delay = _reconnectDelays[_reconnectAttempt++];
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_disposed || _finished || _backgrounded) return;
      _open();
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  void _onMessage(MatchStreamMessage message) {
    _reconnectAttempt = 0; // veri geldi: bağlantı çalışıyor
    if (message is MatchTickMessage) {
      if (message.tick.seq > _lastSeq) _lastSeq = message.tick.seq;
      // Tick geldiyse teklif kapandı - yanıtımızla ya da sunucunun 180 sn
      // emniyet zaman aşımıyla.
      _activeOffer = null;
      _pendingOfferPrompt = null;
      _applyTick(message.tick);
    } else if (message is MatchInterventionMessage) {
      if (message.offer.seq > _lastSeq) _lastSeq = message.offer.seq;
      // Fırsat sayacı gösterimden bağımsız: `resolved:true` replay zarfı
      // ekranda modal açmasa da o teklif maçta gerçekten sunulmuştu.
      _offeredIds.add(message.offer.offerId);
      // `resolved:true` yalnızca E8 replay'inde gelir (§9.2) - canlı akışta
      // hiç görülmez, görülürse de gösterilmeden atlanır.
      if (message.offer.resolved == true) return;
      // §12.2 · kulübeden top kapamazsın. Yedekte beklerken ya da oyundan
      // çıktıktan sonra gelen teklifler gösterilmiyor; motor kadroyu bilmediği
      // (D4/§11.7) için teklif üretmeyi sürdürüyor, süzgeç burada.
      // `_offeredIds`'e yine de yazıldı: teklif maçta gerçekten sunuldu,
      // yalnızca kullanıcıya ulaşmadı.
      if (!_onPitch) return;
      _activeOffer = message.offer;
      _pendingOfferPrompt = message.offer.prompt;
      // Modalda gösterilen "an" metni yorum akışına da yazılır - kullanıcı
      // kararını verip modal kapandıktan sonra da o anın ne olduğunu feed'de
      // görsün (§7.2 [İ-33]: teklif daima kullanıcının takımı için, bu yüzden
      // tint her zaman userSide). Sonucun kendisi (`resolved_intervention`
      // gelince) ayrı bir satır olarak zaten ekleniyor - bu yalnızca "an".
      _events.add(
        MatchEvent(
          minute: message.offer.minute,
          side: _sideFrom(userSide),
          text: message.offer.prompt,
          icon: Icons.touch_app_outlined,
          eventType: 'intervention_offer',
        ),
      );
      notifyListeners();
    }
    // MatchStreamIgnored (error/bilinmeyen) atlanır.
  }

  void _applyTick(TickFrame tick) {
    _meltCondition(tick.team);
    _minute = tick.minute;
    _finished = tick.finished;
    _score = tick.score;
    _possession = tick.possession;
    _team = tick.team;
    _situation = tick.situation;
    _directives = tick.directives;

    final resolved = tick.resolvedIntervention;
    if (resolved != null &&
        !_interventions.any((e) => e.offerId == resolved.offerId)) {
      // offer_id'ye göre tekilleştirilir: aynı zarf E8 replay'inde birebir
      // yeniden gelebilir (§9.2). Dakika artan sırada gelir çünkü tick'ler
      // artan sırada gelir - M2'nin sıralama kuralı yapısal olarak sağlanır.
      _interventions.add(InterventionLogEntry(
        minute: tick.minute,
        offerId: resolved.offerId,
        actionKey: resolved.actionKey,
        outcomeKey: resolved.outcomeKey,
      ));
    }

    for (final event in tick.events) {
      _applySubstitution(event, tick.minute);
      _events.add(
        MatchEvent(
          minute: tick.minute,
          side: _sideFrom(event.side),
          text: event.text,
          isGoal: event.isGoal,
          icon: iconForEventType(event.eventType),
          eventType: event.eventType,
        ),
      );
    }
    // §12.10 · yalnızca `_applySubstitution`'dan SONRA — bu tick'in
    // sahada-olma durumu ondan önce netleşmiş olmalı.
    _accrueCompliance(tick);

    if (tick.finished) {
      // Backend maç sonu için ayrı bir yorum satırı göndermiyor (§10.8) —
      // FE kendi sentetik satırını ekler.
      _events.add(
        MatchEvent(
          minute: tick.minute,
          side: MatchSide.neutral,
          text: 'Maç bitti — ${teams.home.name} ${tick.score.home}-'
              '${tick.score.away} ${teams.away.name}.',
          icon: Icons.sports_score_outlined,
        ),
      );
    }

    notifyListeners();
  }

  /// §12.2 · motorun `substitution` olayı **isimsiz**: kimin girdiğini ya da
  /// çıktığını tel üzerinde taşımıyor, yalnızca hangi tarafın değişiklik
  /// yaptığını. O yüzden "bu değişiklik kullanıcıyı ilgilendiriyor mu"
  /// kararı burada veriliyor:
  ///
  /// * **yedekteyken** kendi tarafının ilk değişikliği oyuncuyu sahaya alır —
  ///   antrenör kulübeye döndüğünde döndüğü kişi odur;
  /// * **sahadayken** bir değişiklik ancak kondisyon gerçekten düştüyse
  ///   oyuncuyu çıkarır. Aksi halde her değişiklik oyuncuyu alırdı ve formda
  ///   bir oyuncu 60. dakikada kendini kulübede bulurdu.
  ///
  /// Bir kez girer, bir kez çıkar: geri dönüş yok.
  void _applySubstitution(dynamic event, int minute) {
    if (event.eventType != 'substitution') return;
    if (_sideFrom(event.side) != _userMatchSide) return;

    if (!_onPitch && _offMinute == null && _onMinute == null) {
      _onPitch = true;
      _onMinute = minute;
      _events.add(MatchEvent(
        minute: minute,
        side: _userMatchSide,
        text: 'Oyuna giriyorsun.',
        icon: Icons.login_outlined,
      ));
      return;
    }

    if (_onPitch && _playerCondition <= _substitutionConditionFloor) {
      _onPitch = false;
      _offMinute = minute;
      _events.add(MatchEvent(
        minute: minute,
        side: _userMatchSide,
        text: 'Oyundan çıkıyorsun.',
        icon: Icons.logout_outlined,
      ));
    }
  }

  /// Bu kondisyonun altında bir değişiklik oyuncuyu alır. Motorun zemini 35
  /// (D38), maliyet §6.6'da ~30 puan; 45 "belirgin yorulmuş ama daha
  /// bitmemiş" demek.
  static const _substitutionConditionFloor = 45.0;

  /// §12.10 · uyumu dakika dakika biriktirir.
  ///
  /// Ölçüm motorun bildirdiği `tick.directives.focus`'tan yapılır, FE'nin
  /// **gönderdiği** değerden değil: E4 toleranslı bir uçtur (§6.1) —
  /// tanınmayan bir `focus` sessizce eskisinde bırakılır — ve
  /// [sendDirective] sonucu iyimser uygulamaz. Gönderdiğimizle ölçmek,
  /// sunucunun reddettiği bir direktifle uyum kazanmak demek olurdu.
  ///
  /// Bir aralık **önceki** tick'in bildirdiği focus'a yazılır: E4'ün
  /// `effective_from_minute`'ı `current + 1`'dir (§6.1) — 34'te gönderilen
  /// direktif 35'ten itibaren geçerli. Aynı gerekçeyle sahada olma durumu da
  /// önceki tick'in sonundaki durumdur: 60'ta oyuna giren oyuncu [59,60]
  /// aralığından sorumlu değil, [60,61]'den itibaren sorumlu —
  /// [minutesPlayed] ile aynı pencere.
  void _accrueCompliance(TickFrame tick) {
    final expected = coachInstruction;
    final previousMinute = _lastJudgedMinute;
    final previousFocus = _lastJudgedFocus;
    final wasOnPitch = _wasOnPitchAtLastTick;

    // E8 replay'i (§9.2) aynı tick'i yeniden yayabilir; imleç yalnızca ileri
    // gider, yoksa geriye dönen bir replay sonraki gerçek tick'te sahte
    // (hatta negatif) bir aralık yazardı.
    if (previousMinute != null && tick.minute < previousMinute) return;

    _lastJudgedMinute = tick.minute;
    _lastJudgedFocus = tick.directives.focus;
    _wasOnPitchAtLastTick = _onPitch;

    if (expected == null || previousMinute == null || !wasOnPitch) return;
    final span = tick.minute - previousMinute;
    if (span <= 0) return; // aynı dakikanın yinelenen/replay zarfı
    _judgedMinutes += span;
    if (previousFocus == expected) _compliantMinutes += span;
  }

  MatchSide get _userMatchSide =>
      userSide == 'home' ? MatchSide.home : MatchSide.away;

  void _meltCondition(TeamTickInfo? tickTeam) {
    if (tickTeam == null) return;
    final previous = _lastTickStamina;
    _lastTickStamina = tickTeam.stamina;
    if (previous == null) return;
    final drop = previous - tickTeam.stamina;
    if (drop <= 0) return;  // yedek değişikliği gibi artışlar taşınmaz
    _playerCondition = (_playerCondition - drop)
        .clamp(staminaCatalog.floor.toDouble(), startCondition.toDouble());
  }

  MatchSide _sideFrom(String side) {
    switch (side) {
      case 'home':
        return MatchSide.home;
      case 'away':
        return MatchSide.away;
      default:
        return MatchSide.neutral;
    }
  }

  void _onStreamError(Object error) {
    if (_disposed || _backgrounded || _finished) return;
    // 4xx (404 maç yok, 410 maç bitti, 400/422 hatalı istek...) yeniden
    // denemekle düzelmez; yalnızca ağ hataları ve 5xx geçici sayılır.
    final status = error is MatchStreamException ? error.statusCode : null;
    final fatal = status != null && status >= 400 && status < 500;
    if (!fatal && _scheduleReconnect()) return;
    if (error is MatchStreamException) {
      _connectionError =
          error.message ?? error.code ?? 'Maç akışına bağlanılamadı.';
    } else {
      _connectionError = 'Maç akışına bağlanılamadı.';
    }
    notifyListeners();
  }

  void _onStreamDone() {
    if (_disposed || _backgrounded || _finished) return;
    // Hata sonrası gelen `done` aynı kopmanın ikinci yarısıdır: bir yeniden
    // bağlanma zaten kurulduysa ya da hata kaydedildiyse tekrar işlenmez.
    if (_reconnectTimer != null || _connectionError != null) return;
    if (_scheduleReconnect()) return;
    _connectionError = 'Bağlantı beklenmedik şekilde kapandı.';
    notifyListeners();
  }

  /// `POST /matches/{id}/directive` (E4). Toleranslı bir uç olduğu için
  /// başarısızlık yalnızca ağ/sunucu hatasında olur; sonuç iyimser şekilde
  /// uygulanmaz — bir sonraki tick'in `directives` alanı tek doğru kaynaktır.
  Future<void> sendDirective({int? effort, int? aggression, String? focus}) async {
    final requestId =
        'req_${matchId}_${DateTime.now().microsecondsSinceEpoch}_${_requestSeq++}';
    try {
      final response = await _apiClient.postDirective(
        matchId,
        clientRequestId: requestId,
        atMinute: _minute,
        effort: effort,
        aggression: aggression,
        focus: focus,
      );
      if (_disposed) return;
      _lastDirectiveNote = response.note;
      notifyListeners();
    } on MatchApiException catch (e) {
      if (_disposed) return;
      _lastDirectiveNote = e.message ?? 'Direktif gönderilemedi.';
      notifyListeners();
    }
  }

  /// `POST /matches/{id}/speed` (E10). Yalnızca sunucunun tick temposunu
  /// değiştirir; maç durumuna dokunmaz. Hız kozmetik bir kontrol olduğu için
  /// başarısız bir çağrı maçı bozmamalı — bu yüzden yalnızca API hatası değil,
  /// her hata yutulur (ör. testlerdeki gerçek soket denemeleri).
  Future<void> sendSpeed(MatchSpeed speed) async {
    try {
      await _apiClient.postSpeed(matchId, speed: speed.wire);
    } catch (_) {
      // Sessizce yok sayılır: bir sonraki basış yeniden dener.
    }
  }

  /// `POST /matches/{id}/intervention` (E5). `resolution:"engine"`
  /// tekliflerinde `outcomeKey` daima `null` gider — zarı sunucu atar,
  /// sonucu bir sonraki tick'in `resolved_intervention` bloğundan öğreniriz
  /// (§7.4). `resolution:"minigame"` tekliflerinde (§7.3) çağıran
  /// (`match_screen.dart`) `InterventionShotScreen`'den dönen gerçek
  /// `outcomeKey`/`minigameResult`'ı geçirir — zarı bu turda FE atıyor.
  /// **Burada deftere hiçbir şey yazılmaz**, defter yalnızca tick'in
  /// `resolved_intervention` bloğundan beslenir (`_applyTick`).
  Future<void> _respondToOffer({
    required bool intervene,
    String? reason,
    String? outcomeKey,
    String? minigameResult,
  }) async {
    final offer = _activeOffer;
    if (offer == null) return; // çift dokunuşta ikinci çağrı sessiz no-op
    _activeOffer = null; // await'ten ÖNCE, senkron olarak temizlenir
    notifyListeners();

    final requestId =
        'req_${matchId}_${DateTime.now().microsecondsSinceEpoch}_${_requestSeq++}';
    try {
      await _apiClient.postIntervention(
        matchId,
        offerId: offer.offerId,
        clientRequestId: requestId,
        action: intervene ? 'intervene' : 'decline',
        outcomeKey: outcomeKey,
        minigameResult: minigameResult,
        reason: reason,
      );
    } on MatchApiException catch (e) {
      if (e.statusCode == 409) {
        // Teklif zaten kapanmış: ya sunucunun 180 sn emniyet zaman aşımı
        // `decline` etti, ya da bu ikinci bir POST. Gövde `{"accepted": false}`
        // olduğu için `e.code` null'dır - kod değil durum koduna bakılır.
        // Yapacak bir şey yok: kapanışın tick'i ya geldi ya geliyor.
        _pendingOfferPrompt = null;
      } else {
        _pendingOfferPrompt = 'Karar gönderilemedi — sunucu bekleniyor…';
      }
    } catch (_) {
      // Ağ hatası. Teklif sunucuda AÇIK kaldı; 180 sn sonra `decline` edilip
      // maç devam edecek. Kullanıcı o ana kadar donmuş bir feed görmesin diye
      // bekleme şeridi (`_WaitingBanner`) açıklamayla ayakta bırakılır.
      _pendingOfferPrompt = 'Karar gönderilemedi — sunucu bekleniyor…';
    }
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> acceptOffer({String? outcomeKey, String? minigameResult}) =>
      _respondToOffer(
        intervene: true,
        outcomeKey: outcomeKey,
        minigameResult: minigameResult,
      );

  Future<void> declineOffer({String reason = 'user'}) =>
      _respondToOffer(intervene: false, reason: reason);

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

/// M2'ye (`interventions[]`, D13) yazılacak tek bir müdahale kaydı — tel
/// şekli değil, FE'nin biriktirdiği defterin bir satırı. `offerId`
/// yalnızca E8 replay'inde tekilleştirme için tutulur, M2 gövdesine sızmaz.
class InterventionLogEntry {
  const InterventionLogEntry({
    required this.minute,
    required this.offerId,
    required this.actionKey,
    required this.outcomeKey,
  });

  final int minute;
  final String offerId;
  final String actionKey;
  final String outcomeKey;
}
