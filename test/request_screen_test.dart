import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/game/intervention_stats.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/request_screen.dart';

MatchResultResponse _result({
  int goals = 1,
  int assists = 1,
  List<RelationshipChange> relationshipChanges = const [],
}) {
  return MatchResultResponse.fromJson({
    'career_state': {
      'current_date': '2026-03-16', 'season_id': '25/26',
      'money': 49700, 'condition': 54, 'day_budget': {'time': 720.0},
    },
    'fixture': {
      'fixture_id': 'f_1', 'status': 'played',
      'score': {'home': 2, 'away': 1},
    },
    'other_results': const [],
    'standing_delta': {'rank_before': 3, 'rank_after': 2},
    'player_stat_delta': {
      'appearances': 1, 'goals': goals, 'assists': assists, 'minutes': 95,
    },
    'relationship_changes': [
      for (final c in relationshipChanges)
        {
          'relationship_id': c.relationshipId,
          'before': c.before,
          'after': c.after,
          'delta': c.delta,
        },
    ],
    'ledger_entries': const [],
    'news_created': const [],
  });
}

const _userStats = UserMatchStats(
  opportunities: 12,
  shots: 4,
  shotsOnTarget: 2,
);

void main() {
  testWidgets('renders the stub content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RequestScreen()));

    expect(find.text('Talepler'), findsOneWidget);
    expect(find.text('İlerle'), findsOneWidget);
    // `result`/`userStats` yoksa istatistik tablosu ve ilişki bölümü hiç
    // çizilmez.
    expect(find.text('Fırsat sayısı'), findsNothing);
  });

  testWidgets('renders the stats table from userStats + playerStatDelta',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RequestScreen(
        result: _result(goals: 2, assists: 1),
        userStats: _userStats,
      ),
    ));

    expect(find.text('Fırsat sayısı'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('İsabetli şut / Şut'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Başarılı pas / Pas denemesi'), findsOneWidget);
    expect(find.text('0/0'), findsNWidgets(2)); // pas ve dribling satırları
    expect(find.text('Gol'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Asist'), findsOneWidget);
  });

  testWidgets('skips the stats table when userStats is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RequestScreen(result: _result()),
    ));

    expect(find.text('Fırsat sayısı'), findsNothing);
  });

  testWidgets(
    'renders relationship bars in a fixed order with signed deltas and a '
    'passive mic icon next to media',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RequestScreen(
          result: _result(relationshipChanges: const [
            RelationshipChange(
                relationshipId: 'media', before: 10, after: 8, delta: -2),
            RelationshipChange(
                relationshipId: 'coach', before: 70, after: 74, delta: 4),
            RelationshipChange(
                relationshipId: 'fans', before: 40, after: 40, delta: 0),
            RelationshipChange(
                relationshipId: 'team', before: 50, after: 52, delta: 2),
          ]),
        ),
      ));

      expect(find.text('Antrenör'), findsOneWidget);
      expect(find.text('Takım'), findsOneWidget);
      expect(find.text('Taraftarlar'), findsOneWidget);
      expect(find.text('Medya'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);

      // Sabit sıra: Antrenör → Takım → Taraftarlar → Medya, girdi sırası
      // ne olursa olsun (yukarıdaki liste 'media' ile başlıyor) - dikey
      // konumlarının artan sırada olduğunu doğrula.
      final ys = ['Antrenör', 'Takım', 'Taraftarlar', 'Medya']
          .map((label) => tester.getTopLeft(find.text(label)).dy)
          .toList();
      expect(ys, [ys[0], ys[1], ys[2], ys[3]]..sort());

      // Medya satırının yanındaki mikrofon pasif - dokununca hiçbir şey
      // yapmaz (röportaj akışı bu turda yok).
      final micButton = tester.widget<IconButton>(find.widgetWithIcon(
        IconButton,
        Icons.mic_none_outlined,
      ));
      expect(micButton.onPressed, isNull);
    },
  );

  testWidgets('skips the relationship section when there are no changes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: RequestScreen(result: _result())));

    expect(find.text('Antrenör'), findsNothing);
    expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
  });

  testWidgets('the career button pops back to the career center already in '
      'the stack', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Giriş ekranı'))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    // CareerCenterScreen'in kendisi PlayerScope istiyor; popUntil davranışı
    // yalnızca route adına baktığı için burada aynı adı taşıyan sade bir
    // yer tutucu yeterli.
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Kariyer merkezi')),
        settings: const RouteSettings(name: CareerCenterScreen.routeName),
      ),
    );
    await tester.pumpAndSettle();

    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Maç'))),
    );
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const RequestScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    expect(find.text('Kariyer merkezi'), findsOneWidget);
    expect(find.byType(RequestScreen), findsNothing);
    expect(find.text('Maç'), findsNothing);
  });

  testWidgets('falls back to the first route when no career center is in the '
      'stack', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Giriş ekranı'))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const RequestScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerle'));
    await tester.pumpAndSettle();

    expect(find.text('Giriş ekranı'), findsOneWidget);
  });
}
