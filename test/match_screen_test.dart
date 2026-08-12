import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/match_feed.dart';
import 'package:project_srpg/screens/match_screen.dart';

/// A feed the test controls by hand instead of relying on real delays.
class _FakeMatchFeed implements MatchFeed {
  final _controller = StreamController<MatchEvent>();

  @override
  Stream<MatchEvent> events({ValueListenable<MatchSpeed>? speed}) =>
      _controller.stream;

  void emit(MatchEvent event) => _controller.add(event);

  void close() => _controller.close();
}

Future<void> _pumpMatchScreen(
  WidgetTester tester,
  _FakeMatchFeed feed,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MatchScreen(feed: feed, home: 'FK Yıldız', away: 'Deniz SK'),
    ),
  );
  await tester.pump();
}

/// Emits an event and pumps twice: once to let the stream's microtask
/// delivery reach the [StreamSubscription] listener and call `setState`,
/// and once more so the resulting rebuild is reflected in the tree.
Future<void> _emit(
  WidgetTester tester,
  _FakeMatchFeed feed,
  MatchEvent event,
) async {
  feed.emit(event);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows an empty state before any event arrives',
      (tester) async {
    final feed = _FakeMatchFeed();
    await _pumpMatchScreen(tester, feed);

    expect(find.text('Maç başlıyor…'), findsOneWidget);

    feed.close();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders a home event in the accent tint', (tester) async {
    final feed = _FakeMatchFeed();
    await _pumpMatchScreen(tester, feed);

    await _emit(
      tester,
      feed,
      const MatchEvent(
        minute: 5,
        side: MatchSide.home,
        text: 'Efe Kaan topu kazandı.',
      ),
    );

    expect(find.textContaining('Efe Kaan topu kazandı'), findsOneWidget);
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.textContaining('Efe Kaan topu kazandı'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0x33228BFF));

    feed.close();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders an away event in the danger tint', (tester) async {
    final feed = _FakeMatchFeed();
    await _pumpMatchScreen(tester, feed);

    await _emit(
      tester,
      feed,
      const MatchEvent(
        minute: 6,
        side: MatchSide.away,
        text: 'Deniz SK topu kesti.',
      ),
    );

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.textContaining('Deniz SK topu kesti'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0x33E85D5D));

    feed.close();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('updates the scoreboard when a goal event arrives',
      (tester) async {
    final feed = _FakeMatchFeed();
    await _pumpMatchScreen(tester, feed);

    expect(find.text('0'), findsNWidgets(2));

    await _emit(
      tester,
      feed,
      const MatchEvent(
        minute: 27,
        side: MatchSide.home,
        text: 'GOL! Efe Kaan attı.',
        isGoal: true,
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    feed.close();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cycles the feed speed through three steps on tap',
      (tester) async {
    final feed = _FakeMatchFeed();
    await _pumpMatchScreen(tester, feed);

    final arrows = find.byIcon(Icons.play_arrow_rounded);
    final minuteButton = find.ancestor(
      of: find.byIcon(Icons.directions_run_outlined),
      matching: find.byType(OutlinedButton),
    );

    expect(arrows, findsNothing); // yavaş

    await tester.tap(minuteButton);
    await tester.pump();
    expect(arrows, findsOneWidget); // orta

    await tester.tap(minuteButton);
    await tester.pump();
    expect(arrows, findsNWidgets(2)); // hızlı

    await tester.tap(minuteButton);
    await tester.pump();
    expect(arrows, findsNothing); // üçüncü basışta başa döner

    feed.close();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancels the subscription on dispose', (tester) async {
    final feed = _FakeMatchFeed();
    await _pumpMatchScreen(tester, feed);

    await tester.pumpWidget(const SizedBox.shrink());

    // Emitting after unmount must not throw or trigger setState-after-dispose.
    expect(() => feed.emit(
          const MatchEvent(minute: 1, side: MatchSide.home, text: 'x'),
        ), returnsNormally);
    await tester.pump();

    feed.close();
  });
}
