import 'package:flutter/material.dart';

/// Uygulamanın paylaşılan renk paleti.
///
/// Bu dosyadan önce her ekran kendi `static const _surface1 = Color(0xFF1A1D24)`
/// satırlarını taşıyordu; aynı onbir ton yirmiden fazla dosyada birebir
/// kopyalanmıştı, yani bir tonu değiştirmek yirmi dosyaya dokunmak demekti.
/// Kural basit: **en az iki dosyada geçen ton buraya taşınır**, tek bir ekrana
/// özgü tonlar (maç içi renkler, haber kategori tintleri, kart neonları)
/// kullanıldıkları yerde kalır.
///
/// `ThemeData` yerine düz sabitler: ekranlar renkleri `BuildContext` üzerinden
/// değil doğrudan okuyor (`CustomPainter`'lar dahil), tema geçişi bu işin
/// kapsamı değil.
abstract final class AppColors {
  /// Bulanık şerit ve en dip panel zemini.
  static const surface0 = Color(0xFF12151B);

  /// Ekran zemini.
  static const surface1 = Color(0xFF1A1D24);

  /// Kart/panel zemini.
  static const surface2 = Color(0xFF22262F);

  /// Kartların altındaki en koyu ton (silüet/bloom zemini).
  static const surfaceDeep = Color(0xFF0E1116);

  /// Kıl payı çerçeveler.
  static const border = Color(0xFF333845);

  static const textPrimary = Color(0xFFE8EAED);
  static const textSecondary = Color(0xFFA0A6B0);

  /// Kart yüzeylerinde kullanılan biraz daha soğuk ikincil metin.
  static const textSoft = Color(0xFF8A909B);

  static const textMuted = Color(0xFF6B7280);

  /// Birincil mavi vurgu.
  static const accent = Color(0xFF1E6FD9);
  static const accentBg = Color(0x33228BFF);

  static const success = Color(0xFF3DDC97);
  static const successBg = Color(0x333DDC97);

  /// Puan durumundaki terfi yeşili ve aynı tonu kullanan kategori tintleri.
  static const greenDeep = Color(0xFF2E9E6B);

  static const warning = Color(0xFFF5A623);

  static const danger = Color(0xFFE85D5D);
  static const dangerBg = Color(0x33E85D5D);

  /// Minigame'lerin daha doygun kırmızısı (rakip/hata göstergeleri).
  static const dangerBright = Color(0xFFE5484D);

  /// `_LitCard` gövde gradyanı (kariyer merkezi kartları).
  static const cardTop = Color(0xFF2E3440);
  static const cardMid = Color(0xFF252932);
  static const cardBottom = Color(0xFF181C23);
}
