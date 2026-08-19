import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend'lerin taban adresleri.
///
/// İkisi de yalnızca localhost'ta çalışır (`run_server.py`): match_engine
/// 8000, career_engine 8001 portunda (CONTRACT.md §2). Android emulator kendi
/// loopback'ini host makineye `10.0.2.2` üzerinden yönlendirir; diğer tüm
/// hedefler (web, iOS simulator, masaüstü) host makinenin kendi loopback
/// adresini doğrudan görür.
class ApiConfig {
  const ApiConfig._();

  static String get _host {
    if (!kIsWeb && Platform.isAndroid) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  /// `match_engine` — tek maç, SSE.
  static String get baseUrl => 'http://$_host:8000';

  /// `career_engine` — kariyer, dünya, lig verileri.
  static String get careerBaseUrl => 'http://$_host:8001';
}
