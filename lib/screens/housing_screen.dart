import 'package:flutter/material.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/money.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// §14.4 · Konut. Kariyerin tek bir aktif konutu var (INV-67); uykusu her
/// gecenin kondisyonunu, derecesi karizmayı belirler. Ekran yalnız sunar: neyin
/// alınabildiği, neyin taşınılabildiği ve neyin tutacağı backend'den gelir
/// (`GET /careers/{cid}/housing`), kira/çıkarılma kuralları orada yaşar.
class HousingScreen extends StatefulWidget {
  const HousingScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<HousingScreen> createState() => _HousingScreenState();
}

/// Sunumun gruplaması `kind`'dan gelir; katalogda ayrı bir alan yok.
const _sections = [
  ('start', 'BAŞLANGIÇ'),
  ('rent', 'KİRALIK'),
  ('hotel', 'OTEL'),
  ('buy', 'SATIN ALINABİLİR'),
  ('holiday', 'TATİL MÜLKLERİ'),
];

class _HousingScreenState extends State<HousingScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  api.HousingState? _state;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final careerId = await _session.resolve();
      final state = await _session.client.housing(careerId);
      if (!mounted) return;
      setState(() => _state = state);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// Tek yazma yolu: isteği yap, dönen `career_state`'i oyuncu durumuna yaz,
  /// konut resmini değiştir. Taşınma karizma bonusunu değiştirir, o yüzden
  /// niteliklerin seviyeleri (BE'de) için P1 tazelenir.
  Future<void> _run(
    Future<api.HousingState> Function(String careerId) call,
    String done,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final player = PlayerScope.of(context);
    try {
      final careerId = await _session.resolve();
      final next = await call(careerId);
      player.applyServerUpdate(careerState: next.careerState);
      if (next.activeResidenceId != _state?.activeResidenceId) player.load();
      if (!mounted) return;
      setState(() {
        _state = next;
        _busy = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(done),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(_messageFor(e))));
    }
  }

  String _messageFor(CareerApiException e) {
    switch (e.code) {
      case 'insufficient_funds':
        return 'Bakiye yetersiz.';
      case 'rest_out_of_season':
        return 'Tatil mülkleri yalnız kış arasında ve yaz penceresinde kullanılır.';
      case 'insufficient_budget':
        return 'Bugünün tamamı lazım; önce gününü boşalt.';
      default:
        return e.message ?? 'İşlem başarısız.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final state = _state;

    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _Header(moneyLabel: player.moneyLabel),
                      Expanded(
                        child: state == null
                            ? Center(
                                child: _error == null
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textMuted,
                                      )
                                    : const Text(
                                        'Konut bilgisi alınamadı.',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                              )
                            : _body(state),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(api.HousingState state) {
    final active = state.active;
    final money = state.careerState.money;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _ActiveSummary(state: state),
        for (final (kind, title) in _sections) ...[
          _SectionTitle(title),
          for (final r in state.residences.where((r) => r.kind == kind))
            _ResidenceCard(
              key: Key('residence_${r.id}'),
              residence: r,
              money: money,
              busy: _busy,
              onAct: () => _act(r),
            ),
        ],
        if (active.isOwnedHome) ...[
          const _SectionTitle('EV GELİŞTİRMELERİ'),
          for (final u in state.upgrades)
            _UpgradeRow(
              key: Key('upgrade_${u.id}'),
              upgrade: u,
              fitted: active.upgrades.contains(u.id),
              money: money,
              busy: _busy,
              onInstall: () => _run(
                (id) => _session.client.installUpgrade(id, active.id, u.id),
                '${u.title} takıldı.',
              ),
            ),
        ] else ...[
          const _SectionTitle('EV GELİŞTİRMELERİ'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Geliştirmeler yalnız sahip olduğun ve yaşadığın eve takılır.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  /// Kartın tek düğmesinin işi, konutun durumundan çıkar.
  void _act(api.Residence r) {
    final client = _session.client;
    if (r.isHoliday && r.held) {
      _run((id) => client.restAt(id, r.id), '${r.title} · dinlendin.');
    } else if (r.held || r.kind == 'start') {
      _run(
        (id) => client.activateResidence(id, r.id),
        '${r.title} artık evin.',
      );
    } else {
      _run(
        (id) => client.acquireResidence(id, r.id),
        r.kind == 'rent' ? '${r.title} kiralandı.' : '${r.title} senin.',
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.moneyLabel});

  final String moneyLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Geri',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back,
              size: 20,
              color: AppColors.textMuted,
            ),
          ),
          const Text(
            'Konut',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            moneyLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSummary extends StatelessWidget {
  const _ActiveSummary({required this.state});

  final api.HousingState state;

  @override
  Widget build(BuildContext context) {
    final home = state.active;
    final noise = state.noiseChance > 0
        ? ' · gürültü %${(state.noiseChance * 100).round()}'
        : '';
    return Container(
      key: const Key('housing_active_summary'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YAŞADIĞIN YER',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            home.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Yarınki gece: +${state.conditionTotal} kondisyon$noise',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (home.expiresOn != null)
            Text(
              'Otel odası ${home.expiresOn} tarihinde biter.',
              style: const TextStyle(color: AppColors.warning, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ResidenceCard extends StatelessWidget {
  const _ResidenceCard({
    super.key,
    required this.residence,
    required this.money,
    required this.busy,
    required this.onAct,
  });

  final api.Residence residence;
  final int money;
  final bool busy;
  final VoidCallback onAct;

  /// (etiket, tıklanabilir mi). Etiket fiyatı taşır; ödenemeyen seçenek pasif.
  (String, bool) get _action {
    final r = residence;
    if (r.active) return ('Burada yaşıyorsun', false);
    if (r.kind == 'hotel') return ('Transferden sonra kulüp verir', false);
    if (r.isHoliday && r.held) {
      return ('Dinlen · +${r.restCondition} kondisyon', !busy);
    }
    if (r.held || r.kind == 'start') return ('Taşın', !busy);
    final (label, cost) = r.kind == 'rent'
        ? ('Kirala · ${formatMoney(r.rentMonthly)}/ay', r.rentMonthly)
        : ('Satın al · ${formatMoney(r.price)}', r.price);
    return money < cost ? ('Bakiye yetersiz', false) : (label, !busy);
  }

  @override
  Widget build(BuildContext context) {
    final r = residence;
    final (label, enabled) = _action;
    final stats = [
      if (!r.isHoliday) 'Uyku +${r.sleep}',
      if (r.isHoliday) 'Gün +${r.restCondition}',
      if (r.grade > 0 && !r.isHoliday) 'Karizma ${r.grade}',
      if (r.kind == 'rent') '${formatMoney(r.rentMonthly)}/ay',
      if (r.kind == 'hotel') '${formatMoney(r.dailyFee)}/gün',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: r.active ? Border.all(color: AppColors.accent, width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stats.join(' · '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            r.note,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: Key('residence_action_${r.id}'),
              onPressed: enabled ? onAct : null,
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    super.key,
    required this.upgrade,
    required this.fitted,
    required this.money,
    required this.busy,
    required this.onInstall,
  });

  final api.ResidenceUpgrade upgrade;
  final bool fitted;
  final int money;
  final bool busy;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final fee = upgrade.monthlyFee > 0
        ? ' · ${formatMoney(upgrade.monthlyFee)}/ay'
        : '';
    final enabled = !fitted && !busy && money >= upgrade.price;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upgrade.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${upgrade.note}$fee',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: enabled ? onInstall : null,
            child: Text(fitted ? 'Takılı' : formatMoney(upgrade.price)),
          ),
        ],
      ),
    );
  }
}
