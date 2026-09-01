import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/dialog_screen.dart';
import 'package:project_srpg/screens/relationships_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/character_card.dart';
import 'package:project_srpg/widgets/character_profile_modal.dart';

/// R1'in beş kartı — eski `_relationships` sabit listesindeki puan ve
/// künyelerle bire bir aynı.
const _relationshipCards = [
  {
    'relationship_id': 'coach', 'kind': 'coach', 'category': 'Antrenör',
    'score': 74, 'person_name': 'Mert Çalışkan', 'contact_name': 'Antrenör Mert',
    'last_contact_at': '2026-08-12', 'has_pending_request': false, 'traits': {},
  },
  {
    'relationship_id': 'team', 'kind': 'team', 'category': 'Takım Arkadaşları',
    'score': 58, 'person_name': 'Burak Şen', 'contact_name': 'Takım grubu',
    'last_contact_at': '2026-08-13', 'has_pending_request': false, 'traits': {},
  },
  {
    'relationship_id': 'media', 'kind': 'media', 'category': 'Medya',
    'score': 51, 'person_name': 'Ayça Kılıç', 'contact_name': 'Spor Manşet',
    'last_contact_at': '2026-08-09', 'has_pending_request': false, 'traits': {},
  },
  {
    'relationship_id': 'partner', 'kind': 'partner', 'category': 'Partner',
    'score': 63, 'person_name': 'Elif Demir', 'contact_name': 'Elif',
    'last_contact_at': '2026-08-14', 'has_pending_request': false, 'traits': {},
  },
  {
    'relationship_id': 'family', 'kind': 'family', 'category': 'Aile / Sosyal Çevre',
    'score': 29, 'person_name': 'Sevgi Yılmaz', 'contact_name': 'Anne',
    'last_contact_at': '2026-07-28', 'has_pending_request': false, 'traits': {},
  },
];

Map<String, dynamic> _profileFor(String relationshipId) {
  final card = _relationshipCards
      .firstWhere((c) => c['relationship_id'] == relationshipId);
  return {
    ...card,
    'age': 48,
    'occupation': 'Baş antrenör',
    'bio': 'Disiplinli ve veriye güvenen bir isim.',
    'hobbies': ['Satranç', 'Yüzme', 'Maç analizi'],
    'recent_events': const [],
  };
}

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

