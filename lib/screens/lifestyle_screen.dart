import 'package:flutter/material.dart';
import 'package:project_srpg/game/attribute_labels.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/shop_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/state/player_state.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/activity_card.dart';
import 'package:project_srpg/net/money.dart';

enum _LifestyleTab { individual, group }

/// Kartın temel ölçüleri. Detay görünümü aynı oranı büyüterek kullanır.
const double _cardWidth = 148;
const double _cardHeight = 176;
const double _detailCardWidth = 232;
const double _detailCardHeight = _detailCardWidth * _cardHeight / _cardWidth;

class _ActivitySectionData {
  const _ActivitySectionData({required this.title, required this.activities});

  final String title;
  final List<LifestyleActivity> activities;
}

/// §5.8 — ikon ve renk tonu BE'den gelmez, FE'nin sunum kararı (N3 yalnızca
/// `catalog_id`/`title`/`description`/`duration_label`/`costs`/`effects`
/// verir). `catalog_id` sabit olduğu için burada elle eşleniyor.
const _iconByCatalogId = {
  'ev-uyku': Icons.bedtime_outlined,
  'ev-yemek': Icons.restaurant_outlined,
  'ev-meditasyon': Icons.self_improvement,
  'ev-oyun': Icons.sports_esports_outlined,
  'ev-film': Icons.movie_outlined,
  'fiz-kosu': Icons.directions_run,
  'fiz-yuzme': Icons.pool_outlined,
  'fiz-bisiklet': Icons.pedal_bike_outlined,
  'fiz-yoga': Icons.accessibility_new,
  'fiz-sauna': Icons.spa_outlined,
  'sos-arkadas': Icons.groups_outlined,
  'sos-kafe': Icons.local_cafe_outlined,
  'sos-aile': Icons.home_outlined,
  'sos-konser': Icons.music_note_outlined,
  'sos-taraftar': Icons.emoji_events_outlined,
};

const _tintByCatalogId = {
  'ev-uyku': Color(0xFF4C5BD4),
  'ev-yemek': AppColors.greenDeep,
  'ev-meditasyon': Color(0xFF7C5CD6),
  'ev-oyun': Color(0xFFC2544D),
  'ev-film': Color(0xFF3F6BA8),
  'fiz-kosu': AppColors.accent,
  'fiz-yuzme': Color(0xFF2AA6C4),
  'fiz-bisiklet': Color(0xFF3D9A57),
  'fiz-yoga': Color(0xFF8E5CC7),
  'fiz-sauna': Color(0xFFD4783C),
  'sos-arkadas': Color(0xFFD9694F),
  'sos-kafe': Color(0xFF9C7A4E),
  'sos-aile': AppColors.greenDeep,
  'sos-konser': Color(0xFF8B4FCF),
  'sos-taraftar': AppColors.warning,
};

const _defaultTint = AppColors.textMuted;

LifestyleActivity _toActivity(api.CatalogItem item, PlayerState player) {
  return LifestyleActivity(
    id: item.catalogId,
    title: item.title,
    description: item.description ?? '',
    icon: _iconByCatalogId[item.catalogId] ?? Icons.circle_outlined,
    tint: _tintByCatalogId[item.catalogId] ?? _defaultTint,
    duration: item.durationLabel ?? '',
    conditionDelta: (item.effects['condition'] as num?)?.toInt() ?? 0,
    // Para bir `cost` değil, negatif bir `effect`'tir (§6.2) — kart burada
    // pozitif bir ₭ etiketi gösterdiği için işareti çeviriyoruz.
    cost: -((item.effects['money'] as num?)?.toInt() ?? 0),
    // D42 · eşiği FE karşılaştırır, BE tekrar doğrular (INV-30). Seviyeler
    // P1'den geldiği gibi okunur; FE `value`'dan seviye türetmez.
    unmetRequirements: unmetRequirements(item.requires, player.attributeLevel),
  );
}

