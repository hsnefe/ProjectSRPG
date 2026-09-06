/// Bir denemenin ne kadar iyi gittiği — ve bunu neyin belirlediği.
///
/// `shot_game.dart` bir uçuşu dokuz ham etiketten birine indirger ("GOL!",
/// "PAS KAÇTI", …). O etiket *ne olduğunu* söyler, *ne kadar iyi olduğunu*
/// söylemez: aynı "PAS TUTTU" bir kurulum senaryosunda güvenli bir top, bir
/// başkasında hattı kıran topun ta kendisidir. Aradaki farkı senaryo bilir,
/// kurallar değil — bu yüzden not verme işi buraya, sahnenin yanına taşındı.
library;

/// `ShotGame.resolve` etiketlerinin tek nüshası.
///
/// Hedef tabloları bu sabitlerden kuruluyor, böylece bir senaryo var olmayan
/// bir etikete puan veremiyor ([ShotObjective] doğrulaması buna bakar).
class ShotLabel {
  static const goal = 'GOL!';
  static const save = 'KURTARIŞ';
  static const post = 'DİREK';
  static const wide = 'AUT';
  static const over = 'ÜSTTEN AUT';
  static const passCaught = 'PAS TUTTU';
  static const passMissed = 'PAS KAÇTI';
  static const intercepted = 'RAKİP KESTİ';
  static const intoSpace = 'BOŞLUĞA';

  /// Oyunun üretebildiği bütün etiketler.
  static const all = {
    goal,
    save,
    post,
    wide,
    over,
    passCaught,
    passMissed,
    intercepted,
    intoSpace,
  };
}

/// Bir denemenin üç kademesi: başarısız — başarılı — çok başarılı.
enum ShotGrade {
  fail('Başarısız'),
  good('Başarılı'),
  great('Çok başarılı');

  const ShotGrade(this.label);

  final String label;

  /// Sayılan bir deneme mi. İki kademeli bir senaryoda [good] zaten tavandır.
  bool get counts => this != ShotGrade.fail;
}

/// Bir senaryonun ne istediği: hangi etiketler sayılır, hangileri tavan.
///
/// İki kademeli senaryolar [great]'i boş bırakır — penaltıda "çok başarılı"
/// diye bir şey yok, top ya girer ya girmez. Üç kademeli olanlar ya [great]'e
/// bir etiket koyar (kaleci çelince `good`, gol olunca `great`) ya da
/// [keyPassIsGreat] ile kararı sahaya bırakır: aynı "PAS TUTTU" güvenli adama
/// giderse `good`, [ShotTarget.isKey] işaretli adama giderse `great`.
class ShotObjective {
  const ShotObjective({
    this.great = const {},
    this.good = const {},
    this.keyPassIsGreat = false,
  });

  /// Tavan sayılan ham etiketler.
  final Set<String> great;

  /// Sayılan ama tavan olmayan ham etiketler. İki kademeli bir senaryoda
  /// buradakiler tek başarı biçimidir.
  final Set<String> good;

  /// [ShotLabel.passCaught], işaretli bir alıcıya ulaştığında `great`'e
  /// yükselsin mi. Kaleyi değil sahayı ödüllendiren senaryoların tamamı bunu
  /// kullanır: seçenekler aynı ekranda durur, farkı hangisini seçtiğin yapar.
  final bool keyPassIsGreat;

  ShotGrade gradeOf(String label, {bool keyReceiver = false}) {
    if (great.contains(label)) return ShotGrade.great;
    if (!good.contains(label)) return ShotGrade.fail;
    return keyReceiver && keyPassIsGreat && label == ShotLabel.passCaught
        ? ShotGrade.great
        : ShotGrade.good;
  }

  /// Bu hedefin üretebildiği kademe sayısı — 2 ya da 3. Katalog testi her
  /// senaryonun en az iki kademesi olduğunu buradan doğruluyor.
  int get tiers => great.isNotEmpty || keyPassIsGreat ? 3 : 2;

  /// Puan verilen bütün etiketler. Doğrulama için.
  Set<String> get scoredLabels => {...great, ...good};

  /// Bir kademenin 0..1 aralığındaki ağırlığı — seansın [TrainingResult.score]
  /// alanı bunların ortalaması. İki kademeli bir senaryoda `good` tavandır, üç
  /// kademelide değil.
  double weightOf(ShotGrade grade) => switch (grade) {
        ShotGrade.fail => 0,
        ShotGrade.good => tiers == 3 ? 0.6 : 1,
        ShotGrade.great => 1,
      };

  // --- Hazır hedefler -----------------------------------------------------

  /// Hiçbir şeyin sayılmadığı serbest mod.
  static const none = ShotObjective();

  /// Yalnızca gol. Antrenman ve sınav şutunun eski davranışı.
  static const goalOnly = ShotObjective(good: {ShotLabel.goal});

  /// Yalnızca tutan pas. Antrenman ve sınav pasının eski davranışı.
  static const passOnly = ShotObjective(good: {ShotLabel.passCaught});

  /// Şut: gol tavan, kaleciye/direğe giden isabetli şut sayılır.
  static const finish = ShotObjective(
    great: {ShotLabel.goal},
    good: {ShotLabel.save, ShotLabel.post},
  );

  /// Şut ya da daha iyi konumdaki arkadaşa çıkarma. Golün de, doğru adama
  /// verilen topun da tavan olduğu ikilemler için.
  static const finishOrLayoff = ShotObjective(
    great: {ShotLabel.goal},
    good: {ShotLabel.save, ShotLabel.post, ShotLabel.passCaught},
    keyPassIsGreat: true,
  );

  /// Pas: tutan her top sayılır, hattı kıran top tavan.
  static const pass = ShotObjective(
    good: {ShotLabel.passCaught},
    keyPassIsGreat: true,
  );

  /// Son bölgede pas ya da bitiriş: ikisi de tavan, isabetli şut sayılır.
  static const assistOrFinish = ShotObjective(
    great: {ShotLabel.goal},
    good: {ShotLabel.passCaught, ShotLabel.save, ShotLabel.post},
    keyPassIsGreat: true,
  );
}
