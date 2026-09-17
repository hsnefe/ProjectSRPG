/// Katalogu JSON'a döken tek seferlik taşıma aracı.
///
/// `scenario_creator/` editörü senaryoları JSON'dan okuyor; elle yazılmış
/// kırk iki şut durumu, dokuz müdahale durumu ve tek dribling kursu oraya bir
/// kez taşınmak zorunda. Dart kaynağını düzenli ifadeyle ayrıştırmak yerine
/// **katalogun kendisini** okuyoruz: `_scene()` zaten çalışmış oluyor, yani
/// bakış açısı ve nişan menzili gibi türetilen alanları da gerçek değerleriyle
/// bir temel dosyaya yazabiliyoruz.
///
/// Bir test olarak yazılmasının sebebi `shot_game.dart`'ın flame/dart:ui'ye
/// bağlı olması — düz `dart run` ile açılmıyor. `test/` altında olmadığı için
/// normal `flutter test` koşusunda da çalışmaz; açıkça çağrılması gerekir:
///
/// ```
/// ./flutter/bin/flutter test tool/dump_scenarios_test.dart
/// ```
///
/// Çıktı `../scenario_creator/` altına yazılır.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/game/dribble_courses.dart';
import 'package:project_srpg/game/match_scenarios.dart';
import 'package:project_srpg/game/pitch_projector.dart';
import 'package:project_srpg/game/shot_game.dart';
import 'package:project_srpg/game/shot_scenarios.dart';
import 'package:project_srpg/game/tackle_scenarios.dart';

/// Editörün bildiği hazır hedefler. Karşılaştırma tam eşitlik arıyor, yani
/// hangisinin daha dar olduğunun bir önemi yok.
const _presets = <String, ShotObjective>{
  'none': ShotObjective.none,
  'goalOnly': ShotObjective.goalOnly,
  'passOnly': ShotObjective.passOnly,
  'finish': ShotObjective.finish,
  'finishOrLayoff': ShotObjective.finishOrLayoff,
  'pass': ShotObjective.pass,
  'assistOrFinish': ShotObjective.assistOrFinish,
};

/// Bir hedefin hazır adı, yoksa alanlarının kendisi.
Object _objectiveJson(ShotObjective objective) {
  for (final entry in _presets.entries) {
    final p = entry.value;
    if (p.great.length == objective.great.length &&
        p.great.containsAll(objective.great) &&
        p.good.length == objective.good.length &&
        p.good.containsAll(objective.good) &&
        p.keyPassIsGreat == objective.keyPassIsGreat) {
      return entry.key;
    }
  }
  return <String, Object>{
    'great': objective.great.toList()..sort(),
    'good': objective.good.toList()..sort(),
    'key_pass_is_great': objective.keyPassIsGreat,
  };
}

double _round(double v) => double.parse(v.toStringAsFixed(4));

Map<String, Object?> _bodyJson(ShotTarget t, {required bool receiver}) => {
      'label': t.label,
      'x': _round(t.x),
      'y': _round(t.y),
      if (receiver) 'key': t.isKey,
    };

String _nowIso() {
  final now = DateTime.now();
  final offset = now.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hh = abs.inHours.toString().padLeft(2, '0');
  final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return '${now.toIso8601String().split('.').first}$sign$hh:$mm';
}

void _write(Directory dir, String name, Object doc) {
  dir.createSync(recursive: true);
  File('${dir.path}/$name.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(doc)}\n',
  );
}