/// N3'ün `group` alanı §5.7'de FE'nin bugünkü üç bölüm başlığıyla birebir
/// aynı ('EV AKTİVİTELERİ' vb.) — sabit üç bölüm yerine kataloğun kendi
/// gruplamasından türetilir.
List<_ActivitySectionData> _sectionsFrom(
  List<api.CatalogItem> items,
  PlayerState player,
) {
  final byGroup = <String, List<LifestyleActivity>>{};
  for (final item in items) {
    (byGroup[item.group ?? ''] ??= []).add(_toActivity(item, player));
  }
  return [
    for (final entry in byGroup.entries)
      _ActivitySectionData(title: entry.key, activities: entry.value),
  ];
}

class LifestyleScreen extends StatefulWidget {
  const LifestyleScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  late Future<api.Catalog> _catalogFuture;

  _LifestyleTab _tab = _LifestyleTab.individual;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _session.client.catalog('lifestyle');
  }

  void _openActivity(LifestyleActivity activity) {
    Navigator.of(context).push(
      _ActivityDetailRoute(activity: activity, session: _session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);

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
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _HeaderSection(condition: player.condition),
                      const SizedBox(height: 14),
                      _TabToggle(
                        tab: _tab,
                        onChanged: (tab) => setState(() => _tab = tab),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: Offset(
                                _tab == _LifestyleTab.individual
                                    ? -0.06
                                    : 0.06,
                                0,
                              ),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: _tab == _LifestyleTab.group
                              ? const Center(
                                  key: ValueKey('group'),
                                  child: Text(
                                    'Grup aktiviteleri yakında.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : FutureBuilder<api.Catalog>(
                                  key: const ValueKey('individual'),
                                  future: _catalogFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return const Center(
                                        child: Text(
                                          'Yaşam tarzı kataloğu alınamadı.',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    }

                                    // PlayerScope.of() burada okunuyor:
                                    // seviyeler değişince (bir aktivite bir
                                    // kapı açtığında) liste kendiliğinden
                                    // yeniden çizilir.
                                    final sections = _sectionsFrom(
                                      snapshot.data!.items,
                                      PlayerScope.of(context),
                                    );
                                    return ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 16, 0, 20),
                                      itemCount: sections.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 18),
                                      itemBuilder: (context, index) {
                                        return _ActivitySection(
                                          section: sections[index],
                                          onActivityTap: _openActivity,
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
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
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.condition});

  final int condition;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_left,
              size: 24,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Kondisyon',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$condition/100',
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(end: condition / 100),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 5,
                        backgroundColor: AppColors.surface1,
                        color: AppColors.success,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Alışveriş',
            icon: const Icon(
              Icons.shopping_bag_outlined,
              size: 22,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  const _TabToggle({
    required this.tab,
    required this.onChanged,
  });

  final _LifestyleTab tab;
  final ValueChanged<_LifestyleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    const height = 30.0;
    const padding = 2.0;
    const segmentWidth = 78.0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox(
        width: segmentWidth * 2,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: tab == _LifestyleTab.individual
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: segmentWidth,
                height: height - padding * 2,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                _ToggleLabel(
                  width: segmentWidth,
                  label: 'Bireysel',
                  selected: tab == _LifestyleTab.individual,
                  onTap: () => onChanged(_LifestyleTab.individual),
                ),
                _ToggleLabel(
                  width: segmentWidth,
                  label: 'Grupsal',
                  selected: tab == _LifestyleTab.group,
                  onTap: () => onChanged(_LifestyleTab.group),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleLabel extends StatelessWidget {
  const _ToggleLabel({
    required this.width,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.section,
    required this.onActivityTap,
  });

  final _ActivitySectionData section;
  final ValueChanged<LifestyleActivity> onActivityTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            section.title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            // Şerit, dıştaki liste bölümü geri dönüştürdüğünde ya da sekme
            // değiştiğinde kaldığı yerden devam etsin.
            key: PageStorageKey<String>('lifestyle-row-${section.title}'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            // Kart gölgeleri ve renk tonu parıltısı taşabilsin; panelin dış
            // ClipRRect'i zaten sınırda kırpıyor.
            clipBehavior: Clip.none,
            itemCount: section.activities.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final activity = section.activities[index];
              return _HeroActivityCard(
                activity: activity,
                width: _cardWidth,
                height: _cardHeight,
                onTap: () => onActivityTap(activity),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Kartı Hero ile sarar. İçerik her zaman aynı iç ölçüde çizilip [FittedBox]
/// ile ölçeklendiği için uçuş sırasında taşma olmaz.
class _HeroActivityCard extends StatelessWidget {
  const _HeroActivityCard({
    required this.activity,
    required this.width,
    required this.height,
    this.onTap,
  });

  final LifestyleActivity activity;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'lifestyle-${activity.id}',
      child: SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.fill,
          child: ActivityCard(
            activity: activity,
            width: _cardWidth,
            height: _cardHeight,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// Karta basılınca kartın öne gelip büyüdüğü, altında açıklama ve "Yap"
/// butonunun belirdiği yarı saydam katman.
class _ActivityDetailRoute extends PageRouteBuilder<void> {
  _ActivityDetailRoute({required this.activity, required this.session})
      : super(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _ActivityDetailPage(
              activity: activity,
              animation: animation,
              session: session,
            );
          },
        );

  final LifestyleActivity activity;
  final CareerSession session;
}

class _ActivityDetailPage extends StatefulWidget {
  const _ActivityDetailPage({
    required this.activity,
    required this.animation,
    required this.session,
  });

  final LifestyleActivity activity;
  final Animation<double> animation;
  final CareerSession session;

  @override
  State<_ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<_ActivityDetailPage> {
  bool _busy = false;

  /// T2 · `POST /careers/{cid}/actions`. Bütçe/para yetmezse (`409`) BE
  /// hiçbir şey yazmaz (INV-3/4) — burada da yalnızca bir uyarı gösterip
  /// sayfada kalınır; başarıdaysa detay kapanır.
  Future<void> _perform(BuildContext context) async {
    setState(() => _busy = true);
    final player = PlayerScope.of(context);
    try {
      final careerId = await widget.session.resolve();
      final result = await widget.session.client.postAction(
        careerId,
        catalogId: widget.activity.id,
      );
      player.applyServerUpdate(
        careerState: result.careerState,
        attributeChanges: result.attributeChanges,
      );
      if (context.mounted) Navigator.of(context).pop();
    } on CareerApiException catch (e) {
      if (!context.mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Aktivite uygulanamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.animation;
    final activity = widget.activity;
    final scrim = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final details = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: FadeTransition(
                opacity: scrim,
                child: const ColoredBox(color: Color(0xB3000000)),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroActivityCard(
                        activity: activity,
                        width: _detailCardWidth,
                        height: _detailCardHeight,
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: details,
                        child: _ActivityDetails(
                          activity: activity,
                          onPerform: (_busy || activity.locked)
                              ? null
                              : () => _perform(context),
                          busy: _busy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDetails extends StatelessWidget {
  const _ActivityDetails({
    required this.activity,
    required this.onPerform,
    this.busy = false,
  });

  final LifestyleActivity activity;
  final VoidCallback? onPerform;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final delta = activity.conditionDelta;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            activity.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Badge(
                icon: Icons.schedule,
                label: activity.duration,
                color: AppColors.textSecondary,
              ),
              if (delta != 0)
                _Badge(
                  icon: delta > 0 ? Icons.trending_up : Icons.trending_down,
                  label: '${delta > 0 ? '+' : ''}$delta kondisyon',
                  color: delta > 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              if (activity.cost > 0)
                _Badge(
                  icon: Icons.payments_outlined,
                  label: formatMoney(activity.cost),
                  color: AppColors.warning,
                ),
              // D42 · kartta yalnızca bir kilit ikonu var; gerekçeyi burada,
              // diğer rozetlerin yanında okunur biçimde yazıyoruz.
              if (activity.locked)
                _Badge(
                  key: const Key('lifestyle_requirement_badge'),
                  icon: Icons.lock_outline,
                  label: requirementLabel(activity.unmetRequirements),
                  color: AppColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPerform,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Text(activity.locked ? 'Kilitli' : 'Yap'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
