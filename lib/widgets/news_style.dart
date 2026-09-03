import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// N1/N2/C3 `category`'nin bilinen altı değeri (§3.5) → filigran ikon ve
/// kart tonu, career_center_screen.dart, news_detail_screen.dart ve
/// news_feed_screen.dart arasında paylaşılır. §5.8: bu ikisi BE'den gelmez,
/// FE'nin sunum kararı. Bilinmeyen bir kategori kartı kırmadan nötr bir
/// varsayılana düşer (ileri uyumluluk) — haber katmanı yeni bir kategori
/// eklediğinde FE'yi güncellemeden önce de çalışmaya devam eder.
const _iconByCategory = {
  'Transfer': Icons.swap_horiz,
  'Maç': Icons.sports_soccer,
  'Röportaj': Icons.record_voice_over_outlined,
  'Analiz': Icons.insights,
  // Magazin haberleri paparazzi objektifinden çıkıyor (§2.3), Yaşam kalemleri
  // ise para/gider hikâyeleri (§2.5) — ikonlar bu iki damarı anlatıyor.
  'Magazin': Icons.camera_alt_outlined,
  'Yaşam': Icons.account_balance_wallet_outlined,
};

const _tintByCategory = {
  'Transfer': AppColors.accent,
  'Maç': AppColors.success,
  'Röportaj': AppColors.warning,
  'Analiz': AppColors.danger,
  // İki yeni ton da paletten seçildi (yeni sabit uydurulmadı): tabloid magazin
  // minigame'lerin doygun kırmızısını, Yaşam ise puan durumunun para yeşilini
  // ödünç alıyor.
  'Magazin': AppColors.dangerBright,
  'Yaşam': AppColors.greenDeep,
};

const _defaultTint = AppColors.textMuted;

/// Filtre çubuklarının gezdiği sıra — §3'teki kategori listesiyle birebir.
/// Bilinmeyen bir kategori bu listede olmasa da akışta görünmeye devam eder;
/// liste yalnızca "filtrelenebilir kategoriler"i tanımlar.
const newsCategories = <String>[
  'Transfer',
  'Maç',
  'Röportaj',
  'Analiz',
  'Magazin',
  'Yaşam',
];

IconData iconForNewsCategory(String category) =>
    _iconByCategory[category] ?? Icons.article_outlined;

Color tintForNewsCategory(String category) =>
    _tintByCategory[category] ?? _defaultTint;

/// Kategori adını taşıyan hap. Detay ekranının hero şeridinde, akış
/// satırlarında ve kariyer merkezinin haber kartında aynı ölçüde çiziliyordu;
/// üçüncü kopya yazılacakken buraya taşındı.
class NewsCategoryPill extends StatelessWidget {
  const NewsCategoryPill({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final color = tintForNewsCategory(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// '2026-03-14T09:00:00+03:00' → '2 saat önce' — §1.3: BE `published_at`
/// verir, göreli zaman etiketini FE türetir.
String newsTimeAgo(String isoDateTime) {
  final published = DateTime.tryParse(isoDateTime);
  if (published == null) return isoDateTime;
  final diff = DateTime.now().difference(published);
  if (diff.inMinutes < 1) return 'az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  final weeks = diff.inDays ~/ 7;
  return '$weeks hafta önce';
}
