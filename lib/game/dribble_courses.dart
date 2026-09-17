/// Top sürme kurslarının katalogu.
///
/// Kurs bir zamanlar tek ve sabitti: on koni, `dribble_game.dart`'ın içine
/// yazılmış. Gerekçesi hâlâ geçerli — aynı kurs her seferinde aynı olsun ki
/// oyuncu ezberleyip gelişebilsin, test de tekrarlanabilir kalsın. Değişen
/// şey kursun *sayısı*: artık birden fazla var ve hangisinin oynanacağını
/// oturum seçiyor, yani ezberlenecek şey tek bir dizilim değil, birkaç tanesi.
///
/// Kayıtlar `dribble_courses.g.dart`'ta — **üretilen** bir dosya, kaynağı
/// `../scenario_creator` editörü.
///
/// ## Koordinatlar
///
/// `distance` bitişe kadarki mesafe, birimi koridor genişliği; `x` koridordaki
/// yanal yer, 0..1 arası ve 0.5 tam orta. Şut katalogunun dünya birimleriyle
/// hiçbir ilgisi yok: bu bir koridor, saha değil.
library;

import 'dart:math' as math;

import 'package:project_srpg/game/dribble_courses.g.dart';

/// Kurstaki tek bir koni. Yeri iki sayı: koridordaki yanal yer ve bitişe olan
/// mesafe — top da aynı iki eksende yaşıyor, o yüzden çarpışma testi düz bir
/// dikdörtgen karşılaştırması.
class DribbleCone {
  const DribbleCone(this.distance, this.x);

  final double distance;
  final double x;
}

/// Bir kurs: koniler, uzunluk ve süre.
///
/// Uzunluk ile süre kursla birlikte geliyor çünkü ikisi birbirine bağlı —
/// aynı süreyle iki kat uzun bir kurs iki kat zor bir kurs demek, ve bunun
/// oyunun genel sabiti değil kursun kendi kararı olması gerekiyor.
class DribbleCourse {
  const DribbleCourse({
    required this.id,
    required this.name,
    required this.brief,
    required this.courseLength,
    required this.timeLimit,
    required this.cones,
  });

  /// Katalog boyunca benzersiz, sabit anahtar.
  final String id;

  /// Ekran başlığında görünen ad.
  final String name;

  /// Tek satırlık tarif: bu kursun neyi zorladığı.
  final String brief;

  /// Bitişe kadarki mesafe. Birim: koridor genişliği.
  final double courseLength;

  /// Kursun tamamı için verilen süre (saniye).
  final double timeLimit;

  final List<DribbleCone> cones;
}

class DribbleCourses {
  const DribbleCourses._();

  static final List<DribbleCourse> all = [
    for (final spec in kDribbleCourseSpecs)
      DribbleCourse(
        id: spec.id,
        name: spec.name,
        brief: spec.brief,
        courseLength: spec.courseLength,
        timeLimit: spec.timeLimit,
        cones: [
          for (final c in spec.cones) DribbleCone(c.distance, c.x),
        ],
      ),
  ];

  static DribbleCourse? byId(String id) {
    for (final course in all) {
      if (course.id == id) return course;
    }
    return null;
  }

  /// Bir antrenman oturumunun kursu — katalogdan rastgele biri.
  ///
  /// `TackleScenarios.pick()` ile aynı kalıp ve aynı gerekçe: oturum tek
  /// kursluk, o yüzden çalma listesi kurmaya gerek yok.
  static DribbleCourse pick({math.Random? random}) =>
      all[(random ?? math.Random()).nextInt(all.length)];
}
