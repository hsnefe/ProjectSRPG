import 'package:flutter/material.dart';
import 'package:project_srpg/game/attribute_labels.dart';
import 'package:project_srpg/game/shot_game.dart' show ShotMode;
import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/ball_training_screen.dart';
import 'package:project_srpg/screens/conditioning_training_screen.dart';
import 'package:project_srpg/screens/strength_training_screen.dart';
import 'package:project_srpg/screens/training_radar_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/state/player_state.dart';
import 'package:project_srpg/theme/app_colors.dart';

enum _TrainingTab { physical, personal }

class _TrainingItem {
  const _TrainingItem({
    required this.catalogId,
    required this.title,
    required this.progress,
    required this.energy,
    required this.icon,
    required this.barColor,
    this.drill,
    this.unmetRequirements = const {},
  });

  final String catalogId;
  final String title;

  /// Oyuncunun bu antrenmanın hedeflediği niteliği ne kadar geliştirdiği,
  /// 0-1 arası — P1'deki ilgili `attribute` değerinden türetilir (N3 kartın
  /// kendi "ilerleme" sayısını vermez, yalnızca hangi niteliği hedeflediğini
  /// `effects`'te taşır).
  final double progress;
  final int energy;
  final IconData icon;
  final Color barColor;

  /// Hangi mini-oyunu açtığı. null olan kartların henüz oyunu yok; butonları
  /// 'Yakında' olarak pasif görünür.
  final TrainingDrill? drill;

  /// D42 · karşılanmayan nitelik eşikleri. Boşsa kart açıktır. 'Yakında'dan
  /// ayrı bir durum: o kartın mini-oyunu **yok**, bu kartın oyunu var ama
  /// oyuncu henüz yeterli değil.
  final Map<String, int> unmetRequirements;

  bool get locked => unmetRequirements.isNotEmpty;
}

/// N3 `drill` string'i → [TrainingDrill]. Yalnızca gerçek bir mini-oyunu
/// olan dört değer eşlenir; kalanı (esneklik, dribling, bütün kişi kalemleri)
/// backend zaten `null` gönderiyor.
const _drillByKey = {
  'conditioning': TrainingDrill.conditioning,
  'strength': TrainingDrill.strength,
  'shot': TrainingDrill.shot,
  'pass': TrainingDrill.pass,
};

/// §5.8 — ikon ve renk BE'den gelmez, FE'nin sunum kararı. `catalog_id`
/// sabit olduğu için burada elle eşleniyor.
const _iconByCatalogId = {
  'kondisyon-kosusu': Icons.directions_run,
  'guc-antrenmani': Icons.fitness_center,
  'esneklik-toparlanma': Icons.self_improvement,
  'sut': Icons.sports_soccer,
  'pas': Icons.swap_horiz,
  'dribling': Icons.directions_walk,
  'medya-egitimi': Icons.mic_outlined,
  'gorgu-dersleri': Icons.handshake_outlined,
  'ozguven-koclugu': Icons.psychology_outlined,
  'satranc-kulubu': Icons.extension_outlined,
  'kriz-simulasyonu': Icons.bolt_outlined,
};

/// `effects` haritasındaki `attribute:<key>` anahtarını bulur — kartın hangi
/// niteliği hedeflediği budur.
String? _targetAttributeOf(api.CatalogItem item) {
  for (final key in item.effects.keys) {
    if (key.startsWith('attribute:')) return key.substring('attribute:'.length);
  }
  return null;
}

Color _barColorFor(double progress) {
  if (progress >= 0.75) return AppColors.success;
  if (progress >= 0.4) return AppColors.accent;
  return AppColors.warning;
}

