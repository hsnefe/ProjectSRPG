import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;

import '../game/event_icons.dart';
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
/// ve `error` çerçeveleri bu turda kapsam dışı: yanıtlanmayan bir teklifi
/// backend kendi 180s güvenlik zaman aşımıyla `decline` edip akışı sürdürür
/// (§7.2), bu yüzden burada özel bir işlem gerekmez.
class MatchController extends ChangeNotifier {
  MatchController({
    required this.matchId,
    required this.streamUrl,
    required this.userSide,
    required this.teams,
    required this.staminaCatalog,
    required this.directiveOptions,
    MatchApiClient? apiClient,
    MatchStreamSource? streamSource,
  })  : _apiClient = apiClient ?? MatchApiClient(),
        _streamSource = streamSource ?? HttpMatchSseClient();

  final String matchId;

  /// `/start`'ın döndürdüğü göreli yol (örn. `/matches/m_xxx/stream`).
  final String streamUrl;
  final String userSide;
  final MatchTeams teams;
  final StaminaCatalog staminaCatalog;
  final DirectiveOptions directiveOptions;

  final MatchApiClient _apiClient;
  final MatchStreamSource _streamSource;

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

  int get minute => _minute;
  bool get finished => _finished;
  ScoreInfo get score => _score;
  PossessionInfo? get possession => _possession;

  /// İlk tick gelene kadar `null` — kullanıcının takımının anlık durumu.
  TeamTickInfo? get team => _team;
  String? get situation => _situation;
  DirectivesInfo? get directives => _directives;
  List<MatchEvent> get events => List.unmodifiable(_events);

  /// Dolu ise SSE bağlantısı koptu/hata verdi/404 döndü — UI bu durumda
  /// ekrandan çıkıp mesaj göstermeli (reconnect bu turda yok).
  String? get connectionError => _connectionError;

  String? get lastDirectiveNote => _lastDirectiveNote;

  void connect() {
    final uri = Uri.parse('${ApiConfig.baseUrl}$streamUrl');
    _subscription = _streamSource.connect(uri).listen(
          _onMessage,
          onError: _onStreamError,
          onDone: _onStreamDone,
        );
  }

  void _onMessage(MatchStreamMessage message) {
    if (message is MatchTickMessage) {
      _applyTick(message.tick);
    }
    // MatchStreamIgnored (intervention_offer/error/bilinmeyen) atlanır.
  }

  void _applyTick(TickFrame tick) {
    _minute = tick.minute;
    _finished = tick.finished;
    _score = tick.score;
    _possession = tick.possession;
    _team = tick.team;
    _situation = tick.situation;
    _directives = tick.directives;

    for (final event in tick.events) {
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
    if (error is MatchStreamException) {
      _connectionError =
          error.message ?? error.code ?? 'Maç akışına bağlanılamadı.';
    } else {
      _connectionError = 'Maç akışına bağlanılamadı.';
    }
    notifyListeners();
  }

  void _onStreamDone() {
    if (!_finished && _connectionError == null) {
      _connectionError = 'Bağlantı beklenmedik şekilde kapandı.';
      notifyListeners();
    }
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
      _lastDirectiveNote = response.note;
      notifyListeners();
    } on MatchApiException catch (e) {
      _lastDirectiveNote = e.message ?? 'Direktif gönderilemedi.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
