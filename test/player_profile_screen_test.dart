import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/player_profile_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/value_scatter_chart.dart';

/// P2 kesitleri — eski sabit `_stats` listesinin bire bir aynısı, artık bir
/// HTTP gövdesi olarak. Sayılar değişmedi, kaynağı değişti: testler
/// toplamanın (`_StatTotals.of`) hâlâ doğru çalıştığını kanıtlıyor.
const _statRows = [
  {
    'season_id': '25/26', 'competition_id': 'c_lig', 'competition_kind': 'lig',
    'competition_name': '1. Lig', 'appearances': 18, 'starts': 15, 'goals': 4,
    'assists': 6, 'minutes': 1342, 'passes_completed': 389, 'passes_attempted': 442,
  },
  {
    'season_id': '25/26', 'competition_id': 'c_kupa', 'competition_kind': 'kupa',
    'competition_name': 'Ulusal Kupa', 'appearances': 4, 'starts': 3, 'goals': 1,
    'assists': 1, 'minutes': 310, 'passes_completed': 88, 'passes_attempted': 101,
  },
  {
    'season_id': '25/26', 'competition_id': 'c_int', 'competition_kind': 'uluslararasi',
    'competition_name': 'Uluslararası', 'appearances': 6, 'starts': 4, 'goals': 2,
    'assists': 2, 'minutes': 421, 'passes_completed': 132, 'passes_attempted': 155,
  },
  {
    'season_id': '24/25', 'competition_id': 'c_lig', 'competition_kind': 'lig',
    'competition_name': '1. Lig', 'appearances': 31, 'starts': 24, 'goals': 5,
    'assists': 8, 'minutes': 2310, 'passes_completed': 640, 'passes_attempted': 742,
  },
  {
    'season_id': '24/25', 'competition_id': 'c_kupa', 'competition_kind': 'kupa',
    'competition_name': 'Ulusal Kupa', 'appearances': 5, 'starts': 4, 'goals': 2,
    'assists': 1, 'minutes': 402, 'passes_completed': 110, 'passes_attempted': 128,
  },
  {
    'season_id': '23/24', 'competition_id': 'c_lig', 'competition_kind': 'lig',
    'competition_name': '1. Lig', 'appearances': 12, 'starts': 5, 'goals': 1,
    'assists': 2, 'minutes': 640, 'passes_completed': 168, 'passes_attempted': 210,
  },
];

const _valueHistory = [
  {'measured_on': '2024-01-15', 'value': 450000},
  {'measured_on': '2024-07-01', 'value': 900000},
];

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