_TrainingItem _toTrainingItem(api.CatalogItem item, PlayerState player) {
  final targetKey = _targetAttributeOf(item);
  final progress = targetKey == null ? 0.0 : player.attribute(targetKey) / 100;
  return _TrainingItem(
    catalogId: item.catalogId,
    title: item.title,
    progress: progress.clamp(0, 1),
    energy: (item.costs['energy'] ?? 0).toInt(),
    icon: _iconByCatalogId[item.catalogId] ?? Icons.fitness_center,
    barColor: _barColorFor(progress),
    drill: _drillByKey[item.drill],
    unmetRequirements: unmetRequirements(item.requires, player.attributeLevel),
  );
}

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  late Future<api.Catalog> _catalogFuture;

  _TrainingTab _tab = _TrainingTab.physical;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _session.client.catalog('training');
  }

  /// Mini-oyunu açar ve sonucunu bekler. Geri tuşuyla çıkılırsa sonuç null
  /// gelir; bu başarısızlık değil, hiçbir şey uygulanmaz.
  Future<void> _start(_TrainingItem item) async {
    final drill = item.drill;
    if (drill == null) return;
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
    await _applyResult(item.catalogId, result);
  }

  /// T2 · `POST /careers/{cid}/actions` — mini-oyunun sonucunu uygular.
  /// Bütçe/para yetmezse (`409`) BE hiçbir şey yazmaz (INV-3/4); burada da
  /// yalnızca bir uyarı gösterip vazgeçilir.
  Future<void> _applyResult(String catalogId, TrainingResult result) async {
    final player = PlayerScope.of(context);
    try {
      final careerId = await _session.resolve();
      final actionResult = await _session.client.postAction(
        careerId,
        catalogId: catalogId,
        result: {'minigame_score': result.score},
      );
      player.applyServerUpdate(
        careerState: actionResult.careerState,
        attributeChanges: actionResult.attributeChanges,
      );
    } on CareerApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Antrenman uygulanamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final condition = PlayerScope.of(context).condition;

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
                        child: FutureBuilder<api.Catalog>(
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
                                  'Antrenman kataloğu alınamadı.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }

                            final player = PlayerScope.of(context);
                            final items = snapshot.data!.items
                                .where((i) => i.family ==
                                    (_tab == _TrainingTab.physical
                                        ? 'saha'
                                        : 'kişi'))
                                .map((i) => _toTrainingItem(i, player))
                                .toList(growable: false);

                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final offset = Tween<Offset>(
                                  begin: Offset(
                                    _tab == _TrainingTab.physical
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
                              child: items.isEmpty
                                  ? const Center(
                                      key: ValueKey('empty'),
                                      child: Text(
                                        'Bu kategoride henüz antrenman yok.',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      key: ValueKey<_TrainingTab>(_tab),
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 16, 20, 20),
                                      itemCount: items.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        return _TrainingCard(
                                          item: item,
                                          onStart:
                                              (item.drill == null || item.locked)
                                                  ? null
                                                  : () => _start(item),
                                        );
                                      },
                                    ),
                            );
                          },
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
                    // Etiket sıkışırsa kısalsın: sayı okunaklı kalmalı, 120
                    // piksele sığmadığında taşan taraf yazı olmalı.
                    const Flexible(
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
                    const SizedBox(width: 4),
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
                  child: LinearProgressIndicator(
                    value: condition / 100,
                    minHeight: 5,
                    backgroundColor: AppColors.surface1,
                    color: AppColors.success,
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
              alignment: tab == _TrainingTab.physical
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
                  label: 'Fiziksel',
                  selected: tab == _TrainingTab.physical,
                  onTap: () => onChanged(_TrainingTab.physical),
                ),
                _ToggleLabel(
                  width: segmentWidth,
                  label: 'Kişisel',
                  selected: tab == _TrainingTab.personal,
                  onTap: () => onChanged(_TrainingTab.personal),
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

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.item, required this.onStart});

  final _TrainingItem item;

  /// null ise kartın mini-oyunu yok: buton pasifleşir ve 'Yakında' yazar.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 92,
            color: AppColors.surface2,
            alignment: Alignment.center,
            child: Icon(
              item.icon,
              size: 26,
              color: AppColors.textMuted,
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
                    style: TextStyle(
                      color: item.locked
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  // D42 · butondaki 'Kilitli' neyin eksik olduğunu söylemez;
                  // eşiği başlığın altında yazıyoruz.
                  if (item.locked) ...[
                    const SizedBox(height: 3),
                    Row(
                      key: const Key('training_requirement_row'),
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            requirementLabel(item.unmetRequirements),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 5,
                      backgroundColor: AppColors.surface2,
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
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${item.energy}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: onStart,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          disabledForegroundColor: AppColors.textMuted,
                          side: const BorderSide(
                            color: AppColors.border,
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
                        child: Text(
                          item.locked
                              ? 'Kilitli'
                              : (onStart == null ? 'Yakında' : 'Başla'),
                        ),
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
