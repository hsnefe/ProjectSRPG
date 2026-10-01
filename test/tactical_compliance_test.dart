import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/net/match_sse_client.dart';
import 'package:project_srpg/state/match_controller.dart';

/// §12.10 — uyum oranının dakika dakika birikimi.
///
/// `squad_status_test.dart`'ın aynı kalıbı: tek konuyu kovalayan ayrı bir
/// dosya, `match_controller_test.dart`'ı büyütmemek için.
class _FakeStreamSource implements MatchStreamSource {
  final controller = StreamController<MatchStreamMessage>();

  @override
  Stream<MatchStreamMessage> connect(Uri uri, {String? lastEventId}) => controller.stream;
}

TickFrame _tick({
  required int seq,
  required int minute,
  String? focus,
  int stamina = 90,
  bool finished = false,
  List<TickEventDto> events = const [],
}) {
  return TickFrame(
    seq: seq,
    matchId: 'm_test',
    minute: minute,
    finished: finished,
    situation: 'balanced',
    score: const ScoreInfo(home: 0, away: 0),
    possession: const PossessionInfo(home: 50, away: 50),
    team: TeamTickInfo(
      userSide: 'home',
      stamina: stamina,
      mentality: 'balanced',
      yellowCards: 0,
      redCards: 0,
    ),
    directives: DirectivesInfo(effort: 50, aggression: 50, focus: focus),
    events: events,
    resolvedIntervention: null,
  );
}

TickEventDto _substitution({String side = 'home'}) => TickEventDto(
      eventId: 'e_${side}_sub',
      side: side,
      text: 'Oyuncu değişikliği',
      isGoal: false,
      eventType: 'substitution',
    );

MatchController _controller(
  _FakeStreamSource source, {
  String squadStatus = 'first_eleven',
  int startCondition = 100,
  String? coachInstruction,
}) {
  return MatchController(
    matchId: 'm_test',
    streamUrl: '/matches/m_test/stream',
    userSide: 'home',
    squadStatus: squadStatus,
    startCondition: startCondition,
    coachInstruction: coachInstruction,
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
    directiveOptions:
        const DirectiveOptions(effort: [], aggression: [], focus: []),
    streamSource: source,
  );
}

