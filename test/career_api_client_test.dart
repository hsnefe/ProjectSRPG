import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';

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
  _timePassEndpointTests();

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
            {'key': 'condition', 'family': 'saha', 'value': 64.0, 'level': 6},
            {'key': 'shooting', 'family': 'saha', 'value': 50.0, 'level': 5},
          ],
          'tactics': [
            {'key': 'gegenpress', 'value': 12.0},
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
      expect(profile.careerState.moneyLabel, '48.200 ₭');
      expect(profile.attribute('shooting'), 50.0);
      // D43 · seviye BE'de türetilir; FE onu okur, hesaplamaz.
      expect(
        profile.attributes.firstWhere((a) => a.key == 'shooting').level,
        5,
      );
      expect(
        profile.attributes.firstWhere((a) => a.key == 'condition').level,
        6,
      );
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
            'tactics': const [],
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
            {
              'key': 'empathy', 'before': 58.0, 'after': 58.6,
              'level_before': 5, 'level_after': 5,
            }
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
      // §5.5 · seviye deltayla birlikte gelir: 58.0 -> 58.6 bir on'luğu
      // geçmediği için ikisi de 5, ve FE bunu kendisi hesaplamaz.
      expect(result.attributeChanges.single.levelBefore, 5);
      expect(result.attributeChanges.single.levelAfter, 5);
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
            {
              'key': 'shooting', 'before': 50.0, 'after': 51.4,
              'level_before': 5, 'level_after': 5,
            }
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
          'player_stat_delta': {
            'appearances': 1, 'goals': 1, 'assists': 1, 'minutes': 95,
          },
          'relationship_changes': [
            {'relationship_id': 'coach', 'before': 70, 'after': 74, 'delta': 4},
            {'relationship_id': 'fans', 'before': 40, 'after': 42, 'delta': 2},
          ],
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
      expect(result.playerStatDelta.assists, 1);
      expect(result.relationshipChanges, hasLength(2));
      expect(result.relationshipChanges.first.relationshipId, 'coach');
      expect(result.relationshipChanges.first.delta, 4);
    });

    test(
      'reportMatchResult() defaults assists/relationship_changes when an '
      'older backend omits them',
      () async {
        final client = _clientWith((request) {
          return _json({
            'career_state': {
              'current_date': '2026-03-16', 'season_id': '25/26',
              'money': 49700, 'condition': 54, 'day_budget': {'time': 720.0},
            },
            'fixture': {'fixture_id': 'f_1', 'status': 'played', 'score': {'home': 2, 'away': 1}},
            'other_results': const [],
            'standing_delta': {'rank_before': 3, 'rank_after': 2},
            // Ne `assists` ne de `relationship_changes` var - v1.4 öncesi
            // career_engine bu alanları hiç göndermiyordu.
            'player_stat_delta': {'appearances': 1, 'goals': 1, 'minutes': 95},
            'ledger_entries': const [],
            'news_created': ['n_0143'],
          });
        });

        final result = await client.reportMatchResult('car_1', 'f_1', {
          'match_id': 'm_20260316_ykz_dnz',
          'score': {'home': 2, 'away': 1},
        });

        expect(result.playerStatDelta.assists, 0);
        expect(result.relationshipChanges, isEmpty);
      },
    );

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
              'requires': {'courage': 6},
            },
          ],
        });
      });

      final catalog = await client.catalog('training');

      expect(catalog.items[0].drill, 'conditioning');
      expect(catalog.items[0].costs['time'], 90.0);
      expect(catalog.items[1].drill, isNull);
      expect(catalog.items[1].effects['money'], -1500);
      // D42 · eşiği olmayan kalem boş sözlük döner, null değil — çağıran
      // her yerde `requires.isEmpty` diye bakabilsin.
      expect(catalog.items[0].requires, isEmpty);
      expect(catalog.items[1].requires, {'courage': 6});
    });

    test('dialogueCatalog() parses thresholds and carries no rewards',
        () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/catalog/dialogue');
        return _json({
          'items': [
            {
              'dialogue_id': 'media_01', 'relationship_id': 'media',
              'leaves': [
                {'leaf_id': 'r0', 'requires': {'charisma': 8}},
                {'leaf_id': 'r1', 'requires': <String, dynamic>{}},
                {'leaf_id': 'r2', 'requires': <String, dynamic>{}},
              ],
            },
            {
              'dialogue_id': 'coach_01', 'relationship_id': 'coach',
              'leaves': [
                {'leaf_id': 'r0', 'requires': {'empathy': 6}},
              ],
            },
          ],
        });
      });

      final catalog = await client.dialogueCatalog();
      final media = catalog.byId('media_01')!;

      expect(media.relationshipId, 'media');
      expect(media.requiresByLeaf, {
        'r0': {'charisma': 8},
        'r1': <String, int>{},
        'r2': <String, int>{},
      });
      expect(catalog.byId('family_01'), isNull);
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
    test('careerOptions() parses nationalities/positions/target_teams',
        () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/options');
        return _json(_optionsBody);
      });

      final options = await client.careerOptions();

      expect(options.nationalities.single.countryCode, 'TR');
      expect(options.nationalities.single.nationality, 'Türk');
      expect(options.positions.map((p) => p.position),
          ['Defans', 'Orta saha']);
      expect(options.positions[1].roles.first.roleId, 'defansif_orta_saha');
      expect(options.positions[1].roles.first.attributes,
          ['tackling', 'passing']);
      expect(options.targetTeams.first.team.teamId, 't_gal');
      expect(options.targetTeams.first.competition?.tier, 1);
      expect(options.targetTeams.first.strengthHint, 'güçlü');
      // Hiçbir lige yazılmamış kulüpte `competition` null gelir.
      expect(options.targetTeams.last.competition, isNull);
    });

    test('careerOptions() sınav ve başlangıç değeri bloklarını da okur',
        () async {
      final client = _clientWith((request) => _json(_optionsBody));

      final options = await client.careerOptions();

      expect(options.skillExams.map((e) => e.examId),
          ['shooting', 'passing', 'tackling']);
      final exam = options.skillExams.first;
      expect(exam.title, 'Şut Sınavı');
      expect(exam.attributeKey, 'shooting');
      expect(exam.minLevel, 1);
      expect(exam.maxLevel, 5);
      expect(exam.maxValue, 100.0);
      expect(exam.awardFor(5), 5.0);

      final starting = options.startingValues;
      expect(starting.money, 100);
      expect(starting.condition, 100);
      expect(starting.relationships['coach'], 70);
      expect(starting.baseSkillValue, 20.0);
      expect(starting.roleBonusPerSlot, 2.0);
      // Regista iki yuvasını da pasa harcar: taban 20 + 2 x 2.
      expect(starting.skillFor('passing', ['passing', 'passing']), 24.0);
      expect(starting.skillFor('shooting', ['passing', 'passing']), 20.0);
    });

    test('createCareer() sends the C1 identity body and reads the hub',
        () async {
      final client = _clientWith((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/careers');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'first_name': 'Efe',
          'last_name': 'Kaan',
          'nationality': 'TR',
          'position': 'Orta saha',
          'role': 'regista',
          'target_team_id': 't_ykz',
        });
        return _json(_createdHubBody('car_1'), status: 201);
      });

      final hub = await client.createCareer(
        firstName: 'Efe',
        lastName: 'Kaan',
        nationality: 'TR',
        position: 'Orta saha',
        role: 'regista',
        targetTeamId: 't_ykz',
      );

      // C1'in yanıtı C3 hub gövdesiyle birebir: sihirbaz atanan kulübü de
      // hedef kulübü de ikinci bir çağrı yapmadan buradan okur.
      expect(hub.careerId, 'car_1');
      expect(hub.firstName, 'Efe');
      expect(hub.lastName, 'Kaan');
      expect(hub.nationality, 'TR');
      expect(hub.role, 'regista');
      expect(hub.roleName, 'Regista');
      expect(hub.playerTeam.name, 'Palamut SK');
      expect(hub.targetTeam?.name, 'FK Yıldız');
    });

    test('submitSkillExams() üç notu tek gövdede yollar ve sonucu çözer',
        () async {
      final client = _clientWith((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/careers/car_1/skill-exams');
        expect(jsonDecode(request.body), {
          'results': [
            {'exam_id': 'shooting', 'level': 5},
            {'exam_id': 'passing', 'level': 3},
            {'exam_id': 'tackling', 'level': 1},
          ],
        });
        return _json({
          'career_id': 'car_1',
          'results': [
            {
              'exam_id': 'shooting', 'level': 5, 'attribute_key': 'shooting',
              'before': 20.0, 'after': 25.0, 'applied': 5.0,
            },
            {
              'exam_id': 'passing', 'level': 3, 'attribute_key': 'passing',
              'before': 24.0, 'after': 27.0, 'applied': 3.0,
            },
            {
              'exam_id': 'tackling', 'level': 1, 'attribute_key': 'tackling',
              'before': 20.0, 'after': 21.0, 'applied': 1.0,
            },
          ],
        });
      });

      final outcomes = await client.submitSkillExams(
        'car_1',
        {'shooting': 5, 'passing': 3, 'tackling': 1},
      );

      expect(outcomes, hasLength(3));
      expect(outcomes.first.attributeKey, 'shooting');
      expect(outcomes.first.before, 20.0);
      expect(outcomes.first.after, 25.0);
      expect(outcomes[1].applied, 3.0);
    });

    test('submitSkillExams() aynı sınav tekrar girilirse 409 fırlatır',
        () async {
      final client = _clientWith(
        (request) => _json(
          {
            'code': 'skill_exam_already_taken',
            'message': 'shooting sınavı zaten girildi',
          },
          status: 409,
        ),
      );

      expect(
        () => client.submitSkillExams('car_1', {'shooting': 5}),
        throwsA(
          isA<CareerApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', 'skill_exam_already_taken'),
        ),
      );
    });

    test('deleteCareer() sends DELETE and expects 204', () async {
      final client = _clientWith((request) {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/careers/car_1');
        return http.Response('', 204);
      });

      await client.deleteCareer('car_1');
    });

    test('listCareers() parses player_age when present', () async {
      final client = _clientWith((request) {
        expect(request.method, 'GET');
        expect(request.url.path, '/careers');
        return _json({
          'careers': [
            {
              'career_id': 'car_1',
              'player_name': 'Efe Kaan',
              'player_age': 21,
              'team': null,
              'competition': null,
              'season_id': '25/26',
              'current_date': '2026-03-14',
            },
          ],
        });
      });

      final careers = await client.listCareers();

      expect(careers.single.playerAge, 21);
    });

    test('listCareers() alan yokken playerAge null kalır', () async {
      final client = _clientWith((request) => _json({
            'careers': [
              {
                'career_id': 'car_1',
                'player_name': 'Efe Kaan',
                'team': null,
                'competition': null,
                'season_id': '25/26',
                'current_date': '2026-03-14',
              },
            ],
          }));

      final careers = await client.listCareers();

      expect(careers.single.playerAge, isNull);
    });
  });

  group('career bootstrap (CareerSession)', () {
    test('kayıtlı kariyer varsa en yenisini kullanır, C1 çağrılmaz', () async {
      var created = false;
      final session = CareerSession(
        client: _clientWith((request) {
          if (request.method == 'POST') created = true;
          expect(request.url.path, '/careers');
          return _json({
            'careers': [
              {
                'career_id': 'car_9', 'player_name': 'Efe Kaan',
                'season_id': '25/26', 'current_date': '2026-03-14',
              }
            ],
          });
        }),
      );

      expect(await session.resolve(), 'car_9');
      expect(created, isFalse);
    });

    test('kariyer yoksa C0 katalogundan geçerli bir künyeyle kurar', () async {
      Map<String, dynamic>? sent;
      final session = CareerSession(
        client: _clientWith((request) {
          switch ('${request.method} ${request.url.path}') {
            case 'GET /careers':
              return _json({'careers': <dynamic>[]});
            case 'GET /careers/options':
              return _json(_optionsBody);
            case 'POST /careers':
              sent = jsonDecode(request.body) as Map<String, dynamic>;
              return _json(_createdHubBody('car_new'), status: 201);
          }
          fail('beklenmeyen istek: ${request.method} ${request.url}');
        }),
      );

      expect(await session.resolve(), 'car_new');
      // Rol pozisyona ait olmalı (C1 doğrular) ve hedef kulüp FE'nin tercihi.
      expect(sent, {
        'first_name': 'Efe',
        'last_name': 'Kaan',
        'nationality': 'TR',
        'position': 'Orta saha',
        'role': 'defansif_orta_saha',
        'target_team_id': 't_ykz',
      });
    });

    test('tercih edilen pozisyon/kulüp katalogda yoksa ilkine düşer', () async {
      Map<String, dynamic>? sent;
      final options = Map<String, dynamic>.from(_optionsBody)
        ..['positions'] = [(_optionsBody['positions'] as List).first]
        ..['target_teams'] = [(_optionsBody['target_teams'] as List).first];
      final session = CareerSession(
        client: _clientWith((request) {
          switch ('${request.method} ${request.url.path}') {
            case 'GET /careers':
              return _json({'careers': <dynamic>[]});
            case 'GET /careers/options':
              return _json(options);
            case 'POST /careers':
              sent = jsonDecode(request.body) as Map<String, dynamic>;
              return _json(_createdHubBody('car_new'), status: 201);
          }
          fail('beklenmeyen istek: ${request.method} ${request.url}');
        }),
      );

      await session.resolve();

      expect(sent!['position'], 'Defans');
      expect(sent!['role'], 'stoper');
      expect(sent!['target_team_id'], 't_gal');
    });

    test('adopt() sihirbazın kurduğu kariyeri hiç istek atmadan benimser',
        () async {
      final session = CareerSession(
        client: _clientWith(
          (request) => fail('adopt sonrası istek beklenmiyordu: ${request.url}'),
        ),
      );

      session.adopt('car_wizard');

      expect(session.careerId, 'car_wizard');
      expect(await session.resolve(), 'car_wizard');
      expect(await session.resolveExisting(), 'car_wizard');
    });

    test('resolveExisting() kariyer yoksa null döner, C1 çağırmaz', () async {
      var created = false;
      final session = CareerSession(
        client: _clientWith((request) {
          if (request.method == 'POST') created = true;
          return _json({'careers': <dynamic>[]});
        }),
      );

      expect(await session.resolveExisting(), isNull);
      expect(created, isFalse);
    });
  });
}

