/// Gömülü CPython'u başlatan tek nokta.
///
/// `serious_python` yalnızca `dart:io` olan hedeflerde import edilir: web
/// derlemesi (`run_web.bat`) `dart.library.io`'suz stub'ı alır, böylece
/// eklenti web paketine hiç girmez. Gerçek giriş `phone_main.run()`'dır; paket
/// `tools/package_phone.sh` ile hazırlanır.
library;

export 'embedded_python_stub.dart'
    if (dart.library.io) 'embedded_python_io.dart';
