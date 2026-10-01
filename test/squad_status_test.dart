import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/net/match_sse_client.dart';
import 'package:project_srpg/state/match_controller.dart';

/// §12.2 — ilk 11 / yedek ve maç içinde oyuna girip çıkma.
///
/// `match_controller_test.dart`'ın yardımcılarıyla aynı kalıp; oraya
/// eklenmedi çünkü bu dosya tek bir konuyu kovalıyor ve o dosya zaten 661
/// satır.
class _FakeStreamSource implements MatchStreamSource {
  final controller = StreamController<MatchStreamMessage>();

  @override
  Stream<MatchStreamMessage> connect(Uri uri, {String? lastEventId}) => controller.stream;
}

TickFrame _tick({
  required int seq,
  required int minute,
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
    directives: const DirectivesInfo(effort: 50, aggression: 50, focus: null),
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

InterventionOfferFrame _offer({String offerId = 'off_1', int minute = 10}) =>
    InterventionOfferFrame(
      seq: 1,
      matchId: 'm_test',
      offerId: offerId,
      minute: minute,
      resolution: 'engine',
      actionKey: 'counter_attack',
      prompt: 'Karşı atak',
      riskHint: null,
      timeoutSeconds: 20,
      onTimeout: 'decline',
    );

MatchController _controller(
  _FakeStreamSource source, {
  String squadStatus = 'first_eleven',
  int startCondition = 100,
}) {
  return MatchController(
    matchId: 'm_test',
    streamUrl: '/matches/m_test/stream',
    userSide: 'home',
    squadStatus: squadStatus,
    startCondition: startCondition,
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

Future<void> _pushOffer(
    _FakeStreamSource source, InterventionOfferFrame offer) async {
  source.controller.add(MatchInterventionMessage(offer));
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('ilk 11', () {
    test('sahada başlar ve tam maç oynar', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source)..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 45));
      expect(controller.onPitch, isTrue);
      expect(controller.started, isTrue);

      await _push(source, _tick(seq: 2, minute: 90, finished: true));
      expect(controller.minutesPlayed, 90);
    });

    test('formda oynarken yapılan değişiklik oyuncuyu almaz', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source)..connect();
      addTearDown(controller.dispose);

      // Kondisyon yüksek: değişiklik başkası için.
      await _push(source, _tick(seq: 1, minute: 60, events: [_substitution()]));

      expect(controller.onPitch, isTrue);
      expect(controller.minutesPlayed, 60);
    });

    test('yorulmuşken yapılan değişiklik oyuncuyu alır', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, startCondition: 46)..connect();
      addTearDown(controller.dispose);

      // Stamina düşüşü kondisyonu eritir; iki tick sonra eşiğin altına iner.
      await _push(source, _tick(seq: 1, minute: 50, stamina: 90));
      await _push(source, _tick(seq: 2, minute: 62, stamina: 70));
      expect(controller.playerCondition, lessThan(45));

      await _push(
        source,
        _tick(seq: 3, minute: 70, stamina: 68, events: [_substitution()]),
      );

      expect(controller.onPitch, isFalse);
      expect(controller.minutesPlayed, 70);
      expect(
        controller.events.any((e) => e.text.contains('Oyundan çıkıyorsun')),
        isTrue,
      );
    });

    test('çıktıktan sonra dakika artmaz', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, startCondition: 46)..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 50, stamina: 90));
      await _push(source, _tick(seq: 2, minute: 62, stamina: 70));
      await _push(
        source,
        _tick(seq: 3, minute: 70, stamina: 68, events: [_substitution()]),
      );
      await _push(source, _tick(seq: 4, minute: 90, finished: true));

      expect(controller.minutesPlayed, 70);
    });

    test('rakibin değişikliği oyuncuyu ilgilendirmez', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, startCondition: 46)..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 50, stamina: 90));
      await _push(source, _tick(seq: 2, minute: 62, stamina: 70));
      await _push(
        source,
        _tick(
          seq: 3,
          minute: 70,
          stamina: 68,
          events: [_substitution(side: 'away')],
        ),
      );

      expect(controller.onPitch, isTrue);
    });
  });

  group('yedek', () {
    test('sahada başlamaz ve başlangıçta 0 dakikası vardır', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, squadStatus: 'bench')..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 30));

      expect(controller.onPitch, isFalse);
      expect(controller.started, isFalse);
      expect(controller.minutesPlayed, 0);
    });

    test('kendi tarafının değişikliğiyle oyuna girer', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, squadStatus: 'bench')..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 58, events: [_substitution()]));
      expect(controller.onPitch, isTrue);
      expect(
        controller.events.any((e) => e.text.contains('Oyuna giriyorsun')),
        isTrue,
      );

      await _push(source, _tick(seq: 2, minute: 90, finished: true));
      expect(controller.minutesPlayed, 32);
      // Girdiği maçta bile "ilk 11'de başladı" değildir.
      expect(controller.started, isFalse);
    });

    test('hiç girmezse dakikası 0 kalır', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, squadStatus: 'bench')..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 90, finished: true));
      expect(controller.minutesPlayed, 0);
    });
  });

  group('müdahale teklifleri', () {
    test('kulübedeyken teklif gösterilmez', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, squadStatus: 'bench')..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 20));
      await _pushOffer(source, _offer(minute: 21));

      expect(controller.activeOffer, isNull);
    });

    test('oyuna girdikten sonra teklif gösterilir', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, squadStatus: 'bench')..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 58, events: [_substitution()]));
      await _pushOffer(source, _offer(minute: 60));

      expect(controller.activeOffer, isNotNull);
    });

    test('oyundan çıktıktan sonra teklif gösterilmez', () async {
      final source = _FakeStreamSource();
      final controller = _controller(source, startCondition: 46)..connect();
      addTearDown(controller.dispose);

      await _push(source, _tick(seq: 1, minute: 50, stamina: 90));
      await _push(source, _tick(seq: 2, minute: 62, stamina: 70));
      await _push(
        source,
        _tick(seq: 3, minute: 70, stamina: 68, events: [_substitution()]),
      );
      await _pushOffer(source, _offer(minute: 75));

      expect(controller.activeOffer, isNull);
    });
  });
}
