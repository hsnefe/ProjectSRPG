import 'package:flutter/material.dart';
import 'package:project_srpg/game/attribute_labels.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/money.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/character_portrait.dart';
import 'package:project_srpg/widgets/date_labels.dart';
import 'package:project_srpg/widgets/delta_row.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';
import 'package:project_srpg/widgets/relationship_presentation.dart';
import 'package:project_srpg/widgets/typewriter_text.dart';

/// Sosyal teklif ekranı — R4'ün metnini gösterir, R5/R6'yı çağırır (§5.4).
///
/// **Çıkılamaz (D53).** Geri tuşu işlemez ve başlıkta geri oku yoktur; kabul ya
/// da ret verilmeden ekrandan çıkılmaz. Bunun güvenli olmasının sebebi INV-40:
/// ret hiçbir gereksinim kontrol etmez, hiçbir şey harcamaz ve başarısız
/// olamaz — parası ve günü bitmiş bir oyuncu bile teklifi temizleyebilir.
/// Kabul reddedilirse (`409`) ekran **teklif fazında kalır** ve mesaj görünür.
///
/// Modal değil de ekran olmasının sebebi `CoachTalkScreen` ile aynı: bu bir
/// konuşma anı. Sahne + portre + daktilo dili 380px'lik bir diyalog kutusuna
/// sığmıyordu; ayrıca sonucu (ilişki/nitelik deltaları) kapanan bir modalın
/// ardından gelen SnackBar yerine kişinin karşısında göstermek istiyoruz.
Future<api.SocialOfferResult?> showSocialOfferScreen(
  BuildContext context, {
  required CareerSession session,
  required api.SocialOffer offer,
}) {
  return Navigator.of(context).push<api.SocialOfferResult>(
    PageRouteBuilder<api.SocialOfferResult>(
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) =>
          SocialOfferScreen(session: session, offer: offer),
      // `showInterventionOffer`'ın açılışıyla aynı eğri: oyunun "karar ver"
      // anları hep bu şekilde beliriyor.
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class SocialOfferScreen extends StatefulWidget {
  const SocialOfferScreen({
    super.key,
    required this.session,
    required this.offer,
  });

  final CareerSession session;
  final api.SocialOffer offer;

  @override
  State<SocialOfferScreen> createState() => _SocialOfferScreenState();
}

class _SocialOfferScreenState extends State<SocialOfferScreen> {
  final _typewriterKey = GlobalKey<TypewriterTextState>();

  bool _busy = false;
  String? _error;
  api.SocialOfferResult? _result;

  bool _typewriterComplete = false;

  /// Butonlar daktilo bittikten sonra 80 ms arayla beliriyor; [_revealGen]
  /// hızlı bir dokunuşun sırayı iptal edebilmesi için (bkz. `dialog_screen`).
  List<bool> _actionVisible = const [false, false];
  int _revealGen = 0;

  Future<void> _answer({required bool accept}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final careerId = await widget.session.resolve();
      final result = accept
          ? await widget.session.client.acceptSocialOffer(
              careerId,
              widget.offer.offerId,
            )
          : await widget.session.client.declineSocialOffer(
              careerId,
              widget.offer.offerId,
            );
      if (!mounted) return;
      // Pop yok: ekran sonuç fazına geçiyor. Deltaları kişi karşında dururken
      // göstermek, kapanan bir modalın ardından gelen SnackBar'dan okunur.
      // Uçuştaki beliriş sırası iptal edilir: sonuç fazının tek butonu kendi
      // daktilosu bitmeden görünmemeli.
      _revealGen++;
      setState(() {
        _busy = false;
        _result = result;
        _typewriterComplete = false;
        _actionVisible = const [false];
      });
    } on CareerApiException catch (e) {
      // Kabul reddedildi (bütçe/gereksinim/bakiye). Teklif fazı açık kalır —
      // reddetmek hâlâ mümkün ve asla başarısız olmaz (INV-40).
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message ?? 'Teklif yanıtlanamadı.';
      });
    }
  }

  Future<void> _revealActionsStaggered() async {
    final gen = ++_revealGen;
    for (var i = 0; i < _actionVisible.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || gen != _revealGen) return;
      final upTo = i;
      setState(() {
        _actionVisible = [
          for (var j = 0; j < _actionVisible.length; j++)
            j <= upTo || _actionVisible[j],
        ];
      });
    }
  }

  /// Metne dokununca: yazı hâlâ yazılıyorsa anında tamamlanır, tamamlandıysa
  /// ve butonlar sırayla beliriyorsa hepsi anında gösterilir.
  void _onMessageTap() {
    if (!_typewriterComplete) {
      _typewriterKey.currentState?.skip();
      return;
    }
    if (_actionVisible.contains(false)) {
      _revealGen++;
      setState(() {
        _actionVisible = List.filled(_actionVisible.length, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final presentation = presentationForRelationship(offer.relationshipId);
    final result = _result;

    return PopScope(
      // Geri tuşu kapatmaz — cevap verilmeden çıkış yok (D53).
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface1,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // Tarayıcıda oynanıyor: 420'nin ötesine yayılan bir portre saçma
              // duruyor, `dialog_screen` de aynı kapağı kullanıyor.
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
                        _HeaderStrip(openedOn: offer.openedOn),
                        _SceneSection(
                          relationshipId: offer.relationshipId,
                          presentation: presentation,
                          contact: offer.relationship,
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _onMessageTap,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                              child: result == null
                                  ? _buildOfferBody(offer)
                                  : _buildResultBody(result),
                            ),
                          ),
                        ),
                        _ActionBar(
                          visible: _actionVisible,
                          children: result == null
                              ? [
                                  _ActionButton(
                                    key: const ValueKey('offerDecline'),
                                    label: offer.declineLabel,
                                    onPressed: _busy
                                        ? null
                                        : () => _answer(accept: false),
                                  ),
                                  _ActionButton(
                                    key: const ValueKey('offerAccept'),
                                    label: offer.acceptLabel,
                                    tint: presentation.tint,
                                    onPressed: _busy
                                        ? null
                                        : () => _answer(accept: true),
                                  ),
                                ]
                              : [
                                  _ActionButton(
                                    key: const ValueKey('offerDone'),
                                    label: 'Devam',
                                    tint: presentation.tint,
                                    onPressed: () =>
                                        Navigator.of(context).pop(result),
                                  ),
                                ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferBody(api.SocialOffer offer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        _typewriter(offer.body),
        if (offer.costs.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: _costChips(offer.costs)),
        ],
        if (offer.requires.isNotEmpty) ...[
          const SizedBox(height: 12),
          // D42 · kabul kapısı. Nitelik adları ortak `attribute_labels.dart`'tan
          // geliyor ki burada ikinci kez yazılmasınlar.
          const Text(
            'Kabul için',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in offer.requires.entries)
                _Chip(
                  icon: Icons.lock_outline,
                  tint: AppColors.danger,
                  label: '${attributeLabel(entry.key)} ${entry.value}',
                ),
            ],
          ),
        ],
        if (_error case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            key: const Key('social_offer_error'),
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildResultBody(api.SocialOfferResult result) {
    final accepted = result.offer.status == 'accepted';
    final contact = widget.offer.relationship;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _typewriter(_closingLine(widget.offer.relationshipId, accepted)),
        const SizedBox(height: 14),
        // §12.8/D58 · bu kabul anında çözülmedi — geri kalanı planın günü
        // bekliyor. Nitelik/kondisyon/para satırları bu yüzden boş kalıyor;
        // burada onun yerine ne zaman gidileceği yazıyor.
        if (result.plan case final plan?)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Chip(
              icon: Icons.event_outlined,
              tint: AppColors.warning,
              label: 'Randevu: ${fullDateLabel(plan.dueOn)}',
            ),
          ),
        for (final change in result.relationshipChanges)
          DeltaRow(
            key: ValueKey('offerRelDelta_${change.relationshipId}'),
            label: change.relationshipId == widget.offer.relationshipId
                ? (contact?.category ?? 'İlişki')
                : change.relationshipId,
            before: change.before.toDouble(),
            after: change.after.toDouble(),
          ),
        for (final change in result.attributeChanges) ...[
          DeltaRow(
            key: ValueKey('offerAttrDelta_${change.key}'),
            label: attributeLabel(change.key),
            before: change.before,
            after: change.after,
          ),
          // D43 · seviyeyi BE yolluyor, ekran bir kilidin açıldığını yeniden
          // hesaplamadan gösterebiliyor (§5.5 notu).
          if (change.levelAfter != change.levelBefore)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Text(
                '${attributeLabel(change.key)} seviye ${change.levelAfter}',
                style: const TextStyle(color: AppColors.success, fontSize: 11),
              ),
            ),
        ],
        for (final entry in result.ledgerEntries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.reason,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  formatMoney(entry.amount),
                  style: TextStyle(
                    color: entry.amount >= 0
                        ? AppColors.success
                        : AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _typewriter(String text) {
    return TypewriterText(
      key: _typewriterKey,
      text: text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        height: 1.55,
      ),
      // Kare sonuna erteleniyor: `TypewriterText` boş metinde `onComplete`'i
      // `initState` içinden çağırıyor, oradan `setState` build sırasında
      // patlardı (`body` sözleşmede boş olabilir, varsayılanı '').
      onComplete: () {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _typewriterComplete) return;
          setState(() => _typewriterComplete = true);
          _revealActionsStaggered();
        });
      },
    );
  }
}

/// Teklif çözülünce kişinin son repliği. §5.8: BE kapanış metni göndermiyor,
/// `coach_talk_screen`'in `_lineFor`'u ile aynı kalıpta FE içeriği.
String _closingLine(String relationshipId, bool accepted) {
  return switch ((relationshipId, accepted)) {
    ('coach', true) => 'İyi. Yarın sahada karşılığını görmek istiyorum.',
    ('coach', false) => 'Peki. Ama bu kapıyı her hafta açmıyorum.',
    ('team', true) => 'Hadi o zaman, seni bekliyoruz.',
    ('team', false) => 'Boş ver, başka sefere. Kaçırdığını biz anlatırız.',
    ('media', true) => 'Teşekkürler, yarın imzanla çıkacak.',
    ('media', false) => 'Anlaşıldı. Yine de bir gün konuşacağız.',
    ('fans', true) => 'Bunu duyunca herkes çok sevinecek.',
    ('fans', false) => 'Olsun. Tribünde yine oradayız.',
    ('partner', true) =>
      'Güzel. Uzun zamandır bir akşamı beraber geçirmemiştik.',
    ('partner', false) => 'Tamam... sen bilirsin.',
    ('family', true) => 'İyi ettin. Sesini duymak yetiyor bize.',
    ('family', false) => 'Meşgulsün, biliyoruz. Kendine iyi bak.',
    (_, true) => 'Anlaştık o zaman.',
    (_, false) => 'Peki, başka zaman.',
  };
}

/// '2 sa' · '20 enerji' — BE sayı gönderir, birimi ekran yazar (§1.3). Tek bir
/// gri satır yerine maliyet başına bir pill: türü renkten de okunuyor.
List<Widget> _costChips(Map<String, double> costs) {
  final chips = <Widget>[];
  for (final entry in costs.entries) {
    switch (entry.key) {
      case 'time':
        final hours = entry.value / 60;
        chips.add(
          _Chip(
            icon: Icons.schedule,
            tint: AppColors.warning,
            label: hours >= 1
                ? '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} sa'
                : '${entry.value.round()} dk',
          ),
        );
      case 'energy':
        chips.add(
          _Chip(
            icon: Icons.bolt,
            tint: AppColors.success,
            label: '${entry.value.round()} enerji',
          ),
        );
      default:
        chips.add(
          _Chip(
            icon: Icons.remove_circle_outline,
            tint: AppColors.textMuted,
            label: '${entry.value.round()} ${entry.key}',
          ),
        );
    }
  }
  return chips;
}

class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.openedOn});

  final String openedOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          const Text(
            'SOSYAL TEKLİF',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Text(
            fullDateLabel(openedOn),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Sahne + portre — `dialog_screen`/`coach_talk_screen` ile aynı iki katman.
/// Üstüne metne doğru kararan bir perde ve kişinin künyesi biniyor.
class _SceneSection extends StatelessWidget {
  const _SceneSection({
    required this.relationshipId,
    required this.presentation,
    required this.contact,
  });

  final String relationshipId;
  final RelationshipPresentation presentation;
  final api.SocialOfferContact? contact;

  @override
  Widget build(BuildContext context) {
    final tint = presentation.tint;

    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: DialogueBackdrop(scene: presentation.scene, tint: tint),
          ),
          Positioned.fill(
            child: CharacterPortrait(
              traits: PortraitTraits.forId(relationshipId, tint: tint),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.surface2.withValues(alpha: 0),
                    AppColors.surface2.withValues(alpha: 0.92),
                  ],
                  stops: const [0, 0.52, 1],
                ),
              ),
            ),
          ),
          if (contact case final person?) ...[
            Positioned(
              right: 12,
              top: 12,
              child: _ScoreCapsule(score: person.score, tint: tint),
            ),
            Positioned(
              left: 14,
              bottom: 10,
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: tint.withValues(alpha: 0.9),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(presentation.icon, size: 14, color: tint),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        person.contactName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        person.category.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 10,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreCapsule extends StatelessWidget {
  const _ScoreCapsule({required this.score, required this.tint});

  final int score;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface0.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.9), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: 12, color: tint),
          const SizedBox(width: 5),
          Text(
            '$score',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.tint, required this.label});

  final IconData icon;
  final Color tint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: tint, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.visible, required this.children});

  final List<bool> visible;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _Revealed(
                visible: i < visible.length && visible[i],
                child: children[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Revealed extends StatelessWidget {
  const _Revealed({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.25),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        // `Opacity` tek başına dokunuşu engellemiyor: görünmez bir butonun
        // basılabilir kalması hem hata hem de testte sessiz bir tuzak olurdu.
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.tint,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Doluysa birincil buton: ilişkinin tonuyla boyanır — antrenör mavi, aile
  /// turuncu, sevgili mor. Null ise ghost.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tone = tint;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: tone != null
            ? AppColors.textPrimary
            : AppColors.textSecondary,
        disabledForegroundColor: AppColors.textMuted,
        backgroundColor: tone?.withValues(alpha: 0.28),
        side: BorderSide(color: tone ?? AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
