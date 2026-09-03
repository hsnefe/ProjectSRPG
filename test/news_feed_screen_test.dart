import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/news_detail_screen.dart';
import 'package:project_srpg/screens/news_feed_screen.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _careersListBody = {
  'careers': [
    {
      'career_id': 'car_test', 'player_name': 'Efe Kaan',
      'season_id': '25/26', 'current_date': '2026-08-19',
    }
  ],
};

Map<String, dynamic> _item({
  required String newsId,
  required String category,
  required String title,
  String source = 'Spor Manşet',
  String publishedAt = '2026-08-19T18:00:00+03:00',
  String? excerpt,
}) {
  return {
    'news_id': newsId,
    'published_at': publishedAt,
    'category': category,
    'title': title,
    'source': source,
    'excerpt': excerpt ?? '$title gövdesinin ilk paragrafı.',
    'fixture_id': null,
  };
}

final _page1 = [
  _item(newsId: 'n_1', category: 'Transfer', title: 'Birinci haber'),
  _item(
    newsId: 'n_2',
    category: 'Magazin',
    title: 'İkinci haber',
    source: 'Magazin Ekspres',
    publishedAt: '2026-08-18T20:00:00+03:00',
  ),
  _item(
    newsId: 'n_3',
    category: 'Yaşam',
    title: 'Üçüncü haber',
    source: 'Lig Ajansı',
    publishedAt: '2026-08-17T20:00:00+03:00',
  ),
];

final _page2 = [
  _item(
    newsId: 'n_4',
    category: 'Analiz',
    title: 'Dördüncü haber',
    publishedAt: '2026-08-16T20:00:00+03:00',
  ),
];

/// N1'i taklit eden sahte backend. [requests] her `GET .../news` çağrısının
/// sorgu parametrelerini sırayla biriktirir — sayfalama ve filtre testleri
/// isteğin kendisini doğruluyor, yalnızca ekrandaki metni değil.
CareerSession _feedSession({
  required List<Map<String, dynamic>> Function(Uri url) items,
  String? Function(Uri url)? nextBefore,
  List<Map<String, String>>? requests,
  Map<String, Map<String, dynamic>> details = const {},
}) {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') return _json(_careersListBody);
    if (request.url.path == '/careers/car_test/news') {
      requests?.add(request.url.queryParameters);
      return _json({
        'items': items(request.url),
        'next_before': nextBefore?.call(request.url),
      });
    }
    final detail = RegExp(r'^/careers/car_test/news/(.+)$')
        .firstMatch(request.url.path);
    if (detail != null) {
      final item = details[detail.group(1)];
      if (item == null) return http.Response('not found', 404);
      return _json(item);
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(
    client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'),
  );
}

Widget _wrap(Widget home) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: home,
  );
}

