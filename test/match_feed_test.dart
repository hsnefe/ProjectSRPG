import 'package:flutter/foundation.dart';
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

    test('scales the tick with the given speed', () async {
      const script = [MatchEvent(minute: 1, side: MatchSide.home, text: 'a')];
      const feed = ScriptedMatchFeed(
        script: script,
        tick: Duration(milliseconds: 200),
      );
      final speed = ValueNotifier(MatchSpeed.fast);

      final watch = Stopwatch()..start();
      await feed.events(speed: speed).toList();
      watch.stop();

      // fast = 0.25 * 200ms; yavaş kademe olsaydı 200ms'yi geçerdi.
      expect(watch.elapsedMilliseconds, lessThan(150));
      speed.dispose();
    });
  });

  group('MatchSpeed', () {
    test('returns to the first step after three steps', () {
      expect(MatchSpeed.slow.next, MatchSpeed.medium);
      expect(MatchSpeed.medium.next, MatchSpeed.fast);
      expect(MatchSpeed.fast.next, MatchSpeed.slow);
    });

    test('draws one more arrow at each step', () {
      expect(MatchSpeed.slow.arrows, 0);
      expect(MatchSpeed.medium.arrows, 1);
      expect(MatchSpeed.fast.arrows, 2);
    });
  });
}