Future<void> _push(_FakeStreamSource source, TickFrame tick) async {
  source.controller.add(MatchTickMessage(tick));
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('MatchController.tacticalCompliance', () {
    test('sahaya hiç çıkmadıysa null döner', () async {
      final source = _FakeStreamSource();
      final controller = _controller(
        source,
        squadStatus: 'bench',
        coachInstruction: 'attack',
      )..connect();
      addTearDown(controller.dispose);

      // Yedekte kalır — hiç sahaya girmeden maç biter.
      await _push(source, _tick(seq: 1, minute: 45, focus: 'attack'));
      await _push(
          source, _tick(seq: 2, minute: 90, finished: true, focus: 'attack'));

      expect(controller.onPitch, isFalse);
      expect(controller.tacticalCompliance, isNull);
    });

    test('talimat null ("farketmez") iken hiçbir zaman ölçülmez', () async {
      final source = _FakeStreamSource();
      // coachInstruction verilmiyor -> null, ilk 11'de baştan sahada.
      final controller = _controller(source)..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 1, focus: 'attack'));
      await _push(source, _tick(seq: 2, minute: 45, focus: 'defend'));
      await _push(
          source, _tick(seq: 3, minute: 90, finished: true, focus: 'attack'));

      expect(controller.tacticalCompliance, isNull);
    });

    test('ilk tick yalnızca baz alır, hiçbir aralık biriktirmez', () async {
      final source = _FakeStreamSource();
      final controller =
          _controller(source, coachInstruction: 'attack')..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 40, focus: 'attack'));

      // Tek tick: henüz yargılanacak bir ÖNCEKI tick yok.
      expect(controller.tacticalCompliance, isNull);
    });

    test('focus maç ortasında değişirse her aralık yürürlükteki focus\'a yazılır',
        () async {
      final source = _FakeStreamSource();
      final controller =
          _controller(source, coachInstruction: 'attack')..connect();
      addTearDown(controller.dispose);

      // [0,60] önceki (baz) tick'in focus'una (attack) yazılır: uyumlu.
      await _push(source, _tick(seq: 1, minute: 0, focus: 'attack'));
      // Bu tick 60'a kadarki aralığı 'attack' ile kapatır, KENDİ focus'u
      // ('defend') bundan sonraki aralığa geçerli olur.
      await _push(source, _tick(seq: 2, minute: 60, focus: 'defend'));
      // [60,90] önceki tick'in bildirdiği focus'a ('defend') yazılır: uyumsuz.
      await _push(
          source, _tick(seq: 3, minute: 90, finished: true, focus: 'defend'));

      // 60 uyumlu + 30 uyumsuz / 90 toplam = 2/3.
      expect(controller.tacticalCompliance, closeTo(60 / 90, 1e-9));
    });

    test('60\'ta oyuna giren oyuncu yalnızca kendi 35 dakikasından sorumlu',
        () async {
      final source = _FakeStreamSource();
      final controller = _controller(
        source,
        squadStatus: 'bench',
        coachInstruction: 'attack',
      )..connect();
      addTearDown(controller.dispose);

      // İlk tick zaten sahaya giriş anı — baz alınır, aralık biriktirmez.
      await _push(source, _tick(
        seq: 1, minute: 60, focus: 'attack', events: [_substitution()],
      ));
      expect(controller.onPitch, isTrue);
      expect(controller.tacticalCompliance, isNull); // henüz baz

      await _push(
          source, _tick(seq: 2, minute: 95, finished: true, focus: 'attack'));

      // Yargılanan pencere tam olarak [60,95] = 35 dakika — minutesPlayed'in
      // penceresiyle aynı.
      expect(controller.minutesPlayed, 35);
      expect(controller.tacticalCompliance, 1.0);
    });

    test('70\'te oyundan çıkan oyuncu için çıkış tick\'i de yargılanır',
        () async {
      final source = _FakeStreamSource();
      // Kondisyon zemin altında başlar: ilk değişiklik oyuncuyu hemen alır.
      final controller = _controller(
        source,
        startCondition: 44,
        coachInstruction: 'attack',
      )..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 0, focus: 'attack'));
      await _push(source, _tick(
        seq: 2, minute: 70, focus: 'attack', events: [_substitution()],
      ));
      expect(controller.onPitch, isFalse);
      expect(controller.minutesPlayed, 70);

      // Sahadan çıktıktan sonraki dakikalar hiç yargılanmaz.
      await _push(
          source, _tick(seq: 3, minute: 90, finished: true, focus: 'defend'));

      expect(controller.tacticalCompliance, 1.0); // yalnızca [0,70], hep uyumlu
    });

    test('geriye dönen bir replay tick\'i sahte aralık yazmaz', () async {
      final source = _FakeStreamSource();
      final controller =
          _controller(source, coachInstruction: 'attack')..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 1, focus: 'attack'));
      await _push(source, _tick(seq: 2, minute: 60, focus: 'attack'));
      // E8 replay'i (§9.2) geçmiş bir tick'i yeniden yayınlıyor — imleç
      // ileri gitmemeli.
      await _push(source, _tick(seq: 3, minute: 5, focus: 'attack'));
      await _push(
          source, _tick(seq: 4, minute: 90, finished: true, focus: 'attack'));

      // Replay yok sayılmasaydı 90-5=85 gibi yanlış bir aralık eklenirdi;
      // gerçek toplam 1'den 90'a kadar (89 dakika), hepsi uyumlu.
      expect(controller.tacticalCompliance, 1.0);
    });
  });
}
