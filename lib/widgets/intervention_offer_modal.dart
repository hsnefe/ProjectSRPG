import 'dart:async';

import 'package:flutter/material.dart';

import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/game_chrome.dart';

/// Kullanıcının bir müdahale teklifine verdiği yanıt — `null` yalnızca
/// programatik bir kapanışta döner (ör. akış hatası ekranı kapatıyor).
enum InterventionChoice { intervene, decline, timeout }

/// Motorun `intervention_offer` yayınladığı anda ekranın ortasında açılan,
/// dışarı tıklanarak kapatılamayan karar paneli (§7.2).
///
/// §0 v1.7'den beri yalnızca `resolution:"engine"` teklifleri buradan geçer
/// — `match_screen.dart::_openOffer` `minigame` tekliflerini panele hiç
/// uğratmadan doğrudan ilgili mini oyuna yönlendiriyor. `outcome_keys`/
/// `minigame` alanları hâlâ ayrıştırılıyor ama panel onları göstermiyor:
/// §7.2 [İ-A2] paneli iki butonla sınırlıyor ("Müdahale et" / "Vazgeç"),
/// aşama 2 yok.
Future<InterventionChoice?> showInterventionOffer(
  BuildContext context, {
  required InterventionOfferFrame offer,
  @visibleForTesting DateTime Function()? debugNow,
}) {
  return showGeneralDialog<InterventionChoice>(
    context: context,
    barrierDismissible: false, // karar zorunlu - motor bu tick'i bekliyor
    barrierLabel: 'Müdahale teklifi',
    barrierColor: Colors.black.withValues(alpha: 0.66),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => InterventionOfferModal(offer: offer, debugNow: debugNow),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class InterventionOfferModal extends StatefulWidget {
  const InterventionOfferModal({super.key, required this.offer, this.debugNow});

  final InterventionOfferFrame offer;

  /// Test-only saat kancası. Üretimde daima `null` kalır ve gerçek
  /// `DateTime.now` kullanılır — `flutter_test`'in `FakeAsync` tabanlı
  /// `pump(duration)`'ı `Timer`'ı sanallaştırır ama `DateTime.now()`'ı
  /// etkilemez, bu yüzden 20 sn'lik zaman aşımını gerçek zaman beklemeden
  /// test edebilmek için bu kanca var (bkz. `test/intervention_offer_modal_test.dart`).
  @visibleForTesting
  final DateTime Function()? debugNow;

  @override
  State<InterventionOfferModal> createState() => _InterventionOfferModalState();
}

class _InterventionOfferModalState extends State<InterventionOfferModal> {
  late final DateTime _deadline;
  Timer? _ticker;
  late Duration _remaining;
  bool _closing = false;

  DateTime Function() get _now => widget.debugNow ?? DateTime.now;

  @override
  void initState() {
    super.initState();
    _remaining = Duration(seconds: widget.offer.timeoutSeconds);
    _deadline = _now().add(_remaining);
    // Duvar saatine bakan bir ticker: uygulama arka plana atılıp geri
    // geldiğinde sayaç "donmuş" değil, gerçekten geçmiş süreyi görür ve
    // gerekiyorsa anında timeout'a düşer — bu bilinçli bir seçim, ticker'ı
    // azalan bir sayaca "düzeltmek" arka plan senaryosunu bozar (bkz.
    // match_screen.dart'ın arka plan notu). 200 ms birikimli sapma bırakmaz.
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final left = _deadline.difference(_now());
      if (left <= Duration.zero) {
        _close(InterventionChoice.timeout);
        return;
      }
      setState(() => _remaining = left);
    });
  }

  void _close(InterventionChoice choice) {
    if (_closing) return; // çift dokunuş / timeout yarışı koruması
    _closing = true;
    _ticker?.cancel();
    Navigator.of(context).pop(choice);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final secondsLeft = _remaining.inMilliseconds / 1000;
    final secondsShown = _remaining.inSeconds + (_remaining.inMilliseconds % 1000 > 0 ? 1 : 0);
    final urgent = secondsLeft <= 5;
    final warn = secondsLeft <= 10;
    final ringColor = urgent
        ? AppColors.danger
        : warn
            ? AppColors.warning
            : AppColors.accent;

    return PopScope(
      // barrierDismissible:false dışarı tıklamayı durdurur ama Android geri
      // tuşunu durdurmaz - bu olmadan geri tuşu paneli `null` ile kapatır ve
      // hiçbir POST atılmadan motor 180 sn boyunca beklemede kalır.
      canPop: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${offer.minute}'",
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'MÜDAHALE TEKLİFİ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ringColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${secondsShown}sn',
                            style: TextStyle(
                              color: ringColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: secondsLeft / offer.timeoutSeconds,
                        minHeight: 3,
                        backgroundColor: AppColors.surface1,
                        valueColor: AlwaysStoppedAnimation(ringColor),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      offer.prompt,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (offer.riskHint case final hint?) ...[
                      const SizedBox(height: 10),
                      GameRiskBar(text: hint),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _closing ? null : () => _close(InterventionChoice.decline),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Vazgeç'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _closing ? null : () => _close(InterventionChoice.intervene),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Müdahale et'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
