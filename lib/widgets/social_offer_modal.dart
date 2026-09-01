import 'package:flutter/material.dart';
import 'package:project_srpg/game/attribute_labels.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/lit_card.dart';

/// Sosyal teklif kartı — R4'ün metnini gösterir, R5/R6'yı çağırır (§5.4).
///
/// **Kapatılamaz (D53).** Barrier'a dokunmak ve geri tuşu işlemez; kabul ya
/// da ret verilmeden çıkılmaz. Bunun güvenli olmasının sebebi INV-40: ret
/// hiçbir gereksinim kontrol etmez, hiçbir şey harcamaz ve başarısız
/// olamaz — parası ve günü bitmiş bir oyuncu bile teklifi temizleyebilir.
/// Kabul reddedilirse (`409`) modal **açık kalır** ve mesaj gösterilir.
Future<api.SocialOfferResult?> showSocialOfferModal(
  BuildContext context, {
  required CareerSession session,
  required api.SocialOffer offer,
}) {
  return showDialog<api.SocialOfferResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SocialOfferModal(session: session, offer: offer),
  );
}

class SocialOfferModal extends StatefulWidget {
  const SocialOfferModal({
    super.key,
    required this.session,
    required this.offer,
  });

  final CareerSession session;
  final api.SocialOffer offer;

  @override
  State<SocialOfferModal> createState() => _SocialOfferModalState();
}

class _SocialOfferModalState extends State<SocialOfferModal> {
  bool _busy = false;
  String? _error;

  Future<void> _answer({required bool accept}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final careerId = await widget.session.resolve();
      final result = accept
          ? await widget.session.client
              .acceptSocialOffer(careerId, widget.offer.offerId)
          : await widget.session.client
              .declineSocialOffer(careerId, widget.offer.offerId);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on CareerApiException catch (e) {
      // Kabul reddedildi (bütçe/gereksinim/bakiye). Modal açık kalır —
      // reddetmek hâlâ mümkün ve asla başarısız olmaz (INV-40).
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message ?? 'Teklif yanıtlanamadı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;

    return PopScope(
      // Geri tuşu da kapatmaz — barrier ile aynı kural (D53).
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: LitCard(
            borderRadius: 14,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (offer.relationship case final contact?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${contact.category} · ${contact.contactName}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  Text(
                    offer.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (offer.costs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _costLabel(offer.costs),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (offer.requires.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _requiresLabel(offer.requires),
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (_error case final message?) ...[
                    const SizedBox(height: 10),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceButton(
                          key: const ValueKey('offerDecline'),
                          label: offer.declineLabel,
                          onPressed: _busy ? null : () => _answer(accept: false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceButton(
                          key: const ValueKey('offerAccept'),
                          label: offer.acceptLabel,
                          primary: true,
                          onPressed: _busy ? null : () => _answer(accept: true),
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
    );
  }
}

/// '2 sa · 20 enerji' — BE sayı gönderir, birimi ekran yazar (§1.3).
String _costLabel(Map<String, double> costs) {
  final parts = <String>[];
  for (final entry in costs.entries) {
    switch (entry.key) {
      case 'time':
        final hours = entry.value / 60;
        parts.add(hours >= 1
            ? '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} sa'
            : '${entry.value.round()} dk');
      case 'energy':
        parts.add('${entry.value.round()} enerji');
      default:
        parts.add('${entry.value.round()} ${entry.key}');
    }
  }
  return parts.join(' · ');
}

/// D42 · kabul kapısı. Etiketler ortak `attribute_labels.dart`'tan gelir ki
/// nitelik adları burada ikinci kez yazılmasın.
String _requiresLabel(Map<String, int> requires) {
  final parts = requires.entries
      .map((e) => '${attributeLabel(e.key)} ${e.value}')
      .join(', ');
  return 'Kabul için: $parts';
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor:
            primary ? AppColors.textPrimary : AppColors.textSecondary,
        disabledForegroundColor: AppColors.textMuted,
        backgroundColor: primary ? AppColors.accentBg : null,
        side: BorderSide(
          color: primary ? AppColors.accent : AppColors.border,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
