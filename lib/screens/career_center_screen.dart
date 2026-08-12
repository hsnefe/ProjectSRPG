import 'package:flutter/material.dart';
import 'package:project_srpg/screens/league_table_screen.dart';
import 'package:project_srpg/screens/lifestyle_screen.dart';
import 'package:project_srpg/screens/news_detail_screen.dart';
import 'package:project_srpg/screens/player_profile_screen.dart';
import 'package:project_srpg/screens/pre_match_screen.dart';
import 'package:project_srpg/screens/relationships_screen.dart';
import 'package:project_srpg/screens/settings_screen.dart';
import 'package:project_srpg/screens/training_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
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
  static const _warning = Color(0xFFF5A623);
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
    final player = PlayerScope.of(context);

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
          // Avatar + isim bloğu tek dokunulabilir birim: oyuncu profilini
          // açar. Bakiye de bu bloğun içinde olduğu için ona basmak da
          // profili açıyor — kimlik alanının parçası, kabul edilebilir.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PlayerProfileScreen(),
                  ),
                );
              },
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
                    child: Text(
                      player.initials,
                      style: const TextStyle(
                        color: CareerCenterScreen._accent,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                player.name,
                                style: const TextStyle(
                                  color: CareerCenterScreen._textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              player.moneyLabel,
                              style: const TextStyle(
                                color: CareerCenterScreen._success,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${player.position} · ${player.teamName}',
                          style: const TextStyle(
                            color: CareerCenterScreen._textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LeagueTableScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              side: const BorderSide(color: CareerCenterScreen._border),
              shape: const CircleBorder(),
            ),
            icon: const Icon(
              Icons.emoji_events_outlined,
              size: 18,
              color: CareerCenterScreen._textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.settings_outlined,
              size: 20,
              color: CareerCenterScreen._textMuted,
            ),
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
    final condition = PlayerScope.of(context).condition;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _LitCard(
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Kondisyon',
                    style: TextStyle(
                      color: CareerCenterScreen._textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '%$condition',
                    style: const TextStyle(
                      color: CareerCenterScreen._textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: condition / 100,
                  minHeight: 8,
                  backgroundColor: CareerCenterScreen._surface1,
                  color: CareerCenterScreen._success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LitCard extends StatelessWidget {
  const _LitCard({
    super.key,
    required this.child,
    this.onTap,
    this.minHeight,
    this.borderRadius = 16,
  });

  static const _cardTop = Color(0xFF2E3440);
  static const _cardMid = Color(0xFF252932);
  static const _cardBottom = Color(0xFF181C23);

  final Widget child;
  final VoidCallback? onTap;
  final double? minHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final innerRadius = borderRadius - 1;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
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
          borderRadius: BorderRadius.circular(borderRadius),
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
          constraints:
              minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerRadius),
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
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(innerRadius),
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
              child,
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return card;

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

class _MatchPreviewSection extends StatefulWidget {
  const _MatchPreviewSection();

  @override
  State<_MatchPreviewSection> createState() => _MatchPreviewSectionState();
}

class _MatchPreviewSectionState extends State<_MatchPreviewSection> {
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
      child: _LitCard(
        key: _cardKey,
        onTap: _openMatchDetail,
        minHeight: 210,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    'SONRAKİ MAÇ',
                    style: TextStyle(
                      color:
                          CareerCenterScreen._accent.withValues(alpha: 0.95),
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
                    color:
                        CareerCenterScreen._success.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          CareerCenterScreen._success.withValues(alpha: 0.18),
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

  static const _news = [
    NewsItem(
      category: 'Transfer',
      icon: Icons.swap_horiz,
      tint: CareerCenterScreen._accent,
      title: "Deniz SK, orta saha transferi için FK Yıldız'ı ziyaret etti",
      source: 'Spor Manşet',
      timeAgo: '2 saat önce',
      body:
          'Deniz SK yönetimi, sezon ortası transfer penceresinde orta saha rotasyonunu güçlendirmek amacıyla FK Yıldız tesislerinde görüşmeler gerçekleştirdi.\n\n'
          'Kaynaklara göre hedef listesinde genç orta saha oyuncuları öne çıkıyor. Kulüp yetkilileri, görüşmelerin olumlu geçtiğini ancak henüz resmi bir teklif yapılmadığını belirtti.\n\n'
          'FK Yıldız tarafı ise kadro planlamasını korumak istediğini ve kritik oyuncular için aceleci davranmayacaklarını açıkladı. Gelişmeler takip ediliyor.',
    ),
    NewsItem(
      category: 'Maç',
      icon: Icons.sports_soccer,
      tint: CareerCenterScreen._success,
      title: 'FK Yıldız, deplasmanda 2-1 galip geldi',
      source: 'Lig Ajansı',
      timeAgo: '1 gün önce',
      body:
          'FK Yıldız, zorlu deplasmanda sahadan 2-1 galip ayrılarak ligde üçüncülüğünü pekiştirdi.\n\n'
          'İlk yarıda dengeyi koruyan misafir ekip, ikinci yarının başında öne geçti. Rakibin geç eşitliği ardından gelen gol, üç puanı getirdi.\n\n'
          'Teknik direktör, oyuncuların disiplinli savunma ve hızlı geçiş oyununu övdü. Bir sonraki hafta ev sahibi avantajıyla kritik bir karşılaşma oynanacak.',
    ),
    NewsItem(
      category: 'Röportaj',
      icon: Icons.record_voice_over_outlined,
      tint: CareerCenterScreen._warning,
      title: 'Antrenör Mert: "Gençlerimiz doğru yolda"',
      source: 'Saha Sohbeti',
      timeAgo: '3 gün önce',
      body:
          'FK Yıldız antrenörü Mert, sezon değerlendirmesinde genç oyuncuların gelişimine vurgu yaptı.\n\n'
          '"Antrenman temposu yüksek ve rekabet sağlıklı. Bireysel performans kadar takım oyunu da yükseliyor," dedi.\n\n'
          'Özellikle orta saha hattında iletişim ve topa sahip olma oranının arttığını belirten antrenör, ligin ikinci yarısında daha istikrarlı sonuçlar beklediklerini ifade etti.',
    ),
    NewsItem(
      category: 'Analiz',
      icon: Icons.insights,
      tint: CareerCenterScreen._danger,
      title: 'Lig tablosu sıkışık: Üst sıralar tek puanlık farklarda',
      source: 'Taktik Defter',
      timeAgo: '5 gün önce',
      body:
          'Sezonun ilk yarısında lig üst sıraları beklenenden daha rekabetçi bir tablo çiziyor.\n\n'
          'Deniz SK liderliğini korurken Anadolu FC ve FK Yıldız yakın takipte. Uzmanlara göre kalan maçlarda deplasman performansı şampiyonluk yarışını belirleyebilir.\n\n'
          'Orta sıralardaki takımlar da puan farkını kapatma peşinde; her hafta sürpriz sonuçlar mümkün görünüyor.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _news.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _LitCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NewsDetailScreen(
                news: _news,
                initialIndex: 0,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: Stack(
                children: [
                  // Detay ekranındaki hero ile aynı ton ve ikon: liste kartı ile
                  // açılan haber aynı şeye benziyor.
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Stack(
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
                          right: -12,
                          top: -12,
                          child: Icon(
                            item.icon,
                            size: 96,
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: item.tint.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: item.tint.withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          color: item.tint,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: CareerCenterScreen._textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.source} · ${item.timeAgo}',
                    style: const TextStyle(
                      color: CareerCenterScreen._textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.fitness_center,
                  label: 'Antrenman',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TrainingScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              icon: Icons.home_outlined,
              label: 'Yaşam tarzı',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LifestyleScreen(),
                  ),
                );
              },
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
    return _LitCard(
      onTap: onPressed,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: CareerCenterScreen._textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: CareerCenterScreen._textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
