import 'package:flutter/material.dart';
import 'package:project_srpg/screens/relationships_screen.dart';
import 'package:project_srpg/screens/pre_match_screen.dart';
import 'package:project_srpg/widgets/expand_page_route.dart';

class CareerCenterScreen extends StatelessWidget {
  const CareerCenterScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textSecondary = Color(0xFFA0A6B0);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _accentBg = Color(0x33228BFF);
  static const _success = Color(0xFF3DDC97);
  static const _successBg = Color(0x333DDC97);
  static const _danger = Color(0xFFE85D5D);
  static const _dangerBg = Color(0x33E85D5D);

  @override
  Widget build(BuildContext context) {
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
                  child: ListView(
                    children: const [
                      _HeaderSection(),
                      _ProgressSection(),
                      _MatchPreviewSection(),
                      _NewsSection(),
                      _ActionsSection(),
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
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CareerCenterScreen._border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: CareerCenterScreen._accentBg,
              shape: BoxShape.circle,
            ),
            child: const Text(
              'EK',
              style: TextStyle(
                color: CareerCenterScreen._accent,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Efe Kaan',
                  style: TextStyle(
                    color: CareerCenterScreen._textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Orta saha · FK Yıldız',
                  style: TextStyle(
                    color: CareerCenterScreen._textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: CareerCenterScreen._textPrimary,
              side: const BorderSide(color: CareerCenterScreen._border),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 13),
            ),
            icon: const Icon(Icons.table_chart_outlined, size: 16),
            label: const Text('Lig tablosu'),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.settings_outlined,
            size: 20,
            color: CareerCenterScreen._textMuted,
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CareerCenterScreen._border,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'İlerleme',
            style: TextStyle(
              color: CareerCenterScreen._textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: _StatBar(
                  label: 'Yetenek',
                  value: 68,
                  max: 100,
                  color: CareerCenterScreen._accent,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _StatBar(
                  label: 'Şöhret',
                  value: 42,
                  max: 100,
                  color: CareerCenterScreen._success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(label: 'Bakiye', value: '₺48.200'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(label: 'Kondisyon', value: '%86'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: CareerCenterScreen._textPrimary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / max,
            minHeight: 4,
            backgroundColor: CareerCenterScreen._surface1,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value/$max',
          style: const TextStyle(
            color: CareerCenterScreen._textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CareerCenterScreen._surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: CareerCenterScreen._textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: CareerCenterScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchPreviewSection extends StatefulWidget {
  const _MatchPreviewSection();

  @override
  State<_MatchPreviewSection> createState() => _MatchPreviewSectionState();
}

class _MatchPreviewSectionState extends State<_MatchPreviewSection> {
  static const _cardTop = Color(0xFF2E3440);
  static const _cardMid = Color(0xFF252932);
  static const _cardBottom = Color(0xFF181C23);

  final _cardKey = GlobalKey();

  void _openMatchDetail() {
    final renderBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;

    Navigator.of(context).push(
      ExpandPageRoute<void>(
        rect: rect,
        page: const PreMatchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: GestureDetector(
        key: _cardKey,
        onTap: _openMatchDetail,
        child: DecoratedBox(
          decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 32,
              offset: const Offset(0, 16),
              spreadRadius: -8,
            ),
            BoxShadow(
              color: CareerCenterScreen._accent.withValues(alpha: 0.22),
              blurRadius: 48,
              spreadRadius: -10,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.06),
                Colors.black.withValues(alpha: 0.35),
              ],
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: Container(
            constraints: const BoxConstraints(minHeight: 210),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_cardTop, _cardMid, _cardBottom],
                stops: [0.0, 0.42, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.42),
                          Colors.white.withValues(alpha: 0.42),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  bottom: 14,
                  left: 0,
                  child: Container(
                    width: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text(
                            'SONRAKİ MAÇ',
                            style: TextStyle(
                              color: CareerCenterScreen._accent
                                  .withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Cumartesi, 20:00',
                            style: TextStyle(
                              color: CareerCenterScreen._textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_outlined,
                                size: 14,
                                color: CareerCenterScreen._textSecondary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '16°C, parçalı bulutlu',
                                style: TextStyle(
                                  color: CareerCenterScreen._textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _TeamBadge(
                            name: 'FK Yıldız',
                            background: CareerCenterScreen._accentBg,
                            iconColor: CareerCenterScreen._accent,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 28),
                            child: Text(
                              'vs',
                              style: TextStyle(
                                color: CareerCenterScreen._textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const _TeamBadge(
                            name: 'Deniz SK',
                            background: CareerCenterScreen._dangerBg,
                            iconColor: CareerCenterScreen._danger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: CareerCenterScreen._successBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: CareerCenterScreen._success
                                .withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CareerCenterScreen._success
                                  .withValues(alpha: 0.18),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Text(
                          'İlk 11',
                          style: TextStyle(
                            color: CareerCenterScreen._success,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({
    required this.name,
    required this.background,
    required this.iconColor,
  });

  final String name;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.shield_outlined, size: 22, color: iconColor),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            color: CareerCenterScreen._textPrimary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _NewsSection extends StatelessWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CareerCenterScreen._border,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                color: CareerCenterScreen._surface1,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_outlined,
                  size: 32,
                  color: CareerCenterScreen._textMuted,
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CareerCenterScreen._dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Transfer',
                    style: TextStyle(
                      color: CareerCenterScreen._danger,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Deniz SK, orta saha transferi için FK Yıldız'ı ziyaret etti",
                  style: TextStyle(
                    color: CareerCenterScreen._textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Spor Manşet · 2 saat önce',
                  style: TextStyle(
                    color: CareerCenterScreen._textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.people_outline,
                  label: 'İlişkiler',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RelationshipsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.fitness_center,
                  label: 'Antrenman',
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              icon: Icons.home_outlined,
              label: 'Yaşam tarzı',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: CareerCenterScreen._textPrimary,
        side: const BorderSide(color: CareerCenterScreen._border),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        textStyle: const TextStyle(fontSize: 13),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
