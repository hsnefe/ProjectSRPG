import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/widgets/social_offer_modal.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _careerState = {
  'current_date': '2026-08-19', 'season_id': '25/26',
  'money': 48200, 'condition': 66, 'day_budget': {'time': 600.0},
};

api.SocialOffer _offer({
  Map<String, dynamic> costs = const {'time': 120, 'energy': 20},
  Map<String, dynamic> requires = const <String, dynamic>{},
}) {
  return api.SocialOffer.fromJson({
    'offer_id': 'so_1',
    'template_id': 'coach_extra_session',
    'relationship_id': 'coach',
    'relationship': {
      'relationship_id': 'coach', 'kind': 'coach', 'category': 'Antrenör',
      'score': 70, 'person_name': 'Mert Çalışkan', 'contact_name': 'Antrenör Mert',
    },
    'title': 'Fazladan idman',
    'body': 'Antrenör yarın sabah bire bir çalışmak istiyor.',
    'accept_label': 'Sahada olurum',
    'decline_label': 'Bu hafta olmaz',
    'costs': costs,
    'requires': requires,
    'opened_on': '2026-08-19',
    'status': 'open',
    'resolved_on': null,
  });
}

Map<String, Object?> _resultBody(String status, int delta) => {
      'career_state': _careerState,
      'offer': {
        'offer_id': 'so_1', 'template_id': 'coach_extra_session',
        'relationship_id': 'coach', 'title': 'Fazladan idman',
        'body': '...', 'accept_label': 'E', 'decline_label': 'H',
        'costs': const <String, dynamic>{}, 'requires': const <String, dynamic>{},
        'opened_on': '2026-08-19', 'status': status,
        'resolved_on': '2026-08-19',
      },
      'relationship_changes': [
        {'relationship_id': 'coach', 'before': 70, 'after': 70 + delta,
         'delta': delta}
      ],
      'attribute_changes': const <dynamic>[],
      'ledger_entries': const <dynamic>[],
    };

class _Backend {
  _Backend({this.acceptStatus = 200});

  final int acceptStatus;
  final List<String> paths = [];

  CareerSession session() {
    final mock = MockClient((request) async {
      paths.add('${request.method} ${request.url.path}');
      if (request.url.path == '/careers') {
        return _json({'careers': [
          {'career_id': 'car_1', 'created_at': '2026-08-01T00:00:00+03:00',
           'season_id': '25/26', 'current_date': '2026-08-19',
           'player_name': 'Efe Kaan',
           'team': {'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
                    'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF'}}
        ]});
      }
      if (request.url.path.endsWith('/accept')) {
        if (acceptStatus != 200) {
          return _json(
            {'code': 'insufficient_budget', 'message': "not enough 'time' left today"},
            status: acceptStatus,
          );
        }
        return _json(_resultBody('accepted', 5));
      }
      if (request.url.path.endsWith('/decline')) {
        return _json(_resultBody('declined', -3));
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    return CareerSession(
      client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'),
    );
  }
}

/// Modalı gerçek bir route olarak açar — barrier ve geri tuşu davranışı
/// ancak böyle test edilebilir.
Future<api.SocialOfferResult?> _open(
  WidgetTester tester,
  _Backend backend, {
  api.SocialOffer? offer,
}) async {
  api.SocialOfferResult? captured;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              captured = await showSocialOfferModal(
                context,
                session: backend.session(),
                offer: offer ?? _offer(),
              );
            },
            child: const Text('aç'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('başlık, gövde ve iki etiket çizilir', (tester) async {
    await _open(tester, _Backend());

    expect(find.text('Fazladan idman'), findsOneWidget);
    expect(find.text('Antrenör yarın sabah bire bir çalışmak istiyor.'),
        findsOneWidget);
    expect(find.text('Sahada olurum'), findsOneWidget);
    expect(find.text('Bu hafta olmaz'), findsOneWidget);
    expect(find.text('Antrenör · Antrenör Mert'), findsOneWidget);
  });

  testWidgets('maliyet okunabilir birimlerle gösterilir', (tester) async {
    await _open(tester, _Backend());
    expect(find.text('2 sa · 20 enerji'), findsOneWidget);
  });

  testWidgets('requires kapısı nitelik adıyla gösterilir', (tester) async {
    await _open(tester, _Backend(),
        offer: _offer(requires: const {'politeness': 4}));
    expect(find.textContaining('Kabul için:'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
  });

  testWidgets('kabul /accept POSTlar ve sonucu döndürür', (tester) async {
    final backend = _Backend();
    await _open(tester, backend);

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();

    expect(backend.paths.last, 'POST /careers/car_1/social/offers/so_1/accept');
    expect(find.text('Fazladan idman'), findsNothing, reason: 'modal kapandı');
  });

  testWidgets('ret /decline POSTlar', (tester) async {
    final backend = _Backend();
    await _open(tester, backend);

    await tester.tap(find.byKey(const ValueKey('offerDecline')));
    await tester.pumpAndSettle();

    expect(backend.paths.last, 'POST /careers/car_1/social/offers/so_1/decline');
    expect(find.text('Fazladan idman'), findsNothing);
  });

  testWidgets('barrier\'a dokunmak modalı kapatmaz', (tester) async {
    await _open(tester, _Backend());

    // Kartın dışında, ekranın en üstünde bir nokta.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Fazladan idman'), findsOneWidget);
  });

  testWidgets('geri tuşu modalı kapatmaz', (tester) async {
    await _open(tester, _Backend());

    final widgetsBinding = tester.binding;
    await widgetsBinding.handlePopRoute();
    await tester.pumpAndSettle();

    // D53 · cevap zorunlu; INV-40 sayesinde ret her zaman mümkün olduğu için
    // bu kilit bir çıkmaz değil.
    expect(find.text('Fazladan idman'), findsOneWidget);
  });

  testWidgets('409 modalı açık bırakır ve mesajı gösterir', (tester) async {
    await _open(tester, _Backend(acceptStatus: 409));

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();

    expect(find.text("not enough 'time' left today"), findsOneWidget);
    expect(find.text('Fazladan idman'), findsOneWidget);
    // Reddetmek hâlâ mümkün olmalı (INV-40); bir sonraki test bunu
    // gerçekten basarak doğruluyor, burada düğmenin etkin olduğu yeter.
    final decline = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('offerDecline')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(decline.onPressed, isNotNull);
  });

  testWidgets('reddedilen kabulden sonra ret hâlâ çalışır', (tester) async {
    final backend = _Backend(acceptStatus: 409);
    await _open(tester, backend);

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('offerDecline')));
    await tester.pumpAndSettle();

    expect(backend.paths.last, 'POST /careers/car_1/social/offers/so_1/decline');
    expect(find.text('Fazladan idman'), findsNothing);
  });
}
