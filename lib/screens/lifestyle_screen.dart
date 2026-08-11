import 'package:flutter/material.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/activity_card.dart';

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

class LifestyleScreen extends StatefulWidget {
  const LifestyleScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _success = Color(0xFF3DDC97);
  static const _warning = Color(0xFFF5A623);
  static const _danger = Color(0xFFE85D5D);

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  static const _sections = [
    _ActivitySectionData(
      title: 'EV AKTİVİTELERİ',
      activities: [
        LifestyleActivity(
          id: 'ev-uyku',
          title: 'Uyku',
          description:
              'Erken yatıp dokuz saat kesintisiz uyu. Kaslar toparlanır, '
              'ertesi güne kondisyonun tazelenmiş başlarsın.',
          icon: Icons.bedtime_outlined,
          tint: Color(0xFF4C5BD4),
          duration: 'Tüm gece',
          conditionDelta: 14,
        ),
        LifestyleActivity(
          id: 'ev-yemek',
          title: 'Sağlıklı Yemek',
          description:
              'Kendi mutfağında dengeli bir öğün hazırla. Doğru beslenme, '
              'antrenmandan aldığın verimi doğrudan artırır.',
          icon: Icons.restaurant_outlined,
          tint: Color(0xFF2E9E6B),
          duration: '1 saat',
          conditionDelta: 6,
          cost: 250,
        ),
        LifestyleActivity(
          id: 'ev-meditasyon',
          title: 'Meditasyon',
          description:
              'Sessiz bir odada nefes çalışması yap. Maç öncesi baskıyı '
              'yönetmeni kolaylaştırır.',
          icon: Icons.self_improvement,
          tint: Color(0xFF7C5CD6),
          duration: '30 dakika',
          conditionDelta: 5,
        ),
        LifestyleActivity(
          id: 'ev-oyun',
          title: 'Video Oyunu',
          description:
              'Birkaç saat oyun oyna, kafanı dağıt. Keyifli ama geç saate '
              'kalırsan kondisyonundan yersin.',
          icon: Icons.sports_esports_outlined,
          tint: Color(0xFFC2544D),
          duration: '3 saat',
          conditionDelta: -6,
        ),
        LifestyleActivity(
          id: 'ev-film',
          title: 'Film Gecesi',
          description:
              'Kanepeye kurul ve uzun bir film izle. Zihnini boşaltır, '
              'bedenini pek dinlendirmez.',
          icon: Icons.movie_outlined,
          tint: Color(0xFF3F6BA8),
          duration: '2 saat',
          conditionDelta: 2,
        ),
      ],
    ),
    _ActivitySectionData(
      title: 'FİZİKSEL AKTİVİTELER',
      activities: [
        LifestyleActivity(
          id: 'fiz-kosu',
          title: 'Sabah Koşusu',
          description:
              'Güneş doğarken parkta tempolu koş. Dayanıklılığını besler ama '
              'gün içinde biraz yorgun hissedersin.',
          icon: Icons.directions_run,
          tint: Color(0xFF1E6FD9),
          duration: '45 dakika',
          conditionDelta: -8,
        ),
        LifestyleActivity(
          id: 'fiz-yuzme',
          title: 'Yüzme',
          description:
              'Havuzda düşük tempolu kulaç at. Eklemleri zorlamadan '
              'toparlanmayı hızlandıran ideal aktif dinlenme.',
          icon: Icons.pool_outlined,
          tint: Color(0xFF2AA6C4),
          duration: '1 saat',
          conditionDelta: 8,
          cost: 180,
        ),
        LifestyleActivity(
          id: 'fiz-bisiklet',
          title: 'Bisiklet',
          description:
              'Sahil boyunca uzun bir tur at. Bacak kaslarını çalıştırır, '
              'kafanı da açar.',
          icon: Icons.pedal_bike_outlined,
          tint: Color(0xFF3D9A57),
          duration: '1,5 saat',
          conditionDelta: -4,
        ),
        LifestyleActivity(
          id: 'fiz-yoga',
          title: 'Yoga',
          description:
              'Esneme ve denge çalışması yap. Sakatlanma riskini düşürür, '
              'kaslarındaki gerginliği alır.',
          icon: Icons.accessibility_new,
          tint: Color(0xFF8E5CC7),
          duration: '50 dakika',
          conditionDelta: 7,
          cost: 200,
        ),
        LifestyleActivity(
          id: 'fiz-sauna',
          title: 'Sauna & Masaj',
          description:
              'Profesyonel bir merkezde tam toparlanma seansı. Pahalı ama '
              'kondisyonu en hızlı geri getiren yöntem.',
          icon: Icons.spa_outlined,
          tint: Color(0xFFD4783C),
          duration: '2 saat',
          conditionDelta: 16,
          cost: 950,
        ),
      ],
    ),
    _ActivitySectionData(
      title: 'SOSYAL AKTİVİTELER',
      activities: [
        LifestyleActivity(
          id: 'sos-arkadas',
          title: 'Arkadaş Buluşması',
          description:
              'Eski dostlarınla bir araya gel. Moralini yükseltir, '
              'sosyal çevrenle bağını canlı tutar.',
          icon: Icons.groups_outlined,
          tint: Color(0xFFD9694F),
          duration: '3 saat',
          conditionDelta: -3,
          cost: 400,
        ),
        LifestyleActivity(
          id: 'sos-kafe',
          title: 'Kafe',
          description:
              'Sakin bir kafede kahve iç. Kısa ve zararsız bir mola, '
              'kafan dinlenir.',
          icon: Icons.local_cafe_outlined,
          tint: Color(0xFF9C7A4E),
          duration: '1 saat',
          conditionDelta: 1,
          cost: 150,
        ),
        LifestyleActivity(
          id: 'sos-aile',
          title: 'Aile Ziyareti',
          description:
              'Ailenle vakit geçir. Kariyerin baskısını hafifletir, '
              'aile ilişkini güçlendirir.',
          icon: Icons.home_outlined,
          tint: Color(0xFF2E9E6B),
          duration: 'Yarım gün',
          conditionDelta: 4,
        ),
        LifestyleActivity(
          id: 'sos-konser',
          title: 'Konser',
          description:
              'Gece boyu sahne önünde ol. Eğlencesi bol, ertesi günkü '
              'antrenmana bedeli ağır.',
          icon: Icons.music_note_outlined,
          tint: Color(0xFF8B4FCF),
          duration: 'Tüm gece',
          conditionDelta: -12,
          cost: 1200,
        ),
        LifestyleActivity(
          id: 'sos-taraftar',
          title: 'Taraftar Etkinliği',
          description:
              'Kulübün taraftar buluşmasına katıl. Tribünün gözünde '
              'değerin artar.',
          icon: Icons.emoji_events_outlined,
          tint: Color(0xFFF5A623),
          duration: '2 saat',
          conditionDelta: -2,
        ),
      ],
    ),
  ];

