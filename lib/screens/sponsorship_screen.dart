import 'package:flutter/material.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/money.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// §12.7 — sponsorluk: gelen teklifler, yürüyen anlaşmalar ve bugün
/// kaçırılamayacak randevular tek ekranda.
///
/// Bekleyen bir randevu varken `advance` `409` döner, o yüzden bu ekran
/// "İlerle"nin önüne de çıkabiliyor: kararı vermeden gün geçmiyor.
class SponsorshipScreen extends StatefulWidget {
  const SponsorshipScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<SponsorshipScreen> createState() => _SponsorshipScreenState();
}

class _SponsorshipScreenState extends State<SponsorshipScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;

  api.SponsorshipState? _state;
  String? _error;
  bool _loading = true;
  String? _busyId;

  /// Ekran açıldığından beri bir şey değiştiyse çağıran tazelensin.
  bool _changed = false;

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
      final state = await _session.client.sponsorships(careerId);
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Sponsorluklar alınamadı.';
        _loading = false;
      });
    }
  }

  Future<void> _run(String busyId, Future<void> Function(String) action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyId = busyId);
    try {
      final careerId = await _session.resolve();
      await action(careerId);
      if (!mounted) return;
      _changed = true;
      await _load();
      if (mounted) setState(() => _busyId = null);
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'İşlem tamamlanamadı.')),
      );
    }
  }

  void _applyState(api.CareerState state) {
    if (!mounted) return;
    PlayerScope.of(context).applyServerUpdate(careerState: state);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface1,
        appBar: AppBar(
          backgroundColor: AppColors.surface1,
          foregroundColor: AppColors.textPrimary,
          title: const Text('Sponsorluk', style: TextStyle(fontSize: 16)),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error case final message?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            key: const Key('sponsorship_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    final state = _state!;
    if (state.offers.isEmpty &&
        state.active.isEmpty &&
        state.pendingObligations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Şu an masada sponsorluk yok.\nMarkalar formda oyuncuları arar.',
            key: Key('sponsorship_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (state.pendingObligations.isNotEmpty) ...[
          const _SectionTitle('Bugünkü randevu'),
          for (final obligation in state.pendingObligations)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ObligationCard(
                obligation: obligation,
                deal: _dealFor(obligation.dealId),
                busy: _busyId == obligation.obligationId,
                onAttend: () => _run(
                  obligation.obligationId,
                  (careerId) async => _applyState(
                    await _session.client.attendSponsorshipObligation(
                      careerId,
                      obligation.obligationId,
                    ),
                  ),
                ),
                onSkip: () => _run(
                  obligation.obligationId,
                  (careerId) async => _applyState(
                    await _session.client.skipSponsorshipObligation(
                      careerId,
                      obligation.obligationId,
                    ),
                  ),
                ),
              ),
            ),
        ],
        if (state.offers.isNotEmpty) ...[
          const _SectionTitle('Gelen teklif'),
          for (final deal in state.offers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DealCard(
                deal: deal,
                busy: _busyId == deal.dealId,
                onAccept: () => _run(
                  deal.dealId,
                  (careerId) async {
                    await _session.client.acceptSponsorship(careerId, deal.dealId);
                  },
                ),
                onDecline: () => _run(
                  deal.dealId,
                  (careerId) async {
                    await _session.client
                        .declineSponsorship(careerId, deal.dealId);
                  },
                ),
              ),
            ),
        ],
        if (state.active.isNotEmpty) ...[
          const _SectionTitle('Yürüyen anlaşmalar'),
          for (final deal in state.active)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DealCard(deal: deal, busy: false),
            ),
        ],
      ],
    );
  }

  api.SponsorshipDeal? _dealFor(String dealId) {
    for (final deal in _state?.active ?? const <api.SponsorshipDeal>[]) {
      if (deal.dealId == dealId) return deal;
    }
    return null;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.deal,
    required this.busy,
    this.onAccept,
    this.onDecline,
  });

  final api.SponsorshipDeal deal;
  final bool busy;

  /// Null ise anlaşma zaten yürüyor — kart bilgi amaçlı.
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final obligation = deal.obligation;
    return Container(
      key: Key('deal_${deal.dealId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deal.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onAccept != null) ...[
            const SizedBox(height: 6),
            Text(
              deal.body,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                '${formatMoney(deal.weeklyIncome)} / hafta',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${deal.seasons} sezon',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // İmzadan önce görünür: sonradan öğrenilen bedel karar değil tuzak.
          Row(
            children: [
              Icon(
                obligation == null
                    ? Icons.check_circle_outline
                    : Icons.event_busy_outlined,
                size: 14,
                color: obligation == null
                    ? AppColors.textMuted
                    : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  obligation == null
                      ? 'Yükümlülük yok'
                      : '${obligation.title} · ${obligation.everyDays} günde bir',
                  style: TextStyle(
                    color: obligation == null
                        ? AppColors.textMuted
                        : AppColors.warning,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (onAccept != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: Key('accept_deal_${deal.dealId}'),
                    onPressed: busy ? null : onAccept,
                    child: Text(deal.acceptLabel),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: Key('decline_deal_${deal.dealId}'),
                  onPressed: busy ? null : onDecline,
                  child: Text(
                    deal.declineLabel,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ObligationCard extends StatelessWidget {
  const _ObligationCard({
    required this.obligation,
    required this.deal,
    required this.busy,
    required this.onAttend,
    required this.onSkip,
  });

  final api.SponsorshipObligation obligation;
  final api.SponsorshipDeal? deal;
  final bool busy;
  final VoidCallback onAttend;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final spec = deal?.obligation;
    return Container(
      key: Key('obligation_${obligation.obligationId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spec?.title ?? 'Sponsorluk etkinliği',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${deal?.brand ?? ''} · ${obligation.dueOn}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Gitmezsen anlaşma bozulur, gelir kesilir ve basın yazar.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: Key('attend_${obligation.obligationId}'),
                  onPressed: busy ? null : onAttend,
                  child: const Text('Katıl'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: Key('skip_${obligation.obligationId}'),
                onPressed: busy ? null : onSkip,
                child: const Text(
                  'Gitme',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
