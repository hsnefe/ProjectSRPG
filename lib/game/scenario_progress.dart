import 'package:flutter/foundation.dart';

import 'package:project_srpg/game/shot_objective.dart';

/// Senaryo sahasında hangi durumdan ne aldığın.
///
/// Kariyerin değil, *senin* kaydın: senaryo sahası bir antrenman değil, bir
/// alıştırma alanı — burada oynanan hiçbir şey karakterin niteliklerine
/// dokunmuyor, dolayısıyla backend'e de gitmiyor. Kayıt uygulama çalıştığı
/// sürece yaşıyor; kalıcı olması için bir depolama paketi gerekirdi ve bir
/// alıştırma skoru bunu hak etmiyor.
///
/// [ChangeNotifier] olmasının tek sebebi liste ekranının bir denemeden
/// dönüldüğünde kendini tazelemesi.
class ScenarioProgress extends ChangeNotifier {
  ScenarioProgress();

  /// Uygulamanın tek nüshası. Testler kendi nüshasını kurabilsin diye
  /// kurucusu açık.
  static final instance = ScenarioProgress();

  final Map<String, ShotGrade> _best = {};
  final Map<String, int> _attempts = {};
  final Map<String, int> _cleared = {};

  /// Bu durumdan alınmış en iyi sonuç. Hiç oynanmadıysa null.
  ShotGrade? bestOf(String id) => _best[id];

  /// Kaç kez denendiği.
  int attemptsOf(String id) => _attempts[id] ?? 0;

  /// Kaç denemenin sayıldığı.
  int clearedOf(String id) => _cleared[id] ?? 0;

  bool wasPlayed(String id) => _attempts.containsKey(id);

  /// Kaç durumun en az bir kez geçildiği.
  int get cleared => _best.values.where((g) => g.counts).length;

  /// Kaç durumda tavan yapıldığı.
  int get mastered =>
      _best.values.where((g) => g == ShotGrade.great).length;

  int get played => _attempts.length;

  void record(String id, ShotGrade grade) {
    _attempts[id] = (_attempts[id] ?? 0) + 1;
    if (grade.counts) _cleared[id] = (_cleared[id] ?? 0) + 1;
    final best = _best[id];
    // Kademeler enum sırasıyla artıyor (fail < good < great), o yüzden
    // "daha iyisi" karşılaştırması index üzerinden.
    if (best == null || grade.index > best.index) _best[id] = grade;
    notifyListeners();
  }

  /// Tek bir durumun kaydını siler. Liste ekranındaki "sıfırla" bunu çağırır.
  void reset(String id) {
    _best.remove(id);
    _attempts.remove(id);
    _cleared.remove(id);
    notifyListeners();
  }

  void resetAll() {
    _best.clear();
    _attempts.clear();
    _cleared.clear();
    notifyListeners();
  }
}