  _LifestyleTab _tab = _LifestyleTab.individual;

  void _openActivity(LifestyleActivity activity) {
    Navigator.of(context).push(_ActivityDetailRoute(activity: activity));
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);

    return Scaffold(
      backgroundColor: LifestyleScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: LifestyleScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: LifestyleScreen._border,
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
                                      color: LifestyleScreen._textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  key: const ValueKey('individual'),
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 16, 0, 20),
                                  itemCount: _sections.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 18),
                                  itemBuilder: (context, index) {
                                    return _ActivitySection(
                                      section: _sections[index],
                                      onActivityTap: _openActivity,
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
          bottom: BorderSide(color: LifestyleScreen._border, width: 0.5),
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
              color: LifestyleScreen._textMuted,
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
                          color: LifestyleScreen._textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$condition/100',
                      maxLines: 1,
                      style: const TextStyle(
                        color: LifestyleScreen._textSecondary,
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
                        backgroundColor: LifestyleScreen._surface1,
                        color: LifestyleScreen._success,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showStubMessage(context, 'Alışveriş yakında.'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Alışveriş',
            icon: const Icon(
              Icons.shopping_bag_outlined,
              size: 22,
              color: LifestyleScreen._textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

void _showStubMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
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
        color: LifestyleScreen._surface1,
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
                  color: LifestyleScreen._accent,
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
                  ? LifestyleScreen._textPrimary
                  : LifestyleScreen._textMuted,
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
              color: LifestyleScreen._textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
  _ActivityDetailRoute({required this.activity})
      : super(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _ActivityDetailPage(
              activity: activity,
              animation: animation,
            );
          },
        );

  final LifestyleActivity activity;
}

class _ActivityDetailPage extends StatelessWidget {
  const _ActivityDetailPage({
    required this.activity,
    required this.animation,
  });

  final LifestyleActivity activity;
  final Animation<double> animation;

  void _perform(BuildContext context) {
    PlayerScope.of(context).applyActivity(
      conditionDelta: activity.conditionDelta,
      cost: activity.cost,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                          onPerform: () => _perform(context),
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
  });

  final LifestyleActivity activity;
  final VoidCallback onPerform;

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
              color: LifestyleScreen._textSecondary,
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
                color: LifestyleScreen._textSecondary,
              ),
              if (delta != 0)
                _Badge(
                  icon: delta > 0 ? Icons.trending_up : Icons.trending_down,
                  label: '${delta > 0 ? '+' : ''}$delta kondisyon',
                  color: delta > 0
                      ? LifestyleScreen._success
                      : LifestyleScreen._danger,
                ),
              if (activity.cost > 0)
                _Badge(
                  icon: Icons.payments_outlined,
                  label: '₺${activity.cost}',
                  color: LifestyleScreen._warning,
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPerform,
              style: FilledButton.styleFrom(
                backgroundColor: LifestyleScreen._accent,
                foregroundColor: LifestyleScreen._textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Yap'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
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
