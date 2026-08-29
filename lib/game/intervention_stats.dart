/// Maç sonu ekranındaki **oyuncuya ait** istatistikler — takımın maç
/// geneli istatistikleri (E9'un `stats[userSide]`'ı) değil.
///
/// E9 özeti motorun simüle ettiği **takım** sayaçlarını verir: 11 tehlikeli
/// atak, 12 şut, 4 isabet... Bunlar 11 kişilik takımın toplamıdır ve
/// kullanıcının o maçta kaç fırsata çıktığıyla hiçbir ilgisi yoktur. Oyuncu
/// maça yalnızca müdahale teklifleriyle katılıyor (§7.2), dolayısıyla
/// oyuncunun "fırsat"ı = kendisine sunulan teklif sayısı, "şut"u da kabul
/// edip **kendisinin bitirdiği** dallardır.
///
/// Aşağıdaki tablo match_engine'in `dev_actions.py` katalogundaki gerçek
/// `Branch.events` içeriğinin aynasıdır — career_engine'in
/// `catalog/match_actions.py`'sinin `GOAL_OUTCOMES` için yaptığının şut
/// karşılığı. Kural: bir dal kullanıcının tarafına ("self") bir `Shot`
/// olayı basıyorsa ve şutu **oyuncunun kendisi** çekmişse şut sayılır;
/// `Goal` ya da `Save` ile bitiyorsa isabetlidir (motorun kendi
/// `ON_TARGET_EVENTS` tanımıyla aynı).
library;

/// `asist` dalları kasten dışarıda: `graded4`'ün bu tier'ında oyuncu şutu
/// çekmek yerine boştaki arkadaşına çıkarıyor ve **o** bitiriyor
/// (`dev_actions.py`, "arkadaşına çıkardı, o bitirdi"). Dalın bastığı
/// `Shot` olayı takımın; oyuncununki bir pas, bu yüzden şut değil asist
/// olarak sayılır (career_engine `is_assist`).
const Map<String, Set<String>> _playerShotOutcomes = {
  // Shot+Goal / Shot+Save / Shot+Miss — üç dal da oyuncunun ayağından çıkıyor.
  'finish_power': {'great', 'good', 'bad'},
  'finish_finesse': {'great', 'good', 'bad'},
  'long_shot': {'great', 'good', 'bad'},
  // `good` (kontra kornere döndü) ve `bad` (son pas yanlış adama) hiç şut
  // üretmiyor — dallarında `Shot` olayı yok.
  'counter_attack': {'great'},
  // Kaleye giden tek dal: kafa golü. `failure` yalnızca korner.
  'set_piece': {'success'},
  // Penaltı gole çevrildi. Motorun takım sayacı penaltıyı `shots`'a
  // yazmıyor (yalnızca `penalties` + `shots_on_target`), ama oyuncu
  // cephesinden bu bir şuttur — golü de career_engine buradan sayıyor.
  'penalty_win': {'success'},
};

/// İsabetli sayılan dallar: `Goal` ya da `Save` basanlar. Kalanlar (`Miss`)
/// isabetsiz — `finish_finesse`'in `good` dalı direkten dönüyor, gerçek
/// hayattaki gibi isabet sayılmıyor.
const Map<String, Set<String>> _onTargetOutcomes = {
  'finish_power': {'great', 'good'}, // Goal / Save
  'finish_finesse': {'great'}, // Goal (good+bad: Miss)
  'long_shot': {'great', 'good'}, // Goal / Save
  'counter_attack': {'great'}, // Goal
  'set_piece': {'success'}, // Goal
  'penalty_win': {'success'}, // Goal (penaltı)
};

bool isPlayerShot(String actionKey, String outcomeKey) =>
    _playerShotOutcomes[actionKey]?.contains(outcomeKey) ?? false;

bool isShotOnTarget(String actionKey, String outcomeKey) =>
    _onTargetOutcomes[actionKey]?.contains(outcomeKey) ?? false;

/// Maç sonu tablosunun oyuncu satırları için türetilen sayaçlar.
class UserMatchStats {
  const UserMatchStats({
    required this.opportunities,
    required this.shots,
    required this.shotsOnTarget,
  });

  /// Maç boyunca oyuncuya sunulan müdahale teklifi sayısı — kabul edilenler,
  /// reddedilenler ve zaman aşımına uğrayanlar dahil. Kullanıcının gördüğü
  /// modal sayısıyla birebir aynıdır.
  final int opportunities;

  /// Oyuncunun kendi çektiği şutlar (kabul edilip şutla sonuçlanan dallar).
  final int shots;

  /// Bunların kaleyi bulanı (`Goal`/`Save`).
  final int shotsOnTarget;

  static const empty =
      UserMatchStats(opportunities: 0, shots: 0, shotsOnTarget: 0);
}