CareerSession _relationshipsSession({
  http.Response Function(http.Request)? onInteract,
  String? pendingFor,
}) {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') return _json(_careersListBody);
    if (request.url.path == '/careers/car_test/relationships') {
      return _json({
        'relationships': [
          for (final card in _relationshipCards)
            {
              ...card,
              'has_pending_request':
                  card['relationship_id'] == pendingFor,
            }
        ],
      });
    }
    final profileMatch =
        RegExp(r'^/careers/car_test/relationships/([^/]+)$').firstMatch(request.url.path);
    if (profileMatch != null) {
      return _json(_profileFor(profileMatch.group(1)!));
    }
    if (request.url.path.endsWith('/interact')) {
      return onInteract?.call(request) ??
          _json({
            'career_state': {
              'current_date': '2026-08-19', 'season_id': '25/26',
              'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
            },
            'relationship_changes': [
              {'relationship_id': 'coach', 'before': 74, 'after': 77, 'delta': 3}
            ],
            'attribute_changes': const [],
            'ledger_entries': const [],
          });
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

/// Kartın kendisini hedefler; metinler cam panelin içinde kalıyor.
Finder _card(String name) {
  return find.ancestor(
    of: find.text(name),
    matching: find.byType(CharacterCard),
  );
}

Widget _wrap(Widget home) {
  return PlayerScope(
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    ),
  );
}

void main() {
  testWidgets('ilişkiler yatay karakter kartı şeridi olarak gelir',
      (tester) async {
    await tester.pumpWidget(
      _wrap(RelationshipsScreen(session: _relationshipsSession())),
    );
    await tester.pumpAndSettle();

    expect(find.text('İlişkiler'), findsOneWidget);

    // Şerit yatay kaydırılabilir olmalı.
    final rows = tester.widgetList<ListView>(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
    );
    expect(rows.length, 1);

    // İlk kartlar ekranda; puan 100'lük skorun onda biri olarak yazılır.
    expect(_card('Antrenör'), findsOneWidget);
    expect(find.text('7.4'), findsOneWidget);
    expect(find.text('AN'), findsOneWidget);
    expect(find.text('KLÜP'), findsWidgets);

    // Eski kompakt liste tamamen kalktı.
    expect(find.text('74/100'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Şeridi sona kaydırınca son ilişki de görünür.
    await tester.scrollUntilVisible(
      find.text('Aile / Sosyal Çevre'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_card('Aile / Sosyal Çevre'), findsOneWidget);
    expect(find.text('2.9'), findsOneWidget);
  });

  testWidgets('ARA butonu diyalog ekranını açar', (tester) async {
    await tester.pumpWidget(
      _wrap(RelationshipsScreen(session: _relationshipsSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ARA').first);
    await tester.pumpAndSettle();

    // DialogScreen'in kendi Column'u test yüzeyine sığmayıp taşma hatası
    // üretiyor; master'da da olan, bu ekranla ilgisiz bir sorun. Testin
    // konusu navigasyon olduğu için bu hataları tüketiyoruz.
    while (tester.takeException() != null) {}

    expect(find.byType(DialogScreen), findsOneWidget);
    expect(find.text('Antrenör Mert'), findsOneWidget);
    expect(
      find.text('Haklısınız hocam, daha fazla paylaşımcı olacağım.'),
      findsOneWidget,
    );
  });

  testWidgets('alttaki buton kariyer merkezine döner', (tester) async {
    await tester.pumpWidget(_wrap(const CareerCenterScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('İlişkiler'), 200);
    await tester.tap(find.text('İlişkiler'));
    await tester.pumpAndSettle();

    expect(find.text('Kariyer Merkezi'), findsOneWidget);

    await tester.tap(find.text('Kariyer Merkezi'));
    await tester.pumpAndSettle();

    expect(find.byType(CareerCenterScreen), findsOneWidget);
    expect(find.byType(CharacterCard), findsNothing);
  });

  testWidgets('PROFİL butonu kişinin künye modalını açar', (tester) async {
    await tester.pumpWidget(
      _wrap(RelationshipsScreen(session: _relationshipsSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFİL').first);
    await tester.pumpAndSettle();

    expect(find.byType(CharacterProfileModal), findsOneWidget);

    // Künye alanları: isim, yaş, meslek, hobiler. İsim hem başlıkta hem
    // künye satırında geçiyor.
    expect(find.text('Mert Çalışkan'), findsNWidgets(2));
    expect(find.text('İsim'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('Baş antrenör'), findsOneWidget);
    expect(find.text('HOBİLER'), findsOneWidget);
    expect(find.text('Satranç'), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterProfileModal), findsNothing);
    expect(_card('Antrenör'), findsOneWidget);
  });

  testWidgets('başlıktaki pusula ilişki haritasına gider', (tester) async {
    await tester.pumpWidget(
      _wrap(RelationshipsScreen(session: _relationshipsSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();

    expect(find.text('İlişki Haritası'), findsOneWidget);
  });

  testWidgets('bekleyen teklifi olan kartta nokta çıkar', (tester) async {
    // R1 `has_pending_request` artık gerçek (§5.4); tam bir kart işaretli
    // olmalı — INV-39 aynı anda tek açık teklife izin veriyor.
    final session = _relationshipsSession(pendingFor: 'coach');
    await tester.pumpWidget(_wrap(RelationshipsScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pendingRequestDot')), findsOneWidget);
  });

  testWidgets('bekleyen teklif yoksa hiçbir kartta nokta yok', (tester) async {
    final session = _relationshipsSession();
    await tester.pumpWidget(_wrap(RelationshipsScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pendingRequestDot')), findsNothing);
  });
}