/// Filtre şeridi yatayda kayıyor: son haplar 420px'lik panele sığmadığı için
/// dokunmadan önce görünür alana getiriliyor.
Future<void> _tapFilter(WidgetTester tester, String category) async {
  final finder = find.byKey(ValueKey('newsFilter:$category'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Ekranda iki kaydırılabilir var (yatay filtre şeridi + akış listesi);
/// `scrollUntilVisible` hangisini süreceğini bilmek zorunda.
final _feedList = find.descendant(
  of: find.byType(ListView),
  matching: find.byType(Scrollable),
);

void main() {
  testWidgets('akış N1 satırlarını başlık, excerpt ve kaynakla çizer',
      (tester) async {
    final session = _feedSession(items: (_) => _page1);

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Haberler'), findsOneWidget);
    expect(find.text('Birinci haber'), findsOneWidget);
    expect(find.text('İkinci haber'), findsOneWidget);
    expect(find.text('Üçüncü haber'), findsOneWidget);
    expect(
      find.text('Birinci haber gövdesinin ilk paragrafı.'),
      findsOneWidget,
    );
    expect(find.textContaining('Magazin Ekspres ·'), findsOneWidget);
  });

  testWidgets('ilk istek limit ile gider, kategori taşımaz', (tester) async {
    final requests = <Map<String, String>>[];
    final session = _feedSession(items: (_) => _page1, requests: requests);

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single['limit'], '20');
    expect(requests.single.containsKey('category'), isFalse);
    expect(requests.single.containsKey('before'), isFalse);
  });

  testWidgets('kategori filtresi N1\'i ?category ile yeniden çağırır',
      (tester) async {
    final requests = <Map<String, String>>[];
    final session = _feedSession(
      requests: requests,
      items: (url) {
        final category = url.queryParameters['category'];
        if (category == null) return _page1;
        return _page1.where((i) => i['category'] == category).toList();
      },
    );

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    await _tapFilter(tester, 'Magazin');

    expect(requests, hasLength(2));
    expect(requests.last['category'], 'Magazin');
    expect(find.text('İkinci haber'), findsOneWidget);
    expect(find.text('Birinci haber'), findsNothing);

    // "Tümü"ye dönmek filtreyi kaldırır.
    await _tapFilter(tester, 'all');

    expect(requests, hasLength(3));
    expect(requests.last.containsKey('category'), isFalse);
    expect(find.text('Birinci haber'), findsOneWidget);
  });

  testWidgets('filtre kategoride haber yoksa boş durumu gösterir',
      (tester) async {
    final session = _feedSession(
      items: (url) => url.queryParameters['category'] == null ? _page1 : [],
    );

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    await _tapFilter(tester, 'Röportaj');

    expect(find.text('Röportaj kategorisinde haber yok.'), findsOneWidget);
  });

  testWidgets('Daha fazla next_before ile ikinci sayfayı ekler',
      (tester) async {
    final requests = <Map<String, String>>[];
    final session = _feedSession(
      requests: requests,
      items: (url) =>
          url.queryParameters['before'] == null ? _page1 : _page2,
      // Arşivin sonu: ikinci sayfa next_before döndürmez.
      nextBefore: (url) => url.queryParameters['before'] == null
          ? '2026-08-17T20:00:00+03:00'
          : null,
    );

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Dördüncü haber'), findsNothing);

    // Düğme listenin sonunda; 420px'lik panelde üç satırın altında kalıyor.
    await tester.scrollUntilVisible(
      find.text('Daha fazla'),
      120,
      scrollable: _feedList,
    );
    await tester.tap(find.text('Daha fazla'));
    await tester.pumpAndSettle();

    expect(requests.last['before'], '2026-08-17T20:00:00+03:00');
    // Yeni sayfa listenin altına eklenir...
    await tester.scrollUntilVisible(
      find.text('Dördüncü haber'),
      120,
      scrollable: _feedList,
    );
    expect(find.text('Dördüncü haber'), findsOneWidget);
    // ...next_before null geldiği için düğme kaybolur.
    expect(find.text('Daha fazla'), findsNothing);
    // ...ve ilk sayfa yerinde durur.
    await tester.scrollUntilVisible(
      find.text('Birinci haber'),
      -120,
      scrollable: _feedList,
    );
    expect(find.text('Birinci haber'), findsOneWidget);
  });

  testWidgets('next_before null ise Daha fazla düğmesi hiç çizilmez',
      (tester) async {
    final session = _feedSession(items: (_) => _page1);

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Daha fazla'), findsNothing);
  });

  testWidgets('boş akışta boş durum metni', (tester) async {
    final session = _feedSession(items: (_) => const []);

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Henüz haber yok.'), findsOneWidget);
  });

  testWidgets('ilk sayfa hatasında Tekrar dene yeniden çağırır',
      (tester) async {
    var calls = 0;
    final mock = MockClient((request) async {
      if (request.url.path == '/careers') return _json(_careersListBody);
      if (request.url.path == '/careers/car_test/news') {
        calls++;
        if (calls == 1) return http.Response('boom', 500);
        return _json({'items': _page1, 'next_before': null});
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    final session = CareerSession(
      client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'),
    );

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.text('Birinci haber'), findsNothing);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Birinci haber'), findsOneWidget);
  });

  testWidgets('satıra dokunmak detayı o indeksle açar', (tester) async {
    final session = _feedSession(
      items: (_) => _page1,
      details: {
        'n_2': {
          ..._page1[1],
          'body': 'İkinci haberin gövdesi.',
        },
      },
    );

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İkinci haber'));
    await tester.pumpAndSettle();

    expect(find.byType(NewsDetailScreen), findsOneWidget);
    // Sayfalayıcı akışın tamamıyla besleniyor: 3 haberin ikincisindeyiz.
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('İkinci haberin gövdesi.'), findsOneWidget);
  });

  testWidgets('bilinmeyen kategori satırı kırmadan çizilir', (tester) async {
    final session = _feedSession(
      items: (_) => [
        _item(newsId: 'n_9', category: 'Söylenti', title: 'Yeni kategori'),
      ],
    );

    await tester.pumpWidget(_wrap(NewsFeedScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('Yeni kategori'), findsOneWidget);
    expect(find.text('Söylenti'), findsOneWidget);
  });

  testWidgets('initialCategory ile açılırsa ilk istek filtreli gider',
      (tester) async {
    final requests = <Map<String, String>>[];
    final session = _feedSession(
      requests: requests,
      items: (url) => _page1
          .where((i) => i['category'] == url.queryParameters['category'])
          .toList(),
    );

    await tester.pumpWidget(
      _wrap(NewsFeedScreen(session: session, initialCategory: 'Yaşam')),
    );
    await tester.pumpAndSettle();

    expect(requests.single['category'], 'Yaşam');
    expect(find.text('Üçüncü haber'), findsOneWidget);
    expect(find.text('Birinci haber'), findsNothing);
  });
}
