import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/month_calendar.dart';
import 'package:project_srpg/widgets/team_badge.dart';

TeamRef _team(String shortName, {String colorPrimary = '#1E6FD9'}) {
  return TeamRef.fromJson({
    'team_id': 't_$shortName',
    'name': shortName,
    'short_name': shortName,
    'color_primary': colorPrimary,
    'color_secondary': '#FFFFFF',
  });
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('isoDate tek haneli gün ve ayı sıfırla doldurur', () {
    expect(MonthCalendar.isoDate(DateTime(2026, 8, 1)), '2026-08-01');
    expect(MonthCalendar.isoDate(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('bilinmeyen bir işaret türü sessiz bir renge düşer', () {
    // §5.0: BE yeni bir mark kind ekleyebilir; grid bunu çizmeye devam eder.
    expect(colorForMarkKind('wage'), AppColors.warning);
    expect(colorForMarkKind('transfer_window'), AppColors.textMuted);
  });

  test('CalendarDayMark match dışı işarette color ister', () {
    expect(
      () => CalendarDayMark(kind: 'wage'),
      throwsA(isA<AssertionError>()),
    );
  });

  test('CalendarDayMark match işaretinde opponent ister', () {
    expect(
      () => CalendarDayMark(kind: 'match'),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('Ağustos 2026 Cumartesi başlar — bütün günler çizilir',
      (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(month: DateTime(2026, 8, 1), marksByDate: const {}),
    ));

    expect(DateTime(2026, 8, 1).weekday, DateTime.saturday);
    for (var day = 1; day <= 31; day++) {
      expect(find.text('$day'), findsOneWidget, reason: 'gün $day çizilmeli');
    }
    expect(find.text('32'), findsNothing);
  });

  testWidgets('Şubat 2027 yirmi sekiz gün çizer', (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(month: DateTime(2027, 2, 14), marksByDate: const {}),
    ));

    expect(find.text('28'), findsOneWidget);
    expect(find.text('29'), findsNothing);
  });

  testWidgets('hafta başlıkları Pazartesi ile başlar', (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(month: DateTime(2026, 8, 1), marksByDate: const {}),
    ));

    expect(find.text('Pt'), findsOneWidget);
    expect(find.text('Pa'), findsOneWidget);
  });

  testWidgets('compact sürüm gün başlıklarını çizmez', (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(
        month: DateTime(2026, 8, 1),
        marksByDate: const {},
        compact: true,
      ),
    ));

    expect(find.text('Pt'), findsNothing);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('hücreler gerçek karedir — genişlik yüksekliğe eşittir',
      (tester) async {
    // Eski sürüm yalnız `height` veriyordu, genişlik `Expanded`'a bağlıydı
    // ve grid genişliği ne olursa olsun kare garanti değildi.
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 350,
        child: MonthCalendar(month: DateTime(2026, 8, 1), marksByDate: const {}),
      ),
    ));

    final size = tester.getSize(find.byKey(const ValueKey('calCell:15')));
    expect(size.width, closeTo(size.height, 0.5));
  });

  testWidgets('kare oranı grid genişliğinden bağımsızdır', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 700,
        child: MonthCalendar(month: DateTime(2026, 8, 1), marksByDate: const {}),
      ),
    ));

    final size = tester.getSize(find.byKey(const ValueKey('calCell:15')));
    expect(size.width, closeTo(size.height, 0.5));
    expect(size.width, greaterThan(60)); // 700/7'ye yakın, önceki 44px'ten büyük
  });

  testWidgets('maç günü rakip rozetiyle doldurulur', (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(
        month: DateTime(2026, 8, 1),
        marksByDate: {
          '2026-08-08': [CalendarDayMark(kind: 'match', opponent: _team('DNZ'))],
        },
      ),
    ));

    expect(find.byKey(const ValueKey('calCrest:8')), findsOneWidget);
    expect(find.byType(TeamBadge), findsOneWidget);
    expect(find.text('DNZ'), findsOneWidget);
  });

  testWidgets('maç dışı işaret sağ altta küçük bir nokta çizer', (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(
        month: DateTime(2026, 8, 1),
        marksByDate: const {
          '2026-08-10': [CalendarDayMark(kind: 'wage', color: AppColors.warning)],
        },
      ),
    ));

    expect(find.byKey(const ValueKey('calMark:wage:10')), findsOneWidget);
    expect(find.byType(TeamBadge), findsNothing);

    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('calMark:wage:10')),
    );
    expect((dot.decoration as BoxDecoration).color, AppColors.warning);
  });

  testWidgets('bir günde ikiden fazla maç dışı işaret varsa ikisi çizilir',
      (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(
        month: DateTime(2026, 8, 1),
        marksByDate: const {
          '2026-08-10': [
            CalendarDayMark(kind: 'wage', color: AppColors.warning),
            CalendarDayMark(kind: 'cup_round', color: AppColors.accent),
            CalendarDayMark(kind: 'contract_expiry', color: AppColors.danger),
          ],
        },
      ),
    ));

    expect(find.byKey(const ValueKey('calMark:wage:10')), findsOneWidget);
    expect(find.byKey(const ValueKey('calMark:cup_round:10')), findsOneWidget);
    // Üçüncüsü hücreyi okunmaz yapardı; gün detayı panelinde görünüyor.
    expect(find.byKey(const ValueKey('calMark:contract_expiry:10')), findsNothing);
  });

  testWidgets('bir günde hem maç hem başka bir işaret olabilir', (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(
        month: DateTime(2026, 8, 1),
        marksByDate: {
          '2026-08-10': [
            CalendarDayMark(kind: 'match', opponent: _team('DNZ')),
            const CalendarDayMark(kind: 'wage', color: AppColors.warning),
          ],
        },
      ),
    ));

    expect(find.byKey(const ValueKey('calCrest:10')), findsOneWidget);
    expect(find.byKey(const ValueKey('calMark:wage:10')), findsOneWidget);
  });

  testWidgets('onSelectDay dokunulan günün ISO tarihini verir', (tester) async {
    String? tapped;
    await tester.pumpWidget(_wrap(
      MonthCalendar(
        month: DateTime(2026, 8, 1),
        marksByDate: const {},
        onSelectDay: (date) => tapped = date,
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('calDay:19')));
    expect(tapped, '2026-08-19');
  });

  testWidgets('onSelectDay verilmezse hücreler dokunulabilir değildir',
      (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(month: DateTime(2026, 8, 1), marksByDate: const {}),
    ));

    expect(find.byKey(const ValueKey('calDay:19')), findsNothing);
  });
}
