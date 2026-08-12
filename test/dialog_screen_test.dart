import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/screens/dialog_screen.dart';

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

/// DialogScreen'i gerçek kullanım gibi bir Navigator üzerinden push eder;
/// böylece "İlerle" butonundaki pop gerçekten ekranı kapatır.
Widget _pushHarness() {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DialogScreen(
                    contactName: 'Test Kişi',
                    tree: _testTree,
                    tint: Colors.blue,
                  ),
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  testWidgets(
    'replik typewriter ile yazılır, seçenek gelir, cevap sonrası ilerle çıkar',
    (tester) async {
      await tester.pumpWidget(_pushHarness());
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
      // typewriter biter bitmez (ek bir stagger beklemeden) görünür.
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
    await tester.pumpWidget(_pushHarness());
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
}
