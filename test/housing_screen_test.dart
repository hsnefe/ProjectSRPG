import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/housing_screen.dart';
import 'package:project_srpg/screens/lifestyle_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

Map<String, dynamic> _home(
  String id,
  String title,
  String kind, {
  int sleep = 6,
  int grade = 0,
  int price = 0,
  int rent = 0,
  int fee = 0,
  double noise = 0,
  bool held = false,
  bool active = false,
  String? tenure,
  Map<String, dynamic>? rest,
  List<String> upgrades = const [],
}) =>
    {
      'residence_id': id, 'title': title, 'kind': kind, 'sleep': sleep,
      'grade': grade, 'price': price, 'rent_monthly': rent, 'daily_fee': fee,
      'noise_chance': noise, 'modifiers': const [], 'description': '…',
      'note': 'Not: $title', 'held': held, 'active': active, 'tenure': tenure,
      'expires_on': null, 'upgrades': List<String>.of(upgrades),
      'rest': ?rest,
    };

const _upgrades = [
  {'upgrade_id': 'up-orthopedic-bed', 'title': 'Ortopedik yatak', 'price': 120,
   'sleep': 1, 'note': 'Uyku kazancı +1'},
  {'upgrade_id': 'up-chef', 'title': 'Özel aşçı', 'price': 400,
   'monthly_fee': 60, 'morning': 2, 'note': 'Her sabah +2'},
];

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Sunucunun konut durumu bellekte tutulur; yazan uçlar onu değiştirir, yani
/// ekranın yanıttan yeniden çizmesi gerçekten sınanır.
class _Backend {
  _Backend({this.money = 48200}) {
    homes = [
      _home('res-dorm', 'Altyapı yurdu', 'start',
          noise: 0.2, held: true, active: true, tenure: 'start'),
      _home('res-family', 'Ailenin evi', 'start', sleep: 8),
      _home('res-studio', 'Merkezi stüdyo daire', 'rent',
          sleep: 8, grade: 1, rent: 55),
      _home('res-hotel', 'Otel odası', 'hotel', sleep: 9, fee: 15),
      _home('res-garden-house', 'Bahçeli müstakil ev', 'buy',
          sleep: 10, grade: 2, price: 2500),
      _home('res-rehab-villa', 'Rehabilitasyon odalı villa', 'buy',
          sleep: 14, grade: 4, price: 2000000),
      _home('hol-village-house', 'Memleketteki köy evi', 'holiday',
          price: 700, rest: {'condition': 15, 'effects': {}}),
    ];
  }

  int money;
  late List<Map<String, dynamic>> homes;
  final calls = <String>[];

  Map<String, dynamic> get _active => homes.firstWhere((h) => h['active'] == true);

  Map<String, dynamic> body({bool moved = false}) => {
        'career_state': {
          'current_date': '2026-08-05', 'season_id': '25/26',
          'money': money, 'condition': 72, 'day_budget': {'time': 720.0},
        },
        'active_residence_id': _active['residence_id'],
        'residences': homes,
        'upgrades': _upgrades,
        'condition_recovery': {
          'base': _active['sleep'], 'bonus': 0, 'total': _active['sleep'],
          'noise': {'chance': _active['noise_chance'], 'halved': false},
        },
        'moved': moved,
      };

  http.Response handle(http.Request request) {
    final path = request.url.path;
    if (path == '/careers') {
      return _json({
        'careers': [
          {'career_id': 'car_test', 'player_name': 'Efe Kaan',
           'season_id': '25/26', 'current_date': '2026-08-05'},
        ],
      });
    }
    if (path == '/careers/car_test/housing') return _json(body());
    final m = RegExp(r'^/careers/car_test/housing/([\w-]+)/(acquire|activate|rest|upgrades/([\w-]+))$')
        .firstMatch(path);
    if (m == null) return http.Response('unexpected $path', 404);
    final id = m.group(1)!;
    final verb = m.group(2)!.split('/').first;
    calls.add('$verb:$id${m.group(3) != null ? ':${m.group(3)}' : ''}');
    final home = homes.firstWhere((h) => h['residence_id'] == id);
    if (verb == 'rest') {
      return _json({'code': 'rest_out_of_season', 'message': 'x'}, status: 409);
    }
    if (verb == 'upgrades') {
      money -= 120;
      (home['upgrades'] as List).add(m.group(3)!);
      return _json(body());
    }
    if (verb == 'acquire') {
      final cost = (home['price'] as int) + (home['rent_monthly'] as int);
      if (money < cost) {
        return _json({'code': 'insufficient_funds', 'message': 'balance is too low'}, status: 409);
      }
      money -= cost;
      home['held'] = true;
      home['tenure'] = home['kind'] == 'rent' ? 'rented' : 'owned';
    }
    final moves = verb == 'activate' || home['kind'] == 'rent';
    if (moves) {
      _active['active'] = false;
      home['held'] = true;
      home['active'] = true;
    }
    return _json(body(moved: moves));
  }
}

CareerSession _session(_Backend backend) => CareerSession(
      client: CareerApiClient(
        httpClient: MockClient((r) async => backend.handle(r)),
        baseUrl: 'http://test',
      ),
    );

