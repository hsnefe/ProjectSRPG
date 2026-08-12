import 'dart:ui';

import 'package:flutter/material.dart';

class NewsItem {
  const NewsItem({
    required this.category,
    required this.title,
    required this.source,
    required this.timeAgo,
    required this.body,
    required this.icon,
    required this.tint,
    this.imageAsset,
  });

  final String category;
  final String title;
  final String source;
  final String timeAgo;
  final String body;

  /// Görsel yerine geçen filigran ikon ve kartın renk tonu.
  final IconData icon;
  final Color tint;

  /// Haber fotoğrafı. Null ise ton ve ikondan prosedürel bir görsel çizilir.
  final String? imageAsset;
}

class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({
    super.key,
    required this.news,
    required this.initialIndex,
  });

  final List<NewsItem> news;
  final int initialIndex;

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);

  late int _index;

  /// Geçiş animasyonunun yönü: sonraki habere giderken içerik soldan gelir.
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  NewsItem get _current => widget.news[_index];

  bool get _canGoPrev => _index > 0;
  bool get _canGoNext => _index < widget.news.length - 1;

  void _goPrev() {
    if (!_canGoPrev) return;
    setState(() {
      _forward = false;
      _index -= 1;
    });
  }

  void _goNext() {
    if (!_canGoNext) return;
    setState(() {
      _forward = true;
      _index += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;

    return Scaffold(
      backgroundColor: _surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _HeaderSection(
                        index: _index,
                        total: widget.news.length,
                        onBack: () => Navigator.of(context).pop(),
                        onPrev: _goPrev,
                        onNext: _goNext,
                        canGoPrev: _canGoPrev,
                        canGoNext: _canGoNext,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: Offset(_forward ? 0.06 : -0.06, 0),
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
                          // AnimatedSwitcher çocuklarını gevşek kısıtlarla
                          // ortalanmış bir Stack'e koyuyor; kendi boyuna
                          // büzüşen bir kaydırma görünümü bu yüzden dikeyde
                          // ortalanıp header'ın altında boşluk bırakıyordu.
                          child: SizedBox.expand(
                            key: ValueKey<int>(_index),
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _NewsHero(item: item),
                                  const SizedBox(height: 16),
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    item.body,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 14,
                                      height: 1.55,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Haberin görseli: aktivite kartlarıyla aynı cam reçetesi — tonlu gövde,
/// filigran ikon, üst ışık çizgisi ve altta gerçekten bulanıklaştırılmış şerit
/// üzerinde kategori ile kaynak.
class _NewsHero extends StatelessWidget {
  const _NewsHero({required this.item});

  static const _height = 200.0;
  static const _radius = 18.0;

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_radius);
    final asset = item.imageAsset;

    return SizedBox(
      height: _height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: item.tint.withValues(alpha: 0.18),
              blurRadius: 18,
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (asset != null)
                Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _ProceduralArt(item: item),
                )
              else
                _ProceduralArt(item: item),
              // Üst kenardaki ışık çizgisi.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              // Alt şerit: arkasındaki görüntüyü bulanıklaştırır.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _height * 0.30,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.46),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _CategoryPill(
                            label: item.category,
                            color: item.tint,
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              '${item.source} · ${item.timeAgo}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: _NewsDetailScreenState._textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Cam kenarlık, her şeyin üstünde.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fotoğraf yokken çizilen gövde: haberin renk tonundan koyuya inen gradient ve
/// kenardan taşan filigran ikon.
class _ProceduralArt extends StatelessWidget {
  const _ProceduralArt({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.tint.withValues(alpha: 0.55),
                item.tint.withValues(alpha: 0.22),
                const Color(0xFF12151B).withValues(alpha: 0.92),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          right: -_NewsHero._height * 0.10,
          top: -_NewsHero._height * 0.10,
          child: Icon(
            item.icon,
            size: _NewsHero._height * 0.62,
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.color});

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
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.index,
    required this.total,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
    required this.canGoPrev,
    required this.canGoNext,
  });

  final int index;
  final int total;
  final VoidCallback onBack;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool canGoPrev;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _NewsDetailScreenState._border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_left,
              size: 24,
              color: _NewsDetailScreenState._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Haber',
            style: TextStyle(
              color: _NewsDetailScreenState._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          _Pager(
            index: index,
            total: total,
            onPrev: onPrev,
            onNext: onNext,
            canGoPrev: canGoPrev,
            canGoNext: canGoNext,
          ),
        ],
      ),
    );
  }
}

/// Haberler arasında gezinme. Tek bir pil içinde toplanıyor: geri okuyla aynı
/// glifi paylaşan iki serbest ok, hangisinin ekrandan çıkardığı belli olmadığı
/// için kafa karıştırıyordu.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.index,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.canGoPrev,
    required this.canGoNext,
  });

  final int index;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool canGoPrev;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _NewsDetailScreenState._surface1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PagerButton(
            icon: Icons.chevron_left,
            tooltip: 'Önceki haber',
            onTap: canGoPrev ? onPrev : null,
          ),
          Text(
            '${index + 1}/$total',
            style: const TextStyle(
              color: _NewsDetailScreenState._textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          _PagerButton(
            icon: Icons.chevron_right,
            tooltip: 'Sonraki haber',
            onTap: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? _NewsDetailScreenState._textPrimary
                : _NewsDetailScreenState._textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
