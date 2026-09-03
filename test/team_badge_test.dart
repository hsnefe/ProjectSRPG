import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/widgets/team_badge.dart';

TeamRef _team({
  String shortName = 'AYD',
  String colorPrimary = '#1E6FD9',
  String colorSecondary = '#FFFFFF',
}) {
  return TeamRef.fromJson({
    'team_id': 't_1',
    'name': 'Aydınlık SK',
    'short_name': shortName,
    'color_primary': colorPrimary,
    'color_secondary': colorSecondary,
  });
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('kısa ismi gösterir', (tester) async {
    await tester.pumpWidget(_wrap(TeamBadge(team: _team(shortName: 'DNZ'), size: 40)));
    expect(find.text('DNZ'), findsOneWidget);
  });

  testWidgets('dolgu birincil renk, kenarlık ikincil renk', (tester) async {
    await tester.pumpWidget(_wrap(TeamBadge(
      team: _team(colorPrimary: '#1E6FD9', colorSecondary: '#FFA500'),
      size: 40,
    )));

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, const Color(0xFF1E6FD9));
    expect(decoration.border!.top.color, const Color(0xFFFFA500));
  });

  testWidgets('boyut parametresi hücreye göre ölçeklenir', (tester) async {
    await tester.pumpWidget(_wrap(TeamBadge(team: _team(), size: 64)));

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth ?? 0, greaterThanOrEqualTo(0));
    final renderBox = tester.renderObject<RenderBox>(find.byType(Container));
    expect(renderBox.size.width, 64);
    expect(renderBox.size.height, 64);
  });

  testWidgets('uzun bir kısa isim taşmaz — FittedBox küçültür', (tester) async {
    // §5.0: BE her zaman kısaltılmış bir short_name döner ama widget kendi
    // başına da güvenli olmalı.
    await tester.pumpWidget(_wrap(TeamBadge(team: _team(shortName: 'ÇOKUZUNISIM'), size: 30)));
    expect(tester.takeException(), isNull);
  });
}
