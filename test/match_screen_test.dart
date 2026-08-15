import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/net/match_sse_client.dart';
import 'package:project_srpg/screens/match_screen.dart';
import 'package:project_srpg/state/match_controller.dart';

/// A stream source the test drives by hand instead of relying on real HTTP.
class _FakeSseClient implements MatchStreamSource {
  final controller = StreamController<MatchStreamMessage>();

  @override
  Stream<MatchStreamMessage> connect(Uri uri) => controller.stream;
}

TickFrame _tick({
  required int minute,
  bool finished = false,
  int homeScore = 0,
  int awayScore = 0,
  int stamina = 90,
  List<TickEventDto> events = const [],
}) {
  return TickFrame(
    seq: minute,
    matchId: 'm_test',
    minute: minute,
    finished: finished,
    situation: 'balanced',
    score: ScoreInfo(home: homeScore, away: awayScore),
    possession: const PossessionInfo(home: 55, away: 45),
    team: TeamTickInfo(
      userSide: 'home',
      stamina: stamina,
      mentality: 'balanced',
      yellowCards: 0,
      redCards: 0,
    ),
    directives: const DirectivesInfo(effort: 50, aggression: 50, focus: null),
    events: events,
  );
}

MatchController _buildController(_FakeSseClient source) {
  return MatchController(
    matchId: 'm_test',
    streamUrl: '/matches/m_test/stream',
    userSide: 'home',
    teams: const MatchTeams(
      home: TeamInfo(name: 'FK Yıldız'),
      away: TeamInfo(name: 'Deniz SK'),
    ),
    staminaCatalog: const StaminaCatalog(
      current: 100,
      floor: 35,
      ceiling: 100,
      substitutionBonus: 6,
    ),
    directiveOptions: const DirectiveOptions(effort: [], aggression: [], focus: []),
    streamSource: source,
  );
}

Future<void> _pumpMatchScreen(
  WidgetTester tester,
  MatchController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(home: MatchScreen(controller: controller)),
  );
  await tester.pump();
}

/// Emits a tick and pumps twice: once to let the stream's microtask
/// delivery reach the controller's listener and call `notifyListeners`,
/// and once more so the resulting rebuild is reflected in the tree.
Future<void> _emitTick(
  WidgetTester tester,
  _FakeSseClient source,
  TickFrame tick,
) async {
  source.controller.add(MatchTickMessage(tick));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows an empty state before any tick arrives', (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    expect(find.text('Maç başlıyor…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders a home event in the accent tint', (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    await _emitTick(
      tester,
      source,
      _tick(
        minute: 5,
        events: const [
          TickEventDto(
            eventId: 'e_5_0',
            side: 'home',
            text: 'Efe Kaan topu kazandı.',
            isGoal: false,
            eventType: 'foul',
          ),
        ],
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

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders an away event in the danger tint', (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    await _emitTick(
      tester,
      source,
      _tick(
        minute: 6,
        events: const [
          TickEventDto(
            eventId: 'e_6_0',
            side: 'away',
            text: 'Deniz SK topu kesti.',
            isGoal: false,
            eventType: 'foul',
          ),
        ],
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

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('updates the scoreboard when a goal event arrives',
      (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    expect(find.text('0'), findsNWidgets(2));

    await _emitTick(
      tester,
      source,
      _tick(
        minute: 27,
        homeScore: 1,
        events: const [
          TickEventDto(
            eventId: 'e_27_0',
            side: 'home',
            text: 'GOL! Efe Kaan attı.',
            isGoal: true,
            eventType: 'goal',
          ),
        ],
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cycles the feed speed through three steps on tap',
      (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

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

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancels the stream subscription on dispose', (tester) async {
    final source = _FakeSseClient();
    await _pumpMatchScreen(tester, _buildController(source));

    expect(source.controller.hasListener, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(source.controller.hasListener, isFalse);
  });
}
