import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/widgets/intervention_offer_modal.dart';

/// `flutter_test`'in `FakeAsync` tabanlı `pump(duration)`'ı `Timer`'ı
/// sanallaştırır ama `DateTime.now()`'ı etkilemez (bilinen bir kısıt) — bu
/// yüzden 20 sn'lik zaman aşımını gerçek zaman beklemeden test edebilmek için
/// `InterventionOfferModal.debugNow` kancası kullanılır. Diğer testler bu
/// kancaya ihtiyaç duymaz: buton tıklamaları anında `Navigator.pop` tetikler.
InterventionOfferFrame _offer({String? riskHint, int timeoutSeconds = 20}) {
  return InterventionOfferFrame(
    seq: 1,
    matchId: 'm_test',
    offerId: 'off_1',
    minute: 63,
    resolution: 'engine',
    actionKey: 'counter_attack',
    prompt: 'Rakip savunması dağınık, hızlı çıkış fırsatı var',
    riskHint: riskHint,
    timeoutSeconds: timeoutSeconds,
    onTimeout: 'decline',
  );
}

Future<Future<InterventionChoice?>> _open(
  WidgetTester tester, {
  InterventionOfferFrame? offer,
  DateTime Function()? debugNow,
}) async {
  late Future<InterventionChoice?> result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () {
          result = showInterventionOffer(
            context,
            offer: offer ?? _offer(),
            debugNow: debugNow,
          );
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump();
  return result;
}

void main() {
  testWidgets('shows the minute, prompt, risk hint and both buttons', (tester) async {
    await _open(tester, offer: _offer(riskHint: 'Kötü zamanlama doğrudan kırmızı kart getirir.'));

    expect(find.textContaining('63\''), findsOneWidget);
    expect(find.textContaining('Rakip savunması dağınık'), findsOneWidget);
    expect(
      find.textContaining('Kötü zamanlama doğrudan kırmızı kart getirir.'),
      findsOneWidget,
    );
    expect(find.text('Müdahale et'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);

    // Zamanlayıcıyı temiz bitiriyoruz - kapanmadan test sonlanırsa "A Timer
    // is still pending" hatası alınır.
    await tester.tap(find.text('Vazgeç'));
    await tester.pump();
  });

  testWidgets('Müdahale et resolves the future with InterventionChoice.intervene',
      (tester) async {
    final result = await _open(tester);

    await tester.tap(find.text('Müdahale et'));
    await tester.pump();

    expect(await result, InterventionChoice.intervene);
  });

  testWidgets('Vazgeç resolves the future with InterventionChoice.decline',
      (tester) async {
    final result = await _open(tester);

    await tester.tap(find.text('Vazgeç'));
    await tester.pump();

    expect(await result, InterventionChoice.decline);
  });

  testWidgets('a double tap on Müdahale et produces only one resolution',
      (tester) async {
    final result = await _open(tester);

    await tester.tap(find.text('Müdahale et'));
    // İkinci vuruş no-op olmalı; ilk vuruş kapanışı zaten başlattığı için
    // buton artık hit-test edilemeyebilir - bu beklenen, uyarı bastırılır.
    await tester.tap(find.text('Müdahale et'), warnIfMissed: false);
    await tester.pump();

    expect(await result, InterventionChoice.intervene);
  });

  testWidgets('countdown expiry resolves the future with InterventionChoice.timeout',
      (tester) async {
    var fakeNow = DateTime(2030, 1, 1);
    final result = await _open(
      tester,
      offer: _offer(timeoutSeconds: 20),
      debugNow: () => fakeNow,
    );
    expect(find.text('Müdahale et'), findsOneWidget);

    // Son tarihi geride bırak, sonra ticker'ın bir kez daha atması için
    // yalnızca bir periyot (200 ms) kadar sanal zaman ilerlet - gerçek 20 sn
    // beklemeye gerek yok.
    fakeNow = fakeNow.add(const Duration(seconds: 25));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.text('Müdahale et'), findsNothing);
    expect(await result, InterventionChoice.timeout);
  });

  testWidgets('the countdown chip counts down as fake time advances',
      (tester) async {
    var fakeNow = DateTime(2030, 1, 1);
    await _open(tester, offer: _offer(timeoutSeconds: 20), debugNow: () => fakeNow);

    expect(find.text('20sn'), findsOneWidget);

    fakeNow = fakeNow.add(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('15sn'), findsOneWidget);

    // Zamanlayıcıyı temiz bitir.
    fakeNow = fakeNow.add(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
  });
}
