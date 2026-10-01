import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/boot/boot_gate.dart';
import 'package:project_srpg/boot/python_host.dart';
import 'package:project_srpg/net/api_config.dart';

final _urls = [
  Uri.parse('http://127.0.0.1:8000/health'),
  Uri.parse('http://127.0.0.1:8001/health'),
];

/// Gömülü olmayan hedefte ev sahibi hiçbir şey başlatmaz: web/masaüstü akışı
/// (run_all.bat) bu sınıftan habersiz çalışmaya devam eder.
PythonHost _external() => PythonHost(
  embedded: false,
  starter: () => fail('Python başlatılmamalıydı'),
  probe: (_) => fail('yoklama yapılmamalıydı'),
);

PythonHost _embedded({
  required Future<String?> Function() starter,
  required Future<bool> Function(Uri) probe,
  Duration timeout = const Duration(seconds: 5),
}) => PythonHost(
  embedded: true,
  starter: starter,
  probe: probe,
  healthUrls: _urls,
  timeout: timeout,
  pollInterval: const Duration(milliseconds: 10),
);

void main() {
  group('ApiConfig', () {
    test('iOS dışı hedeflerde gömülü back-end yok, iki sağlık adresi var', () {
      expect(ApiConfig.usesEmbeddedBackend, isFalse);
      expect(ApiConfig.healthUrls.map((u) => u.path), everyElement('/health'));
      expect(ApiConfig.healthUrls.map((u) => u.port), [8000, 8001]);
    });
  });

  group('PythonHost', () {
    test('gömülü olmayan hedefte baştan hazır, Python başlatmaz', () async {
      final host = _external();
      expect(host.isReady, isTrue);
      await host.start();
      expect(host.phase, BootPhase.ready);
    });

    test('iki sunucu da yanıt verene dek bekler, sonra hazır olur', () async {
      var polls = 0;
      final host = _embedded(
        starter: () => Completer<String?>().future, // blokluyor, çıkmıyor
        // match ilk yoklamada hazır; career üçüncüde.
        probe: (u) async => u.port == 8000 || ++polls >= 3,
      );
      final phases = <BootPhase>[];
      host.addListener(() => phases.add(host.phase));

      expect(host.phase, BootPhase.starting);
      await host.start();

      expect(host.isReady, isTrue);
      expect(phases, [BootPhase.ready]);
      expect(polls, 3);
    });

    test(
      'bağlantı hatası "henüz hazır değil" sayılır, çökme sayılmaz',
      () async {
        var attempts = 0;
        final host = _embedded(
          starter: () => Completer<String?>().future,
          probe: (_) async {
            if (++attempts <= 4) {
              throw const FormatException('connection refused');
            }
            return true;
          },
        );
        await host.start();
        expect(host.isReady, isTrue);
      },
    );

    test('süre dolarsa başarısız olur ve yeniden denenebilir', () async {
      var healthy = false;
      final host = _embedded(
        starter: () => Completer<String?>().future,
        probe: (_) async => healthy,
        timeout: const Duration(milliseconds: 80),
      );
      await host.start();
      expect(host.phase, BootPhase.failed);
      expect(host.error, contains('hazır olmadı'));
      expect(host.canRetry, isTrue);

      healthy = true;
      await host.retry();
      expect(host.isReady, isTrue);
      expect(host.error, isNull);
    });

    test('Python başlatılamazsa hemen başarısız, yeniden denenemez', () async {
      final host = _embedded(
        starter: () async => 'Python exited with code 1',
        probe: (_) async => false,
        timeout: const Duration(seconds: 30),
      );
      await host.start();
      expect(host.phase, BootPhase.failed);
      expect(host.error, contains('Python exited with code 1'));
      expect(host.startFailed, isTrue);
      expect(host.canRetry, isFalse);
    });

    test('starter istisna fırlatırsa başarısız olur', () async {
      final host = _embedded(
        starter: () => Future<String?>.error(StateError('no runtime')),
        probe: (_) async => false,
        timeout: const Duration(seconds: 30),
      );
      await host.start();
      expect(host.phase, BootPhase.failed);
      expect(host.error, contains('no runtime'));
    });

    test(
      'starter hemen null ile dönse de (başlatıldı) hata sayılmaz',
      () async {
        // serious_python sync olmayan modda thread kalkınca tamamlanır; bu
        // "Python bitti" demek değildir (cihazda yaşanan ilk hata buydu).
        var healthy = false;
        final host = _embedded(
          starter: () async => null,
          probe: (_) async => healthy,
        );
        final boot = host.start();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(host.phase, BootPhase.starting);
        healthy = true;
        await boot;
        expect(host.isReady, isTrue);
      },
    );

    test('start tekrar çağrılınca Python ikinci kez başlatılmaz', () async {
      var starts = 0;
      final host = _embedded(
        starter: () {
          starts++;
          return Completer<String?>().future;
        },
        probe: (_) async => true,
      );
      await Future.wait([host.start(), host.start()]);
      await host.start();
      expect(starts, 1);
    });
  });

  group('BootGate', () {
    testWidgets('gömülü olmayan hedefte splash göstermeden child açılır', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BootGate(host: _external(), child: const Text('oyun')),
        ),
      );
      expect(find.text('oyun'), findsOneWidget);
      expect(find.text('Oyun hazırlanıyor…'), findsNothing);
    });

    testWidgets('hazır olana dek splash, sonra child', (tester) async {
      final ready = Completer<bool>();
      final host = _embedded(
        starter: () => Completer<String?>().future,
        probe: (_) => ready.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BootGate(host: host, child: const Text('oyun')),
        ),
      );
      expect(find.text('Oyun hazırlanıyor…'), findsOneWidget);
      expect(find.text('oyun'), findsNothing);

      ready.complete(true);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('oyun'), findsOneWidget);
      expect(find.text('Oyun hazırlanıyor…'), findsNothing);
    });

    // Not: testWidgets sahte zamanda koşar, ama PythonHost süre aşımını gerçek
    // saatle ölçer. Bu yüzden başarısız açılışlar widget kurulmadan önce
    // gerçek bölgede (runAsync) yaşatılır; ekran yalnızca sonucu çizer.
    testWidgets('başarısızlıkta neden ve "Tekrar dene" gösterir', (
      tester,
    ) async {
      var healthy = false;
      final host = _embedded(
        starter: () => Completer<String?>().future,
        probe: (_) async => healthy,
        timeout: const Duration(milliseconds: 50),
      );
      await tester.runAsync(host.start);
      await tester.pumpWidget(
        MaterialApp(
          home: BootGate(host: host, child: const Text('oyun')),
        ),
      );

      expect(find.text('Oyun motoru başlatılamadı'), findsOneWidget);
      expect(find.textContaining('hazır olmadı'), findsOneWidget);

      healthy = true; // sunucu bu arada kalktı: ilk yoklama hemen geçer
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      await tester.pump();
      expect(find.text('oyun'), findsOneWidget);
    });

    testWidgets('Python başlatılamadıysa "Tekrar dene" yok, kapat-aç denir', (
      tester,
    ) async {
      final host = _embedded(
        starter: () async => 'Python exited with code 7',
        probe: (_) async => false,
      );
      await tester.runAsync(host.start);
      await tester.pumpWidget(
        MaterialApp(
          home: BootGate(host: host, child: const Text('oyun')),
        ),
      );

      expect(find.text('Tekrar dene'), findsNothing);
      expect(find.text('Uygulamayı kapatıp yeniden açın.'), findsOneWidget);
      expect(find.textContaining('code 7'), findsOneWidget);
    });
  });
}
