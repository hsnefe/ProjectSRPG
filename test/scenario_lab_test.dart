import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/scenario_progress.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';
import 'package:project_srpg/screens/scenario_lab_screen.dart';
import 'package:project_srpg/screens/scenario_play_screen.dart';

/// Senaryo sahasının ekran testleri.
///
/// Katalog testleri kırk iki durumun *oynanabilir* olduğunu kanıtlıyor; bu
/// dosya onları tek tek seçip oynayabildiğini kanıtlıyor: liste doluyor mu,
/// filtre çalışıyor mu, bir durum açılıyor mu, ve oynanan bir durumun sonucu
/// listeye geri yansıyor mu.
Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  group('senaryo listesi', () {
    testWidgets('katalogun tamamı listeleniyor', (tester) async {
      await tester.pumpWidget(_app(ScenarioLabScreen(
        progress: ScenarioProgress(),
      )));

      expect(find.text('Senaryo Sahası'), findsOneWidget);
      // Sayaç kataloğun boyunu gösterir, hiçbiri oynanmamışken sıfırdan.
      expect(find.text('0/${ShotScenarios.all.length}'), findsOneWidget);
      // İlk aile ve ilk durum ekranda.
      expect(find.text('ŞUT'), findsOneWidget);
      expect(find.text('Penaltı'), findsOneWidget);
    });

    testWidgets('filtre yalnızca o aileyi bırakır', (tester) async {
      await tester.pumpWidget(_app(ScenarioLabScreen(
        progress: ScenarioProgress(),
      )));

      await tester.tap(find.text('Geriden kurulum · 9'));
      await tester.pumpAndSettle();

      expect(find.text('Kaleden kısa çıkış'), findsOneWidget);
      expect(find.text('Penaltı'), findsNothing);
      // Tek aile seçiliyken başlık tekrarlanmıyor.
      expect(find.text('GERİDEN KURULUM'), findsNothing);
    });

    testWidgets('her ailenin çipi kendi sayısını yazar', (tester) async {
      await tester.pumpWidget(_app(ScenarioLabScreen(
        progress: ScenarioProgress(),
      )));

      // Çip şeridi ekrandan taşıyor, o yüzden son aileler kaydırmadan
      // görünmüyor — kaydırılabilir olması da testin bir parçası.
      final chips = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      );
      for (final label in [
        'Tümü · ${ShotScenarios.all.length}',
        for (final kind in ShotScenarioKind.values)
          '${kind.label} · ${ShotScenarios.of(kind).length}',
      ]) {
        await tester.dragUntilVisible(
          find.text(label),
          chips,
          const Offset(-80, 0),
        );
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('bir duruma dokununca o durum açılır', (tester) async {
      await tester.pumpWidget(_app(ScenarioLabScreen(
        progress: ScenarioProgress(),
      )));

      await tester.tap(find.text('Penaltı'));
      // `pumpAndSettle` değil: açılan ekranda Flame'in oyun döngüsü sürekli
      // kare istiyor, sahne hiç durulmuyor.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ScenarioPlayScreen), findsOneWidget);
      // Aramalar açılan ekranın içiyle sınırlı: geçiş sırasında liste hâlâ
      // ağaçta duruyor ve aynı tarifi o da yazıyor.
      Finder inPlayScreen(Finder matching) => find.descendant(
            of: find.byType(ScenarioPlayScreen),
            matching: matching,
          );
      // Brifing çubuğunda ailesi ve durumun tarifi.
      expect(inPlayScreen(find.text('Şut')), findsOneWidget);
      expect(inPlayScreen(find.textContaining('Köşeyi seç')), findsOneWidget);
      // Ve durumun kendi hedef tablosu.
      expect(inPlayScreen(find.text('Topu kaybet')), findsOneWidget);
    });

    testWidgets('oynanmış bir durum kaydını listede gösterir', (tester) async {
      final progress = ScenarioProgress()
        ..record('shot_penalty', ShotGrade.good);

      await tester.pumpWidget(_app(ScenarioLabScreen(progress: progress)));

      expect(find.text('1/${ShotScenarios.all.length}'), findsOneWidget);
      expect(find.text('1 deneme'), findsOneWidget);
      expect(find.text(ShotGrade.good.label), findsWidgets);
    });
  });

  group('tek durum ekranı', () {
    testWidgets('hedef tablosu durumun kendi adamlarını yazar',
        (tester) async {
      // Üç kademeli bir kurulum durumu: tavanı hattı kıran adam, orta kademesi
      // güvenli olan. İkisinin de adı ekranda yazmalı — oyuncunun neyi
      // aradığını bilmesinin tek yolu bu.
      final scenario = ShotScenarios.byId('build_keeper_short')!;
      await tester.pumpWidget(_app(ScenarioPlayScreen(
        scenario: scenario,
        progress: ScenarioProgress(),
      )));

      expect(find.text('Ön libero ile buluş'), findsOneWidget);
      expect(find.text('Yan stoper'), findsOneWidget);
      expect(find.text('Topu kaybet'), findsOneWidget);
      expect(find.text('ilk deneme'), findsOneWidget);
    });

    testWidgets('iki kademeli durum iki satır gösterir', (tester) async {
      final scenario = ShotScenarios.byId('shot_penalty')!;
      final rows = ScenarioObjectiveLegend.rowsFor(scenario);

      expect(rows.length, 2);
      expect(rows.map((r) => r.grade), [ShotGrade.good, ShotGrade.fail]);
      expect(rows.first.what, 'Gol at');
    });

    testWidgets('şut durumunun tavanı gol, orta kademesi isabet',
        (tester) async {
      final rows =
          ScenarioObjectiveLegend.rowsFor(ShotScenarios.byId('shot_edge_d')!);

      expect(rows.length, 3);
      expect(rows[0], (grade: ShotGrade.great, what: 'Gol at'));
      expect(rows[1], (grade: ShotGrade.good, what: 'Kaleyi bul'));
    });

    testWidgets('katalogdaki her durumun tablosu kademe sayısıyla uyuşur',
        (tester) async {
      // Tablo koddan türetiliyor; bir hedef ya da anahtar adam değişirse
      // panelin sessizce yanlışa düşmemesi gerekiyor.
      for (final scenario in ShotScenarios.all) {
        final rows = ScenarioObjectiveLegend.rowsFor(scenario);
        expect(
          rows.length,
          scenario.objective.tiers,
          reason: '${scenario.id}: ${rows.map((r) => r.what).toList()}',
        );
        expect(rows.last.grade, ShotGrade.fail, reason: scenario.id);
        for (final row in rows) {
          expect(row.what, isNotEmpty, reason: scenario.id);
        }
      }
    });
  });

  group('ilerleme kaydı', () {
    test('en iyisi tutulur, daha kötüsü onu düşürmez', () {
      final progress = ScenarioProgress()
        ..record('a', ShotGrade.good)
        ..record('a', ShotGrade.fail);

      expect(progress.bestOf('a'), ShotGrade.good);
      expect(progress.attemptsOf('a'), 2);
      expect(progress.clearedOf('a'), 1);

      progress.record('a', ShotGrade.great);
      expect(progress.bestOf('a'), ShotGrade.great);
    });

    test('sayaçlar geçilen ve tavan yapılan durumları ayırır', () {
      final progress = ScenarioProgress()
        ..record('a', ShotGrade.great)
        ..record('b', ShotGrade.good)
        ..record('c', ShotGrade.fail);

      expect(progress.played, 3);
      expect(progress.cleared, 2);
      expect(progress.mastered, 1);
      expect(progress.bestOf('yok'), isNull);
      expect(progress.wasPlayed('c'), isTrue);
    });

    test('sıfırlama tek durumu ve tamamını temizler', () {
      final progress = ScenarioProgress()
        ..record('a', ShotGrade.great)
        ..record('b', ShotGrade.good);

      progress.reset('a');
      expect(progress.bestOf('a'), isNull);
      expect(progress.bestOf('b'), ShotGrade.good);

      progress.resetAll();
      expect(progress.played, 0);
    });

    test('kayıt dinleyicileri uyarır', () {
      var calls = 0;
      final progress = ScenarioProgress()..addListener(() => calls++);

      progress.record('a', ShotGrade.good);
      expect(calls, 1);
      progress.reset('a');
      expect(calls, 2);
    });
  });
}
