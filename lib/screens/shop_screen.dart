import 'package:flutter/material.dart';

import 'package:project_srpg/game/attribute_labels.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/shop_item_card.dart';

/// §14.2 · N3 `category` değerleriyle birebir aynı isimler. Altı giyilebilir
/// kategori (`clothing`…`special`) artı eskiden beri var olan ikisi.
enum ShopCategory {
  clothing('Giyim'),
  accessory('Aksesuar'),
  tech('Teknoloji'),
  vehicle('Araç'),
  living('Ev'),
  special('Özel'),
  realEstate('Gayrimenkul'),
  investment('Yatırım');

  const ShopCategory(this.label);

  final String label;

  static ShopCategory? byName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// §5.8 — ikon ve renk tonu BE'den gelmez, FE'nin sunum kararı. `catalog_id`
/// sabit olduğu için burada elle eşleniyor.
const _iconBySlot = {
  'shoes': Icons.directions_walk,
  'top': Icons.checkroom,
  'outerwear': Icons.dry_cleaning,
  'formal': Icons.business_center,
  'eyewear': Icons.visibility,
  'bracelet': Icons.circle_outlined,
  'wallet': Icons.account_balance_wallet,
  'fragrance': Icons.spa,
  'necklace': Icons.diamond_outlined,
  'bag': Icons.backpack,
  'watch': Icons.watch,
  'ring': Icons.diamond,
  'phone': Icons.smartphone,
  'earbuds': Icons.headphones,
  'stream_kit': Icons.mic,
  'photographer': Icons.photo_camera,
  'media_team': Icons.videocam,
  'vehicle': Icons.directions_car,
  'plants': Icons.local_florist,
  'audio_home': Icons.album,
  'kitchen': Icons.coffee,
  'cinema': Icons.tv,
  'art': Icons.palette,
  'jersey': Icons.sports_soccer,
  'goal_ball': Icons.sports_soccer,
  'signature_boots': Icons.sports_soccer,
  'membership': Icons.card_membership,
  'foundation': Icons.volunteer_activism,
};

/// Yuvası olmayan kalemler (gayrimenkul, yatırım) kendi kimliğiyle eşlenir.
const _iconByCatalogId = {
  'estate-studio': Icons.apartment,
  'estate-flat': Icons.location_city,
  'estate-villa': Icons.villa,
  'invest-bond': Icons.account_balance,
  'invest-gold': Icons.savings,
  'invest-fund': Icons.trending_up,
};

/// Giyilebilir kalemlerin tonu kategoriden gelir; 40 kimliği tek tek saymaktan
/// iyi, çünkü aynı kategori aynı renkte okunuyor.
const _tintByCategory = {
  'clothing': Color(0xFF4A5568),
  'accessory': AppColors.warning,
  'tech': AppColors.accent,
  'vehicle': AppColors.success,
  'living': Color(0xFFB07A4B),
  'special': Color(0xFF7A5CD0),
};

const _tintByCatalogId = {
  'estate-studio': Color(0xFF5A7D9A),
  'estate-flat': AppColors.accent,
  'estate-villa': AppColors.success,
  'invest-bond': Color(0xFF4A5568),
  'invest-gold': AppColors.warning,
  'invest-fund': AppColors.success,
};

const _defaultTint = AppColors.textMuted;

/// §12.12 · `daily_effects`'ten Türkçe bir rozet etiketi türetir. Birden
/// fazla anahtar taşıyan bir kalem yok bugün, o yüzden ilk eşleşen yeterli.
String? _dailyBenefitLabelFor(Map<String, dynamic> dailyEffects) {
  for (final entry in dailyEffects.entries) {
    final amount = (entry.value as num).toString();
    switch (entry.key) {
      case 'condition':
        return 'Günlük +$amount kondisyon';
      case 'energy':
        return 'Günlük +$amount enerji';
      case 'fame:overall':
        return 'Günlük +$amount şöhret';
    }
  }
  return null;
}

/// §13.3 · `passive_effects`'ten rozet. `daily_effects`'inkinden ayrı bir
/// cümle kuruyor çünkü ayrı bir şey anlatıyor: bu bonus her gün *yazılmıyor*,
/// eşya durduğu sürece *var* — ve eşya gidince kendiliğinden kayboluyor.
/// Birden fazla nitelik taşıyan tek kalem villa; hepsi listeleniyor.
String? _passiveBenefitLabelFor(Map<String, double> passiveEffects) {
  if (passiveEffects.isEmpty) return null;
  final parts = [
    for (final entry in passiveEffects.entries)
      '${attributeLabel(entry.key.split(':').last)} '
          '+${entry.value.toStringAsFixed(entry.value % 1 == 0 ? 0 : 1)}',
  ];
  return 'Sahipken ${parts.join(' · ')}';
}

/// İki rozetin tek satırı. Bir kalem ikisini birden taşıyabiliyor
/// (`estate-flat`: günlük kondisyon + sahipken özgüven), o yüzden
/// birleştiriliyor; kart tek bir `benefitLabel` alanı taşıyor.
String? _benefitLabelFor(api.CatalogItem item) {
  final labels = [
    ?_dailyBenefitLabelFor(item.dailyEffects),
    ?_passiveBenefitLabelFor(item.passiveEffects),
  ];
  return labels.isEmpty ? null : labels.join(' · ');
}

ShopItem _toShopItem(api.CatalogItem item) {
  return ShopItem(
    id: item.catalogId,
    title: item.title,
    description: item.description ?? '',
    icon: _iconByCatalogId[item.catalogId] ??
        _iconBySlot[item.slot] ??
        Icons.shopping_bag_outlined,
    tint: _tintByCatalogId[item.catalogId] ??
        _tintByCategory[item.group] ??
        _defaultTint,
    price: item.price ?? 0,
    note: item.note,
    benefitLabel: _benefitLabelFor(item),
    grade: item.grade,
    slot: item.slot,
    grantOnly: item.grantOnly,
  );
}

/// N3'ün `category` alanı `ShopCategory`'nin kendi isimleriyle birebir aynı
/// (§5.7, career_engine/catalog/shop.py) — çeviri katmanı gerekmez.
Map<ShopCategory, List<ShopItem>> _catalogueFrom(List<api.CatalogItem> items) {
  final byCategory = <ShopCategory, List<ShopItem>>{
    for (final category in ShopCategory.values) category: [],
  };
  for (final item in items) {
    final category = ShopCategory.byName(item.group ?? '');
    if (category != null) byCategory[category]!.add(_toShopItem(item));
  }
  return byCategory;
}

/// Dört kategoriye ayrılmış vitrin. Kartlar Yaşam Tarzı ekranıyla aynı cam
/// dilini konuşuyor; satın alma T4 (`POST /careers/{cid}/purchases`) ile
/// backend'e yazılır.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

const _cardWidth = 172.0;
const _cardHeight = 210.0;
const _detailCardWidth = 240.0;
const _detailCardHeight = 293.0;

class _ShopScreenState extends State<ShopScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  late Future<api.Catalog> _catalogFuture;

