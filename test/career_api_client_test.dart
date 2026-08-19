import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';

/// career_engine CONTRACT.md §5'teki her uç için bir sağlık testi: gerçek
/// örnek gövdeler doğru ayrıştırılıyor mu, doğru HTTP metodu/yol/gövde
/// gönderiliyor mu. League table zaten W1/W2'yi ayrıca test ediyor
/// (league_table_screen_test.dart); burada P/W3-4/R/T/M/N kalıyor.

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

CareerApiClient _clientWith(
  http.Response Function(http.Request request) handler,
) {
  final mock = MockClient((request) async => handler(request));
  return CareerApiClient(httpClient: mock, baseUrl: 'http://test');
}

void main() {
  group('player (P1-P3)', () {
    test('player() parses attributes/fame/market_value', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/player');
        return _json({
          'player_id': 'p_user',
          'name': 'Efe Kaan',
          'position': 'Orta saha',
          'birth_date': '2004-08-19',
          'age': 21,
          'team': {
            'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
            'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
          },
          'career_state': {
            'current_date': '2026-03-14', 'season_id': '25/26',
            'money': 48200, 'condition': 72,
            'day_budget': {'time': 330, 'energy': 62},
          },
          'attributes': [
            {'key': 'condition', 'family': 'saha', 'value': 64.0},
            {'key': 'shooting', 'family': 'saha', 'value': 50.0},
          ],
          'fame': [
            {'scope': 'overall', 'value': 0.0}
          ],
          'market_value': {'current': 4200000, 'measured_on': '2026-01-01'},
        });
      });

      final profile = await client.player('car_1');

      expect(profile.name, 'Efe Kaan');
      expect(profile.careerState.money, 48200);
      expect(profile.careerState.moneyLabel, '₺48.200');
      expect(profile.attribute('shooting'), 50.0);
      expect(profile.marketValue?.current, 4200000);
    });

    test('player() with null market_value does not throw', () async {
      final client = _clientWith((request) => _json({
            'player_id': 'p_user', 'name': 'Efe Kaan', 'position': 'Orta saha',
            'birth_date': '2004-08-19', 'age': 21,
            'team': {
              'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
              'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
            },
            'career_state': {
              'current_date': '2026-03-14', 'season_id': '25/26',
              'money': 0, 'condition': 72, 'day_budget': {'time': 720.0},
            },
            'attributes': const [],
            'fame': const [],
            'market_value': null,
          }));

      final profile = await client.player('car_1');
      expect(profile.marketValue, isNull);
    });

    test('playerStats() sends season/competition query params', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/player/stats');
        expect(request.url.queryParameters['season'], '25/26');
        expect(request.url.queryParameters['competition'], 'all');
        return _json({
          'rows': [
            {
              'season_id': '25/26', 'competition_id': 'c_lig2',
              'competition_kind': 'lig', 'competition_name': '1. Lig',
              'appearances': 12, 'starts': 12, 'goals': 3, 'assists': 0,
              'minutes': 1140, 'passes_completed': 0, 'passes_attempted': 0,
            }
          ],
          'value_history': [
            {'measured_on': '2024-01-15', 'value': 450000}
          ],
        });
      });

      final stats = await client.playerStats('car_1', season: '25/26', competition: 'all');

      expect(stats.rows.single.goals, 3);
      expect(stats.valueHistory.single.value, 450000);
    });

    test('playerContract() returns null body as null, not a throw', () async {
      final client = _clientWith((request) => http.Response('null', 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));

      expect(await client.playerContract('car_1'), isNull);
    });

    test('playerContract() parses a real contract and derives monthly wage', () async {
      final client = _clientWith((request) => _json({
            'team': {
              'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
              'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
            },
            'signed_at': '2025-07-01', 'expires_at': '2027-06-30',
            'weekly_wage': 12000, 'appearance_bonus': 1500,
            'goal_bonus': 2500, 'release_clause': 750000,
            'days_until_expiry': 472,
          }));

      final contract = await client.playerContract('car_1');

      expect(contract!.weeklyWage, 12000);
      expect(contract.monthlyWage, 48000);
    });
  });

  group('world (W3-W4)', () {
    test('fixtures() sends filters and parses rounds', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/fixtures');
        expect(request.url.queryParameters['team_id'], 't_ykz');
        return _json({
          'fixtures': [
            {
              'fixture_id': 'f_1', 'competition': {
                'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig',
              },
              'round_no': 13, 'leg': null, 'kickoff_at': '2026-03-16T20:00:00+03:00',
              'home': {
                'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
                'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
              },
              'away': {
                'team_id': 't_dnz', 'name': 'Deniz SK', 'short_name': 'DNZ',
                'color_primary': '#0B2E5B', 'color_secondary': '#E8EAED',
              },
              'status': 'scheduled', 'score': null, 'is_user_match': true,
            }
          ],
          'rounds': [
            {'round_no': 5, 'stage': 'r32', 'scheduled_on': '2026-11-03', 'drawn': false}
          ],
          'next_before': null,
        });
      });

      final page = await client.fixtures('car_1', teamId: 't_ykz');

      expect(page.fixtures.single.isPlayed, isFalse);
      expect(page.rounds.single.drawn, isFalse);
    });

    test('team() parses ratings and standing', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/teams/t_ykz');
        return _json({
          'team': {
            'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
            'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
          },
          'country': 'TR', 'mentality': 'balanced',
          'ratings': {'attack': 68.4, 'midfield': 71.0, 'defense': 64.2, 'goalkeeper': 66.0},
          'competition': {'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig'},
          'standing': {'rank': 3, 'played': 12, 'points': 24},
        });
      });

      final detail = await client.team('car_1', 't_ykz');

      expect(detail.attack, 68.4);
      expect(detail.standing?.rank, 3);
    });
  });

  group('relationships (R1-R3)', () {
    test('relationships() parses five cards with traits', () async {
      final client = _clientWith((request) => _json({
            'relationships': [
              {
                'relationship_id': 'coach', 'kind': 'coach', 'category': 'Antrenör',
                'score': 74, 'person_name': 'Mert Aydın', 'contact_name': 'Mert Hoca',
                'last_contact_at': '2026-03-12', 'has_pending_request': false,
                'traits': {'trust': 74, 'promised_minutes': 60, 'tactical_fit': 0.8},
              }
            ],
          }));

      final cards = await client.relationships('car_1');

      expect(cards.single.traits['trust'], 74);
    });

    test('relationship() parses profile with recent events', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/relationships/coach');
        return _json({
          'relationship_id': 'coach', 'kind': 'coach', 'category': 'Antrenör',
          'score': 74, 'person_name': 'Mert Aydın', 'contact_name': 'Mert Hoca',
          'last_contact_at': '2026-03-12', 'has_pending_request': false, 'traits': {},
          'age': 44, 'occupation': 'Baş antrenör', 'bio': '…',
          'hobbies': ['satranç', 'koşu'],
          'recent_events': [
            {'happened_at': '2026-03-12T18:00:00+03:00', 'delta': 3, 'reason': 'dialogue:coach_01:choice_2'}
          ],
        });
      });

      final profile = await client.relationship('car_1', 'coach');

      expect(profile.hobbies, ['satranç', 'koşu']);
      expect(profile.recentEvents.single.delta, 3);
    });

    test('interact() posts dialogue_id/choice_path and parses deltas', () async {
      final client = _clientWith((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/careers/car_1/relationships/coach/interact');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['dialogue_id'], 'coach_01');
        expect(body['choice_path'], ['n1', 'c2']);
        return _json({
          'career_state': {
            'current_date': '2026-03-14', 'season_id': '25/26',
            'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
          },
          'relationship_changes': [
            {'relationship_id': 'coach', 'before': 71, 'after': 74, 'delta': 3}
          ],
          'attribute_changes': [
            {'key': 'politeness', 'before': 58.0, 'after': 58.6}
          ],
          'ledger_entries': const [],
        });
      });

      final result = await client.interact(
        'car_1', 'coach',
        dialogueId: 'coach_01',
        choicePath: ['n1', 'c2'],
      );

      expect(result.relationshipChanges.single.after, 74);
      expect(result.attributeChanges.single.after, 58.6);
    });
  });

  group('time (T1-T4)', () {
    test('day() parses events with extra fields', () async {
      final client = _clientWith((request) => _json({
            'career_state': {
              'current_date': '2026-03-14', 'season_id': '25/26',
              'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
            },
            'is_match_day': false,
            'events': [
              {'kind': 'cup_draw', 'ref_id': 'c_kupa', 'round_no': 5},
              {'kind': 'upkeep_warning', 'ref_id': null, 'shortfall': 800},
            ],
          }));

      final day = await client.day('car_1');

      expect(day.events[0].extra['round_no'], 5);
      expect(day.events[1].refId, isNull);
      expect(day.events[1].extra['shortfall'], 800);
    });

    test('postAction() posts catalog_id and optional result', () async {
      final client = _clientWith((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/careers/car_1/actions');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['catalog_id'], 'sut');
        expect(body['result'], {'minigame_score': 0.72});
        return _json({
          'career_state': {
            'current_date': '2026-03-14', 'season_id': '25/26',
            'money': 48200, 'condition': 72, 'day_budget': {'time': 660.0},
          },
          'applied_costs': {'time': 60, 'energy': 18},
          'applied_effects': {'attribute:shooting': 1.4},
          'attribute_changes': [
            {'key': 'shooting', 'before': 50.0, 'after': 51.4}
          ],
          'relationship_changes': const [],
          'ledger_entries': const [],
        });
      });

      final result = await client.postAction(
        'car_1',
        catalogId: 'sut',
        result: {'minigame_score': 0.72},
      );

      expect(result.attributeChanges.single.after, 51.4);
      expect(result.appliedCosts['time'], 60.0);
    });

    test('advance() posts `to` and parses the summary', () async {
      final client = _clientWith((request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['to'], 'next_event');
        return _json({
          'career_state': {
            'current_date': '2026-03-16', 'season_id': '25/26',
            'money': 44200, 'condition': 80, 'day_budget': {'time': 720.0},
          },
          'days_advanced': 3, 'stopped_on': '2026-03-16', 'stop_reason': 'match_day',
          'simulated': {'fixtures': 51, 'competitions': 3},
          'ledger_entries': const [],
          'news_created': ['n_0143', 'n_0144'],
          'repossessed': const [],
        });
      });

      final result = await client.advance('car_1', to: 'next_event');

      expect(result.daysAdvanced, 3);
      expect(result.stopReason, 'match_day');
      expect(result.newsCreated, ['n_0143', 'n_0144']);
    });

    test('purchase() posts catalog_id and parses the item', () async {
      final client = _clientWith((request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['catalog_id'], 'daire-merkez');
        return _json({
          'career_state': {
            'current_date': '2026-03-14', 'season_id': '25/26',
            'money': 250000, 'condition': 72, 'day_budget': {'time': 720.0},
          },
          'item': {
            'catalog_id': 'daire-merkez', 'purchased_at': '2026-03-14',
            'price_paid': 250000, 'upkeep_weekly': 1800,
          },
          'ledger_entries': const [],
        });
      });

      final result = await client.purchase('car_1', 'daire-merkez');

      expect(result.item.upkeepWeekly, 1800);
    });
  });

  group('match (M1-M3)', () {
    test('nextMatch() parses engine_payload untouched', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/matches/next');
        return _json({
          'fixture_id': 'f_25_26_c_lig2_r13_ykz_dnz',
          'competition': {'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig'},
          'kickoff_at': '2026-03-16T20:00:00+03:00',
          'user_side': 'home',
          'engine_payload': {
            'teams': {
              'home': {'name': 'FK Yıldız', 'attack': 68.4, 'midfield': 71.0,
                       'defense': 64.2, 'goalkeeper': 66.0, 'mentality': 'balanced'},
              'away': {'name': 'Deniz SK', 'attack': 74.1, 'midfield': 70.3,
                       'defense': 69.8, 'goalkeeper': 72.5, 'mentality': 'attacking'},
            },
            'user_side': 'home', 'user_condition': 72, 'client_seed': 918273,
          },
        });
      });

      final next = await client.nextMatch('car_1');

      expect(next.fixtureId, 'f_25_26_c_lig2_r13_ykz_dnz');
      expect(next.enginePayload['client_seed'], 918273);
    });

    test('nextMatch() surfaces 409 match_in_progress as CareerApiException', () async {
      final client = _clientWith((request) => _json(
            {'code': 'match_in_progress', 'message': "fixture 'f_1' has an unfinished match"},
            status: 409,
          ));

      expect(
        () => client.nextMatch('car_1'),
        throwsA(isA<CareerApiException>()
            .having((e) => e.code, 'code', 'match_in_progress')),
      );
    });

    test('reportMatchResult() posts the body verbatim and parses the result', () async {
      final client = _clientWith((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/careers/car_1/matches/f_1/result');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['match_id'], 'm_20260316_ykz_dnz');
        return _json({
          'career_state': {
            'current_date': '2026-03-16', 'season_id': '25/26',
            'money': 49700, 'condition': 54, 'day_budget': {'time': 720.0},
          },
          'fixture': {'fixture_id': 'f_1', 'status': 'played', 'score': {'home': 2, 'away': 1}},
          'other_results': const [],
          'standing_delta': {'rank_before': 3, 'rank_after': 2},
          'player_stat_delta': {'appearances': 1, 'goals': 1, 'minutes': 95},
          'ledger_entries': const [],
          'news_created': ['n_0143'],
        });
      });

      final result = await client.reportMatchResult('car_1', 'f_1', {
        'match_id': 'm_20260316_ykz_dnz',
        'score': {'home': 2, 'away': 1},
      });

      expect(result.fixture.status, 'played');
      expect(result.standingDelta.rankAfter, 2);
      expect(result.playerStatDelta.goals, 1);
    });

    test('abandonMatch() posts with no body and parses the fixture', () async {
      final client = _clientWith((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/careers/car_1/matches/f_1/abandon');
        return _json({
          'career_state': {
            'current_date': '2026-03-14', 'season_id': '25/26',
            'money': 48200, 'condition': 72, 'day_budget': {'time': 720.0},
          },
          'fixture': {'fixture_id': 'f_1', 'status': 'scheduled'},
        });
      });

      final result = await client.abandonMatch('car_1', 'f_1');

      expect(result.fixture.status, 'scheduled');
    });
  });

  group('content (N1-N3)', () {
    test('news() parses items and next_before cursor', () async {
      final client = _clientWith((request) => _json({
            'items': [
              {
                'news_id': 'n_0142', 'published_at': '2026-03-14T09:00:00+03:00',
                'category': 'Transfer', 'title': '…', 'source': 'Spor Manşet',
                'excerpt': '…', 'fixture_id': null,
              }
            ],
            'next_before': '2026-03-09T09:00:00+03:00',
          }));

      final feed = await client.news('car_1');

      expect(feed.items.single.category, 'Transfer');
      expect(feed.nextBefore, '2026-03-09T09:00:00+03:00');
    });

    test('newsItem() parses the full body', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/news/n_0142');
        return _json({
          'news_id': 'n_0142', 'published_at': '2026-03-14T09:00:00+03:00',
          'category': 'Transfer', 'title': '…', 'source': 'Spor Manşet',
          'excerpt': '…', 'fixture_id': null, 'body': 'Paragraf 1\n\nParagraf 2',
        });
      });

      final detail = await client.newsItem('car_1', 'n_0142');

      expect(detail.body, contains('\n\n'));
    });

    test('catalog() is career-independent and parses kind-specific fields', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/catalog/training');
        return _json({
          'items': [
            {
              'catalog_id': 'kondisyon-kosusu', 'title': 'Kondisyon Koşusu',
              'description': '…', 'family': 'saha', 'drill': 'conditioning',
              'costs': {'time': 90, 'energy': 15},
              'effects': {'attribute:condition': 1.2},
            },
            {
              'catalog_id': 'medya-egitimi', 'title': 'Medya Eğitimi',
              'family': 'kişi', 'drill': null,
              'costs': {'time': 60, 'energy': 5},
              'effects': {'attribute:charisma': 0.8, 'money': -1500},
            },
          ],
        });
      });

      final catalog = await client.catalog('training');

      expect(catalog.items[0].drill, 'conditioning');
      expect(catalog.items[0].costs['time'], 90.0);
      expect(catalog.items[1].drill, isNull);
      expect(catalog.items[1].effects['money'], -1500);
    });

    test('shop catalog exposes price/upkeep/note via raw fallbacks', () async {
      final client = _clientWith((request) => _json({
            'items': [
              {
                'catalog_id': 'daire-merkez', 'title': '…', 'description': '…',
                'category': 'housing', 'price': 250000, 'upkeep_weekly': 1800,
                'note': '3+1, 120 m²',
              }
            ],
          }));

      final catalog = await client.catalog('shop');
      final item = catalog.items.single;

      expect(item.price, 250000);
      expect(item.upkeepWeekly, 1800);
      expect(item.note, '3+1, 120 m²');
      expect(item.group, 'housing');
    });
  });

  group('career lifecycle', () {
    test('deleteCareer() sends DELETE and expects 204', () async {
      final client = _clientWith((request) {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/careers/car_1');
        return http.Response('', 204);
      });

      await client.deleteCareer('car_1');
    });
  });
}
