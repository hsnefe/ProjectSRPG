import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:project_srpg/screens/dialog_screen.dart';
import 'package:project_srpg/screens/relationships_radar_screen.dart';
import 'package:project_srpg/widgets/character_card.dart';
import 'package:project_srpg/widgets/expand_page_route.dart';

class RelationshipsScreen extends StatelessWidget {
  const RelationshipsScreen({super.key});

  static const _surface1 = Color(0xFF1A1D24);
  static const _surface2 = Color(0xFF22262F);
  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textMuted = Color(0xFF6B7280);
  static const _accent = Color(0xFF1E6FD9);
  static const _success = Color(0xFF3DDC97);
  static const _danger = Color(0xFFE85D5D);
  static const _warning = Color(0xFFF5A623);
  static const _purple = Color(0xFF9B5CF6);

  static const _cardWidth = 225.0;
  static const _cardHeight = 380.0;

  static const _relationships = [
    _RelationshipData(
      id: 'coach',
      name: 'Antrenör',
      status: 'Güven seviyesi yüksek',
      score: 74,
      icon: Icons.assignment_outlined,
      tint: _accent,
      badgeCode: 'AN',
      leftTag: 'KLÜP',
      rightTag: '+3',
      dateLabel: '12 Ağu · 14:30',
      contactName: 'Antrenör Mert',
      dialogueTree: DialogueTree(
        startId: 'start',
        nodes: {
          'start': DialogueNode(
            id: 'start',
            line:
                'Son maçta bireysel performansın iyiydi ama takım oyununda seni daha aktif görmek istiyorum. Bu konuda ne düşünüyorsun?',
            options: [
              DialogueOption(
                text: 'Haklısınız hocam, daha fazla paylaşımcı olacağım.',
                nextId: 'r0',
              ),
              DialogueOption(
                text: 'Bence bireysel oynamam takıma zarar vermiyor.',
                nextId: 'r1',
              ),
              DialogueOption(
                text: 'Bu konuyu maç sonrasında konuşalım mı?',
                nextId: 'r2',
              ),
            ],
          ),
          'r0': DialogueNode(
            id: 'r0',
            line:
                'Bunu duymak güzel. Bu hafta antrenmanlarda bunu göreceğimi umuyorum.',
          ),
          'r1': DialogueNode(
            id: 'r1',
            line:
                'Anlıyorum ama istatistikler farklı söylüyor. Bu konuşmayı unutma.',
          ),
          'r2': DialogueNode(
            id: 'r2',
            line: 'Olur, o zaman daha sakin kafayla devam ederiz.',
          ),
        },
      ),
    ),
    _RelationshipData(
      id: 'team',
      name: 'Takım Arkadaşları',
      status: 'Saha içi sinerji iyi',
      score: 58,
      icon: Icons.groups_outlined,
      tint: _success,
      badgeCode: 'TK',
      leftTag: 'KLÜP',
      rightTag: '+1',
      dateLabel: '13 Ağu · 09:10',
      contactName: 'Takım grubu',
      dialogueTree: DialogueTree(
        startId: 'start',
        nodes: {
          'start': DialogueNode(
            id: 'start',
            line:
                'Bu hafta antrenmanlarda iletişim iyi gidiyor. Maç günü aynı enerjiyi sahaya taşıyalım mı?',
            options: [
              DialogueOption(
                text: 'Evet, birlikte daha güçlüyüz.',
                nextId: 'r0',
              ),
              DialogueOption(text: 'Biraz daha zaman lazım.', nextId: 'r1'),
            ],
          ),
          'r0': DialogueNode(
            id: 'r0',
            line: 'Harika, o zaman maç günü aynı ekipteyiz!',
          ),
          'r1': DialogueNode(
            id: 'r1',
            line: 'Sorun değil, adım adım ilerleriz.',
          ),
        },
      ),
    ),
    _RelationshipData(
      id: 'media',
      name: 'Medya',
      status: 'Röportaj talebi bekliyor',
      score: 51,
      icon: Icons.mic_none_outlined,
      tint: _danger,
      badgeCode: 'MD',
      leftTag: 'BASIN',
      rightTag: '−2',
      dateLabel: '09 Ağu · 18:45',
      contactName: 'Spor Manşet',
      dialogueTree: DialogueTree(
        startId: 'start',
        nodes: {
          'start': DialogueNode(
            id: 'start',
            line:
                'Maç sonrası kısa bir röportaj için müsait misiniz? Transfer söylentileri hakkında da sorularımız var.',
            options: [
              DialogueOption(
                text: 'Tabii, 10 dakika ayırabilirim.',
                nextId: 'r0',
              ),
              DialogueOption(
                text: 'Bugün konuşmak istemiyorum.',
                nextId: 'r1',
              ),
              DialogueOption(
                text: 'Sadece maç hakkında konuşalım.',
                nextId: 'r2',
              ),
            ],
          ),
          'r0': DialogueNode(
            id: 'r0',
            line: 'Harika, maç sonrası sahada bekliyoruz.',
          ),
          'r1': DialogueNode(
            id: 'r1',
            line: 'Anlıyoruz, başka zaman tekrar deneriz.',
          ),
          'r2': DialogueNode(
            id: 'r2',
            line: 'Elbette, transferle ilgili soru sormayacağız.',
          ),
        },
      ),
    ),
    _RelationshipData(
      id: 'partner',
      name: 'Partner',
      status: 'Bugün özlemiş',
      score: 63,
      icon: Icons.favorite_border,
      tint: _purple,
      badgeCode: 'PA',
      leftTag: 'ÖZEL',
      rightTag: '+4',
      dateLabel: '14 Ağu · 08:05',
      contactName: 'Elif',
      dialogueTree: DialogueTree(
        startId: 'start',
        nodes: {
          'start': DialogueNode(
            id: 'start',
            line:
                'Bu akşam maçın var diye biliyorum. Yine de kısa bir telefon konuşması yapabilir miyiz?',
            options: [
              DialogueOption(text: 'Maçtan sonra ararım.', nextId: 'r0'),
              DialogueOption(
                text: 'Şimdi 5 dakika konuşabiliriz.',
                nextId: 'r1',
              ),
            ],
          ),
          'r0': DialogueNode(
            id: 'r0',
            line: 'Tamam, seni bekliyorum. Bol şans!',
          ),
          'r1': DialogueNode(
            id: 'r1',
            line: 'Ne güzel, seni duymak iyi geldi.',
          ),
        },
      ),
    ),
    _RelationshipData(
      id: 'family',
      name: 'Aile / Sosyal Çevre',
      status: 'Uzun süredir görüşülmedi',
      score: 29,
      icon: Icons.home_outlined,
      tint: _warning,
      badgeCode: 'AS',
      leftTag: 'ÖZEL',
      rightTag: '−1',
      dateLabel: '28 Tem · 20:15',
      contactName: 'Anne',
      dialogueTree: DialogueTree(
        startId: 'start',
        nodes: {
          'start': DialogueNode(
            id: 'start',
            line:
                'Seni özledik. Bu hafta sonu eve uğrayabilir misin? Maç programını da merak ediyoruz.',
            options: [
              DialogueOption(
                text: 'Cumartesi antrenman sonrası gelirim.',
                nextId: 'r0',
              ),
              DialogueOption(text: 'Bu hafta maç var, gelemem.', nextId: 'r1'),
              DialogueOption(
                text: 'Pazar öğleden sonra konuşalım.',
                nextId: 'r2',
              ),
            ],
          ),
          'r0': DialogueNode(
            id: 'r0',
            line: 'Harika, seni bekliyoruz canım.',
          ),
          'r1': DialogueNode(
            id: 'r1',
            line: 'Anlıyoruz, bir dahaki sefere görüşürüz.',
          ),
          'r2': DialogueNode(id: 'r2', line: 'Olur, o zaman seni ararım.'),
        },
      ),
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
                  // Panel ekranın tamamını kaplar; kart şeridi dikeyde
                  // ortalanır, dönüş butonu en altta sabit kalır.
                  child: Column(
                    children: [
                      const _HeaderSection(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Kart, kalan alana sığmıyorsa oranını koruyarak
                            // küçülür; böylece dar ekranlarda taşma olmaz.
                            final cardHeight = math.min(
                              _cardHeight,
                              constraints.maxHeight - 40,
                            );
                            final cardWidth =
                                cardHeight * _cardWidth / _cardHeight;

                            return Center(
                              child: Stack(
                                // Kart gölgeleri taşabilsin; dış ClipRRect
                                // panel sınırında zaten kırpıyor.
                                clipBehavior: Clip.none,
                                children: [
                                  // Kartların arkasındaki dev hayalet yazı.
                                  Positioned(
                                    left: 18,
                                    top: 6,
                                    child: Text(
                                      'İLİŞKİLER',
                                      style: TextStyle(
                                        fontSize: 58,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                        color: Colors.white.withValues(
                                          alpha: 0.035,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: cardHeight,
                                    // Masaüstü ve web'de fare/trackpad ile
                                    // sürükleyerek kaydırmak varsayılan olarak
                                    // kapalı; şerit kayabilsin diye açıyoruz.
                                    child: ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(
                                            dragDevices: const {
                                              PointerDeviceKind.touch,
                                              PointerDeviceKind.mouse,
                                              PointerDeviceKind.trackpad,
                                              PointerDeviceKind.stylus,
                                            },
                                          ),
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        clipBehavior: Clip.none,
                                        itemCount: _relationships.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(width: 14),
                                        itemBuilder: (context, index) {
                                          return _RelationshipCharacterCard(
                                            data: _relationships[index],
                                            width: cardWidth,
                                            height: cardHeight,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const _FooterSection(),
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
    required this.id,
    required this.name,
    required this.status,
    required this.score,
    required this.icon,
    required this.tint,
    required this.badgeCode,
    required this.leftTag,
    required this.rightTag,
    required this.dateLabel,
    required this.contactName,
    required this.dialogueTree,
  });

  final String id;
  final String name;
  final String status;
  final int score;
  final IconData icon;
  final Color tint;
  final String badgeCode;
  final String leftTag;
  final String rightTag;
  final String dateLabel;
  final String contactName;
  final DialogueTree dialogueTree;

  /// Karta beslenen görsel model; diyalog metinleri widget katmanına sızmaz.
  CharacterCardData toCardData() {
    return CharacterCardData(
      id: id,
      name: name,
      subtitle: status,
      score: score,
      icon: icon,
      tint: tint,
      badgeCode: badgeCode,
      leftTag: leftTag,
      rightTag: rightTag,
      dateLabel: dateLabel,
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
                  builder: (_) => const RelationshipsRadarScreen(),
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

/// Panelin altındaki kariyer merkezine dönüş şeridi.
class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: RelationshipsScreen._border, width: 0.5),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: RelationshipsScreen._textPrimary,
            side: const BorderSide(color: RelationshipsScreen._border),
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Kariyer Merkezi'),
        ),
      ),
    );
  }
}

class _RelationshipCharacterCard extends StatefulWidget {
  const _RelationshipCharacterCard({
    required this.data,
    required this.width,
    required this.height,
  });

  final _RelationshipData data;
  final double width;
  final double height;

  @override
  State<_RelationshipCharacterCard> createState() =>
      _RelationshipCharacterCardState();
}

class _RelationshipCharacterCardState
    extends State<_RelationshipCharacterCard> {
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
          tree: widget.data.dialogueTree,
          tint: widget.data.tint,
        ),
      ),
    );
  }

  void _openRadar() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RelationshipsRadarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CharacterCard(
      data: widget.data.toCardData(),
      width: widget.width,
      height: widget.height,
      primaryKey: _callButtonKey,
      onPrimary: _openDialog,
      onSecondary: _openRadar,
    );
  }
}
