import 'package:flutter/foundation.dart';

/// Tek kaynaklı oyuncu durumu. Kondisyon ve para bütün ekranlarda buradan
/// okunur; aktiviteler [applyActivity] ile bu değerleri değiştirir.
class PlayerState extends ChangeNotifier {
  int _condition = 72;
  int _money = 48200;

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
