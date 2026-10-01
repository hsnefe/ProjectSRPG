import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/screens/new_career/exam_step.dart';

/// C0'ın sınav kataloğunun kısaltılmış hali: ikisinin oyunu var, ikisinin yok.
Map<String, dynamic> _exam(String examId, String title, String attributeKey) => {
      'exam_id': examId,
      'title': title,
      'description': '$title açıklaması.',
      'attribute_key': attributeKey,
      'points_per_level': 1.0,
      'min_level': 1,
      'max_level': 5,
      'max_value': 100.0,
    };

final _options = api.CareerOptions.fromJson({
  'nationalities': <dynamic>[],
  'positions': <dynamic>[],
  'target_teams': <dynamic>[],
  'skill_exams': [
    _exam('shooting', 'Şut Sınavı', 'shooting'),
    _exam('passing', 'Pas Sınavı', 'passing'),
    _exam('tackling', 'Müdahale Sınavı', 'tackling'),
    _exam('dribbling', 'Dribling Sınavı', 'dribbling'),
    // Oyunu henüz olmayan bir sınav elle notlanmaya devam eder.
    _exam('future_exam', 'Gelecek Sınav', 'tackling'),
  ],
  'starting_values': {
    'money': 100,
    'condition': 100,
    'relationships': <String, dynamic>{},
    'base_skill_value': 20.0,
    'role_bonus_per_slot': 2.0,
  },
});

/// Dört kart 800x600'e sığmıyor ve `ListView` görünmeyeni hiç kurmuyor;
/// yüzeyi uzatmadan son kart aranamaz.
Future<void> _pumpStep(
  WidgetTester tester, {
  Map<String, int> levels = const {},
  void Function(String, int)? onLevel,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExamStep(
          options: _options,
          levels: levels,
          outcomes: null,
          previewOf: (exam) => 20,
          baseOf: (exam) => 20,
          onLevel: onLevel ?? (_, __) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('oyunu olan sınav oynanır, olmayan elle notlanır', (tester) async {
    await _pumpStep(tester);

    // Şut, pas, müdahale ve dribling oynanarak notlanıyor.
    expect(find.text('Sınava Gir'), findsNWidgets(4));

    // Yalnızca oyunu olmayan sınav beşli not sırasını koruyor.
    for (var value = 1; value <= 5; value++) {
      expect(find.text('$value'), findsOneWidget);
    }
  });

  testWidgets('alınan not kartta görünür ve düğme tekrara döner', (
    tester,
  ) async {
    await _pumpStep(tester, levels: const {'shooting': 4});

    expect(find.text('Tekrar Gir'), findsOneWidget);
    expect(find.text('Sınava Gir'), findsNWidgets(3));
    expect(find.text('sınav notun'), findsOneWidget);
  });

  testWidgets('elle not seçimi onLevel ile yukarı çıkar', (tester) async {
    final graded = <String, int>{};
    await _pumpStep(tester, onLevel: (id, level) => graded[id] = level);

    await tester.tap(find.text('3'));
    await tester.pump();

    expect(graded, {'future_exam': 3});
  });
}
