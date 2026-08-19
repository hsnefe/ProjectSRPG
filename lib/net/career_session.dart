import 'career_api_client.dart';

/// Uygulamanın hangi kariyerle konuştuğunu tutar.
///
/// FE'de henüz kariyer kurma/seçme ekranı yok (landing doğrudan kariyer
/// merkezine gidiyor), ama `career_engine`'in her dünya ucu bir `career_id`
/// istiyor. Bu sınıf aradaki boşluğu kapatır: **varsa** en son kariyeri
/// kullanır (C2), yoksa FE'nin bugünkü sabit künyesiyle bir tane açar (C0+C1).
///
/// Kimlik bir kez çözülür ve uygulama çalıştığı sürece bellekte kalır; kalıcı
/// saklama ve gerçek bir kariyer seçme akışı kayıt ekranıyla birlikte gelecek.
class CareerSession {
  CareerSession({CareerApiClient? client})
      : _client = client ?? CareerApiClient();

  /// Uygulama genelinde paylaşılan örnek. Ekranların ayrı ayrı kariyer
  /// açmasını engeller — iki ekran aynı anda isterse ikisi de aynı
  /// [Future]'ı bekler.
  static final CareerSession instance = CareerSession();

  /// FE'nin bugünkü sabit oyuncu künyesi (`player_state.dart`). Kariyer kurma
  /// ekranı geldiğinde bunun yerini kullanıcının girdisi alacak.
  static const _defaultPlayerName = 'Efe Kaan';
  static const _defaultPosition = 'Orta saha';

  /// C0'ın listesinde varsa tercih edilen kulüp — FE'nin metinlerinde geçen
  /// takım bu (`player_state.dart` `teamName`). Yoksa listenin ilki alınır.
  static const _preferredTeamId = 't_ykz';

  final CareerApiClient _client;

  CareerApiClient get client => _client;

  Future<String>? _pending;
  String? _careerId;

  /// Çözülmüş kariyer kimliği; henüz çözülmediyse null.
  String? get careerId => _careerId;

  /// Kariyer kimliğini döndürür, gerekiyorsa çözer. Aynı anda birden fazla
  /// çağrı gelirse hepsi tek isteği bekler; hata durumunda [Future] yeniden
  /// denenebilsin diye temizlenir.
  Future<String> resolve() {
    final cached = _careerId;
    if (cached != null) return Future.value(cached);
    return _pending ??= _resolveAndCache();
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

    final clubs = await _client.careerOptions();
    if (clubs.isEmpty) {
      throw StateError('career_engine seçilebilir kulüp döndürmedi');
    }
    final club = clubs.firstWhere(
      (c) => c.team.teamId == _preferredTeamId,
      orElse: () => clubs.first,
    );
    return _client.createCareer(
      playerName: _defaultPlayerName,
      position: _defaultPosition,
      teamId: club.team.teamId,
    );
  }
}
