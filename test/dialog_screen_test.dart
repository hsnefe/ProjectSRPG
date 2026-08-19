import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/dialog_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

const _testTree = DialogueTree(
  startId: 'start',
  nodes: {
    'start': DialogueNode(
      id: 'start',
      line: 'Merhaba, nasılsın?',
      options: [DialogueOption(text: 'İyiyim, sen nasılsın?', nextId: 'end')],
    ),
    'end': DialogueNode(id: 'end', line: 'Ben de iyiyim, teşekkürler.'),
  },
);

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// R3'ün sahte backend'i — testin tek diyalog ağacı (start -> 'end') için
/// tek bir yaprak (`end`) kabul eder, gerçek `interact()` çağrısının
/// diyalog akışını bozmadığını doğrular.
CareerSession _dialogSession() {
  final mock = MockClient((request) async {
    if (request.url.path == '/careers') {
      return _json({
        'careers': [
          {
            'career_id': 'car_test', 'player_name': 'Efe Kaan',
            'season_id': '25/26', 'current_date': '2026-08-19',
          }
        ],
      });
    }
    if (request.url.path == '/careers/car_test/relationships/test_rel/interact') {
      return _json({
        'career_state': {
          'current_date': '2026-08-19', 'season_id': '25/26',
          'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
        },
        'relationship_changes': const [],
        'attribute_changes': const [],
        'ledger_entries': const [],
      });
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

/// DialogScreen'i gerçek kullanım gibi bir Navigator üzerinden push eder;
/// böylece "İlerle" butonundaki pop gerçekten ekranı kapatır.
Widget _pushHarness(CareerSession session) {
  return PlayerScope(
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DialogScreen(
                      contactName: 'Test Kişi',
                      tree: _testTree,
                      tint: Colors.blue,
                      relationshipId: 'test_rel',
                      dialogueId: 'test_dialogue_01',
                      session: session,
                    ),
                  ),
                ),
                child: const Text('Aç'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
    'replik typewriter ile yazılır, seçenek gelir, cevap sonrası ilerle çıkar',
    (tester) async {
      await tester.pumpWidget(_pushHarness(_dialogSession()));
      await tester.tap(find.text('Aç'));
      await tester.pump();

      // Typewriter henüz bitmedi: tam metin ekranda yok.
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('Merhaba, nasılsın?'), findsNothing);

      // 18 karakter × 18ms yazım + tek seçeneğin 80ms'lik stagger'ı için
      // bolca pay bırakan tek seferlik ileri sarma (pumpAndSettle yerine;
      // ham Timer'lar pumpAndSettle'ın "settle" sezgisini yanıltabiliyor).
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Test Kişi'), findsOneWidget);
      expect(find.text('Merhaba, nasılsın?'), findsOneWidget);
      expect(find.text('İyiyim, sen nasılsın?'), findsOneWidget);
      expect(find.text('İlerle'), findsNothing);

      await tester.tap(find.text('İyiyim, sen nasılsın?'));
      await tester.pump();

      // Yeni replik ("Ben de iyiyim, teşekkürler.", 27 karakter) yazılana
      // kadar bekle; bu düğümün seçeneği olmadığı için İlerle butonu
      // typewriter biter bitmez (ek bir stagger beklemeden) görünür. Aynı
      // anda terminal düğüme ulaşıldığı için R3 çağrısı da tetiklenir.
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Ben de iyiyim, teşekkürler.'), findsOneWidget);
      expect(find.text('İyiyim, sen nasılsın?'), findsNothing);
      expect(find.text('İlerle'), findsOneWidget);

      await tester.tap(find.text('İlerle'));
      await tester.pumpAndSettle();
      expect(find.byType(DialogScreen), findsNothing);
    },
  );

  testWidgets('mesaj kutusuna dokununca typewriter anında tamamlanır', (
    tester,
  ) async {
    await tester.pumpWidget(_pushHarness(_dialogSession()));
    await tester.tap(find.text('Aç'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 30));
    expect(find.text('Merhaba, nasılsın?'), findsNothing);

    await tester.tap(find.byKey(const Key('dialogue_message_box')));
    await tester.pump();

    expect(find.text('Merhaba, nasılsın?'), findsOneWidget);

    // Skip sonrası tetiklenen seçenek stagger'ının Future'ı tamamen aksın;
    // aksi halde test bitiminde "pending timer" hatası alınır.
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('R3 çağrısı terminal düğümde tam olarak bir kez yapılır', (
    tester,
  ) async {
    var calls = 0;
    final mock = MockClient((request) async {
      if (request.url.path == '/careers') {
        return _json({
          'careers': [
            {
              'career_id': 'car_test', 'player_name': 'Efe Kaan',
              'season_id': '25/26', 'current_date': '2026-08-19',
            }
          ],
        });
      }
      if (request.url.path.endsWith('/interact')) {
        calls++;
        return _json({
          'career_state': {
            'current_date': '2026-08-19', 'season_id': '25/26',
            'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
          },
          'relationship_changes': const [],
          'attribute_changes': const [],
          'ledger_entries': const [],
        });
      }
      return http.Response('unexpected ${request.url}', 404);
    });
    final session =
        CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));

    await tester.pumpWidget(_pushHarness(session));
    await tester.tap(find.text('Aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('İyiyim, sen nasılsın?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(calls, 1);

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    // İlerle bir kez daha R3'ü tetiklemez.
    expect(calls, 1);
  });
}
