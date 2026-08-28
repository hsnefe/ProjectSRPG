import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/net/match_models.dart';

// JSON gövdeleri `API_CONTRACT.md` §3.1, §8.1, §8.2, §6.1'deki örneklerden
// birebir alınmıştır.
const _nextMatchJson = '''
{
  "match_id": "m_20260815_ykz_dnz",
  "kickoff_at": "2026-08-15T20:00:00+03:00",
  "user_side": "home",
  "teams": {
    "home": { "name": "FK Yıldız" },
    "away": { "name": "Deniz SK" }
  },
  "team_tactic": { "code": "attacking", "label": "Hücumcu" },
  "stamina": {
    "current": 100,
    "floor": 35,
    "ceiling": 100,
    "substitution_bonus": 6
  },
  "directive_options": {
    "effort": [
      { "value": 10, "label": "Çok düşük", "offers_per_match": 10, "stamina_multiplier": 0.52, "projected_end_stamina": 76 },
      { "value": 50, "label": "Normal", "offers_per_match": 33, "stamina_multiplier": 1.00, "projected_end_stamina": 54 }
    ],
    "aggression": [
      { "value": 10, "label": "Çok temiz", "foul_multiplier": 0.72 },
      { "value": 50, "label": "Normal", "foul_multiplier": 1.00 }
    ],
    "focus": [
      { "value": "attack", "label": "Hücum" },
      { "value": null, "label": "Farketmez" }
    ]
  },
  "defaults": { "effort": 50, "aggression": 50, "focus": null }
}
''';

const _startMatchJson = '''
{ "match_id": "m_20260815_ykz_dnz", "stream_url": "/matches/m_20260815_ykz_dnz/stream" }
''';

const _directiveResponseJson = '''
{
  "accepted": true,
  "note": "caliskanlik 150 -> 100 aralığa çekildi",
  "effective_from_minute": 35,
  "applied": { "effort": 100, "aggression": 70, "focus": "attack" }
}
''';

const _tickJson = '''
{
  "type": "tick",
  "seq": 128,
  "match_id": "m_20260815_ykz_dnz",
  "minute": 34,
  "finished": false,
  "situation": "home_dominating",
  "score": { "home": 1, "away": 0 },
  "possession": { "home": 54, "away": 46 },
  "team": {
    "user_side": "home",
    "stamina": 81,
    "mentality": "attacking",
    "yellow_cards": 1,
    "red_cards": 0
  },
  "directives": { "effort": 50, "aggression": 70, "focus": "defend" },
  "events": [
    {
      "event_id": "e_128_0",
      "side": "home",
      "text": "Ceza sahası dışından sert vuruş — kaleci köşeye uzanıp çeldi.",
      "is_goal": false,
      "event_type": "save_long_shot"
    }
  ]
}
''';

