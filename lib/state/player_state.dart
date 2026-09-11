import 'package:flutter/foundation.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/money.dart';

/// Tek kaynaklı oyuncu durumu. Kondisyon ve para bütün ekranlarda buradan
/// okunur; aktiviteler backend'e yazıldıktan sonra [applyServerUpdate] ile
/// buraya yansıtılır.
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

  /// '48.200 ₭' biçiminde (§1.3 — BE sayıyı verir, etiketi FE yazar).
  String get moneyLabel => formatMoney(_money);

  /// D30'un on bir niteliği — [training_radar_screen] ve
  /// [relationships_radar_screen] buradan okur, ikinci bir çağrı yapmaz.
  List<PlayerAttribute> get attributes => _attributes;

  double attribute(String key) {
    for (final a in _attributes) {
      if (a.key == key) return a.value;
    }
    return 0;
  }

  /// D43 · niteliğin 0-10 seviyesi, **BE'den geldiği gibi**. Bir `requires`
  /// eşiği (D42) daima bununla karşılaştırılır; `value`'dan seviye türeten
  /// bir satır bu dosyada bilinçli olarak yoktur.
  int attributeLevel(String key) {
    for (final a in _attributes) {
      if (a.key == key) return a.level;
    }
    return 0;
  }

  /// P1'i çeker ve alanları doldurur. Hata durumunda sessizce vazgeçer —
  /// ekranlar boş/varsayılan değerlerle kalır, kritik bir akışı bloklamaz;
  /// [PlayerScope] uygulama açılışında bir kez, sihirbaz da yeni kariyeri
  /// kurduktan sonra bir kez çağırır.
  ///
  /// Kariyer **yoksa** hiçbir şey yapmaz: açılışta kariyer açmak, kullanıcı
  /// sihirbazda künyesini girmeden sahipsiz bir kayıt yaratmak olurdu
  /// ([CareerSession.resolveExisting]).
  Future<void> load() async {
    try {
      final careerId = await _session.resolveExisting();
      if (careerId == null) return;
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

  /// T2/T4/R3 gibi durum değiştiren her uç tam bir `career_state` bloğu
  /// döner (D28, INV-18); bu, o yanıtı yerel duruma yazan **tek** yol —
  /// ekranlar kendi başına `_condition`/`_money` mutasyonu yapmaz.
  /// [attributeChanges] verilirse (T2/R3) ilgili niteliklerin `value`'sunu
  /// da günceller, radar ekranları ikinci bir P1 çağrısı yapmadan tazelenir.
  void applyServerUpdate({
    CareerState? careerState,
    List<AttributeChange> attributeChanges = const [],
  }) {
    if (careerState != null) {
      _condition = careerState.condition;
      _money = careerState.money;
    }
    if (attributeChanges.isNotEmpty) {
      final updated = [..._attributes];
      for (final change in attributeChanges) {
        final index = updated.indexWhere((a) => a.key == change.key);
        if (index != -1) {
          updated[index] = PlayerAttribute(
            key: change.key,
            family: updated[index].family,
            value: change.after,
            // Seviye de yanıtta geliyor (§5.5), o yüzden burada
            // hesaplanmıyor: bir aktivite bir kapıyı açtıysa kilitli kartlar
            // P1 tazelenmeden, aynı karede açılır.
            level: change.levelAfter,
          );
        }
      }
      _attributes = updated;
    }
    notifyListeners();
  }

  /// Satın alınmış ürünlerin kimlikleri. ⚠️ Yalnızca bu oturumda yapılan
  /// alışverişleri tutar: contract'ta `inventory`'yi listeleyen bir GET ucu
  /// yok (T4 yalnızca az önce alınan tek kalemi döner), o yüzden P1 gibi
  /// baştan yüklenemez — bilinen bir sınır, uydurma bir veri değil.
  final Set<String> _owned = <String>{};

  bool owns(String id) => _owned.contains(id);

  bool canAfford(int price) => _money >= price;

  /// T4 başarıyla satın aldıktan sonra ekranın çağırdığı işaretleyici.
  void markOwned(String id) {
    if (!_owned.add(id)) return;
    notifyListeners();
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase());
    return letters.join();
  }

}
