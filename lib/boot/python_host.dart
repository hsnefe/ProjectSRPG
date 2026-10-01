import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../net/api_config.dart';
import 'embedded_python.dart';

enum BootPhase { starting, ready, failed }

/// iOS'ta iki back-end telefonun içinde, gömülü CPython'da çalışır
/// (`tools/phone/phone_main.py`). Bu sınıf onu bir kez başlatır ve iki sunucu
/// `/health`'e yanıt verene dek [BootPhase.starting]'de kalır; `BootGate` o
/// süre boyunca splash gösterir, yani hiçbir istek sunucu kalkmadan çıkmaz.
///
/// Diğer hedeflerde (web, masaüstü, Android emulator) back-end'ler dışarıda
/// kalkar ve ev sahibi baştan [BootPhase.ready]'dir — istemcinin geri kalanı bu
/// sınıftan habersiz çalışır.
///
/// Python'u ikinci kez başlatmak yok: yorumlayıcı süreç başına bir kez
/// kalkabilir. Bu yüzden [retry] yalnızca yoklamayı yeniler; Python hiç
/// başlatılamadıysa ([startFailed]) kurtarma uygulamayı kapatıp açmaktır.
class PythonHost extends ChangeNotifier {
  PythonHost({
    required bool embedded,
    Future<String?> Function()? starter,
    Future<bool> Function(Uri url)? probe,
    this.healthUrls,
    this.timeout = const Duration(seconds: 90),
    this.pollInterval = const Duration(milliseconds: 150),
    this.recoverTimeout = const Duration(seconds: 20),
  }) : _embedded = embedded,
       _starter = starter ?? startEmbeddedPython,
       _probe = probe ?? _httpProbe,
       _phase = embedded ? BootPhase.starting : BootPhase.ready;

  /// Uygulama genelindeki ev sahibi; yalnızca iOS'ta gömülü Python kullanır.
  static final PythonHost instance = PythonHost(
    embedded: ApiConfig.usesEmbeddedBackend,
  );

  /// İlk sunucu yanıtı ~1,5 sn sürüyor (iPhone SE, release); 90 sn bir
  /// donma/çökme ayrımı içindir, normal yavaşlık için değil.
  final Duration timeout;
  final Duration pollInterval;

  /// [recover]'ın varsayılan bekleme süresi.
  final Duration recoverTimeout;

  final bool _embedded;
  final Future<String?> Function() _starter;
  final Future<bool> Function(Uri url) _probe;

  /// Boşsa [ApiConfig.healthUrls].
  final List<Uri>? healthUrls;

  BootPhase _phase;
  String? _error;
  bool _started = false;
  bool _startFailed = false;
  String? _lastProbeProblem;
  Future<void>? _running;

  BootPhase get phase => _phase;
  bool get isReady => _phase == BootPhase.ready;

  /// [BootPhase.failed] iken kullanıcıya gösterilecek neden.
  String? get error => _error;

  /// Python hiç başlatılamadı; yeniden yoklamak işe yaramaz.
  bool get startFailed => _startFailed;
  bool get canRetry => _phase == BootPhase.failed && !_startFailed;

  List<Uri> get _urls => healthUrls ?? ApiConfig.healthUrls;

  /// Başlatır ve hazır olunca (ya da başarısız olunca) tamamlanır. Tekrar
  /// çağrılırsa süren işi döndürür.
  Future<void> start() => _running ??= _boot();

  /// Uygulama ön plana dönerken (ya da bir istek bağlantı hatası verdiğinde)
  /// iki sunucunun sağlığını yoklar; iOS askıdayken dinleyen soketleri geri
  /// almış olabilir, o zaman Python tarafındaki gözetmen (`phone_main.py`,
  /// ~2 sn'de bir) onları yeniden bağlar. [timeout] dolmadan sağlıklıysa
  /// `true`. Ev sahibinin evresini değiştirmez: açılış kapısı yalnızca ilk
  /// açılışa aittir.
  Future<bool> recover({Duration? timeout}) async {
    if (!_embedded) return true;
    final deadline = DateTime.now().add(timeout ?? recoverTimeout);
    while (true) {
      if (await _allHealthy()) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(pollInterval);
    }
  }

  /// Başarısız bir açılışı yeniden yoklar (Python hâlâ yaşıyorsa).
  Future<void> retry() {
    if (!canRetry) return _running ?? Future.value();
    _set(BootPhase.starting);
    return _running = _waitUntilHealthy();
  }

  Future<void> _boot() async {
    if (!_embedded) return;
    if (!_started) {
      _started = true;
      // Future programın bitişini değil, başlatılışını bildirir (bkz.
      // embedded_python_io.dart): null = tamam, dolu = başlatma hatası.
      unawaited(_starter().then<void>(_onStarted, onError: _onStartError));
    }
    await _waitUntilHealthy();
  }

  void _onStarted(String? failure) {
    if (failure == null || failure.isEmpty) return;
    _failStart('Python başlatılamadı: $failure');
  }

  void _onStartError(Object e, StackTrace _) =>
      _failStart('Python başlatılamadı: $e');

  void _failStart(String message) {
    _startFailed = true;
    if (_phase != BootPhase.ready) _fail(message);
  }

  Future<void> _waitUntilHealthy() async {
    final deadline = DateTime.now().add(timeout);
    while (_phase == BootPhase.starting) {
      if (await _allHealthy()) {
        _set(BootPhase.ready);
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        _fail(
          'Oyun motoru ${timeout.inSeconds} sn içinde hazır olmadı'
          '${_lastProbeProblem == null ? '.' : ' ($_lastProbeProblem)'}',
        );
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<bool> _allHealthy() async {
    for (final url in _urls) {
      try {
        if (!await _probe(url)) {
          _lastProbeProblem = '$url yanıtı 200 değil';
          return false;
        }
      } catch (e) {
        _lastProbeProblem = '$url: $e';
        return false;
      }
    }
    return true;
  }

  void _fail(String message) {
    _error = message;
    _set(BootPhase.failed);
  }

  void _set(BootPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    if (phase != BootPhase.failed) _error = null;
    notifyListeners();
  }

  /// 200 yetmez: aynı porta başka bir süreç (örn. eski bir geliştirme
  /// sunucusu) oturmuş olabilir. `phone_main.py`'nin `/health` gövdesi
  /// `{"ok": true, "service": ...}` taşır; ikisi de aranır.
  static Future<bool> _httpProbe(Uri url) async {
    final response = await http.get(url).timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) return false;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map && body['ok'] == true && body['service'] is String;
    } catch (_) {
      return false;
    }
  }
}
