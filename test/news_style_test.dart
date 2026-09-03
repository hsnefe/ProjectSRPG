import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/news_style.dart';

void main() {
  test('altı kategori de kendi ikon ve tonunu döndürür', () {
    expect(newsCategories, hasLength(6));
    for (final category in newsCategories) {
      expect(
        iconForNewsCategory(category),
        isNot(Icons.article_outlined),
        reason: '$category nötr ikona düşüyor',
      );
      expect(
        tintForNewsCategory(category),
        isNot(AppColors.textMuted),
        reason: '$category nötr tona düşüyor',
      );
    }
  });

  test('yeni kategoriler eski dördünün tonunu çalmıyor', () {
    final tints = {
      for (final category in newsCategories) tintForNewsCategory(category),
    };
    final icons = {
      for (final category in newsCategories) iconForNewsCategory(category),
    };
    expect(tints, hasLength(newsCategories.length));
    expect(icons, hasLength(newsCategories.length));
  });

  test('Magazin ve Yaşam sözleşmenin kategori listesinde', () {
    expect(newsCategories, containsAll(<String>['Magazin', 'Yaşam']));
    // §3'ün sırası: eski dördü önce, yeniler sonra.
    expect(newsCategories.take(4), <String>[
      'Transfer',
      'Maç',
      'Röportaj',
      'Analiz',
    ]);
  });

  test('bilinmeyen kategori nötre düşer (ileri uyumluluk)', () {
    expect(iconForNewsCategory('Söylenti'), Icons.article_outlined);
    expect(tintForNewsCategory('Söylenti'), AppColors.textMuted);
    expect(iconForNewsCategory(''), Icons.article_outlined);
    expect(tintForNewsCategory(''), AppColors.textMuted);
  });

  testWidgets('kategori hapı adı kategorinin tonuyla yazar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: NewsCategoryPill(category: 'Magazin'))),
      ),
    );

    final text = tester.widget<Text>(find.text('Magazin'));
    expect(text.style?.color, tintForNewsCategory('Magazin'));
  });

  testWidgets('bilinmeyen kategorinin hapı da çizilir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: NewsCategoryPill(category: 'Söylenti'))),
      ),
    );

    expect(find.text('Söylenti'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Söylenti')).style?.color,
      AppColors.textMuted,
    );
  });

  test('newsTimeAgo göreli etiketi Türkçe kurar', () {
    final now = DateTime.now();
    String ago(Duration d) => newsTimeAgo(now.subtract(d).toIso8601String());

    expect(ago(const Duration(seconds: 20)), 'az önce');
    expect(ago(const Duration(minutes: 5)), '5 dakika önce');
    expect(ago(const Duration(hours: 3)), '3 saat önce');
    expect(ago(const Duration(days: 2)), '2 gün önce');
    expect(ago(const Duration(days: 15)), '2 hafta önce');
    // Ayrıştırılamayan değer olduğu gibi geri döner — ekran boş kalmaz.
    expect(newsTimeAgo('bilinmiyor'), 'bilinmiyor');
  });
}
