import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/social_offer_screen.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';

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

Map<String, Object?> _resultBody(
  String status,
  int delta, {
  List<Object?> attributeChanges = const <dynamic>[],
}) =>
    {
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
      'attribute_changes': attributeChanges,
      'ledger_entries': const <dynamic>[],
    };

class _Backend {
  _Backend({this.acceptStatus = 200, this.acceptBody});

  final int acceptStatus;

  /// Kabul yanıtını değiştirmek isteyen testler için; null ise yalnızca +5'lik
  /// ilişki değişimi taşıyan varsayılan gövde döner.
  final Map<String, Object?>? acceptBody;

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
        return _json(acceptBody ?? _resultBody('accepted', 5));
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

/// Ekranı gerçek bir route olarak iter — geri tuşu davranışı ve `pop`'un
/// döndürdüğü sonuç ancak böyle test edilebilir. Dönen fonksiyon çağrıldığında
/// ekranın `pop` ettiği değeri verir: `_open` itme anında dönüyor, sonuç ise
/// ekran kapandığında yazılıyor.
Future<api.SocialOfferResult? Function()> _open(
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
              captured = await showSocialOfferScreen(
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
  return () => captured;
}

/// Daktilo bitene ve butonlar belirene kadar ilerletir.
///
/// `pumpAndSettle` tek başına yetmiyor: butonlar `Future.delayed` ile 80 ms
/// arayla beliriyor ve bekleyen bir gecikmenin planlanmış karesi olmadığı için
/// `pumpAndSettle` erken dönüyor. Metne dokunmak yazıyı anında tamamlar,
/// ikinci dokunuş da sıradaki butonları bir kerede açar.
Future<void> _skipIntro(WidgetTester tester) async {
  await tester.tap(find.byType(SingleChildScrollView));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(SingleChildScrollView));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('başlık, gövde ve iki etiket çizilir', (tester) async {
    await _open(tester, _Backend());
    await _skipIntro(tester);

    expect(find.text('Fazladan idman'), findsOneWidget);
    expect(find.text('Antrenör yarın sabah bire bir çalışmak istiyor.'),
        findsOneWidget);
    expect(find.text('Sahada olurum'), findsOneWidget);
    expect(find.text('Bu hafta olmaz'), findsOneWidget);
  });

  testWidgets('kişinin künyesi ve skoru sahnenin üstünde durur', (tester) async {
    await _open(tester, _Backend());

    expect(find.text('Antrenör Mert'), findsOneWidget);
    expect(find.text('ANTRENÖR'), findsOneWidget);
    expect(find.text('70'), findsOneWidget);
  });

  group('§4.1 mekânsal bağımlılık', () {
    testWidgets('coach_extra_session soyunma odası yerine sahada geçer',
        (tester) async {
      // _offer()'ın varsayılanı zaten 'coach_extra_session' — coach'ın
      // kendi varsayılanı (lockerRoom) burada ezilmiş olmalı.
      await _open(tester, _Backend());

      final backdrop = tester.widget<DialogueBackdrop>(
        find.byType(DialogueBackdrop),
      );
      expect(backdrop.scene, DialogueScene.trainingGround);
    });

    testWidgets('eşlenmeyen bir şablon ilişkinin varsayılan sahnesini kullanır',
        (tester) async {
      final offer = api.SocialOffer.fromJson({
        'offer_id': 'so_2',
        'template_id': 'coach_video_review',
        'relationship_id': 'coach',
        'relationship': {
          'relationship_id': 'coach', 'kind': 'coach', 'category': 'Antrenör',
          'score': 70, 'person_name': 'Mert Çalışkan', 'contact_name': 'Antrenör Mert',
        },
        'title': 'Video toplantısı',
        'body': '...',
        'accept_label': 'İzleyelim',
        'decline_label': 'Gerek yok',
        'costs': const <String, dynamic>{'time': 90},
        'requires': const <String, dynamic>{},
        'opened_on': '2026-08-19',
        'status': 'open',
        'resolved_on': null,
      });
      await _open(tester, _Backend(), offer: offer);

      final backdrop = tester.widget<DialogueBackdrop>(
        find.byType(DialogueBackdrop),
      );
      expect(backdrop.scene, DialogueScene.lockerRoom);
    });
  });

  testWidgets('maliyet ayrı rozetlerde okunabilir birimlerle gösterilir',
      (tester) async {
    await _open(tester, _Backend());

    expect(find.text('2 sa'), findsOneWidget);
    expect(find.text('20 enerji'), findsOneWidget);
  });

  testWidgets('requires kapısı nitelik adıyla rozetlenir', (tester) async {
    await _open(tester, _Backend(),
        offer: _offer(requires: const {'empathy': 4}));

    expect(find.text('Kabul için'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
  });

  testWidgets('daktilo bitmeden butonlar basılamaz', (tester) async {
    final backend = _Backend();
    await _open(tester, backend);

    // Yazı akarken butonlar görünmez ve `IgnorePointer` altında.
    await tester.tap(find.byKey(const ValueKey('offerAccept')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(backend.paths,
        isNot(contains('POST /careers/car_1/social/offers/so_1/accept')));
  });

  testWidgets('kabul /accept POSTlar ve ekranı sonuç fazına geçirir',
      (tester) async {
    final backend = _Backend();
    await _open(tester, backend);
    await _skipIntro(tester);

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();

    expect(backend.paths.last, 'POST /careers/car_1/social/offers/so_1/accept');
    // Ekran kapanmaz: sonuç kişinin karşısında gösteriliyor.
    expect(find.byType(SocialOfferScreen), findsOneWidget);
    expect(find.text('Antrenör'), findsOneWidget);
    expect(find.text('70 → 75'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
  });

  testWidgets('sonuç panelindeki Devam ekranı kapatır ve sonucu döndürür',
      (tester) async {
    final result = await _open(tester, _Backend());
    await _skipIntro(tester);

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();
    await _skipIntro(tester);
    await tester.tap(find.byKey(const ValueKey('offerDone')));
    await tester.pumpAndSettle();

    expect(find.byType(SocialOfferScreen), findsNothing);
    expect(result()?.offer.status, 'accepted');
    expect(result()?.relationshipChanges.single.delta, 5);
  });

  testWidgets('ret /decline POSTlar ve düşen skoru gösterir', (tester) async {
    final backend = _Backend();
    await _open(tester, backend);
    await _skipIntro(tester);

    await tester.tap(find.byKey(const ValueKey('offerDecline')));
    await tester.pumpAndSettle();

    expect(backend.paths.last, 'POST /careers/car_1/social/offers/so_1/decline');
    expect(find.text('70 → 67'), findsOneWidget);
    expect(find.text('-3'), findsOneWidget);
  });

  testWidgets('§12.8/D58 · planlı bir kabul randevu tarihini gösterir',
      (tester) async {
    final backend = _Backend(
      acceptBody: {
        ..._resultBody('accepted', 5),
        'plan': {
          'plan_id': 'spl_1',
          'offer_id': 'so_1',
          'template_id': 'coach_extra_session',
          'relationship_id': 'coach',
          'title': 'Fazladan idman',
          'body': '...',
          'due_on': '2026-08-20',
          'status': 'pending',
          'costs': {'time': 120.0, 'energy': 20.0},
        },
      },
    );
    await _open(tester, backend);
    await _skipIntro(tester);

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Randevu'), findsOneWidget);
  });

  testWidgets('seviye atlayan nitelik sonuç panelinde belirtilir',
      (tester) async {
    final backend = _Backend(
      acceptBody: _resultBody('accepted', 5, attributeChanges: [
        {'key': 'finishing', 'before': 41.0, 'after': 44.0,
         'level_before': 2, 'level_after': 3},
      ]),
    );
    await _open(tester, backend);
    await _skipIntro(tester);

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();

    expect(find.text('41 → 44'), findsOneWidget);
    expect(find.textContaining('seviye 3'), findsOneWidget);
  });

  testWidgets('geri tuşu ekranı kapatmaz', (tester) async {
    await _open(tester, _Backend());

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // D53 · cevap zorunlu; INV-40 sayesinde ret her zaman mümkün olduğu için
    // bu kilit bir çıkmaz değil.
    expect(find.byType(SocialOfferScreen), findsOneWidget);
    expect(find.text('Fazladan idman'), findsOneWidget);
  });

  testWidgets('409 teklif fazını açık bırakır ve mesajı gösterir',
      (tester) async {
    await _open(tester, _Backend(acceptStatus: 409));
    await _skipIntro(tester);

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();

    expect(find.text("not enough 'time' left today"), findsOneWidget);
    expect(find.text('Fazladan idman'), findsOneWidget);
    // Reddetmek hâlâ mümkün olmalı (INV-40); bir sonraki test bunu gerçekten
    // basarak doğruluyor, burada düğmenin etkin olduğu yeter.
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
    await _skipIntro(tester);

    await tester.tap(find.byKey(const ValueKey('offerAccept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('offerDecline')));
    await tester.pumpAndSettle();

    expect(backend.paths.last, 'POST /careers/car_1/social/offers/so_1/decline');
    expect(find.text('70 → 67'), findsOneWidget);
  });
}
