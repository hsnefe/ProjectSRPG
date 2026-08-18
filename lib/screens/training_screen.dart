import 'package:flutter/material.dart';
import 'package:project_srpg/game/shot_game.dart' show ShotMode;
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/screens/ball_training_screen.dart';
import 'package:project_srpg/screens/conditioning_training_screen.dart';
import 'package:project_srpg/screens/strength_training_screen.dart';
import 'package:project_srpg/screens/training_radar_screen.dart';
import 'package:project_srpg/state/player_scope.dart';

enum _TrainingTab { physical, tactical }

class _TrainingItem {
  const _TrainingItem({
    required this.title,
    required this.lastDone,
    required this.progress,
    required this.energy,
    required this.icon,
    required this.barColor,
    this.drill,
  });

  final String title;
  final String lastDone;
  final double progress;
  final int energy;
  final IconData icon;
  final Color barColor;

  /// Hangi mini-oyunu açtığı. null olan kartların henüz oyunu yok; butonları
  /// 'Yakında' olarak pasif görünür.
  final TrainingDrill? drill;
}

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _success = Color(0xFF3DDC97);
  static const _warning = Color(0xFFF5A623);

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  // NOT: buradaki progress değerleri training_radar_screen.dart içinde de
  // sabit olarak duruyor. İkisi PlayerState bağlantısı gelince tek kaynağa
  // katlanacak — asıl sapmaya başlayacakları an orası.
  static const _physical = [
    _TrainingItem(
      title: 'Kondisyon Koşusu',
      lastDone: '2 gün önce yapıldı',
      progress: 0.64,
      energy: 15,
      icon: Icons.directions_run,
      barColor: TrainingScreen._accent,
      drill: TrainingDrill.conditioning,
    ),
    _TrainingItem(
      title: 'Güç Antrenmanı',
      lastDone: '5 gün önce yapıldı',
      progress: 0.38,
      energy: 20,
      icon: Icons.fitness_center,
      barColor: TrainingScreen._accent,
      drill: TrainingDrill.strength,
    ),
    _TrainingItem(
      title: 'Esneklik & Toparlanma',
      lastDone: 'Bugün yapıldı',
      progress: 0.92,
      energy: 8,
      icon: Icons.self_improvement,
      barColor: TrainingScreen._success,
    ),
    _TrainingItem(
      title: 'Şut',
      lastDone: '3 gün önce yapıldı',
      progress: 0.50,
      energy: 18,
      icon: Icons.sports_soccer,
      barColor: TrainingScreen._accent,
      drill: TrainingDrill.shot,
    ),
    _TrainingItem(
      title: 'Pas',
      lastDone: '1 gün önce yapıldı',
      progress: 0.80,
      energy: 12,
      icon: Icons.swap_horiz,
      barColor: TrainingScreen._success,
      drill: TrainingDrill.pass,
    ),
    _TrainingItem(
      title: 'Dribling',
      lastDone: '6 gün önce yapıldı',
      progress: 0.25,
      energy: 18,
      icon: Icons.directions_walk,
      barColor: TrainingScreen._warning,
    ),
  ];

  static const _tactical = <_TrainingItem>[];

  _TrainingTab _tab = _TrainingTab.physical;

  List<_TrainingItem> get _items =>
      _tab == _TrainingTab.physical ? _physical : _tactical;

  /// Mini-oyunu açar ve sonucunu bekler. Geri tuşuyla çıkılırsa sonuç null
  /// gelir; bu başarısızlık değil, hiçbir şey uygulanmaz.
  Future<void> _start(TrainingDrill drill) async {
    final route = switch (drill) {
      TrainingDrill.conditioning => MaterialPageRoute<TrainingResult>(
          builder: (_) => const ConditioningTrainingScreen(),
        ),
      TrainingDrill.strength => MaterialPageRoute<TrainingResult>(
          builder: (_) => const StrengthTrainingScreen(),
        ),
      TrainingDrill.shot => MaterialPageRoute<TrainingResult>(
          builder: (_) => const BallTrainingScreen(mode: ShotMode.shot),
        ),
      TrainingDrill.pass => MaterialPageRoute<TrainingResult>(
          builder: (_) => const BallTrainingScreen(mode: ShotMode.pass),
        ),
      TrainingDrill.flexibility || TrainingDrill.dribble => null,
    };
    if (route == null) return;

    final result = await Navigator.of(context).push(route);
    if (!mounted || result == null) return;
    _applyResult(result);
  }

  /// Antrenman sonucunun kalıcı etkisi burada uygulanacak: yetenek puanı,
  /// enerji harcaması ve kartın ilerleme çubuğu. Şu an bilerek boş —
  /// [TrainingResult] zaten hangi antrenman, başarılı mı ve ne kadar iyi
  /// gittiğini taşıyor; buraya eklenecek tek şey PlayerScope mutasyonu.
  ///
  /// Örnek (henüz uygulanmıyor):
  ///   PlayerScope.of(context).applyActivity(
  ///     conditionDelta: result.succeeded ? 4 : -2, cost: 0);
  void _applyResult(TrainingResult result) {}

  @override
  Widget build(BuildContext context) {
    final condition = PlayerScope.of(context).condition;

    return Scaffold(
      backgroundColor: TrainingScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: TrainingScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: TrainingScreen._border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _HeaderSection(
                        condition: condition,
                        onExplore: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TrainingRadarScreen(),
                            ),
                          );
                        },
                      ),
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
                                _tab == _TrainingTab.physical ? -0.06 : 0.06,
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
                          child: _items.isEmpty
                              ? const Center(
                                  key: ValueKey('empty'),
                                  child: Text(
                                    'Taktiksel antrenmanlar yakında.',
                                    style: TextStyle(
                                      color: TrainingScreen._textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  key: ValueKey<_TrainingTab>(_tab),
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return _TrainingCard(
                                      item: item,
                                      onStart: item.drill == null
                                          ? null
                                          : () => _start(item.drill!),
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
  const _HeaderSection({
    required this.condition,
    required this.onExplore,
  });

  final int condition;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TrainingScreen._border, width: 0.5),
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
              color: TrainingScreen._textMuted,
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
                    // Etiket sıkışırsa kısalsın: sayı okunaklı kalmalı, 120
                    // piksele sığmadığında taşan taraf yazı olmalı.
                    const Flexible(
                      child: Text(
                        'Kondisyon',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: TrainingScreen._textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$condition/100',
                      maxLines: 1,
                      style: const TextStyle(
                        color: TrainingScreen._textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: condition / 100,
                    minHeight: 5,
                    backgroundColor: TrainingScreen._surface1,
                    color: TrainingScreen._success,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onExplore,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Keşfet',
            icon: const Icon(
              Icons.explore_outlined,
              size: 22,
              color: TrainingScreen._textMuted,
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

  final _TrainingTab tab;
  final ValueChanged<_TrainingTab> onChanged;

  @override
  Widget build(BuildContext context) {
    const height = 30.0;
    const padding = 2.0;
    const segmentWidth = 78.0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: TrainingScreen._surface1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox(
        width: segmentWidth * 2,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: tab == _TrainingTab.physical
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: segmentWidth,
                height: height - padding * 2,
                decoration: BoxDecoration(
                  color: TrainingScreen._accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                _ToggleLabel(
                  width: segmentWidth,
                  label: 'Fiziksel',
                  selected: tab == _TrainingTab.physical,
                  onTap: () => onChanged(_TrainingTab.physical),
                ),
                _ToggleLabel(
                  width: segmentWidth,
                  label: 'Taktiksel',
                  selected: tab == _TrainingTab.tactical,
                  onTap: () => onChanged(_TrainingTab.tactical),
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
                  ? TrainingScreen._textPrimary
                  : TrainingScreen._textMuted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.item, required this.onStart});

  final _TrainingItem item;

  /// null ise kartın mini-oyunu yok: buton pasifleşir ve 'Yakında' yazar.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        color: TrainingScreen._surface1,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 92,
            color: TrainingScreen._surface2,
            alignment: Alignment.center,
            child: Icon(
              item.icon,
              size: 26,
              color: TrainingScreen._textMuted,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TrainingScreen._textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.lastDone,
                    style: const TextStyle(
                      color: TrainingScreen._textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 5,
                      backgroundColor: TrainingScreen._surface2,
                      color: item.barColor,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.bolt,
                        size: 13,
                        color: TrainingScreen._textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${item.energy}',
                        style: const TextStyle(
                          color: TrainingScreen._textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: onStart,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TrainingScreen._textPrimary,
                          disabledForegroundColor: TrainingScreen._textMuted,
                          side: const BorderSide(
                            color: TrainingScreen._border,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(onStart == null ? 'Yakında' : 'Başla'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