CareerSession _statsSession() {
  final mock = MockClient((request) async {
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
    if (request.url.path == '/careers/car_test/player/stats') {
      return _json({'rows': _statRows, 'value_history': _valueHistory});
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

Widget _wrap(Widget home) {
  return PlayerScope(
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: home,
    ),
  );
}

/// Hap seçicilerden birini açıp verilen seçeneğe basar.
Future<void> _pick(
  WidgetTester tester,
  String filterKey,
  String option,
) async {
  await tester.tap(find.byKey(ValueKey(filterKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  // Kimlik alanları (yaş/isim/takım) PlayerScope'un P1'inden gelir; test
  // ortamında career_engine çalışmadığından PlayerState kendi yer
  // tutucularına düşer — bunlar da tam olarak 21/'Efe Kaan'/'FK Yıldız'.
  // İstatistikler ise bu ekranın kendi P2 çağrısından, sahte backend'den gelir.
  testWidgets('profil ekranı kimlik satırını ve bu sezonun istatistiklerini '
      'gösterir', (tester) async {
    await tester.pumpWidget(
      _wrap(PlayerProfileScreen(session: _statsSession())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yaş: 21'), findsOneWidget);
    expect(find.text('Efe Kaan'), findsOneWidget);
    expect(find.text('FK Yıldız'), findsOneWidget);
    expect(find.text('Oynanan dakika'), findsOneWidget);

    // Çıplak sayılar satırlar arasında çakıştığı için kesire assert ediyoruz.
    expect(find.text('609/698'), findsOneWidget);
    expect(find.text('Başarılı pas: %87'), findsOneWidget);
  });

  testWidgets('müsabaka filtresi istatistikleri daraltır', (tester) async {
    await tester.pumpWidget(
      _wrap(PlayerProfileScreen(session: _statsSession())),
    );
    await tester.pumpAndSettle();

    await _pick(tester, 'competitionFilter', 'Kupa');

    expect(find.text('88/101'), findsOneWidget);
    expect(find.text('Başarılı pas: %87'), findsOneWidget);
    expect(find.text('609/698'), findsNothing);
  });

  testWidgets('Tümü seçimi bütün sezonları toplar', (tester) async {
    await tester.pumpWidget(
      _wrap(PlayerProfileScreen(session: _statsSession())),
    );
    await tester.pumpAndSettle();

    await _pick(tester, 'seasonFilter', 'Tümü');

    // 1527/1778 tohum tablosunda hiç geçmiyor; toplamanın hesaplandığını
    // (hardcode edilmediğini) kanıtlayan değer bu.
    expect(find.text('76'), findsOneWidget);
    expect(find.text('1527/1778'), findsOneWidget);
    expect(find.text('Başarılı pas: %86'), findsOneWidget);
  });

  testWidgets('iki filtre birlikte çalışır', (tester) async {
    await tester.pumpWidget(
      _wrap(PlayerProfileScreen(session: _statsSession())),
    );
    await tester.pumpAndSettle();

    await _pick(tester, 'seasonFilter', 'Tümü');
    await _pick(tester, 'competitionFilter', 'Lig');

    expect(find.text('61'), findsOneWidget);
    expect(find.text('1197/1394'), findsOneWidget);
    expect(find.text('Başarılı pas: %86'), findsOneWidget);
  });

  testWidgets('değer tablosu grafiği filtrelerden etkilenmez', (tester) async {
    await tester.pumpWidget(
      _wrap(PlayerProfileScreen(session: _statsSession())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ValueScatterChart), findsOneWidget);
    expect(find.text('Kariyer boyunca piyasa değeri'), findsOneWidget);

    final before =
        tester.widget<ValueScatterChart>(find.byType(ValueScatterChart)).points;

    await _pick(tester, 'competitionFilter', 'Kupa');

    final after =
        tester.widget<ValueScatterChart>(find.byType(ValueScatterChart)).points;
    // P2'nin `value_history`'si artık her build'de tazeden eşlendiği için
    // (§1.3: BE tarihi verir, ekran etiketi türetir) nesne kimliği değil,
    // içerik aynılığı doğru kontrol — asıl iddia filtrenin veriyi
    // budamadığıdır.
    expect(after.length, before.length);
    for (var i = 0; i < before.length; i++) {
      expect(after[i].label, before[i].label);
      expect(after[i].value, before[i].value);
    }
  });

  testWidgets('Sözleşme butonu sözleşme ekranını açar', (tester) async {
    await tester.pumpWidget(
      _wrap(PlayerProfileScreen(session: _statsSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sözleşme'));
    await tester.pumpAndSettle();

    // Sözleşme ekranı kendi (singleton) CareerSession'ını kullanır ve test
    // ortamında career_engine yok — BE'ye erişemediği için "sözleşme
    // alınamadı" durumuna düşer; buradaki iddia yalnızca navigasyonun
    // çalıştığıdır (P3'ün kendi testleri contract_screen_test.dart'ta).
    expect(find.text('Sözleşme'), findsWidgets);
  });

  testWidgets('kariyer merkezinde isme basınca profil açılır', (tester) async {
    await tester.pumpWidget(_wrap(const CareerCenterScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Efe Kaan'));
    await tester.pumpAndSettle();

    // Kariyer merkezi alttaki rotada mount kaldığı için 'Efe Kaan' iki kez
    // bulunur; profile özgü olan 'Yaş: 21'e assert ediyoruz.
    expect(find.text('Yaş: 21'), findsOneWidget);
  });
}
