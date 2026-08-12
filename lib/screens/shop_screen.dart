import 'package:flutter/material.dart';

import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/widgets/shop_item_card.dart';

enum ShopCategory {
  home('Ev'),
  personal('Kişisel'),
  realEstate('Gayrimenkul'),
  investment('Yatırım');

  const ShopCategory(this.label);

  final String label;
}

/// Dört kategoriye ayrılmış vitrin. Kartlar Yaşam Tarzı ekranıyla aynı cam
/// dilini konuşuyor; satın alma parayı [PlayerState] üzerinden düşürüyor.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

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
  State<ShopScreen> createState() => _ShopScreenState();
}

const _cardWidth = 172.0;
const _cardHeight = 210.0;
const _detailCardWidth = 240.0;
const _detailCardHeight = 293.0;

class _ShopScreenState extends State<ShopScreen> {
  static const _catalogue = <ShopCategory, List<ShopItem>>{
    ShopCategory.home: [
      ShopItem(
        id: 'home-tv',
        title: 'Akıllı TV',
        description:
            'Oturma odasına 65 inç. Maç akşamları arkadaşları çağırmak için '
            'yeterince büyük.',
        icon: Icons.tv,
        tint: Color(0xFF1E6FD9),
        price: 32000,
        note: '65 inç, 4K',
      ),
      ShopItem(
        id: 'home-espresso',
        title: 'Espresso makinesi',
        description:
            'Sabah antrenmanından önce kahve kuyruğunda beklemeye son.',
        icon: Icons.coffee,
        tint: Color(0xFFB07A4B),
        price: 12500,
        note: 'Otomatik öğütücülü',
      ),
      ShopItem(
        id: 'home-console',
        title: 'Oyun konsolu',
        description:
            'Boş günlerin standart eğlencesi. Takım arkadaşlarıyla online '
            'turnuvalar için de iyi bahane.',
        icon: Icons.sports_esports,
        tint: Color(0xFF7A5CD0),
        price: 18900,
        note: 'İki kollu',
      ),
      ShopItem(
        id: 'home-treadmill',
        title: 'Koşu bandı',
        description:
            'Kamp dışı günlerde kondisyonu evde korumanın en kolay yolu.',
        icon: Icons.directions_run,
        tint: Color(0xFF3DDC97),
        price: 41000,
        note: 'Eğimli, 20 km/s',
      ),
    ],
    ShopCategory.personal: [
      ShopItem(
        id: 'personal-watch',
        title: 'Kol saati',
        description: 'Röportajlarda ve sponsor çekimlerinde görünen tek takı.',
        icon: Icons.watch,
        tint: Color(0xFFF5A623),
        price: 27500,
        note: 'Çelik kasa',
      ),
      ShopItem(
        id: 'personal-boots',
        title: 'Krampon',
        description:
            'Kendi ayağına göre kalıplanmış çift. Islak zeminde fark ediyor.',
        icon: Icons.sports_soccer,
        tint: Color(0xFF3DDC97),
        price: 8900,
        note: 'Kişiye özel kalıp',
      ),
      ShopItem(
        id: 'personal-suit',
        title: 'Takım elbise',
        description: 'Deplasman yolculukları ve kulüp galaları için.',
        icon: Icons.checkroom,
        tint: Color(0xFF4A5568),
        price: 15400,
        note: 'Ismarlama',
      ),
      ShopItem(
        id: 'personal-headphones',
        title: 'Kulaklık',
        description:
            'Otobüs yolculuklarında dış sesi kesiyor; maç öncesi rutinin '
            'parçası.',
        icon: Icons.headphones,
        tint: Color(0xFF1E6FD9),
        price: 6200,
        note: 'Gürültü engelleyici',
      ),
    ],
    ShopCategory.realEstate: [
      ShopItem(
        id: 'estate-studio',
        title: 'Stüdyo daire',
        description:
            'Tesise on beş dakika. Küçük ama kendi başına yaşamak için yeterli.',
        icon: Icons.apartment,
        tint: Color(0xFF5A7D9A),
        price: 1850000,
        note: '1+0, 55 m²',
      ),
      ShopItem(
        id: 'estate-flat',
        title: 'Şehir merkezi daire',
        description: 'Merkezde geniş bir kat. Aile ziyaretleri için yer var.',
        icon: Icons.location_city,
        tint: Color(0xFF1E6FD9),
        price: 4600000,
        note: '3+1, 120 m²',
      ),
      ShopItem(
        id: 'estate-villa',
        title: 'Deniz manzaralı villa',
        description:
            'Sezon arasında kaçılacak yer. Bahçesinde kendi antrenman alanı '
            'kurulabilir.',
        icon: Icons.villa,
        tint: Color(0xFF3DDC97),
        price: 12750000,
        note: 'Havuzlu, 380 m²',
      ),
    ],
    ShopCategory.investment: [
      ShopItem(
        id: 'invest-bond',
        title: 'Devlet tahvili',
        description:
            'Sıkıcı ama öngörülebilir. Kariyerin geri kalanı için güvenli zemin.',
        icon: Icons.account_balance,
        tint: Color(0xFF4A5568),
        price: 25000,
        note: 'Yıllık %28 getiri',
      ),
      ShopItem(
        id: 'invest-gold',
        title: 'Altın',
        description: 'Kasaya girer, unutulur. Enflasyona karşı klasik siper.',
        icon: Icons.savings,
        tint: Color(0xFFF5A623),
        price: 40000,
        note: '100 gram',
      ),
      ShopItem(
        id: 'invest-fund',
        title: 'Hisse portföyü',
        description:
            'Menajerin önerdiği karma fon. Dalgalı ama uzun vadede iddialı.',
        icon: Icons.trending_up,
        tint: Color(0xFF3DDC97),
        price: 120000,
        note: 'Orta risk',
      ),
    ],
  };