  ShopCategory _category = ShopCategory.clothing;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _session.client.catalog('shop');
    // PlayerScope'a ilk karede ulaşılır: initState'te bağımlılık kurulamaz.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInventory());
  }

  /// §14.2 · sahiplik ve "giyili mi" sunucudan gelir. Ekran açılırken bir kez
  /// çekilir; başarısızsa oturumdaki işaretlere güvenilir (vitrin yine çalışır).
  Future<void> _loadInventory() async {
    final player = PlayerScope.of(context);
    try {
      final careerId = await _session.resolveExisting();
      if (careerId == null) return;
      final items = await _session.client.inventory(careerId);
      if (!mounted) return;
      player.applyInventory(items);
    } catch (_) {
      // Katalog gelmiş olabilir; envanter gelmediyse vitrin boş sahiplikle açılır.
    }
  }

  void _openItem(ShopItem item) {
    Navigator.of(context).push(
      _ShopItemDetailRoute(item: item, session: _session),
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
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _HeaderSection(moneyLabel: player.moneyLabel),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _CategoryTabs(
                          category: _category,
                          onChanged: (next) =>
                              setState(() => _category = next),
                        ),
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
                                  'Dükkân kataloğu alınamadı.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }

                            final catalogue =
                                _catalogueFrom(snapshot.data!.items);
                            final items = catalogue[_category]!;

                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final offset = Tween<Offset>(
                                  begin: const Offset(0.06, 0),
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
                              child: GridView.builder(
                                key: ValueKey<ShopCategory>(_category),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                // Kart gölgeleri kırpılmasın.
                                clipBehavior: Clip.none,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: _cardWidth / _cardHeight,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final owned = player.owns(item.id);
                                  final affordable = item.grantOnly ||
                                      player.canAfford(item.price);
                                  return _HeroShopCard(
                                    item: item,
                                    owned: owned,
                                    equipped: player.isEquipped(item.id),
                                    affordable: affordable,
                                    faded: !owned && !affordable,
                                    onTap: () => _openItem(item),
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
  const _HeaderSection({required this.moneyLabel});

  final String moneyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          const SizedBox(width: 10),
          const Text(
            'Alışveriş',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            moneyLabel,
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sekmeler. Yaşam Tarzı'ndaki ikili pil toggle dört segmentte rahattı; sekiz
/// kategori tek satıra sığmıyor ve kaydırılan bir şerit, ekrandaki son sekmeyi
/// görünmez bırakıyordu — bu yüzden sığmayanı alt satıra taşıyan çipler.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.category, required this.onChanged});

  final ShopCategory category;
  final ValueChanged<ShopCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in ShopCategory.values)
          _TabLabel(
            label: value.label,
            selected: value == category,
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface1,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Kartı Hero ile sarar; içerik hep aynı iç ölçüde çizilip [FittedBox] ile
/// ölçeklendiği için uçuş sırasında taşma olmaz.
class _HeroShopCard extends StatelessWidget {
  const _HeroShopCard({
    required this.item,
    required this.owned,
    this.equipped = false,
    required this.affordable,
    this.faded = false,
    this.onTap,
    this.width = _cardWidth,
    this.height = _cardHeight,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool affordable;
  final bool faded;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'shop-${item.id}',
      child: SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.fill,
          child: ShopItemCard(
            item: item,
            owned: owned,
            equipped: equipped,
            affordable: affordable,
            faded: faded,
            width: _cardWidth,
            height: _cardHeight,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// Karta basılınca kartın öne gelip büyüdüğü, altında açıklama ve satın alma
/// butonunun belirdiği yarı saydam katman.
class _ShopItemDetailRoute extends PageRouteBuilder<void> {
  _ShopItemDetailRoute({required this.item, required this.session})
      : super(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _ShopItemDetailPage(
              item: item,
              animation: animation,
              session: session,
            );
          },
        );

  final ShopItem item;
  final CareerSession session;
}

class _ShopItemDetailPage extends StatefulWidget {
  const _ShopItemDetailPage({
    required this.item,
    required this.animation,
    required this.session,
  });

  final ShopItem item;
  final Animation<double> animation;
  final CareerSession session;

  @override
  State<_ShopItemDetailPage> createState() => _ShopItemDetailPageState();
}

class _ShopItemDetailPageState extends State<_ShopItemDetailPage> {
  bool _busy = false;

  /// T4 · `POST /careers/{cid}/purchases`. Zaten sahipse BE `409
  /// already_owned`, bakiye yetmezse `409 insufficient_funds` döner (INV-5) —
  /// ikisinde de hiçbir şey yazılmaz; burada yalnızca bir uyarı gösterilir.
  Future<void> _buy(BuildContext context) async {
    final item = widget.item;
    setState(() => _busy = true);
    final player = PlayerScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final careerId = await widget.session.resolve();
      final result = await widget.session.client.purchase(careerId, item.id);
      player.applyServerUpdate(careerState: result.careerState);
      // §14.2 · yuva boşsa kalem satın alınır alınmaz giyilir; bonus da o an
      // başlar, o yüzden nitelikleri (seviyeler BE'den) P1'den tazele.
      player.markOwned(item.id, equipped: result.item.equipped);
      if (result.item.equipped) player.load();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${item.title} satın alındı.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } on CareerApiException catch (e) {
      if (!context.mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Satın alma başarısız.')),
      );
    }
  }

  /// §14.2 · `POST /inventory/{id}/equip|unequip`. Aynı yuvadaki öncekini
  /// sunucu çıkarır (INV-66); istemci yalnız dönen listeyi yazar ve P1'i
  /// tazeler, çünkü seviye ölçeği BE'de.
  Future<void> _toggleEquip(BuildContext context, bool equipped) async {
    final item = widget.item;
    setState(() => _busy = true);
    final player = PlayerScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final careerId = await widget.session.resolve();
      final client = widget.session.client;
      final result = equipped
          ? await client.unequipItem(careerId, item.id)
          : await client.equipItem(careerId, item.id);
      player.applyServerUpdate(careerState: result.careerState);
      player.applyInventory(result.items);
      player.load();
      if (!mounted) return;
      setState(() => _busy = false);
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'İşlem başarısız.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final animation = widget.animation;
    final player = PlayerScope.of(context);
    final owned = player.owns(item.id);
    final equipped = player.isEquipped(item.id);
    final affordable = item.grantOnly || player.canAfford(item.price);

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
                      _HeroShopCard(
                        item: item,
                        owned: owned,
                        equipped: equipped,
                        affordable: affordable,
                        width: _detailCardWidth,
                        height: _detailCardHeight,
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: details,
                        child: _ItemDetails(
                          item: item,
                          owned: owned,
                          equipped: equipped,
                          affordable: affordable,
                          onBuy: _busy ? null : () => _buy(context),
                          onToggleEquip: _busy
                              ? null
                              : () => _toggleEquip(context, equipped),
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

class _ItemDetails extends StatelessWidget {
  const _ItemDetails({
    required this.item,
    required this.owned,
    required this.affordable,
    required this.onBuy,
    this.equipped = false,
    this.onToggleEquip,
    this.busy = false,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool affordable;
  final VoidCallback? onBuy;

  /// §14.2 · sahip olunan giyilebilir kalemde düğme Tak/Çıkar'a döner.
  final VoidCallback? onToggleEquip;
  final bool busy;

  /// Sahip olunan giyilebilir kalemde tek düğme iki iş yapıyor: satın alma
  /// bitti, geriye giymek ya da çıkarmak kalıyor.
  bool get _wearable => owned && item.equippable;

  String get _buttonLabel {
    if (_wearable) return equipped ? 'Çıkar' : 'Tak';
    if (owned) return 'Sahipsin';
    if (item.grantOnly) return 'Bir olayla kazanılır';
    if (!affordable) return 'Bakiye yetersiz';
    return 'Satın Al';
  }

  @override
  Widget build(BuildContext context) {
    final note = item.note;
    final enabled = _wearable || (!owned && !item.grantOnly && affordable);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.description,
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
                icon: Icons.payments_outlined,
                label: item.priceLabel,
                color: affordable || owned
                    ? AppColors.warning
                    : AppColors.danger,
              ),
              if (note != null)
                _Badge(
                  icon: Icons.info_outline,
                  label: note,
                  color: AppColors.textSecondary,
                ),
              if (owned)
                _Badge(
                  icon: equipped ? Icons.checkroom : Icons.check,
                  label: equipped ? 'Takılı' : 'Sahip',
                  color: AppColors.success,
                ),
              // §12.12 · `note`'dan ayrı, canlı bir rozet: sahip olunan bir
              // kalemin gerçekte ne sağladığı, vitrin metninden ayrışıyor.
              if (owned && (!item.equippable || equipped) && item.benefitLabel != null)
                _Badge(
                  icon: Icons.auto_awesome,
                  label: item.benefitLabel!,
                  color: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? (_wearable ? onToggleEquip : onBuy) : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.surface2,
                disabledForegroundColor: AppColors.textMuted,
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
                  : Text(_buttonLabel),
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
