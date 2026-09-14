import 'package:flutter/material.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// §12.8/D58 — kabul edildiğinde anında çözülmeyip ileri bir güne
/// ertelenmiş sosyal teklifler ("planlar"): bugün gidip yapılacaklar.
///
/// Bekleyen bir plan varken `advance` `409 social_plan_pending` döner
/// (sponsorluk randevusuyla aynı kapı, bkz. [SponsorshipScreen]), o yüzden
/// bu ekran de "İlerle"nin önüne çıkabiliyor.
class SocialPlanScreen extends StatefulWidget {
  const SocialPlanScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<SocialPlanScreen> createState() => _SocialPlanScreenState();
}

class _SocialPlanScreenState extends State<SocialPlanScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;

  List<api.SocialPlan>? _plans;
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
      final plans = await _session.client.socialPlans(careerId);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Planlar alınamadı.';
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
          title: const Text('Bugünkü plan', style: TextStyle(fontSize: 16)),
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
            key: const Key('social_plan_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    final plans = _plans ?? const <api.SocialPlan>[];
    if (plans.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Bekleyen bir plan yok.',
            key: Key('social_plan_empty'),
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
        for (final plan in plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlanCard(
              plan: plan,
              busy: _busyId == plan.planId,
              onAttend: () => _run(
                plan.planId,
                (careerId) async => _applyState(
                  (await _session.client.attendSocialPlan(careerId, plan.planId))
                      .careerState,
                ),
              ),
              onSkip: () => _run(
                plan.planId,
                (careerId) async => _applyState(
                  (await _session.client.skipSocialPlan(careerId, plan.planId))
                      .careerState,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.busy,
    required this.onAttend,
    required this.onSkip,
  });

  final api.SocialPlan plan;
  final bool busy;
  final VoidCallback onAttend;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('plan_${plan.planId}'),
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
            plan.title.isEmpty ? 'Plan' : plan.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.relationship?.personName ?? ''} · ${plan.dueOn}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (plan.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.body,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Gitmezsen ilişki reddetmekten daha çok yara alır — söz vermiştin.',
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
                  key: Key('attend_${plan.planId}'),
                  onPressed: busy ? null : onAttend,
                  child: const Text('Git'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: Key('skip_${plan.planId}'),
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