Widget _wrap(Widget home) => PlayerScope(
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: home,
      ),
    );

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('§14.4 · aktif konut, yarınki gece ve bölümler görünür', (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(_wrap(HousingScreen(session: _session(_Backend()))));
    await tester.pumpAndSettle();

    expect(find.text('Konut'), findsOneWidget);
    expect(find.text('Altyapı yurdu'), findsWidgets);
    expect(find.textContaining('Yarınki gece: +6 kondisyon'), findsOneWidget);
    expect(find.textContaining('gürültü %20'), findsOneWidget);
    for (final title in ['BAŞLANGIÇ', 'KİRALIK', 'OTEL', 'SATIN ALINABİLİR', 'TATİL MÜLKLERİ']) {
      expect(find.text(title), findsOneWidget);
    }
    // Aktif konutun düğmesi pasif.
    final active = tester.widget<FilledButton>(find.byKey(const Key('residence_action_res-dorm')));
    expect(active.onPressed, isNull);
    // Otel elle alınmaz.
    final hotel = tester.widget<FilledButton>(find.byKey(const Key('residence_action_res-hotel')));
    expect(hotel.onPressed, isNull);
    expect(find.text('Transferden sonra kulüp verir'), findsOneWidget);
  });

  testWidgets('§14.4 · kiralayınca taşınır ve ekran yanıttan yeniden çizilir', (tester) async {
    _tallSurface(tester);
    final backend = _Backend();
    await tester.pumpWidget(_wrap(HousingScreen(session: _session(backend))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('residence_action_res-studio')));
    await tester.pumpAndSettle();

    expect(backend.calls, ['acquire:res-studio']);
    expect(find.textContaining('Merkezi stüdyo daire kiralandı'), findsOneWidget);
    expect(find.textContaining('Yarınki gece: +8 kondisyon'), findsOneWidget);
    final studio = tester.widget<FilledButton>(find.byKey(const Key('residence_action_res-studio')));
    expect(studio.onPressed, isNull);
    expect(find.text('Burada yaşıyorsun'), findsOneWidget);
  });

  testWidgets('§14.4 · satın almak taşımaz; Taşın ayrı bir adımdır', (tester) async {
    _tallSurface(tester);
    final backend = _Backend();
    await tester.pumpWidget(_wrap(HousingScreen(session: _session(backend))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('residence_action_res-garden-house')));
    await tester.pumpAndSettle();
    expect(backend.calls, ['acquire:res-garden-house']);
    expect(find.text('Burada yaşıyorsun'), findsOneWidget);      // hâlâ yurt
    expect(find.text('Taşın'), findsWidgets);

    await tester.tap(find.byKey(const Key('residence_action_res-garden-house')));
    await tester.pumpAndSettle();
    expect(backend.calls.last, 'activate:res-garden-house');
    expect(find.textContaining('Yarınki gece: +10 kondisyon'), findsOneWidget);
  });

  testWidgets('§14.4 · bakiyesi yetmeyen konut pasif ve bakiye yetersiz yazar', (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(_wrap(HousingScreen(session: _session(_Backend()))));
    await tester.pumpAndSettle();

    final villa = tester.widget<FilledButton>(find.byKey(const Key('residence_action_res-rehab-villa')));
    expect(villa.onPressed, isNull);
    expect(find.text('Bakiye yetersiz'), findsOneWidget);
  });

  testWidgets('§14.4 · geliştirme yalnız sahip olunan evde takılır', (tester) async {
    _tallSurface(tester);
    final backend = _Backend();
    await tester.pumpWidget(_wrap(HousingScreen(session: _session(backend))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('upgrade_up-chef')), findsNothing);
    expect(find.textContaining('yalnız sahip olduğun'), findsOneWidget);

    await tester.tap(find.byKey(const Key('residence_action_res-garden-house')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('residence_action_res-garden-house')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('upgrade_up-orthopedic-bed')), findsOneWidget);
    expect(find.text('Özel aşçı'), findsOneWidget);
    expect(find.textContaining('/ay'), findsWidgets);            // aşçının aylık ücreti

    await tester.tap(find.descendant(
      of: find.byKey(const Key('upgrade_up-orthopedic-bed')),
      matching: find.byType(OutlinedButton),
    ));
    await tester.pumpAndSettle();
    expect(backend.calls.last, 'upgrades:res-garden-house:up-orthopedic-bed');
    expect(find.text('Takılı'), findsOneWidget);
  });

  testWidgets('§14.4 · sezon dışı dinlenme sunucunun reddiyle anlatılır', (tester) async {
    _tallSurface(tester);
    final backend = _Backend();
    backend.homes.firstWhere((h) => h['residence_id'] == 'hol-village-house')['held'] = true;
    await tester.pumpWidget(_wrap(HousingScreen(session: _session(backend))));
    await tester.pumpAndSettle();

    expect(find.text('Dinlen · +15 kondisyon'), findsOneWidget);
    await tester.tap(find.byKey(const Key('residence_action_hol-village-house')));
    await tester.pumpAndSettle();

    expect(find.textContaining('kış arasında ve yaz penceresinde'), findsOneWidget);
  });

  testWidgets('Yaşam Tarzı header\'ındaki butondan açılır', (tester) async {
    await tester.pumpWidget(_wrap(const LifestyleScreen()));
    expect(find.byTooltip('Konut'), findsOneWidget);
  });
}
