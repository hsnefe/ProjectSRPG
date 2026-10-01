import 'package:serious_python/serious_python.dart';

/// Paketlenmiş `main.py`'yi (→ `phone_main.run()`) arka plan thread'inde
/// başlatır.
///
/// Dönen future **programın bitmesini beklemez**: `sync: false` iken Python
/// worker thread'i ayağa kalkar kalkmaz tamamlanır — `null` "başlatıldı",
/// dolu metin ("Python exited with code N") başlatma hatasıdır. Python'un
/// sonradan çökmesi buradan görünmez; onu `PythonHost` hazırlık yoklaması
/// (zaman aşımı) ve cihazdaki `phone_main.log` yakalar.
Future<String?> startEmbeddedPython() => SeriousPython.run();
