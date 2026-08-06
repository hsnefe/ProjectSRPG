import 'package:flutter/material.dart';
import 'package:project_srpg/screens/dialog_screen.dart';
import 'package:project_srpg/screens/explore_screen.dart';
import 'package:project_srpg/widgets/expand_page_route.dart';

class RelationshipsScreen extends StatelessWidget {
  const RelationshipsScreen({super.key});

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
  static const _warning = Color(0xFFF5A623);
  static const _warningBg = Color(0x33F5A623);

  static const _relationships = [
    _RelationshipData(
      name: 'Antrenör',
      status: 'Güven seviyesi yüksek',
      score: 74,
      icon: Icons.assignment_outlined,
      iconColor: _accent,
      iconBg: _accentBg,
      barColor: _accent,
      contactName: 'Antrenör Mert',
      dialogMessage:
          'Son maçta bireysel performansın iyiydi ama takım oyununda seni daha aktif görmek istiyorum. Bu konuda ne düşünüyorsun?',
      dialogChoices: [
        'Haklısınız hocam, daha fazla paylaşımcı olacağım.',
        'Bence bireysel oynamam takıma zarar vermiyor.',
        'Bu konuyu maç sonrasında konuşalım mı?',
      ],
    ),
    _RelationshipData(
      name: 'Takım Arkadaşları',
      status: 'Saha içi sinerji iyi',
      score: 58,
      icon: Icons.groups_outlined,
      iconColor: _success,
      iconBg: _successBg,
      barColor: _success,
      contactName: 'Takım grubu',
      dialogMessage:
          'Bu hafta antrenmanlarda iletişim iyi gidiyor. Maç günü aynı enerjiyi sahaya taşıyalım mı?',
      dialogChoices: [
        'Evet, birlikte daha güçlüyüz.',
        'Biraz daha zaman lazım.',
      ],
    ),
    _RelationshipData(
      name: 'Medya',
      status: 'Röportaj talebi bekliyor',
      score: 51,
      icon: Icons.mic_none_outlined,
      iconColor: _danger,
      iconBg: _dangerBg,
      barColor: _danger,
      contactName: 'Spor Manşet',
      dialogMessage:
          'Maç sonrası kısa bir röportaj için müsait misiniz? Transfer söylentileri hakkında da sorularımız var.',
      dialogChoices: [
        'Tabii, 10 dakika ayırabilirim.',
        'Bugün konuşmak istemiyorum.',
        'Sadece maç hakkında konuşalım.',
      ],
    ),
    _RelationshipData(
      name: 'Partner',
      status: 'Bugün özlemiş',
      score: 63,
      icon: Icons.favorite_border,
      iconColor: _warning,
      iconBg: _warningBg,
      barColor: _warning,
      contactName: 'Elif',
      dialogMessage:
          'Bu akşam maçın var diye biliyorum. Yine de kısa bir telefon konuşması yapabilir miyiz?',
      dialogChoices: [
        'Maçtan sonra ararım.',
        'Şimdi 5 dakika konuşabiliriz.',
      ],
    ),
    _RelationshipData(
      name: 'Aile / Sosyal Çevre',
      status: 'Uzun süredir görüşülmedi',
      score: 29,
      icon: Icons.home_outlined,
      iconColor: _accent,
      iconBg: _accentBg,
      barColor: _accent,
      contactName: 'Anne',
      dialogMessage:
          'Seni özledik. Bu hafta sonu eve uğrayabilir misin? Maç programını da merak ediyoruz.',
      dialogChoices: [
        'Cumartesi antrenman sonrası gelirim.',
        'Bu hafta maç var, gelemem.',
        'Pazar öğleden sonra konuşalım.',
      ],
    ),
  ];

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _HeaderSection(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            for (var i = 0; i < _relationships.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              _RelationshipCard(data: _relationships[i]),
                            ],
                          ],
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

class _RelationshipData {
  const _RelationshipData({
    required this.name,
    required this.status,
    required this.score,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.barColor,
    required this.contactName,
    required this.dialogMessage,
    required this.dialogChoices,
  });

  final String name;
  final String status;
  final int score;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color barColor;
  final String contactName;
  final String dialogMessage;
  final List<String> dialogChoices;
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: RelationshipsScreen._border, width: 0.5),
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
              color: RelationshipsScreen._textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'İlişkiler',
            style: TextStyle(
              color: RelationshipsScreen._textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ExploreScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.explore_outlined,
              size: 22,
              color: RelationshipsScreen._textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipCard extends StatefulWidget {
  const _RelationshipCard({required this.data});

  final _RelationshipData data;

  @override
  State<_RelationshipCard> createState() => _RelationshipCardState();
}

class _RelationshipCardState extends State<_RelationshipCard> {
  final _callButtonKey = GlobalKey();

  void _openDialog() {
    final renderBox =
        _callButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;

    Navigator.of(context).push(
      ExpandPageRoute<void>(
        rect: rect,
        page: DialogScreen(
          contactName: widget.data.contactName,
          message: widget.data.dialogMessage,
          choices: widget.data.dialogChoices,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: RelationshipsScreen._surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, size: 16, color: data.iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        color: RelationshipsScreen._textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      data.status,
                      style: const TextStyle(
                        color: RelationshipsScreen._textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${data.score}/100',
                style: const TextStyle(
                  color: RelationshipsScreen._textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: data.score / 100,
                    minHeight: 4,
                    backgroundColor: RelationshipsScreen._surface2,
                    color: data.barColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: _callButtonKey,
                onPressed: _openDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: RelationshipsScreen._textPrimary,
                  side: const BorderSide(color: RelationshipsScreen._border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(Icons.phone_outlined, size: 14),
                label: const Text('Ara'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
