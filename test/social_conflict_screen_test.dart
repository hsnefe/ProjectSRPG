import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/social_conflict_screen.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _careerState = {
  'current_date': '2026-08-19', 'season_id': '25/26',
  'money': 48200, 'condition': 66, 'day_budget': {'time': 600.0},
};

const _conflictBody = {
  'conflict_id': 'scf_1', 'source': 'plan', 'due_on': '2026-08-19',
  'status': 'open', 'chosen_ref': null,
  'sides': [
    {
      'ref_id': 'spl_1', 'relationship_id': 'partner',
      'template_id': 'partner_evening_out',
      'title': 'Akşam yemeği', 'body': 'Yemek rezervasyonu yaptırmış.',
      'relationship': {
        'relationship_id': 'partner', 'kind': 'partner', 'category': 'Sevgili',
        'score': 64, 'person_name': 'Deniz Arda', 'contact_name': 'Deniz',
      },
    },
    {
      'ref_id': 'spl_2', 'relationship_id': 'team',
      'template_id': 'team_dinner',
      'title': 'Kadro yemeği', 'body': 'Kadro yemeğine çağırdılar.',
      'relationship': {
        'relationship_id': 'team', 'kind': 'team', 'category': 'Takım',
        'score': 58, 'person_name': 'Takım', 'contact_name': 'Takım',
      },
    },
  ],
};

/// Sunucunun `choose` yanıtı — çakışmanın çözülmüş hâli ve **iki** ilişki
/// değişimi (INV-52). Barlar yalnızca buradan besleniyor.
Map<String, Object?> _resultBody({
  required String chosenRef,
  required int partnerBefore,
  required int partnerAfter,
  required int teamBefore,
  required int teamAfter,
}) =>
    {
      'career_state': _careerState,
      'conflict': {..._conflictBody, 'status': 'resolved', 'chosen_ref': chosenRef},
      'relationship_changes': [
        {'relationship_id': 'partner', 'before': partnerBefore,
         'after': partnerAfter, 'delta': partnerAfter - partnerBefore},
        {'relationship_id': 'team', 'before': teamBefore,
         'after': teamAfter, 'delta': teamAfter - teamBefore},
      ],
      'attribute_changes': const <dynamic>[],
      'ledger_entries': const <dynamic>[],
    };

class _Backend {
  _Backend({this.chooseStatus = 200});

  final int chooseStatus;
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
      if (request.url.path.contains('/choose/')) {
        if (chooseStatus != 200) {
          return _json(
            {'code': 'internal', 'message': 'sunucuya ulaşılamadı'},
            status: chooseStatus,
          );
        }
        // Seçilen taraf yükselir, eleneni düşer — sunucunun gerçekten
        // döndürdüğü asimetri (+4 / -12).
        final chose = request.url.path.endsWith('/spl_1');
        return _json(_resultBody(
          chosenRef: chose ? 'spl_1' : 'spl_2',
          partnerBefore: 64, partnerAfter: chose ? 68 : 52,
          teamBefore: 58, teamAfter: chose ? 46 : 62,
        ));
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    return CareerSession(
      client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'),
    );
  }
}

