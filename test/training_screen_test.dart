import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/game/shot_game.dart' show ShotMode;
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/ball_training_screen.dart';
import 'package:project_srpg/screens/conditioning_training_screen.dart';
import 'package:project_srpg/screens/flexibility_training_screen.dart';
import 'package:project_srpg/screens/strength_training_screen.dart';
import 'package:project_srpg/screens/tackle_training_screen.dart';
import 'package:project_srpg/screens/training_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

/// N3 `training` kataloğu — career_engine/catalog/training.py'nin 10
/// kaleminin aynısı (7 saha + 3 taktik; §13.5/D77 kişi ailesini kaldırdı).
/// Elle tutulan bir ayna
/// olduğu için katalog değiştikçe burası da güncellenmeli: literal kendi
/// kendine yettiğinden, saptığında testler sessizce eski davranışı
/// doğrulamaya devam eder.
const _trainingItems = [
  {
    'catalog_id': 'kondisyon-kosusu', 'title': 'Kondisyon Koşusu',
    'description': '…', 'family': 'saha', 'drill': 'conditioning',
    'costs': {'time': 90, 'energy': 15},
    'effects': {'attribute:condition': 1.2},
  },
  {
    'catalog_id': 'guc-antrenmani', 'title': 'Güç Antrenmanı',
    'description': '…', 'family': 'saha', 'drill': 'strength',
    'costs': {'time': 75, 'energy': 20},
    'effects': {'attribute:strength': 1.2},
  },
  {
    'catalog_id': 'esneklik-toparlanma', 'title': 'Esneklik & Toparlanma',
    'description': '…', 'family': 'saha', 'drill': 'flexibility',
    'costs': {'time': 45, 'energy': 8},
    'effects': {'attribute:flexibility': 1.0, 'condition': 4},
  },
  {
    'catalog_id': 'sut', 'title': 'Şut',
    'description': '…', 'family': 'saha', 'drill': 'shot',
    'costs': {'time': 60, 'energy': 18},
    'effects': {'attribute:shooting': 1.2},
  },
  {
    'catalog_id': 'pas', 'title': 'Pas',
    'description': '…', 'family': 'saha', 'drill': 'pass',
    'costs': {'time': 60, 'energy': 12},
    'effects': {'attribute:passing': 1.2},
  },
  {
    'catalog_id': 'dribling', 'title': 'Dribling',
    'description': '…', 'family': 'saha', 'drill': 'dribble',
    'costs': {'time': 60, 'energy': 18},
    'effects': {'attribute:dribbling': 1.0},
  },
  {
    'catalog_id': 'mudahale', 'title': 'Müdahale',
    'description': '…', 'family': 'saha', 'drill': 'tackling',
    'costs': {'time': 60, 'energy': 20},
    'effects': {'attribute:tackling': 1.0},
  },
  {
    'catalog_id': 'gegenpress', 'title': 'Gegenpress',
    'description': '…', 'family': 'taktik', 'drill': null,
    'costs': {'time': 60, 'energy': 8},
    'effects': {'tactic:gegenpress': 0.8},
  },
  {
    'catalog_id': 'pozisyonel-oyun', 'title': 'Pozisyonel Oyun',
    'description': '…', 'family': 'taktik', 'drill': null,
    'costs': {'time': 75, 'energy': 6},
    'effects': {'tactic:pozisyonel_oyun': 0.8},
  },
  {
    'catalog_id': 'derin-blok', 'title': 'Derin Blok',
    'description': '…', 'family': 'taktik', 'drill': null,
    'costs': {'time': 45, 'energy': 5},
    'effects': {'tactic:derin_blok': 0.8},
  },
];

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