/// C1/C3'ün hub gövdesi — yeni kariyer kurulduğunda dönen yanıt.
Map<String, dynamic> _createdHubBody(String careerId) => {
      'career_id': careerId,
      'career_state': {
        'current_date': '2026-08-01', 'season_id': '25/26',
        'money': 100, 'condition': 100, 'day_budget': {'time': 720.0},
      },
      'player': {
        'name': 'Efe Kaan', 'first_name': 'Efe', 'last_name': 'Kaan',
        'nationality': 'TR', 'position': 'Orta saha', 'role': 'regista',
        'role_name': 'Regista', 'age': 21,
        'team': {
          'team_id': 't_plm', 'name': 'Palamut SK', 'short_name': 'PLM',
          'color_primary': '#003049', 'color_secondary': '#F5A623',
        },
        'target_team': {
          'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
          'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
        },
      },
      'next_fixture': null,
      'standing_summary': null,
      'news_preview': <dynamic>[],
    };

/// C0'ın gerçek yanıtının kısaltılmış hali (CONTRACT.md §5.1).
const _optionsBody = <String, dynamic>{
  'nationalities': [
    {'country_code': 'TR', 'name': 'Türkiye', 'nationality': 'Türk'},
  ],
  'positions': [
    {
      'position': 'Defans',
      'roles': [
        {
          'role_id': 'stoper', 'name': 'Stoper', 'group': 'DC',
          'attributes': ['tackling', 'tackling'],
        },
      ],
    },
    {
      'position': 'Orta saha',
      'roles': [
        {
          'role_id': 'defansif_orta_saha', 'name': 'Defansif Orta Saha',
          'group': 'DM', 'attributes': ['tackling', 'passing'],
        },
        {
          'role_id': 'regista', 'name': 'Regista', 'group': 'DM',
          'attributes': ['passing', 'passing'],
        },
      ],
    },
  ],
  'target_teams': [
    {
      'team': {
        'team_id': 't_gal', 'name': 'Galatasaray', 'short_name': 'GS',
        'color_primary': '#A32638', 'color_secondary': '#FBB03B',
      },
      'competition': {
        'competition_id': 'c_sl', 'kind': 'league', 'name': 'Süper Lig',
        'country': 'TR', 'tier': 1,
      },
      'strength_hint': 'güçlü',
    },
    {
      'team': {
        'team_id': 't_ykz', 'name': 'FK Yıldız', 'short_name': 'YKZ',
        'color_primary': '#1E6FD9', 'color_secondary': '#FFFFFF',
      },
      'competition': null,
      'strength_hint': 'orta',
    },
  ],
  'skill_exams': [
    {
      'exam_id': 'shooting', 'title': 'Şut Sınavı',
      'description': 'Bitiricilik ve isabet ölçümü.',
      'attribute_key': 'shooting', 'points_per_level': 1.0,
      'min_level': 1, 'max_level': 5, 'max_value': 100.0,
    },
    {
      'exam_id': 'passing', 'title': 'Pas Sınavı',
      'description': 'Kısa ve uzun pas isabeti ölçümü.',
      'attribute_key': 'passing', 'points_per_level': 1.0,
      'min_level': 1, 'max_level': 5, 'max_value': 100.0,
    },
    {
      'exam_id': 'tackling', 'title': 'Müdahale Sınavı',
      'description': 'Top kapma ve ikili mücadele ölçümü.',
      'attribute_key': 'tackling', 'points_per_level': 1.0,
      'min_level': 1, 'max_level': 5, 'max_value': 100.0,
    },
  ],
  'starting_values': {
    'money': 100, 'condition': 100,
    'relationships': {
      'coach': 70, 'team': 50, 'media': 10, 'fans': 40,
      'partner': 0, 'family': 0,
    },
    'base_skill_value': 20.0, 'role_bonus_per_slot': 2.0,
  },
};

