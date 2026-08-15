import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// match_engine API'sinin taban adresi.
///
/// Backend yalnızca localhost'ta çalışır (`run_server.py`, 127.0.0.1:8000).
/// Android emulator kendi loopback'ini host makineye `10.0.2.2` üzerinden
/// yönlendirir; diğer tüm hedefler (web, iOS simulator, masaüstü) host
/// makinenin kendi loopback adresini doğrudan görür.
class ApiConfig {
  const ApiConfig._();

  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
