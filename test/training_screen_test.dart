import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_srpg/game/shot_game.dart' show ShotMode;
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/ball_training_screen.dart';
import 'package:project_srpg/screens/conditioning_training_screen.dart';
import 'package:project_srpg/screens/strength_training_screen.dart';
import 'package:project_srpg/screens/training_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

/// N3 `training` kataloğu — career_engine/catalog/training.py'nin 11
/// kaleminin aynısı (6 saha + 5 kişi).
const _trainingItems = [
  {
    'catalog_id': 'kondisyon-kosusu', 'title': 'Kondisyon Koşusu',
    'description': '…', 'family': 'saha', 'drill': 'conditioning',
    'costs': {'time': 90, 'energy': 15},
    'effects': {'attribute:condition': 1.2},
  },
  {
    'catalog_id': 'guc-antrenmani', 'title': 'Güç Antrenmanı',
    'description': '…', 'family': 'saha', 'drill': 'strength',
    'costs': {'time': 75, 'energy': 20},
    'effects': {'attribute:strength': 1.2},
  },
  {
    'catalog_id': 'esneklik-toparlanma', 'title': 'Esneklik & Toparlanma',
    'description': '…', 'family': 'saha', 'drill': null,
    'costs': {'time': 45, 'energy': 8},
    'effects': {'attribute:flexibility': 1.0, 'condition': 4},
  },
  {
    'catalog_id': 'sut', 'title': 'Şut',
    'description': '…', 'family': 'saha', 'drill': 'shot',
    'costs': {'time': 60, 'energy': 18},
    'effects': {'attribute:shooting': 1.2},
  },
  {
    'catalog_id': 'pas', 'title': 'Pas',
    'description': '…', 'family': 'saha', 'drill': 'pass',
    'costs': {'time': 60, 'energy': 12},
    'effects': {'attribute:passing': 1.2},
  },
  {
    'catalog_id': 'dribling', 'title': 'Dribling',
    'description': '…', 'family': 'saha', 'drill': null,
    'costs': {'time': 60, 'energy': 18},
    'effects': {'attribute:dribbling': 1.0},
  },
  {
    'catalog_id': 'medya-egitimi', 'title': 'Medya Eğitimi',
    'description': '…', 'family': 'kişi', 'drill': null,
    'costs': {'time': 60, 'energy': 5},
    'effects': {'attribute:charisma': 0.8, 'money': -1500},
  },
  {
    'catalog_id': 'gorgu-dersleri', 'title': 'Görgü Dersleri',
    'description': '…', 'family': 'kişi', 'drill': null,
    'costs': {'time': 45, 'energy': 5},
    'effects': {'attribute:politeness': 0.8, 'money': -800},
  },
  {
    'catalog_id': 'ozguven-koclugu', 'title': 'Özgüven Koçluğu',
    'description': '…', 'family': 'kişi', 'drill': null,
    'costs': {'time': 60, 'energy': 8},
    'effects': {'attribute:confidence': 0.8, 'money': -1200},
  },
  {
    'catalog_id': 'satranc-kulubu', 'title': 'Satranç Kulübü',
    'description': '…', 'family': 'kişi', 'drill': null,
    'costs': {'time': 90, 'energy': 5},
    'effects': {'attribute:intelligence': 0.8, 'money': -500},
  },
  {
    'catalog_id': 'kriz-simulasyonu', 'title': 'Kriz Simülasyonu',
    'description': '…', 'family': 'kişi', 'drill': null,
    'costs': {'time': 60, 'energy': 10},
    'effects': {'attribute:resourcefulness': 0.8, 'money': -1000},
  },
];

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

CareerSession _trainingSession() {
  final mock = MockClient((request) async {
    if (request.url.path == '/catalog/training') {
      return _json({'items': _trainingItems});
    }
    return http.Response('unexpected ${request.url}', 404);
  });
  return CareerSession(client: CareerApiClient(httpClient: mock, baseUrl: 'http://test'));
}

Widget _wrap(Widget home) => PlayerScope(
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: home,
      ),
    );

/// Kart widget'ı ekrana özel ve private, o yüzden tip adından bulunuyor.
final _card = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_TrainingCard',
);

/// Antrenman kartındaki butonu başlığından bulur.
Finder _startButton(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: _card),
      matching: find.byType(OutlinedButton),
    );

OutlinedButton _button(WidgetTester tester, String title) =>
    tester.widget<OutlinedButton>(_startButton(title));

/// Antrenman kartının butonunu tıklanabilir hale getirir. Listenin sonundaki
/// kartlar ekrana yarım sığdığı için başlığı görmek yetmiyor — butonun
/// kendisini görünür alana çekmek gerekiyor.
Future<void> _scrollTo(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(_startButton(title));
  await tester.pump();
}

void main() {
  group('mini-oyunu olmayan kartlar', () {
    testWidgets('Esneklik ve Dribling Yakında yazar ve pasiftir',
        (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();

      for (final title in ['Esneklik & Toparlanma', 'Dribling']) {
        await _scrollTo(tester, title);
        expect(_button(tester, title).onPressed, isNull, reason: title);
      }

      expect(find.text('Yakında'), findsNWidgets(2));
    });

    testWidgets('diğer dördü Başla yazar ve tıklanabilir', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();

      for (final title in ['Kondisyon Koşusu', 'Güç Antrenmanı', 'Şut', 'Pas']) {
        await _scrollTo(tester, title);
        expect(_button(tester, title).onPressed, isNotNull, reason: title);
      }
    });
  });

  testWidgets('Kişisel sekmesi kişi ailesindeki beş kalemi listeler',
      (tester) async {
    await tester.pumpWidget(
      _wrap(TrainingScreen(session: _trainingSession())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kişisel'));
    await tester.pumpAndSettle();

    expect(find.text('Medya Eğitimi'), findsOneWidget);
    expect(find.text('Görgü Dersleri'), findsOneWidget);
    // Kondisyon Koşusu 'saha' ailesinde — kişisel sekmede görünmemeli.
    expect(find.text('Kondisyon Koşusu'), findsNothing);
  });

  group('mini-oyunları açmak', () {
    testWidgets('Kondisyon koşu ekranını açar', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'Kondisyon Koşusu');

      await tester.tap(_startButton('Kondisyon Koşusu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConditioningTrainingScreen), findsOneWidget);

      // Canlı bir GameWidget kaldığı için test bitmeden söküyoruz.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Güç bench press ekranını açar', (tester) async {
      await tester.pumpWidget(
        _wrap(TrainingScreen(session: _trainingSession())),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'Güç Antrenmanı');

      await tester.tap(_startButton('Güç Antrenmanı'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StrengthTrainingScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Şut ve Pas aynı ekranı farklı modla açar', (tester) async {
      for (final (title, mode) in [
        ('Şut', ShotMode.shot),
        ('Pas', ShotMode.pass),
      ]) {
        await tester.pumpWidget(
          _wrap(TrainingScreen(session: _trainingSession())),
        );
        await tester.pumpAndSettle();
        await _scrollTo(tester, title);

        await tester.tap(_startButton(title));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final screen = tester.widget<BallTrainingScreen>(
          find.byType(BallTrainingScreen),
        );
        expect(screen.mode, mode, reason: title);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
