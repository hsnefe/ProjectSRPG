import 'package:flutter/material.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/money.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// §11.7 S3/S4 — transfer penceresindeki teklifler.
///
/// Mevcut kulübün yenileme teklifi ve rakiplerin teklifleri **aynı listede**:
/// oyuncu için ikisi de aynı karar — nerede oynayacağım. Yenilemenin tek
/// farkı bir kez "daha iyisini iste" hakkı taşıması (§12.4).
class TransferOffersScreen extends StatefulWidget {
  const TransferOffersScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<TransferOffersScreen> createState() => _TransferOffersScreenState();
}

class _TransferOffersScreenState extends State<TransferOffersScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;

  api.TransferOffers? _offers;
  String? _error;
  bool _loading = true;

  /// İşlem yapılan teklifin id'si — o kartın butonları kilitlenir, diğerleri
  /// çalışmaya devam eder.
  String? _busyOfferId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final careerId = await _session.resolve();
      final offers = await _session.client.transferOffers(careerId);
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Teklifler alınamadı.';
        _loading = false;
      });
    }
  }

  Future<void> _accept(api.TransferOffer offer) async {
    final messenger = ScaffoldMessenger.of(context);
    final player = PlayerScope.of(context);
    setState(() => _busyOfferId = offer.offerId);
    try {
      final careerId = await _session.resolve();
      final result =
          await _session.client.acceptTransferOffer(careerId, offer.offerId);
      if (!mounted) return;
      player.applyServerUpdate(careerState: result.careerState);
      // §13.1 · yeni kulüpte antrenör, kaptan ve tribün baştan başlıyor.
      // Snackbar'a yazılıyor çünkü bu sessizce olursa kullanıcı kadro
      // dışı kaldığında sebebini (antrenörün güveni sıfırlandı, §12.2)
      // hiçbir yerden okuyamaz.
      messenger.showSnackBar(SnackBar(
        content: Text(
          result.relationshipsReset.isEmpty
              ? '${result.team.name} ile anlaştın.'
              : '${result.team.name} ile anlaştın. Yeni bir soyunma odası: '
                  '${_resetSummary(result.relationshipsReset)}.',
        ),
        duration: const Duration(seconds: 5),
      ));
      Navigator.of(context).pop(true);
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyOfferId = null);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Teklif kabul edilemedi.')),
      );
    }
  }

  /// §13.1 · 'Antrenör Kerem, Takım grubu ve taraftarlarla sıfırdan' —
  /// BE isimleri gönderiyor (`relationships_reset`), cümleyi ekran kuruyor
  /// (§1.3). Yeni kartların kendisi bir sonraki R1'de gelir.
  String _resetSummary(List<api.RelationshipReset> resets) {
    final names = [for (final r in resets) r.contactName];
    if (names.length <= 1) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} ve ${names.last}';
  }

  Future<void> _counter(api.TransferOffer offer) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyOfferId = offer.offerId);
    try {
      final careerId = await _session.resolve();
      final result =
          await _session.client.counterTransferOffer(careerId, offer.offerId);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(result.accepted
            ? 'Kulüp teklifi yükseltti: ${formatMoney(result.offer.weeklyWage)}/hafta'
            : 'Kulüp teklifini yükseltmedi.'),
      ));
      await _load();
      if (mounted) setState(() => _busyOfferId = null);
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyOfferId = null);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Görüşme yapılamadı.')),
      );
    }
  }

  Future<void> _decline(api.TransferOffer offer) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyOfferId = offer.offerId);
    try {
      final careerId = await _session.resolve();
      final offers =
          await _session.client.declineTransferOffer(careerId, offer.offerId);
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _busyOfferId = null;
      });
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyOfferId = null);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Teklif reddedilemedi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface1,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Teklifler', style: TextStyle(fontSize: 16)),
        elevation: 0,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error case final message?) {
      return _Message(
        key: const Key('transfer_error'),
        icon: Icons.error_outline,
        title: 'Bir şeyler ters gitti',
        body: message,
      );
    }

    final offers = _offers;
    if (offers == null || !offers.isOpen) {
      return const _Message(
        key: Key('transfer_window_closed'),
        icon: Icons.lock_clock,
        title: 'Transfer dönemi kapalı',
        body: 'Kulüpler yalnızca devre arasında ve sezon aralarında '
            'teklif yapabilir.',
      );
    }
    if (offers.offers.isEmpty) {
      return const _Message(
        key: Key('transfer_no_offers'),
        icon: Icons.inbox_outlined,
        title: 'Henüz teklif yok',
        body: 'Bu pencerede kimse kapını çalmadı.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _WindowBanner(window: offers.window!, closesOn: offers.closesOn),
        const SizedBox(height: 12),
        for (final offer in offers.offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OfferCard(
              offer: offer,
              busy: _busyOfferId == offer.offerId,
              onAccept: () => _accept(offer),
              onCounter: offer.canCounter ? () => _counter(offer) : null,
              onDecline: () => _decline(offer),
            ),
          ),
      ],
    );
  }
}

class _WindowBanner extends StatelessWidget {
  const _WindowBanner({required this.window, required this.closesOn});

  final String window;
  final String? closesOn;

  @override
  Widget build(BuildContext context) {
    final label = window == 'winter' ? 'Devre arası' : 'Sezon arası';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              closesOn == null
                  ? '$label transfer dönemi açık'
                  : '$label transfer dönemi · $closesOn tarihine kadar',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onCounter,
    required this.onDecline,
  });

  final api.TransferOffer offer;
  final bool busy;
  final VoidCallback onAccept;

  /// Null ise karşı teklif hakkı ya yok (rakip kulüp) ya da kullanılmış.
  final VoidCallback? onCounter;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('offer_${offer.offerId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: offer.isRenewal ? AppColors.accent : AppColors.border,
          width: offer.isRenewal ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.team.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (offer.isRenewal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'YENİLEME',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          if (offer.competition case final competition?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                competition.name,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 10),
          _Term(label: 'Haftalık', value: formatMoney(offer.weeklyWage)),
          _Term(label: 'Maç primi', value: formatMoney(offer.appearanceBonus)),
          _Term(label: 'Gol primi', value: formatMoney(offer.goalBonus)),
          _Term(
            label: 'Serbest kalma',
            value: formatMoney(offer.releaseClause),
          ),
          _Term(
            label: 'Süre',
            value: '${offer.lengthSeasons} sezon · ${offer.expiresAt}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: Key('accept_${offer.offerId}'),
                  onPressed: busy ? null : onAccept,
                  child: const Text('Kabul et'),
                ),
              ),
              if (onCounter != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: Key('counter_${offer.offerId}'),
                    onPressed: busy ? null : onCounter,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Daha iyisini iste'),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              TextButton(
                key: Key('decline_${offer.offerId}'),
                onPressed: busy ? null : onDecline,
                child: const Text(
                  'Reddet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if (offer.isRenewal && offer.counterUsed)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Bu teklif üzerinde bir kez görüşüldü.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _Term extends StatelessWidget {
  const _Term({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
