import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// N1/N2/C3 `category`'nin bilinen dört değeri (§3.5) → filigran ikon ve
/// kart tonu, career_center_screen.dart ile news_detail_screen.dart arasında
/// paylaşılır. §5.8: bu ikisi BE'den gelmez, FE'nin sunum kararı. Bilinmeyen
/// bir kategori kartı kırmadan nötr bir varsayılana düşer (ileri uyumluluk).
const _iconByCategory = {
  'Transfer': Icons.swap_horiz,
  'Maç': Icons.sports_soccer,
  'Röportaj': Icons.record_voice_over_outlined,
  'Analiz': Icons.insights,
};

const _tintByCategory = {
  'Transfer': AppColors.accent,
  'Maç': AppColors.success,
  'Röportaj': AppColors.warning,
  'Analiz': AppColors.danger,
};

const _defaultTint = AppColors.textMuted;

IconData iconForNewsCategory(String category) =>
    _iconByCategory[category] ?? Icons.article_outlined;

Color tintForNewsCategory(String category) =>
    _tintByCategory[category] ?? _defaultTint;

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
