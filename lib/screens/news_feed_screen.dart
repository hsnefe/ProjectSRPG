import 'package:flutter/material.dart';

import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/news_detail_screen.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/news_style.dart';
import 'package:project_srpg/widgets/panel_states.dart';

/// N1'in tam akışı — kariyer merkezindeki tek kartlık önizlemenin (C3
/// `news_preview`) arkasındaki bütün arşiv.
///
/// Sayfalama N1'in kendi imzasıyla yapılır: `before` **kesin olarak daha eski**
/// demek (§5.7), yani bir sonraki sayfa `next_before`'ı olduğu gibi geri
/// göndermekle alınır. `next_before` null geldiğinde arşivin sonundayız —
/// "Daha fazla" düğmesi o an kaybolur.
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key, this.session, this.initialCategory});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  /// Açılışta seçili kategori; null "Tümü" demek.
  final String? initialCategory;

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  /// N1 `limit`. Ekran 420px'e sıkıştığı için bir sayfa iki ekran boyu tutar;
  /// BE tavanı (`MAX_PAGE_SIZE`) bunun çok üstünde, sınır bizim tercihimiz.
  static const _pageSize = 20;

  late final CareerSession _session = widget.session ?? CareerSession.instance;

  late String? _category = widget.initialCategory;

  final List<api.NewsSummary> _items = [];
  String? _nextBefore;

  bool _loading = true;
  bool _loadingMore = false;

  /// İlk sayfanın hatası tüm gövdeyi kaplar; sonraki sayfanınki yalnızca
  /// alttaki düğmeyi kırmızıya çevirir — okunmuş haberler ekranda kalsın.
  Object? _error;
  bool _moreFailed = false;

  /// Kategori hızlıca değiştirildiğinde geç dönen isteğin listeyi ele
  /// geçirmesini engeller: her yeni ilk sayfa isteği jetonu artırır, eski
  /// jetonla dönen cevap sessizce düşer.
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final token = ++_requestToken;
    setState(() {
      _loading = true;
      _error = null;
      _moreFailed = false;
      _items.clear();
      _nextBefore = null;
    });

    try {
      final careerId = await _session.resolve();
      final feed = await _session.client.news(
        careerId,
        limit: _pageSize,
        category: _category,
      );
      if (!mounted || token != _requestToken) return;
      setState(() {
        _items
          ..clear()
          ..addAll(feed.items);
        _nextBefore = feed.nextBefore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final before = _nextBefore;
    if (before == null || _loadingMore) return;

    final token = _requestToken;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });

    try {
      final careerId = await _session.resolve();
      final feed = await _session.client.news(
        careerId,
        limit: _pageSize,
        before: before,
        category: _category,
      );
      if (!mounted || token != _requestToken) return;
      setState(() {
        _items.addAll(feed.items);
        _nextBefore = feed.nextBefore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  void _selectCategory(String? category) {
    if (category == _category) return;
    setState(() => _category = category);
    _loadFirstPage();
  }

  /// Detay ekranı sayfalayıcısını **o an yüklenmiş** liste ile besler: kullanıcı
  /// akışta ne kadar aşağı indiyse detayda da o kadar ileri gidebilir.
  void _openDetail(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewsDetailScreen(
          newsIds: [for (final item in _items) item.newsId],
          initialIndex: index,
          session: _session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      const _HeaderSection(),
                      _CategoryFilterBar(
                        selected: _category,
                        onChanged: _selectCategory,
                      ),
                      Expanded(child: _body()),
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

  Widget _body() {
    if (_loading) return const CenteredSpinner();
    if (_error != null) {
      return PanelError(
        message: careerErrorText(_error!),
        onRetry: _loadFirstPage,
      );
    }
    if (_items.isEmpty) {
      return PanelEmpty(
        icon: Icons.article_outlined,
        message: _category == null
            ? 'Henüz haber yok.\nGünleri ilerlettikçe manşetler burada birikir.'
            : '$_category kategorisinde haber yok.',
      );
    }

    final hasMore = _nextBefore != null;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: _items.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return _LoadMoreFooter(
            loading: _loadingMore,
            failed: _moreFailed,
            onTap: _loadMore,
          );
        }
        return _NewsRow(
          item: _items[index],
          onTap: () => _openDetail(index),
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

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
            'Haberler',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kategori filtresi. Yedi seçenek (Tümü + §3'ün altı kategorisi) alışveriş
/// ekranındaki dört segmentlik pil toggle'a sığmıyor — bu yüzden aynı pil
/// dilinde, yatay kayan bir hap şeridi. Seçili hap kategorinin kendi tonunu
/// alıyor: filtre ile satırlardaki rozet aynı renkte konuşuyor.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.selected, required this.onChanged});

  /// null = Tümü.
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _FilterChip(
              key: const ValueKey('newsFilter:all'),
              label: 'Tümü',
              color: AppColors.accent,
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
            for (final category in newsCategories) ...[
              const SizedBox(width: 8),
              _FilterChip(
                key: ValueKey('newsFilter:$category'),
                label: category,
                icon: iconForNewsCategory(category),
                color: tintForNewsCategory(category),
                selected: selected == category,
                onTap: () => onChanged(category),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : AppColors.surface1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.45)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? color : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Akıştaki bir haber. Detay ekranındaki hero'nun satıra inmiş hâli: aynı
/// gradient + filigran ikon reçetesi, ama 200px'lik kapak yerine solda küçük
/// bir kare — bir ekrana altı manşet sığsın diye.
class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item, required this.onTap});

  static const _thumbSize = 76.0;

  final api.NewsSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = tintForNewsCategory(item.category);
    final radius = BorderRadius.circular(14);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: tint.withValues(alpha: 0.10),
              blurRadius: 16,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: radius,
            border: Border.all(
              color: tint.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RowThumb(category: item.category, size: _thumbSize),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NewsCategoryPill(category: item.category),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.source} · ${newsTimeAgo(item.publishedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Haber fotoğrafı BE'de yok — kategori tonundan prosedürel kapak
/// (news_detail_screen.dart'ın `_ProceduralArt`'ı ile aynı gradient).
class _RowThumb extends StatelessWidget {
  const _RowThumb({required this.category, required this.size});

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = tintForNewsCategory(category);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint.withValues(alpha: 0.55),
                    tint.withValues(alpha: 0.22),
                    AppColors.surface0.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Kenardan taşan filigran + okunur boyuttaki asıl ikon: aktivite
            // kartlarındaki ikili katman.
            Positioned(
              right: -size * 0.16,
              top: -size * 0.10,
              child: Icon(
                iconForNewsCategory(category),
                size: size * 0.72,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            Center(
              child: Icon(
                iconForNewsCategory(category),
                size: size * 0.30,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            // Üst kenardaki ışık çizgisi.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.22)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listenin sonundaki sayfalama düğmesi. Sonsuz kaydırma yerine açık bir
/// düğme: N1 sayfaları tarih imleçli, sessizce yüklenen bir sayfanın nereye
/// eklendiği kullanıcıya görünmüyor.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.loading,
    required this.failed,
    required this.onTap,
  });

  final bool loading;
  final bool failed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          if (failed)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Daha fazla haber alınamadı.',
                style: TextStyle(color: AppColors.danger, fontSize: 11),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                failed ? 'Tekrar dene' : 'Daha fazla',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
