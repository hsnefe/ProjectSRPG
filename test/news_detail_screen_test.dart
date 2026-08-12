import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/screens/news_detail_screen.dart';

const _news = [
  NewsItem(
    category: 'Transfer',
    icon: Icons.swap_horiz,
    tint: Color(0xFF1E6FD9),
    title: 'Birinci haber',
    source: 'Spor Manşet',
    timeAgo: '2 saat önce',
    body: 'Birinci haberin gövdesi.',
  ),
  NewsItem(
    category: 'Maç',
    icon: Icons.sports_soccer,
    tint: Color(0xFF3DDC97),
    title: 'İkinci haber',
    source: 'Lig Ajansı',
    timeAgo: '1 gün önce',
    body: 'İkinci haberin gövdesi.',
  ),
];

Widget _wrap(Widget home) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: home,
  );
}

void main() {
  testWidgets('hero, kategori pili ve sayaç görünür', (tester) async {
    await tester.pumpWidget(
      _wrap(const NewsDetailScreen(news: _news, initialIndex: 0)),
    );

    expect(find.text('Haber'), findsOneWidget);
    expect(find.text('Birinci haber'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Spor Manşet · 2 saat önce'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('pager haberler arasında gezinir', (tester) async {
    await tester.pumpWidget(
      _wrap(const NewsDetailScreen(news: _news, initialIndex: 0)),
    );

    await tester.tap(find.byTooltip('Sonraki haber'));
    await tester.pumpAndSettle();

    expect(find.text('İkinci haber'), findsOneWidget);
    expect(find.text('Birinci haber'), findsNothing);
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Önceki haber'));
    await tester.pumpAndSettle();

    expect(find.text('Birinci haber'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('uçlarda pager pasif kalır', (tester) async {
    await tester.pumpWidget(
      _wrap(const NewsDetailScreen(news: _news, initialIndex: 0)),
    );

    // İlk haberde geriye gidilemez.
    await tester.tap(find.byTooltip('Önceki haber'));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);

    // Son haberde ileri gidilemez.
    await tester.tap(find.byTooltip('Sonraki haber'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sonraki haber'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });
}