void _timePassEndpointTests() {
  group('calendar (W5)', () {
    test('calendar() sends from/to and parses marks', () async {
      late Map<String, String> params;
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/calendar');
        params = request.url.queryParameters;
        return _json({
          'from': '2026-08-01',
          'to': '2026-08-31',
          'today': '2026-08-19',
          'season': {
            'season_id': '25/26',
            'starts_on': '2026-08-01',
            'ends_on': '2027-05-31',
          },
          'days': [
            {
              'date': '2026-08-08',
              'marks': [
                {
                  'kind': 'match',
                  'ref_id': 'f_1',
                  'competition': {
                    'competition_id': 'c_lig2', 'kind': 'league', 'name': '1. Lig',
                  },
                  'round_no': 1,
                  'kickoff_at': '2026-08-08T20:00:00+03:00',
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
            },
            {
              'date': '2026-08-10',
              'marks': [
                {'kind': 'wage', 'ref_id': null},
                {
                  'kind': 'cup_round', 'ref_id': 'c_kupa',
                  'round_no': 1, 'stage': 'r32', 'drawn': false,
                },
              ],
            },
          ],
        });
      });

      final page = await client.calendar(
        'car_1',
        from: '2026-08-01',
        to: '2026-08-31',
      );

      expect(params, {'from': '2026-08-01', 'to': '2026-08-31'});
      expect(page.season!.endsOn, '2027-05-31');
      expect(page.marksByDate.keys, ['2026-08-08', '2026-08-10']);

      final match = page.days.first.marks.single;
      expect(match.isMatch, isTrue);
      expect(match.isPlayed, isFalse);
      expect(match.away!.shortName, 'DNZ');
      expect(match.competition!.name, '1. Lig');

      expect(page.days.last.marks.map((m) => m.kind), ['wage', 'cup_round']);
      expect(page.days.last.marks.last.drawn, isFalse);
    });

    test('calendar() omits both bounds when not given', () async {
      final client = _clientWith((request) {
        expect(request.url.queryParameters, isEmpty);
        return _json({
          'from': '2026-08-01', 'to': '2026-08-31', 'today': '2026-08-19',
          'season': null, 'days': <dynamic>[],
        });
      });

      final page = await client.calendar('car_1');
      expect(page.season, isNull);
      expect(page.days, isEmpty);
    });

    test('an unknown mark kind parses without losing its neighbours', () async {
      // §5.0: adding a mark kind is not a breaking change.
      final client = _clientWith((request) {
        return _json({
          'from': '2026-08-01', 'to': '2026-08-31', 'today': '2026-08-19',
          'season': null,
          'days': [
            {
              'date': '2026-08-10',
              'marks': [
                {'kind': 'transfer_window', 'ref_id': null},
                {'kind': 'wage', 'ref_id': null},
              ],
            }
          ],
        });
      });

      final page = await client.calendar('car_1');
      expect(page.days.single.marks.map((m) => m.kind),
          ['transfer_window', 'wage']);
    });
  });

  group('social offers (R4-R6)', () {
    final offerBody = {
      'offer_id': 'so_9f21c3',
      'template_id': 'coach_extra_session',
      'relationship_id': 'coach',
      'relationship': {
        'relationship_id': 'coach', 'kind': 'coach', 'category': 'Antrenör',
        'score': 74, 'person_name': 'Mert Çalışkan', 'contact_name': 'Antrenör Mert',
      },
      'title': 'Fazladan idman',
      'body': 'Antrenör yarın sabah bire bir çalışmak istiyor.',
      'accept_label': 'Sahada olurum',
      'decline_label': 'Bu hafta olmaz',
      'costs': {'time': 120, 'energy': 20},
      'requires': <String, dynamic>{},
      'opened_on': '2026-08-19',
      'status': 'open',
      'resolved_on': null,
    };

    test('socialOffers() parses the text and the gate', () async {
      final client = _clientWith((request) {
        expect(request.method, 'GET');
        expect(request.url.path, '/careers/car_1/social/offers');
        return _json({'offers': [offerBody]});
      });

      final offers = await client.socialOffers('car_1');
      final offer = offers.single;

      expect(offer.offerId, 'so_9f21c3');
      expect(offer.isOpen, isTrue);
      expect(offer.title, 'Fazladan idman');
      expect(offer.acceptLabel, 'Sahada olurum');
      expect(offer.costs, {'time': 120.0, 'energy': 20.0});
      expect(offer.requires, isEmpty);
      expect(offer.relationship!.personName, 'Mert Çalışkan');
    });

    test('acceptSocialOffer() POSTs to /accept and parses the deltas', () async {
      final client = _clientWith((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/careers/car_1/social/offers/so_9f21c3/accept');
        return _json({
          'career_state': _careerStateBody,
          'offer': {...offerBody, 'status': 'accepted', 'resolved_on': '2026-08-19'},
          'relationship_changes': [
            {'relationship_id': 'coach', 'before': 70, 'after': 75, 'delta': 5}
          ],
          'attribute_changes': [
            {
              'key': 'shooting', 'before': 50.0, 'after': 50.6,
              'level_before': 5, 'level_after': 5,
            }
          ],
          'ledger_entries': <dynamic>[],
        });
      });

      final result = await client.acceptSocialOffer('car_1', 'so_9f21c3');

      expect(result.offer.status, 'accepted');
      expect(result.offer.isOpen, isFalse);
      expect(result.relationshipChanges.single.delta, 5);
      expect(result.attributeChanges.single.key, 'shooting');
    });

    test('declineSocialOffer() POSTs to /decline', () async {
      final client = _clientWith((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/careers/car_1/social/offers/so_9f21c3/decline');
        return _json({
          'career_state': _careerStateBody,
          'offer': {...offerBody, 'status': 'declined', 'resolved_on': '2026-08-19'},
          'relationship_changes': [
            {'relationship_id': 'coach', 'before': 70, 'after': 67, 'delta': -3}
          ],
          'attribute_changes': <dynamic>[],
          'ledger_entries': <dynamic>[],
        });
      });

      final result = await client.declineSocialOffer('car_1', 'so_9f21c3');
      expect(result.offer.status, 'declined');
      expect(result.relationshipChanges.single.delta, -3);
    });
  });

  group('advance (T3) additive fields', () {
    Map<String, Object?> advanceBody({bool withNewFields = true}) => {
          'career_state': _careerStateBody,
          'days_advanced': 3,
          'stopped_on': '2026-08-08',
          'stop_reason': 'social_offer',
          'simulated': {'fixtures': 12, 'competitions': 2},
          'ledger_entries': <dynamic>[],
          'news_created': <dynamic>[],
          'repossessed': <dynamic>[],
          if (withNewFields) ...{
            'stopped_events': [
              {
                'kind': 'social_offer', 'ref_id': 'so_9f21c3',
                'relationship_id': 'coach', 'opened_on': '2026-08-08',
              },
              {'kind': 'relationship_low', 'ref_id': 'partner'},
            ],
            'condition_before': 72,
            'condition_after': 80,
          },
        };

    test('advance() parses stopped_events and the condition pair', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/advance');
        expect(jsonDecode(request.body), {'to': 'next_day'});
        return _json(advanceBody());
      });

      final result = await client.advance('car_1', to: 'next_day');

      expect(result.conditionBefore, 72);
      expect(result.conditionAfter, 80);
      expect(result.stoppedEvents.map((e) => e.kind),
          ['social_offer', 'relationship_low']);
      expect(result.stoppedOfferId, 'so_9f21c3');
      // Event-specific fields survive in `extra` (§1.3).
      expect(result.stoppedEvents.first.extra['relationship_id'], 'coach');
    });

    test('advance() still parses a body without the new fields', () async {
      // §5.0 additivity runs both ways: an older backend must not crash FE.
      final client = _clientWith(
        (request) => _json(advanceBody(withNewFields: false)),
      );

      final result = await client.advance('car_1', to: 'next_event');

      expect(result.daysAdvanced, 3);
      expect(result.stoppedEvents, isEmpty);
      expect(result.conditionBefore, isNull);
      expect(result.stoppedOfferId, isNull);
    });
  });

  group('day (T1) condition_recovery', () {
    test('day() parses the recovery preview and its sources', () async {
      final client = _clientWith((request) {
        expect(request.url.path, '/careers/car_1/day');
        return _json({
          'career_state': _careerStateBody,
          'is_match_day': false,
          'events': [
            {
              'kind': 'social_offer', 'ref_id': 'so_1',
              'relationship_id': 'family', 'opened_on': '2026-08-19',
            }
          ],
          'condition_recovery': {
            'base': 5, 'bonus': 2, 'total': 7, 'capped': false,
            'sources': [
              {'item_id': 'home-treadmill', 'title': 'Koşu bandı', 'amount': 2}
            ],
          },
        });
      });

      final day = await client.day('car_1');

      expect(day.conditionRecovery!.total, 7);
      expect(day.conditionRecovery!.capped, isFalse);
      expect(day.conditionRecovery!.sources.single.title, 'Koşu bandı');
      expect(day.pendingOfferId, 'so_1');
    });

    test('day() survives a body with no condition_recovery', () async {
      final client = _clientWith(
        (request) => _json({
          'career_state': _careerStateBody,
          'is_match_day': false,
          'events': <dynamic>[],
        }),
      );

      final day = await client.day('car_1');
      expect(day.conditionRecovery, isNull);
      expect(day.pendingOfferId, isNull);
    });
  });
}

const _careerStateBody = {
  'career_id': 'car_1',
  'current_date': '2026-08-19',
  'season_id': '25/26',
  'money': 48200,
  'condition': 80,
  'day_budget': {'time': 720.0, 'energy': 100.0},
};
