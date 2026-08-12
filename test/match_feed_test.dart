import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/match_feed.dart';

void main() {
  group('ScriptedMatchFeed', () {
    test('emits the script in order', () async {
      const feed = ScriptedMatchFeed(tick: Duration.zero);

      final emitted = await feed.events().toList();

      expect(emitted, equals(kDemoMatchScript));
    });

    test('minutes are non-decreasing across the script', () async {
      const feed = ScriptedMatchFeed(tick: Duration.zero);

      final emitted = await feed.events().toList();

      for (var i = 1; i < emitted.length; i++) {
        expect(emitted[i].minute, greaterThanOrEqualTo(emitted[i - 1].minute));
      }
    });

    test('goal events are only ever home or away, never neutral', () async {
      const feed = ScriptedMatchFeed(tick: Duration.zero);

      final emitted = await feed.events().toList();
      final goals = emitted.where((e) => e.isGoal);

      expect(goals, isNotEmpty);
      for (final goal in goals) {
        expect(goal.side, isNot(MatchSide.neutral));
      }
    });

    test('respects a custom script and tick', () async {
      const customScript = [
        MatchEvent(minute: 1, side: MatchSide.home, text: 'a'),
        MatchEvent(minute: 2, side: MatchSide.away, text: 'b', isGoal: true),
      ];
      const feed = ScriptedMatchFeed(
        script: customScript,
        tick: Duration.zero,
      );

      final emitted = await feed.events().toList();

      expect(emitted, equals(customScript));
    });
  });
}