  ShopCategory _category = ShopCategory.home;

  void _openItem(ShopItem item) {
    Navigator.of(context).push(_ShopItemDetailRoute(item: item));
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final items = _catalogue[_category]!;

    return Scaffold(
      backgroundColor: ShopScreen._surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ShopScreen._surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShopScreen._border, width: 0.5),
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
                        child: AnimatedSwitcher(
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
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                              final affordable = player.canAfford(item.price);
                              return _HeroShopCard(
                                item: item,
                                owned: owned,
                                affordable: affordable,
                                faded: !owned && !affordable,
                                onTap: () => _openItem(item),
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
  const _HeaderSection({required this.moneyLabel});

  final String moneyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ShopScreen._border, width: 0.5),
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
              color: ShopScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Alışveriş',
            style: TextStyle(
              color: ShopScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            moneyLabel,
            style: const TextStyle(
              color: ShopScreen._success,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yaşam Tarzı'ndaki ikili pil toggle'ın dörde genelleştirilmiş hâli: seçili
/// segment [AnimatedPositioned] ile kayıyor, genişlik gelen alandan bölünüyor.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.category, required this.onChanged});

  final ShopCategory category;
  final ValueChanged<ShopCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    const height = 30.0;
    const padding = 2.0;
    const values = ShopCategory.values;

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth =
            (constraints.maxWidth - padding * 2) / values.length;

        return Container(
          height: height,
          padding: const EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: ShopScreen._surface1,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: segmentWidth * values.indexOf(category),
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ShopScreen._accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in values)
                    _TabLabel(
                      width: segmentWidth,
                      label: value.label,
                      selected: value == category,
                      onTap: () => onChanged(value),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: selected
                      ? ShopScreen._textPrimary
                      : ShopScreen._textSecondary,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
                child: Text(label),
              ),
            ),
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
    required this.affordable,
    this.faded = false,
    this.onTap,
    this.width = _cardWidth,
    this.height = _cardHeight,
  });

  final ShopItem item;
  final bool owned;
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
  _ShopItemDetailRoute({required this.item})
      : super(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _ShopItemDetailPage(item: item, animation: animation);
          },
        );

  final ShopItem item;
}

class _ShopItemDetailPage extends StatelessWidget {
  const _ShopItemDetailPage({required this.item, required this.animation});

  final ShopItem item;
  final Animation<double> animation;

  void _buy(BuildContext context) {
    final bought = PlayerScope.of(context).purchase(
      id: item.id,
      price: item.price,
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (!bought) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('${item.title} satın alındı.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final owned = player.owns(item.id);
    final affordable = player.canAfford(item.price);

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
                          affordable: affordable,
                          onBuy: () => _buy(context),
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
  });

  final ShopItem item;
  final bool owned;
  final bool affordable;
  final VoidCallback onBuy;

  String get _buttonLabel {
    if (owned) return 'Sahipsin';
    if (!affordable) return 'Bakiye yetersiz';
    return 'Satın Al';
  }

  @override
  Widget build(BuildContext context) {
    final note = item.note;
    final enabled = !owned && affordable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ShopScreen._textSecondary,
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
                    ? ShopScreen._warning
                    : ShopScreen._danger,
              ),
              if (note != null)
                _Badge(
                  icon: Icons.info_outline,
                  label: note,
                  color: ShopScreen._textSecondary,
                ),
              if (owned)
                _Badge(
                  icon: Icons.check,
                  label: 'Sahip',
                  color: ShopScreen._success,
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onBuy : null,
              style: FilledButton.styleFrom(
                backgroundColor: ShopScreen._accent,
                foregroundColor: ShopScreen._textPrimary,
                disabledBackgroundColor: ShopScreen._surface2,
                disabledForegroundColor: ShopScreen._textMuted,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(_buttonLabel),
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
