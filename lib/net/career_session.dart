import 'career_api_client.dart';

/// Uygulamanın hangi kariyerle konuştuğunu tutar.
///
/// Normal yol artık sihirbaz: [NewCareerScreen] kariyeri kurar ve [adopt] ile
/// oturuma bağlar. [resolve] bunun yedeği — bir ekran sihirbazdan geçmeden
/// açıldığında (testler, doğrudan navigasyon) **varsa** en son kariyeri
/// kullanır (C2), yoksa sabit bir künyeyle bir tane açar (C0+C1).
///
/// Kimlik bir kez çözülür ve uygulama çalıştığı sürece bellekte kalır; kalıcı
/// saklama ve kariyer seçme akışı kayıt ekranıyla birlikte gelecek.
class CareerSession {
  CareerSession({CareerApiClient? client})
      : _client = client ?? CareerApiClient();

  /// Uygulama genelinde paylaşılan örnek. Ekranların ayrı ayrı kariyer
  /// açmasını engeller — iki ekran aynı anda isterse ikisi de aynı
  /// [Future]'ı bekler.
  ///
  /// `final` değil: testler, ekranların kendi başına inşa ettiği (dolayısıyla
  /// bir `session:` parametresiyle geçilemeyen) iç içe navigasyon zincirlerini
  /// sahte bir backend'e bağlamak için bunu geçici olarak değiştirebilir —
  /// üretim kodu asla atama yapmaz.
  static CareerSession instance = CareerSession();

  /// [resolve]'un yedek yolunda kullanılan sabit künye (`player_state.dart`
  /// metinleriyle aynı isim). Sihirbazdan geçen kullanıcı bunu hiç görmez.
  static const _defaultFirstName = 'Efe';
  static const _defaultLastName = 'Kaan';
  static const _defaultNationality = 'TR';
  static const _defaultPosition = 'Orta saha';

  /// C0'ın hedef kulüp listesinde varsa tercih edilen kulüp — FE'nin
  /// metinlerinde geçen takım bu (`player_state.dart` `teamName`). Yoksa
  /// listenin ilki alınır. Not: bu **hedef** kulüptür; oynanan kulübü §3
  /// milliyetten atar, istek onu seçmez.
  static const _preferredTeamId = 't_ykz';

  final CareerApiClient _client;

  CareerApiClient get client => _client;

  Future<String>? _pending;
  String? _careerId;

  /// Çözülmüş kariyer kimliği; henüz çözülmediyse null.
  String? get careerId => _careerId;

  /// Sihirbazın kurduğu kariyeri oturumun kariyeri yapar.
  ///
  /// [resolve] listenin ilkini alacağı için çoğu zaman aynı kimliğe varırdı,
  /// ama bu hem fazladan bir C2 turu hem de "en son kariyer" varsayımına
  /// bağımlılık demek: kullanıcı hangi kariyeri kurduysa oturum onu tutar,
  /// eski kariyerler kayıt listesinde durmaya devam eder.
  void adopt(String careerId) {
    _careerId = careerId;
    _pending = null;
  }

  /// Kariyer kimliğini döndürür, gerekiyorsa çözer. Aynı anda birden fazla
  /// çağrı gelirse hepsi tek isteği bekler; hata durumunda [Future] yeniden
  /// denenebilsin diye temizlenir.
  Future<String> resolve() {
    final cached = _careerId;
    if (cached != null) return Future.value(cached);
    return _pending ??= _resolveAndCache();
  }

  /// Var olan kariyeri döndürür, **yenisini açmaz** (yoksa null).
  ///
  /// Açılışta çalışan [PlayerState.load] bunu kullanır: uygulama daha landing
  /// ekranındayken sabit künyeli bir kariyer açmak, kullanıcı sihirbazda kendi
  /// künyesini girmeden önce ortada sahipsiz bir kayıt bırakırdı.
  Future<String?> resolveExisting() async {
    final cached = _careerId;
    if (cached != null) return cached;

    final careers = await _client.listCareers();
    if (careers.isEmpty) return null;
    return _careerId = careers.first.careerId;
  }

  Future<String> _resolveAndCache() async {
    try {
      final id = await _resolve();
      _careerId = id;
      return id;
    } finally {
      // Başarıda da temizlenir: bundan sonra `_careerId` kısa devre yapar.
      // Hatada temizlenmesi asıl önemli olan — ekran yeniden deneyebilsin.
      _pending = null;
    }
  }

  Future<String> _resolve() async {
    final careers = await _client.listCareers();
    if (careers.isNotEmpty) return careers.first.careerId;

    final options = await _client.careerOptions();
    if (options.positions.isEmpty || options.targetTeams.isEmpty) {
      throw StateError('career_engine kariyer seçeneği döndürmedi');
    }

    // Sabit künyeyi katalogla eşleştiririz: tercih edilen değer listede yoksa
    // ilkine düşeriz, böylece BE katalogu değişince C1 `422` yerine geçerli
    // bir kariyer üretmeye devam eder.
    final nationality = _pick(
      options.nationalities,
      (n) => n.countryCode == _defaultNationality,
    );
    if (nationality == null) {
      throw StateError('career_engine milliyet döndürmedi');
    }

    // Rolsüz pozisyon geçerli kariyer üretemez (C1 rolü zorunlu ister), o
    // yüzden yedek seçim de rolü olanlar arasından yapılır.
    final withRoles =
        options.positions.where((p) => p.roles.isNotEmpty).toList();
    final position = _pick(withRoles, (p) => p.position == _defaultPosition);
    if (position == null) {
      throw StateError('career_engine rolü olan pozisyon döndürmedi');
    }

    final target = _pick(
      options.targetTeams,
      (t) => t.team.teamId == _preferredTeamId,
    )!;

    final hub = await _client.createCareer(
      firstName: _defaultFirstName,
      lastName: _defaultLastName,
      nationality: nationality.countryCode,
      position: position.position,
      role: position.roles.first.roleId,
      targetTeamId: target.team.teamId,
    );
    return hub.careerId;
  }

  /// [test]'i sağlayan ilk kalem, yoksa listenin ilki; liste boşsa null.
  static T? _pick<T>(List<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return items.isEmpty ? null : items.first;
  }
}
