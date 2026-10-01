import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/boot/python_host.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/net/match_sse_client.dart';
import 'package:project_srpg/net/timeout_client.dart';

void main() {
  group('TimeoutClient', () {
    test('yanıt başlıkları süre içinde gelirse olduğu gibi geçirir', () async {
      final client = TimeoutClient(
        MockClient((_) async => http.Response('merhaba', 200)),
        timeout: const Duration(seconds: 1),
      );
      final response = await client.get(Uri.parse('http://x/a'));
      expect(response.statusCode, 200);
      expect(response.body, 'merhaba');
    });

    test('hiç yanıt gelmeyen istek TimeoutException ile biter', () async {
      final client = TimeoutClient(
        MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        client.get(Uri.parse('http://x/a')),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('gövde yarıda takılırsa toplam süre aşımı fırlatır', () async {
      final client = TimeoutClient(
        MockClient.streaming((request, _) async {
          final body = StreamController<List<int>>()..add(utf8.encode('yarım'));
          return http.StreamedResponse(body.stream, 200); // kapanmıyor
        }),
        timeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        client.get(Uri.parse('http://x/a')),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('gövde süre içinde tamamlanırsa baştan sona okunur', () async {
      final client = TimeoutClient(
        MockClient.streaming((request, _) async {
          Stream<List<int>> parts() async* {
            for (var i = 0; i < 3; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
              yield utf8.encode('$i');
            }
          }

          return http.StreamedResponse(parts(), 200);
        }),
        timeout: const Duration(seconds: 2),
      );
      final response = await client.get(Uri.parse('http://x/a'));
      expect(response.body, '012');
      expect(response.contentLength, 3);
    });

    test('durum kodu ve başlıklar korunur', () async {
      final client = TimeoutClient(
        MockClient(
          (_) async => http.Response('', 404, headers: {'x-test': '1'}),
        ),
        timeout: const Duration(seconds: 1),
      );
      final response = await client.get(Uri.parse('http://x/a'));
      expect(response.statusCode, 404);
      expect(response.headers['x-test'], '1');
    });
  });

  group('MatchApiClient', () {
    test(
      'pause/resume doğru yola reason gövdesiyle gider, 204 beklenir',
      () async {
        final seen = <String>[];
        final client = MatchApiClient(
          httpClient: MockClient((request) async {
            seen.add('${request.method} ${request.url.path} ${request.body}');
            return http.Response('', 204);
          }),
          baseUrl: 'http://test',
        );
        await client.postPause('m_1', reason: 'app_backgrounded');
        await client.postResume('m_1', reason: 'user_left');

        expect(seen, [
          'POST /matches/m_1/pause {"reason":"app_backgrounded"}',
          'POST /matches/m_1/resume {"reason":"user_left"}',
        ]);
      },
    );

    test('pause bilinmeyen maçta MatchApiException(404) fırlatır', () async {
      final client = MatchApiClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'code': 'match_not_found', 'message': 'yok'}),
            404,
          ),
        ),
        baseUrl: 'http://test',
      );
      await expectLater(
        client.postPause('m_x', reason: 'user_left'),
        throwsA(
          isA<MatchApiException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });
  });

  group('HttpMatchSseClient', () {
    Future<http.BaseRequest> capture({String? lastEventId}) async {
      http.BaseRequest? seen;
      final client = HttpMatchSseClient(
        httpClient: MockClient.streaming((request, _) async {
          seen = request;
          return http.StreamedResponse(const Stream.empty(), 200);
        }),
      );
      await client
          .connect(Uri.parse('http://x/s'), lastEventId: lastEventId)
          .toList();
      return seen!;
    }

    test('lastEventId verilirse Last-Event-ID başlığı gider', () async {
      final request = await capture(lastEventId: '42');
      expect(request.headers['Last-Event-ID'], '42');
      expect(request.headers['Accept'], 'text/event-stream');
    });

    test('ilk bağlantıda Last-Event-ID başlığı yoktur', () async {
      final request = await capture();
      expect(request.headers.containsKey('Last-Event-ID'), isFalse);
    });
  });

  group('PythonHost sağlık yoklaması', () {
    Future<BootPhase> bootWith(http.Response Function() response) {
      return http.runWithClient(() async {
        final host = PythonHost(
          embedded: true,
          starter: () async => null,
          healthUrls: [Uri.parse('http://127.0.0.1:8000/health')],
          timeout: const Duration(milliseconds: 60),
          pollInterval: const Duration(milliseconds: 10),
        );
        await host.start();
        return host.phase;
      }, () => MockClient((_) async => response()));
    }

    test('ok:true ve service taşıyan 200 sağlıklıdır', () async {
      final phase = await bootWith(
        () => http.Response('{"ok":true,"service":"match_engine"}', 200),
      );
      expect(phase, BootPhase.ready);
    });

    test('başka bir sunucunun düz 200 yanıtı sağlıklı sayılmaz', () async {
      final phase = await bootWith(() => http.Response('<html>hi</html>', 200));
      expect(phase, BootPhase.failed);
    });

    test('service alanı olmayan JSON sağlıklı sayılmaz', () async {
      final phase = await bootWith(() => http.Response('{"ok":true}', 200));
      expect(phase, BootPhase.failed);
    });

    test('200 olmayan yanıt sağlıklı sayılmaz', () async {
      final phase = await bootWith(
        () => http.Response('{"ok":true,"service":"x"}', 503),
      );
      expect(phase, BootPhase.failed);
    });
  });
}
