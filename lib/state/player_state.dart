import 'package:flutter/foundation.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/net/career_session.dart';

/// Tek kaynaklı oyuncu durumu. Kondisyon ve para bütün ekranlarda buradan
/// okunur; aktiviteler [applyActivity] ile bu değerleri değiştirir.
///
/// P1 (`GET /careers/{cid}/player`, CONTRACT.md §5.2) tarafından beslenir.
/// [load] çağrılana kadar alanlar boş/sıfır kalır — [PlayerScope] bunu bir
/// kez, ağaç kurulurken tetikler; her ekran zaten [ChangeNotifier] dinlediği
/// için veri gelince kendiliğinden yeniden çizilir.
class PlayerState extends ChangeNotifier {
  PlayerState({CareerSession? session}) : _session = session ?? CareerSession.instance;

  final CareerSession _session;

  bool _loaded = false;
  bool get loaded => _loaded;

  // [load] henüz bitmeden gösterilecek yer tutucular. Rastgele değerler
  // değil: career_session.dart'ın C1'e yeni kariyer açarken gönderdiği aynı
  // varsayılan künye ve config.py'nin STARTING_CONDITION/STARTING_MONEY'i
  // (career_engine/api/config.py) — yani "henüz yüklenmedi" ile "kariyer
  // henüz gün 0'da" durumları aynı sayılarla temsil ediliyor, uydurma yok.
  String _name = 'Efe Kaan';
  String _position = 'Orta saha';
  String _teamName = 'FK Yıldız';
  int _age = 21;
  int _condition = 72;
  int _money = 48200;
  List<PlayerAttribute> _attributes = const [];

  /// Oyuncunun kimliği — P1'den.
  String get name => _name;

  /// Avatar dairesinde gösterilen baş harfler — isimden türetilir.
  String get initials => _initialsOf(_name);

  String get position => _position;

  String get teamName => _teamName;

  int get age => _age;

  /// 0-100 arası kondisyon — `career_state.condition` (D15: bugünkü değer;
  /// tavan [attribute]'daki `condition` anahtarındadır).
  int get condition => _condition;

  int get money => _money;

  /// '₺48.200' biçiminde, binlik ayracı nokta (§1.3 — BE sayıyı verir,
  /// etiketi FE yazar).
  String get moneyLabel => '₺${_thousands(_money)}';

  /// D30'un on bir niteliği — [training_radar_screen] ve
  /// [relationships_radar_screen] buradan okur, ikinci bir çağrı yapmaz.
  List<PlayerAttribute> get attributes => _attributes;

  double attribute(String key) {
    for (final a in _attributes) {
      if (a.key == key) return a.value;
    }
    return 0;
  }

  /// P1'i çeker ve alanları doldurur. Hata durumunda sessizce vazgeçer —
  /// ekranlar boş/varsayılan değerlerle kalır, kritik bir akışı bloklamaz;
  /// [PlayerScope] uygulama açılışında bir kez çağırır.
  Future<void> load() async {
    try {
      final careerId = await _session.resolve();
      final profile = await _session.client.player(careerId);
      _name = profile.name;
      _position = profile.position;
      _teamName = profile.team.name;
      _age = profile.age;
      _condition = profile.careerState.condition;
      _money = profile.careerState.money;
      _attributes = profile.attributes;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Bkz. yukarıdaki not — sessizce yutulur.
    }
  }

  /// Bir aktivitenin etkisini uygular. [conditionDelta] artı ya da eksi
  /// olabilir, sonuç 0-100 aralığına sıkıştırılır. [cost] paradan düşülür.
  ///
  /// ⚠️ Şimdilik yalnızca yerel durumu değiştirir — T2'ye (`POST
  /// /careers/{cid}/actions`) henüz bağlı değil; o bağlantı training/
  /// lifestyle ekranlarının kendi commit'inde gelecek.
  void applyActivity({int conditionDelta = 0, int cost = 0}) {
    final nextCondition = (_condition + conditionDelta).clamp(0, 100);
    final nextMoney = _money - cost;
    if (nextCondition == _condition && nextMoney == _money) {
      return;
    }
    _condition = nextCondition;
    _money = nextMoney;
    notifyListeners();
  }

  /// Satın alınmış ürünlerin kimlikleri.
  final Set<String> _owned = <String>{};

  bool owns(String id) => _owned.contains(id);

  bool canAfford(int price) => _money >= price;

  /// Bir ürünü satın alır. [applyActivity]'den farklı olarak bakiyeyi eksiye
  /// düşürmez ve aynı ürünün ikinci kez alınmasına izin vermez; alınamadıysa
  /// false döner ve hiçbir şey değişmez.
  ///
  /// ⚠️ Şimdilik yalnızca yerel durumu değiştirir — T4'e henüz bağlı değil;
  /// bkz. [applyActivity]'deki aynı not.
  bool purchase({required String id, required int price}) {
    if (_owned.contains(id) || !canAfford(price)) return false;
    _money -= price;
    _owned.add(id);
    notifyListeners();
    return true;
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase());
    return letters.join();
  }

  static String _thousands(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
