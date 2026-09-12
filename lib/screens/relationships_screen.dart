import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/dialog_screen.dart';
import 'package:project_srpg/screens/relationships_radar_screen.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/character_portrait.dart';
import 'package:project_srpg/widgets/character_card.dart';
import 'package:project_srpg/widgets/character_profile_modal.dart';
import 'package:project_srpg/widgets/expand_page_route.dart';
import 'package:project_srpg/widgets/relationship_presentation.dart';

/// D23: diyalog **ağacı** (metin + dallanma) BE'de tutulmaz, FE'nin içeriği —
/// catalog/dialogue.py bunu doğrudan yorumluyor: her düğüm id'si ve yaprağı
/// (`r0`/`r1`/…) iki tarafta da birebir aynı olmalı, ekranda değiştirilecekse
/// `catalog/dialogue.py`'deki `DIALOGUE_OUTCOMES` de güncellenmeli.
const _dialogueTreeByRelationshipId = {
  'coach': DialogueTree(
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
  'team': DialogueTree(
    startId: 'start',
    nodes: {
      'start': DialogueNode(
        id: 'start',
        line:
            'Bu hafta antrenmanlarda iletişim iyi gidiyor. Maç günü aynı enerjiyi sahaya taşıyalım mı?',
        options: [
          DialogueOption(text: 'Evet, birlikte daha güçlüyüz.', nextId: 'r0'),
          DialogueOption(text: 'Biraz daha zaman lazım.', nextId: 'r1'),
        ],
      ),
      'r0': DialogueNode(
        id: 'r0',
        line: 'Harika, o zaman maç günü aynı ekipteyiz!',
      ),
      'r1': DialogueNode(id: 'r1', line: 'Sorun değil, adım adım ilerleriz.'),
    },
  ),
  'media': DialogueTree(
    startId: 'start',
    nodes: {
      'start': DialogueNode(
        id: 'start',
        line:
            'Maç sonrası kısa bir röportaj için müsait misiniz? Transfer söylentileri hakkında da sorularımız var.',
        options: [
          DialogueOption(text: 'Tabii, 10 dakika ayırabilirim.', nextId: 'r0'),
          DialogueOption(text: 'Bugün konuşmak istemiyorum.', nextId: 'r1'),
          DialogueOption(text: 'Sadece maç hakkında konuşalım.', nextId: 'r2'),
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
  'partner': DialogueTree(
    startId: 'start',
    nodes: {
      'start': DialogueNode(
        id: 'start',
        line:
            'Bu akşam maçın var diye biliyorum. Yine de kısa bir telefon konuşması yapabilir miyiz?',
        options: [
          DialogueOption(text: 'Maçtan sonra ararım.', nextId: 'r0'),
          DialogueOption(text: 'Şimdi 5 dakika konuşabiliriz.', nextId: 'r1'),
        ],
      ),
      'r0': DialogueNode(id: 'r0', line: 'Tamam, seni bekliyorum. Bol şans!'),
      'r1': DialogueNode(id: 'r1', line: 'Ne güzel, seni duymak iyi geldi.'),
    },
  ),
  'family': DialogueTree(
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
          DialogueOption(text: 'Pazar öğleden sonra konuşalım.', nextId: 'r2'),
        ],
      ),
      'r0': DialogueNode(id: 'r0', line: 'Harika, seni bekliyoruz canım.'),
      'r1': DialogueNode(
        id: 'r1',
        line: 'Anlıyoruz, bir dahaki sefere görüşürüz.',
      ),
      'r2': DialogueNode(id: 'r2', line: 'Olur, o zaman seni ararım.'),
    },
  ),
};

/// R1'in `score`sundan türetilmiş genel bir durum cümlesi (§1.3 — BE sayıyı
/// verir, cümleyi FE kurar). İlişkiye özel öykü metni değil: hangi
/// olayın skoru bu hale getirdiğini FE bilemez, yalnızca sayının kendisini
/// yorumlayabilir.
String _statusLabel(int score) {
  if (score >= 80) return 'Çok güçlü bağ';
  if (score >= 60) return 'İyi gidiyor';
  if (score >= 40) return 'Dengeli';
  if (score >= 20) return 'Zayıflıyor';
  return 'Kritik seviyede';
}

const _dateMonths = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];

/// 'YYYY-MM-DD' → '19 Ağu' — §1.3, `last_contact_at` tarih-yalnız (saat yok).
String _lastContactLabel(String? isoDate) {
  if (isoDate == null) return 'Henüz temas yok';
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  return '${date.day} ${_dateMonths[date.month - 1]}';
}

CharacterCardData _toCardData(api.RelationshipCard card) {
  final presentation = presentationForRelationship(card.relationshipId);
  return CharacterCardData(
    id: card.relationshipId,
    name: card.category,
    subtitle: _statusLabel(card.score),
    score: card.score,
    icon: presentation.icon,
    tint: presentation.tint,
    badgeCode: presentation.badgeCode,
    leftTag: presentation.leftTag,
    dateLabel: _lastContactLabel(card.lastContactAt),
    hasPendingRequest: card.hasPendingRequest,
  );
}

CharacterProfile _toProfile(api.RelationshipProfile profile) {
  final card = profile.card;
  final presentation = presentationForRelationship(card.relationshipId);
  return CharacterProfile(
    name: card.personName,
    relationLabel: card.category,
    age: profile.age ?? 0,
    occupation: profile.occupation ?? '',
    hobbies: profile.hobbies,
    bio: profile.bio ?? '',
    badgeCode: presentation.badgeCode,
    icon: presentation.icon,
    tint: presentation.tint,
    score: card.score,
    lastContact: _lastContactLabel(card.lastContactAt),
  );
}

class RelationshipsScreen extends StatefulWidget {
  const RelationshipsScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  static const _cardWidth = 225.0;
  static const _cardHeight = 380.0;

  @override
  State<RelationshipsScreen> createState() => _RelationshipsScreenState();
}

class _RelationshipsScreenState extends State<RelationshipsScreen> {
  late final CareerSession _session =
      widget.session ?? CareerSession.instance;
  late Future<List<api.RelationshipCard>> _relationshipsFuture;

  @override
  void initState() {
    super.initState();
    _relationshipsFuture = _load();
  }

  /// R1 · `GET /careers/{cid}/relationships` — beş kart.
  Future<List<api.RelationshipCard>> _load() async {
    final careerId = await _session.resolve();
    return _session.client.relationships(careerId);
  }

  void _reload() => setState(() => _relationshipsFuture = _load());

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
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  // Panel ekranın tamamını kaplar; kart şeridi dikeyde
                  // ortalanır, dönüş butonu en altta sabit kalır.
                  child: Column(
                    children: [
                      const _HeaderSection(),
                      Expanded(
                        child: FutureBuilder<List<api.RelationshipCard>>(
                          future: _relationshipsFuture,
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
                                  'İlişkiler alınamadı.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                            return _RelationshipStrip(
                              relationships: snapshot.data!,
                              session: _session,
                              onChanged: _reload,
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

class _RelationshipStrip extends StatelessWidget {
  const _RelationshipStrip({
    required this.relationships,
    required this.session,
    required this.onChanged,
  });

  final List<api.RelationshipCard> relationships;
  final CareerSession session;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Kart, kalan alana sığmıyorsa oranını koruyarak küçülür; böylece
        // dar ekranlarda taşma olmaz.
        final cardHeight = math.min(
          RelationshipsScreen._cardHeight,
          constraints.maxHeight - 40,
        );
        final cardWidth =
            cardHeight * RelationshipsScreen._cardWidth / RelationshipsScreen._cardHeight;

        return Center(
          child: Stack(
            // Kart gölgeleri taşabilsin; dış ClipRRect panel sınırında
            // zaten kırpıyor.
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
                    color: Colors.white.withValues(alpha: 0.035),
                  ),
                ),
              ),
              SizedBox(
                height: cardHeight,
                // Masaüstü ve web'de fare/trackpad ile sürükleyerek kaydırmak
                // varsayılan olarak kapalı; şerit kayabilsin diye açıyoruz.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    clipBehavior: Clip.none,
                    itemCount: relationships.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      return _RelationshipCharacterCard(
                        card: relationships[index],
                        session: session,
                        onChanged: onChanged,
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
            'İlişkiler',
            style: TextStyle(
              color: AppColors.textPrimary,
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
              color: AppColors.textMuted,
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
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
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
    required this.card,
    required this.session,
    required this.onChanged,
    required this.width,
    required this.height,
  });

  final api.RelationshipCard card;
  final CareerSession session;
  final VoidCallback onChanged;
  final double width;
  final double height;

  @override
  State<_RelationshipCharacterCard> createState() =>
      _RelationshipCharacterCardState();
}

class _RelationshipCharacterCardState
    extends State<_RelationshipCharacterCard> {
  final _callButtonKey = GlobalKey();
  final _cardKey = GlobalKey();

  /// Anahtarın işaret ettiği widget'ın ekran koordinatındaki dikdörtgeni.
  Rect? _globalRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    return renderBox.localToGlobal(Offset.zero) & renderBox.size;
  }

  Future<void> _openDialog() async {
    final rect = _globalRect(_callButtonKey);
    if (rect == null) return;
    final relationshipId = widget.card.relationshipId;
    final presentation = presentationForRelationship(relationshipId);
    final tree = _dialogueTreeByRelationshipId[relationshipId];
    if (tree == null) return;

    final changed = await Navigator.of(context).push<bool>(
      ExpandPageRoute<bool>(
        rect: rect,
        page: DialogScreen(
          contactName: widget.card.contactName,
          tree: tree,
          tint: presentation.tint,
          relationshipId: relationshipId,
          dialogueId: presentation.dialogueId,
          scene: presentation.scene,
          // Kişinin görünüşü kimliğinden türetiliyor: antrenör her
          // açılışta aynı, medyacı ondan farklı (bkz. PortraitTraits.forId).
          portrait: PortraitTraits.forId(relationshipId, tint: presentation.tint),
          session: widget.session,
        ),
      ),
    );
    if (changed == true) widget.onChanged();
  }

  /// R2 · `GET /careers/{cid}/relationships/{rid}` — profil künyesi ancak
  /// açılırken çekilir; R1'in beş kartı bunu taşımaz (§5.4).
  Future<void> _openProfile() async {
    final origin = _globalRect(_cardKey);
    try {
      final careerId = await widget.session.resolve();
      final profile = await widget.session.client.relationship(
        careerId,
        widget.card.relationshipId,
      );
      if (!mounted) return;
      await showCharacterProfile(
        context,
        profile: _toProfile(profile),
        originRect: origin,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil alınamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CharacterCard(
      key: _cardKey,
      data: _toCardData(widget.card),
      width: widget.width,
      height: widget.height,
      primaryKey: _callButtonKey,
      onPrimary: _openDialog,
      onSecondary: _openProfile,
    );
  }
}
