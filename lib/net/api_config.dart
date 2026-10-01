import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend'lerin taban adresleri.
///
/// İkisi de yalnızca localhost'ta çalışır (`run_server.py`): match_engine
/// 8000, career_engine 8001 portunda (CONTRACT.md §2). Android emulator kendi
/// loopback'ini host makineye `10.0.2.2` üzerinden yönlendirir; diğer tüm
/// hedefler (web, iOS simulator, masaüstü) host makinenin kendi loopback
/// adresini doğrudan görür.
///
/// iOS'ta back-end'ler telefonun içinde (gömülü CPython, `tools/phone/`) aynı
/// iki porttan dinler; adresler değişmez, yalnızca sunucuların **hazır
/// olması** beklenir — bkz. [usesEmbeddedBackend] ve `lib/boot/`.
class ApiConfig {
  const ApiConfig._();

  static String get _host {
    if (!kIsWeb && Platform.isAndroid) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  /// Back-end'ler bu uygulamanın içinde mi çalışıyor? Yalnızca iOS: orada
  /// internetsiz, tek cihazda oynanır. Diğer hedeflerde `run_all.bat` gibi
  /// dışarıdan kaldırılır ve hazırlık kapısı atlanır.
  static bool get usesEmbeddedBackend => !kIsWeb && Platform.isIOS;

  /// Hazırlık kapısının yokladığı adresler. Hiçbir engine `/health`
  /// tanımlamaz (CONTRACT.md'de yok); telefonda `phone_main.py` canlı
  /// uygulamaya ekler.
  static List<Uri> get healthUrls =>
      [Uri.parse('$baseUrl/health'), Uri.parse('$careerBaseUrl/health')];

  /// `match_engine` — tek maç, SSE.
  static String get baseUrl => 'http://$_host:8000';

  /// `career_engine` — kariyer, dünya, lig verileri.
  static String get careerBaseUrl => 'http://$_host:8001';
}