/// Ekranı gerçek bir route olarak iter; dönen fonksiyon pop edilen sonucu verir.
Future<api.SocialConflictResult? Function()> _open(
  WidgetTester tester,
  _Backend backend,
) async {
  api.SocialConflictResult? captured;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              captured = await showSocialConflictScreen(
                context,
                session: backend.session(),
                conflict: api.SocialConflict.fromJson(
                  Map<String, dynamic>.from(_conflictBody),
                ),
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

Finder _card(String key) => find.byKey(ValueKey(key));

/// POST'u çözer, barları oynatır, ama ekranın kendi kapanışını beklemez.
///
/// İlk iki kare isteği ve `setState`'i geçirip `TweenAnimationBuilder`'ın
/// ticker'ını başlatıyor (değer hâlâ 0), sonuncusu 400 ms ileri sararak
/// 320 ms'lik animasyonu tamamlıyor. Toplam süre 1100 ms'lik kapanma
/// gecikmesinin altında kalıyor, o yüzden ekran hâlâ açık.
Future<void> _settleBars(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Kapanma zamanlayıcısını da geçirir; bekleyen bir `Timer` ile biten test
/// `!timersPending` iddiasına takılır.
Future<void> _closeScreen(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('iki tarafın künyesi ve plan metni çizilir', (tester) async {
    await _open(tester, _Backend());

    expect(find.text('Deniz'), findsOneWidget);
    expect(find.text('SEVGİLİ'), findsOneWidget);
    expect(find.text('Yemek rezervasyonu yaptırmış.'), findsOneWidget);
    expect(find.text('Takım'), findsWidgets);
    expect(find.text('Kadro yemeğine çağırdılar.'), findsOneWidget);
    expect(find.text('YA DA'), findsOneWidget);
  });

  testWidgets('ekranda hiç buton yok', (tester) async {
    await _open(tester, _Backend());

    // Seçim karta dokunarak yapılıyor: onay da devam da yok.
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.text('Devam'), findsNothing);
  });

  testWidgets('kartlar karedir ve çapraz yerleşir', (tester) async {
    await _open(tester, _Backend());

    final firstSize = tester.getSize(_card('conflictFirst'));
    final secondSize = tester.getSize(_card('conflictSecond'));
    expect(firstSize.width, firstSize.height);
    expect(firstSize, secondSize);

    final firstCorner = tester.getTopLeft(_card('conflictFirst'));
    final secondCorner = tester.getTopLeft(_card('conflictSecond'));
    expect(secondCorner.dx, greaterThan(firstCorner.dx));
    expect(secondCorner.dy, greaterThan(firstCorner.dy));
  });

  testWidgets('seçimden önce mevcut puanlar durur, delta gösterilmez',
      (tester) async {
    await _open(tester, _Backend());

    expect(find.text('64'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('birinci karta basınca POST atılır ve barlar yanıttan oynar',
      (tester) async {
    final backend = _Backend();
    await _open(tester, backend);

    await tester.tap(_card('conflictFirst'));
    await _settleBars(tester);

    expect(backend.paths.last,
        'POST /careers/car_1/social/conflicts/scf_1/choose/spl_1');
    expect(find.text('68'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('46'), findsOneWidget);
    expect(find.text('-12'), findsOneWidget);
    // Ekran henüz kapanmadı — animasyon okunacak kadar duruyor.
    expect(find.byType(SocialConflictScreen), findsOneWidget);

    await _closeScreen(tester);
  });

  testWidgets('ikinci karta basınca aynası olur', (tester) async {
    final backend = _Backend();
    await _open(tester, backend);

    await tester.tap(_card('conflictSecond'));
    await _settleBars(tester);

    expect(backend.paths.last,
        'POST /careers/car_1/social/conflicts/scf_1/choose/spl_2');
    expect(find.text('62'), findsOneWidget);
    expect(find.text('52'), findsOneWidget);

    await _closeScreen(tester);
  });

  testWidgets('seçimden sonra diğer karta dokunmak ikinci POST atmaz',
      (tester) async {
    final backend = _Backend();
    await _open(tester, backend);

    await tester.tap(_card('conflictFirst'));
    await _settleBars(tester);
    await tester.tap(_card('conflictSecond'), warnIfMissed: false);
    await _settleBars(tester);

    final chooses =
        backend.paths.where((p) => p.contains('/choose/')).toList();
    expect(chooses, hasLength(1));
    expect(find.text('68'), findsOneWidget, reason: 'ilk seçim korunur');

    await _closeScreen(tester);
  });

  testWidgets('ekran kendi kapanır ve sonucu döndürür', (tester) async {
    final result = await _open(tester, _Backend());

    await tester.tap(_card('conflictSecond'));
    await _closeScreen(tester);

    expect(find.byType(SocialConflictScreen), findsNothing);
    expect(result()?.conflict.chosenRef, 'spl_2');
    expect(result()?.relationshipChanges, hasLength(2));
  });

  testWidgets('hata gelirse ekran açık kalır ve seçim geri alınır',
      (tester) async {
    await _open(tester, _Backend(chooseStatus: 500));

    await tester.tap(_card('conflictFirst'));
    await _settleBars(tester);

    expect(find.byKey(const Key('social_conflict_error')), findsOneWidget);
    expect(find.byType(SocialConflictScreen), findsOneWidget);
    // Puanlar kıpırdamadı; oyuncu yeniden seçebilir.
    expect(find.text('64'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
  });

  testWidgets('seçim yapılmadan geri tuşu ekranı kapatmaz', (tester) async {
    await _open(tester, _Backend());

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SocialConflictScreen), findsOneWidget);
  });
}