void main() {
  final root = Directory('${Directory.current.parent.path}/scenario_creator');
  final stamp = _nowIso();

  test('şut katalogu JSON olarak yazılır', () {
    // action_key senaryonun kendisine taşınıyor: bugün ayrı bir liste
    // (`match_scenarios.dart`) tutuyor, taşımadan sonra tek kaynak senaryo.
    final actionOf = <String, String>{
      for (final entry in MatchScenarios.byActionKey.entries)
        for (final id in entry.value) id: entry.key,
    };

    final dir = Directory('${root.path}/shot');
    var written = 0;
    for (final kind in ShotScenarioKind.values) {
      final family = ShotScenarios.of(kind);
      for (var i = 0; i < family.length; i++) {
        final s = family[i];
        final scene = s.scene;
        _write(dir, s.id, {
          'schema': 1,
          'id': s.id,
          'kind': kind.name,
          'order': i,
          'title': s.title,
          'brief': s.brief,
          'aim_hint': s.aimHint,
          'objective': _objectiveJson(s.objective),
          'action_key': actionOf[s.id],
          'origin': {'x': _round(scene.origin.x), 'y': _round(scene.origin.y)},
          'receivers': [
            for (final r in scene.receivers) _bodyJson(r, receiver: true),
          ],
          'rivals': [
            for (final r in scene.rivals) _bodyJson(r, receiver: false),
          ],
          'scores_goals': scene.scoresGoals,
          'has_keeper': scene.hasKeeper,
          'back_y': _round(scene.backY),
          'created_at': stamp,
          'updated_at': stamp,
        });
        written++;
      }
    }
    expect(written, ShotScenarios.all.length);
  });

  test('müdahale katalogu JSON olarak yazılır', () {
    final dir = Directory('${root.path}/tackle');
    for (final kind in TackleScenarioKind.values) {
      final family = TackleScenarios.of(kind);
      for (var i = 0; i < family.length; i++) {
        final s = family[i];
        _write(dir, s.id, {
          'schema': 1,
          'id': s.id,
          'kind': kind.name,
          'order': i,
          'title': s.title,
          'brief': s.brief,
          'close_scale': s.closeScale,
          'window_scale': s.windowScale,
          'created_at': stamp,
          'updated_at': stamp,
        });
      }
    }
  });

  test('dribling kursları JSON olarak yazılır', () {
    final dir = Directory('${root.path}/dribble');
    for (final course in DribbleCourses.all) {
      _write(dir, course.id, {
        'schema': 1,
        'id': course.id,
        'name': course.name,
        'brief': course.brief,
        'course_length': course.courseLength,
        'time_limit': course.timeLimit,
        'cones': [
          for (final c in course.cones)
            {'distance': _round(c.distance), 'x': _round(c.x)},
        ],
        'created_at': stamp,
        'updated_at': stamp,
      });
    }
  });

  test('türetilen değerler temel dosyaya yazılır', () {
    // Taşımanın hiçbir senaryoyu değiştirmediğinin kanıtı: üretilen Dart
    // yerine konduktan sonra bu test yeniden koşturulur ve dosya
    // değişmemelidir. `_scene()` çıktısının tamamı burada.
    final doc = <String, Object>{};
    for (final s in ShotScenarios.all) {
      final scene = s.scene;
      doc[s.id] = {
        'kind': s.kind.name,
        'origin': [_round(scene.origin.x), _round(scene.origin.y)],
        'start_angle': _round(scene.startAngle),
        'look_at': [_round(scene.lookAt!.x), _round(scene.lookAt!.y)],
        'default_aim_depth': _round(scene.defaultAimDepth),
        'default_aim_lateral': _round(scene.defaultAimLateral),
        'max_aim_depth': _round(scene.maxAimDepth),
        'back_y': _round(scene.backY),
        'scores_goals': scene.scoresGoals,
        'has_keeper': scene.hasKeeper,
        'tiers': s.objective.tiers,
        'receivers': [
          for (final r in scene.receivers)
            '${r.label}@${_round(r.x)},${_round(r.y)}${r.isKey ? '*' : ''}',
        ],
        'rivals': [
          for (final r in scene.rivals)
            '${r.label}@${_round(r.x)},${_round(r.y)}',
        ],
      };
    }
    Directory(root.path).createSync(recursive: true);
    File('${root.path}/baseline.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(doc)}\n',
    );
    expect(doc.length, ShotScenarios.all.length);
    // Temel dosya sahanın kendi sabitlerine dayanıyor; biri değişirse burada
    // fark edilsin.
    expect(PitchLines.goalLineY, 1.0);
  });
}
