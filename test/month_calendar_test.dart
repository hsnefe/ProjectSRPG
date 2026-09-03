import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/month_calendar.dart';

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

  testWidgets('Ağustos 2026 Cumartesi başlar — ilk satırda beş boş hücre',
      (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(month: DateTime(2026, 8, 1), marksByDate: const {}),
    ));

    // 1 Ağustos 2026 Cumartesi; Pazartesi başlangıçlı gridde önünde beş boş
    // hücre olmalı, yani ilk satır 1'i altıncı sütunda gösterir.
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

  testWidgets('bir işaret verilen rengiyle çizilir', (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(
        month: DateTime(2026, 8, 1),
        marksByDate: const {
          '2026-08-08': [
            CalendarDayMark(kind: 'match', color: Color(0xFF1E6FD9), refId: 'f_1'),
          ],
        },
      ),
    ));

    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('calMark:match:8')),
    );
    expect((dot.decoration as BoxDecoration).color, const Color(0xFF1E6FD9));
  });

  testWidgets('bir günde üçten fazla işaret varsa üçü çizilir', (tester) async {
    await tester.pumpWidget(_wrap(
      MonthCalendar(
        month: DateTime(2026, 8, 1),
        marksByDate: const {
          '2026-08-10': [
            CalendarDayMark(kind: 'wage', color: AppColors.warning),
            CalendarDayMark(kind: 'cup_round', color: AppColors.accent),
            CalendarDayMark(kind: 'social_offer', color: AppColors.success),
            CalendarDayMark(kind: 'contract_expiry', color: AppColors.danger),
          ],
        },
      ),
    ));

    expect(find.byKey(const ValueKey('calMark:wage:10')), findsOneWidget);
    expect(find.byKey(const ValueKey('calMark:social_offer:10')), findsOneWidget);
    // Dördüncüsü hücreyi okunmaz yapardı; gün detayı panelinde görünüyor.
    expect(find.byKey(const ValueKey('calMark:contract_expiry:10')), findsNothing);
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