CareerSession _trainingSession() {
  final mock = MockClient((request) async {
    if (request.url.path == '/catalog/training') {
      return _json({'items': _trainingItems});
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

/// D42 · oyuncunun özgüven seviyesini [confidenceLevel] yapar; eşiğin
/// kendisi katalogda zaten duruyor.
/// §13.5 · D42'nin kapısı artık bir SAHA kartına takılıyor: kişi ailesi
/// (ve onunla birlikte tek `requires` taşıyan antrenman kalemi) kalktı.
/// Katalogda bugün eşiği olan bir antrenman yok — kapı bir mekanizma, onu
/// kullanmak bir içerik kararı — o yüzden test kendi eşiğini iliştiriyor.
CareerSession _gatedTrainingSession({required int confidenceLevel}) {
  final items = [
    for (final item in _trainingItems)
      if (item['catalog_id'] == 'sut')
        {...item, 'requires': const {'courage': 6}}
      else
        item,
  ];
  final mock = MockClient((request) async {
    if (request.url.path == '/catalog/training') {
      return _json({'items': items});
    }
    if (request.url.path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test', 'player_name': 'Efe Kaan',
            'season_id': '25/26', 'current_date': '2026-08-05',
          }
        ],
      });
    }
    if (request.url.path == '/careers/car_test/player') {
      return _json({
        'player_id': 'p_user', 'name': 'Efe Kaan', 'position': 'Orta saha',
        'birth_date': '2004-08-19', 'age': 21,
        'team': {
          'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
          'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
        },
        'career_state': {
          'current_date': '2026-08-05', 'season_id': '25/26',
          'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
        },
        'attributes': [
          {
            'key': 'courage', 'family': 'kişi',
            'value': confidenceLevel * 10.0, 'level': confidenceLevel,
            'passive_bonus': 0.0, 'effective_value': confidenceLevel * 10.0,
          },
        ],
        // §12.11 · P1 bunu her zaman gönderiyor (INV-55). Eksikti ve
        // PlayerProfile'ın sert cast'i yüzünden bu fixture'ın P1'i hiç
        // yüklenmiyordu: iki kapı testi de seviye 0 okuyup boşa geçiyordu.
        'tactics': const [
          {'key': 'gegenpress', 'value': 0.0},
        ],
        'fame': const [], 'market_value': null,
      });
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

/// Taktik kartının mini-oyunu olmadan doğrudan uygulanmasını sınamak için:
/// `/careers`, P1 VE `POST /actions`'ın hepsini gerçek bir round-trip'e
/// yetecek kadar sahte döndürür. [postedCatalogIds] her `POST /actions`
/// çağrısının `catalog_id`'sini biriktirir — testin "mini-oyun açılmadı,
/// doğrudan uygulandı" iddiasının kanıtı.
CareerSession _tacticalTrainingSession({required List<String> postedCatalogIds}) {
  final mock = MockClient((request) async {
    if (request.url.path == '/catalog/training') {
      return _json({'items': _trainingItems});
    }
    if (request.url.path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test', 'player_name': 'Efe Kaan',
            'season_id': '25/26', 'current_date': '2026-08-05',
          }
        ],
      });
    }
    if (request.url.path == '/careers/car_test/player') {
      return _json({
        'player_id': 'p_user', 'name': 'Efe Kaan', 'position': 'Orta saha',
        'birth_date': '2004-08-19', 'age': 21,
        'team': {
          'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
          'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
        },
        'career_state': {
          'current_date': '2026-08-05', 'season_id': '25/26',
          'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
        },
        'attributes': const [],
        'tactics': [
          {'key': 'gegenpress', 'value': 12.0},
        ],
        'fame': const [], 'market_value': null,
      });
    }
    if (request.method == 'POST' &&
        request.url.path == '/careers/car_test/actions') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      postedCatalogIds.add(body['catalog_id'] as String);
      return _json({
        'career_state': {
          'current_date': '2026-08-05', 'season_id': '25/26',
          'money': 48200, 'condition': 72, 'day_budget': {'time': 660.0},
        },
        'applied_costs': {'time': 60, 'energy': 8},
        'applied_effects': {'tactic:gegenpress': 0.8},
        'attribute_changes': const [],
        'tactic_changes': [
          {'key': 'gegenpress', 'before': 12.0, 'after': 12.8},
        ],
        'relationship_changes': const [],
        'ledger_entries': const [],
      });
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

Widget _wrap(Widget home, {CareerSession? session}) => PlayerScope(
      session: session,
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: home,
      ),
    );

/// Kart widget'ı ekrana özel ve private, o yüzden tip adından bulunuyor.
final _card = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_TrainingCard',
);

/// Antrenman kartındaki butonu başlığından bulur.
Finder _startButton(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: _card),
      matching: find.byType(OutlinedButton),
    );

