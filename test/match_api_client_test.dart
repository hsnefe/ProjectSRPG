import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/match_api_client.dart';

void main() {
  group('MatchApiClient.fetchNextMatch', () {
    test('parses a 200 response', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/matches/next');
        return http.Response(
          jsonEncode({
            'match_id': 'm_test',
            'kickoff_at': '2026-08-15T20:00:00+03:00',
            'user_side': 'home',
            'teams': {
              'home': {'name': 'FK Yıldız'},
              'away': {'name': 'Deniz SK'},
            },
            'team_tactic': {'code': 'attacking', 'label': 'Hücumcu'},
            'stamina': {
              'current': 100,
              'floor': 35,
              'ceiling': 100,
              'substitution_bonus': 6,
            },
            'directive_options': {
              'effort': [],
              'aggression': [],
              'focus': [],
            },
            'defaults': {'effort': 50, 'aggression': 50, 'focus': null},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final client = MatchApiClient(httpClient: mock, baseUrl: 'http://test');

      final result = await client.fetchNextMatch();

      expect(result.matchId, 'm_test');
    });

    test('throws MatchApiException with parsed code/message on error', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'internal', 'message': 'boom'}),
          500,
        );
      });
      final client = MatchApiClient(httpClient: mock, baseUrl: 'http://test');

      expect(
        () => client.fetchNextMatch(),
        throwsA(
          isA<MatchApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.code, 'code', 'internal')
              .having((e) => e.message, 'message', 'boom'),
        ),
      );
    });
  });

  group('MatchApiClient.startMatch', () {
    test('posts the request body and parses a 201 response', () async {
      Map<String, dynamic>? sentBody;
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/matches/m_test/start');
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'match_id': 'm_test',
            'stream_url': '/matches/m_test/stream',
          }),
          201,
        );
      });
      final client = MatchApiClient(httpClient: mock, baseUrl: 'http://test');

      final result = await client.startMatch(
        'm_test',
        userSide: 'home',
        effort: 50,
        aggression: 50,
      );

      expect(result.streamUrl, '/matches/m_test/stream');
      expect(sentBody, {
        'user_side': 'home',
        'effort': 50,
        'aggression': 50,
        'focus': null,
        'client_seed': null,
      });
    });
  });

  group('MatchApiClient.postDirective', () {
    test('posts partial updates and parses the tolerant response', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/matches/m_test/directive');
        return http.Response(
          jsonEncode({
            'accepted': true,
            'note': null,
            'effective_from_minute': 35,
            'applied': {'effort': 70, 'aggression': 50, 'focus': null},
          }),
          200,
        );
      });
      final client = MatchApiClient(httpClient: mock, baseUrl: 'http://test');

      final result = await client.postDirective(
        'm_test',
        clientRequestId: 'req_1',
        atMinute: 34,
        effort: 70,
      );

      expect(result.accepted, isTrue);
      expect(result.applied.effort, 70);
    });
  });
}
