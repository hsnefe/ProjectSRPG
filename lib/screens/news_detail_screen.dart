import 'package:flutter/material.dart';

class NewsItem {
  const NewsItem({
    required this.category,
    required this.title,
    required this.source,
    required this.timeAgo,
    required this.body,
  });

  final String category;
  final String title;
  final String source;
  final String timeAgo;
  final String body;
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
  static const _textMuted = Color(0xFF6B7280);
  static const _danger = Color(0xFFE85D5D);
  static const _dangerBg = Color(0x33E85D5D);

  late int _index;

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
    setState(() => _index -= 1);
  }

  void _goNext() {
    if (!_canGoNext) return;
    setState(() => _index += 1);
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
                        onBack: () => Navigator.of(context).pop(),
                        onPrev: _goPrev,
                        onNext: _goNext,
                        canGoPrev: _canGoPrev,
                        canGoNext: _canGoNext,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          key: ValueKey<int>(_index),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 160,
                                width: double.infinity,
                                color: _surface1,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                  color: _textMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _dangerBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.category,
                                  style: const TextStyle(
                                    color: _danger,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 18,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.source} · ${item.timeAgo}',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 20),
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
    required this.onBack,
    required this.onPrev,
    required this.onNext,
    required this.canGoPrev,
    required this.canGoNext,
  });

  final VoidCallback onBack;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool canGoPrev;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          const Expanded(
            child: Text(
              'Haber',
              style: TextStyle(
                color: _NewsDetailScreenState._textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            onPressed: canGoPrev ? onPrev : null,
            icon: Icon(
              Icons.chevron_left,
              size: 24,
              color: canGoPrev
                  ? _NewsDetailScreenState._textPrimary
                  : _NewsDetailScreenState._textMuted.withValues(alpha: 0.4),
            ),
          ),
          IconButton(
            onPressed: canGoNext ? onNext : null,
            icon: Icon(
              Icons.chevron_right,
              size: 24,
              color: canGoNext
                  ? _NewsDetailScreenState._textPrimary
                  : _NewsDetailScreenState._textMuted.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
