import 'package:flutter/foundation.dart';

/// Tek kaynaklı oyuncu durumu. Kondisyon ve para bütün ekranlarda buradan
/// okunur; aktiviteler [applyActivity] ile bu değerleri değiştirir.
class PlayerState extends ChangeNotifier {
  int _condition = 72;
  int _money = 48200;

  /// Oyuncunun kimliği. Şimdilik sabit; kariyer merkezi, profil ve sözleşme
  /// ekranları aynı metinleri kopyalamasın diye burada duruyor.
  String get name => 'Efe Kaan';

  /// Avatar dairesinde gösterilen baş harfler.
  String get initials => 'EK';

  String get position => 'Orta saha';

  String get teamName => 'FK Yıldız';

  int get age => 21;

  /// 0-100 arası kondisyon.
  int get condition => _condition;

  int get money => _money;

  /// '₺48.200' biçiminde, binlik ayracı nokta.
  String get moneyLabel => '₺${_thousands(_money)}';

  /// Bir aktivitenin etkisini uygular. [conditionDelta] artı ya da eksi
  /// olabilir, sonuç 0-100 aralığına sıkıştırılır. [cost] paradan düşülür.
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
  bool purchase({required String id, required int price}) {
    if (_owned.contains(id) || !canAfford(price)) return false;
    _money -= price;
    _owned.add(id);
    notifyListeners();
    return true;
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