void main() {
  group('NextMatchResponse.fromJson', () {
    test('parses every field from the contract example', () {
      final result = NextMatchResponse.fromJson(
        jsonDecode(_nextMatchJson) as Map<String, dynamic>,
      );

      expect(result.matchId, 'm_20260815_ykz_dnz');
      expect(result.kickoffAt, DateTime.parse('2026-08-15T20:00:00+03:00'));
      expect(result.userSide, 'home');
      expect(result.teams.home.name, 'FK Yıldız');
      expect(result.teams.away.name, 'Deniz SK');
      expect(result.teamTactic.code, 'attacking');
      expect(result.stamina.floor, 35);
      expect(result.stamina.ceiling, 100);
      expect(result.stamina.substitutionBonus, 6);
      expect(result.directiveOptions.effort, hasLength(2));
      expect(result.directiveOptions.effort.first.staminaMultiplier, 0.52);
      expect(result.directiveOptions.aggression.first.foulMultiplier, 0.72);
      expect(result.directiveOptions.focus.last.value, isNull);
      expect(result.directiveOptions.focus.last.label, 'Farketmez');
      expect(result.defaults.effort, 50);
      expect(result.defaults.focus, isNull);
    });
  });

  group('StartMatchResponse.fromJson', () {
    test('parses match id and stream url', () {
      final result = StartMatchResponse.fromJson(
        jsonDecode(_startMatchJson) as Map<String, dynamic>,
      );

      expect(result.matchId, 'm_20260815_ykz_dnz');
      expect(result.streamUrl, '/matches/m_20260815_ykz_dnz/stream');
    });
  });

  group('DirectiveResponse.fromJson', () {
    test('parses accepted response with a clamp note', () {
      final result = DirectiveResponse.fromJson(
        jsonDecode(_directiveResponseJson) as Map<String, dynamic>,
      );

      expect(result.accepted, isTrue);
      expect(result.note, contains('aralığa çekildi'));
      expect(result.effectiveFromMinute, 35);
      expect(result.applied.effort, 100);
      expect(result.applied.focus, 'attack');
    });
  });

  group('TickFrame.fromJson', () {
    test('parses a full tick envelope including nested events', () {
      final result = TickFrame.fromJson(
        jsonDecode(_tickJson) as Map<String, dynamic>,
      );

      expect(result.seq, 128);
      expect(result.minute, 34);
      expect(result.finished, isFalse);
      expect(result.situation, 'home_dominating');
      expect(result.score.home, 1);
      expect(result.possession.home + result.possession.away, 100);
      expect(result.team.stamina, 81);
      expect(result.team.mentality, 'attacking');
      expect(result.directives.focus, 'defend');
      expect(result.events, hasLength(1));
      expect(result.events.single.eventType, 'save_long_shot');
      expect(result.events.single.side, 'home');
      expect(result.events.single.isGoal, isFalse);
    });

    test('accepts an empty events array (silent tick)', () {
      final json = jsonDecode(_tickJson) as Map<String, dynamic>;
      json['events'] = <dynamic>[];

      final result = TickFrame.fromJson(json);

      expect(result.events, isEmpty);
    });

    test('resolvedIntervention is null when the block is absent', () {
      final result = TickFrame.fromJson(
        jsonDecode(_tickJson) as Map<String, dynamic>,
      );

      expect(result.resolvedIntervention, isNull);
    });

    test('parses the resolved_intervention block when present (§3.1)', () {
      final json = jsonDecode(_tickJson) as Map<String, dynamic>;
      json['resolved_intervention'] = {
        'offer_id': 'off_a91c',
        'action_key': 'finish_power',
        'outcome_key': 'great',
      };

      final result = TickFrame.fromJson(json);

      expect(result.resolvedIntervention?.offerId, 'off_a91c');
      expect(result.resolvedIntervention?.actionKey, 'finish_power');
      expect(result.resolvedIntervention?.outcomeKey, 'great');
    });
  });

  group('InterventionOfferFrame.fromJson', () {
    test('parses an engine offer (no minigame/outcome_keys)', () {
      final json = {
        'type': 'intervention_offer',
        'seq': 142,
        'match_id': 'm_20260815_ykz_dnz',
        'offer_id': 'off_a91c',
        'minute': 63,
        'resolution': 'engine',
        'action_key': 'counter_attack',
        'prompt': 'Rakip savunması dağınık, hızlı çıkış fırsatı var',
        'risk_hint': null,
        'timeout_seconds': 20,
        'on_timeout': 'decline',
      };

      final result = InterventionOfferFrame.fromJson(json);

      expect(result.offerId, 'off_a91c');
      expect(result.resolution, 'engine');
      expect(result.minigame, isNull);
      expect(result.outcomeKeys, isEmpty);
      expect(result.resolved, isNull);
    });

    test('parses a minigame offer with ordered outcome_keys (dormant this round)',
        () {
      final json = {
        'seq': 142,
        'match_id': 'm_test',
        'offer_id': 'off_a91c',
        'minute': 63,
        'resolution': 'minigame',
        'minigame': 'shot',
        'action_key': 'finish_power',
        'prompt': 'Forvet ceza sahasında topla buluştu',
        'risk_hint': null,
        'timeout_seconds': 20,
        'on_timeout': 'decline',
        'outcome_keys': [
          {'key': 'great', 'label': 'Ağlara gitti', 'tone': 'positive'},
          {'key': 'good', 'label': 'Kaleci çeldi', 'tone': 'neutral'},
          {'key': 'bad', 'label': 'Kaleyle alakasız', 'tone': 'negative'},
        ],
      };

      final result = InterventionOfferFrame.fromJson(json);

      expect(result.minigame, 'shot');
      expect(result.outcomeKeys, hasLength(3));
      expect(result.outcomeKeys.first.key, 'great');
      expect(result.outcomeKeys.first.tone, 'positive');
    });

    test('an unrecognized resolution degrades to engine (§7.2 [İ-31])', () {
      final json = {
        'seq': 1,
        'match_id': 'm_test',
        'offer_id': 'off_x',
        'minute': 1,
        'resolution': 'some_future_mode',
        'action_key': 'counter_attack',
        'prompt': 'x',
        'risk_hint': null,
        'timeout_seconds': 20,
        'on_timeout': 'decline',
      };

      final result = InterventionOfferFrame.fromJson(json);

      expect(result.resolution, 'engine');
    });
  });
}