OutlinedButton _button(WidgetTester tester, String title) =>
    tester.widget<OutlinedButton>(_startButton(title));

LinearProgressIndicator _progressBar(WidgetTester tester, String title) =>
    tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.ancestor(of: find.text(title), matching: _card),
        matching: find.byType(LinearProgressIndicator),
      ),
    );

/// Antrenman kartının butonunu tıklanabilir hale getirir. Listenin sonundaki
/// kartlar ekrana yarım sığdığı için başlığı görmek yetmiyor — butonun
/// kendisini görünür alana çekmek gerekiyor.
Future<void> _scrollTo(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(_startButton(title));
  await tester.pump();
}

void main() {
  group('kart butonları', () {
    // Müdahale'nin de oyunu olduğuna göre yedi saha kartının hepsi açık;
    // 'Yakında' artık yalnızca kişi kalemlerinde kalan bir durum.
    testWidgets('yedi saha kartı da Başla yazar ve tıklanabilir',
        (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();

      for (final title in [
        'Kondisyon Koşusu',
        'Güç Antrenmanı',
        'Esneklik & Toparlanma',
        'Şut',
        'Pas',
        'Dribling',
        'Müdahale',
      ]) {
        await _scrollTo(tester, title);
        expect(_button(tester, title).onPressed, isNotNull, reason: title);
      }
    });

    // §13.5/D77 · 'Yakında' dalı kişi kalemleriyle birlikte öldü. Kilitli
    // olmayan her kart artık gerçekten başlatılabilir.
    testWidgets('hiçbir kart Yakında yazmaz', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yakında'), findsNothing);

      await tester.tap(find.text('Taktik'));
      await tester.pumpAndSettle();
      expect(find.text('Yakında'), findsNothing);
    });
  });

  // §13.5/D77 · iki sekme kaldı. Kişi nitelikleri artık yaşam aktiviteleri,
  // sosyal teklifler, diyalog, aktivite olayları ve sahip olunan eşyalarla
  // gelişiyor (D78) — antrenman salonunda değil.
  testWidgets('Kişisel sekmesi yok, iki aile kaldı', (tester) async {
    await tester.pumpWidget(
      _wrap(TrainingScreen(session: _trainingSession())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kişisel'), findsNothing);
    expect(find.text('Fiziksel'), findsOneWidget);
    expect(find.text('Taktik'), findsOneWidget);
    expect(find.text('Medya Eğitimi'), findsNothing);
  });

  group('mini-oyunları açmak', () {
    testWidgets('Kondisyon koşu ekranını açar', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'Kondisyon Koşusu');

      await tester.tap(_startButton('Kondisyon Koşusu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConditioningTrainingScreen), findsOneWidget);

      // Canlı bir GameWidget kaldığı için test bitmeden söküyoruz.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Müdahale baskı zinciri ekranını açar', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'Müdahale');

      await tester.tap(_startButton('Müdahale'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TackleTrainingScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Güç bench press ekranını açar', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'Güç Antrenmanı');

      await tester.tap(_startButton('Güç Antrenmanı'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StrengthTrainingScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Esneklik desen ekranını açar', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'Esneklik & Toparlanma');

      await tester.tap(_startButton('Esneklik & Toparlanma'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FlexibilityTrainingScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Şut ve Pas aynı ekranı farklı modla açar', (tester) async {
      for (final (title, mode) in [
        ('Şut', ShotMode.shot),
        ('Pas', ShotMode.pass),
      ]) {
        await tester.pumpWidget(
          _wrap(TrainingScreen(session: _trainingSession())),
        );
        await tester.pumpAndSettle();
        await _scrollTo(tester, title);

        await tester.tap(_startButton(title));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final screen = tester.widget<BallTrainingScreen>(
          find.byType(BallTrainingScreen),
        );
        expect(screen.mode, mode, reason: title);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  testWidgets('eşiği tutulmayan antrenman Kilitli yazar, gerekçesi görünür',
      (tester) async {
    final session = _gatedTrainingSession(confidenceLevel: 5);
    await tester.pumpWidget(
      _wrap(TrainingScreen(session: session), session: session),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, 'Şut');

    expect(_button(tester, 'Şut').onPressed, isNull);
    expect(find.byKey(const Key('training_requirement_row')), findsOneWidget);
    expect(find.text('Cesaret 6 gerekli'), findsOneWidget);
    expect(find.text('Kilitli'), findsOneWidget);
  });

  testWidgets('eşik karşılanınca kilit satırı kaybolur', (tester) async {
    final session = _gatedTrainingSession(confidenceLevel: 6);
    await tester.pumpWidget(
      _wrap(TrainingScreen(session: session), session: session),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, 'Şut');
    expect(find.byKey(const Key('training_requirement_row')), findsNothing);
    expect(find.text('Kilitli'), findsNothing);
    // §13.5 · kilit kalkınca kart doğrudan başlatılabilir hâle gelir; eskiden
    // araya giren 'Yakında' durumu artık yok.
    expect(_button(tester, 'Şut').onPressed, isNotNull);
  });

  group('taktik sekmesi (§12.11)', () {
    testWidgets('taktik ailesindeki üç kalemi listeler', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Taktik'));
      await tester.pumpAndSettle();

      expect(find.text('Gegenpress'), findsOneWidget);
      expect(find.text('Pozisyonel Oyun'), findsOneWidget);
      expect(find.text('Derin Blok'), findsOneWidget);
      // Kondisyon Koşusu 'saha' ailesinde — taktik sekmede görünmemeli.
      expect(find.text('Kondisyon Koşusu'), findsNothing);
    });

    testWidgets('mini-oyunu olmasa da Başla yazar ve tıklanabilir',
        (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taktik'));
      await tester.pumpAndSettle();

      // Kişi kalemlerinin aksine (drill:null → Yakında), taktik kalemleri
      // drill:null olsa da tıklanabilir — §12.11'in ayırdığı nokta.
      expect(_button(tester, 'Gegenpress').onPressed, isNotNull);
      expect(find.text('Yakında'), findsNothing);
    });

    testWidgets(
        'Başla mini-oyun açmadan doğrudan uygular ve ilerlemeyi günceller',
        (tester) async {
      final posted = <String>[];
      final session = _tacticalTrainingSession(postedCatalogIds: posted);
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: session), session: session),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taktik'));
      await tester.pumpAndSettle();

      final before = _progressBar(tester, 'Gegenpress').value;
      expect(before, closeTo(0.12, 1e-9)); // P1: gegenpress 12.0/100

      await tester.tap(_startButton('Gegenpress'));
      await tester.pumpAndSettle();

      // Doğrudan uygulandı: ekran hâlâ TrainingScreen, hiçbir mini-oyun
      // ekranı açılmadı.
      expect(posted, ['gegenpress']);
      expect(find.byType(TrainingScreen), findsOneWidget);
      expect(_progressBar(tester, 'Gegenpress').value, closeTo(0.128, 1e-9));
    });
  });
}
