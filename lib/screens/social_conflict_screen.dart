import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/character_portrait.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';
import 'package:project_srpg/widgets/relationship_presentation.dart';
import 'package:project_srpg/widgets/turkish_text.dart';

/// Çakışan iki sosyal planın tek bir akşam için yarıştığı ekran (§12.9, D59).
///
/// **Çıkılamaz ve butonsuz.** Karta basmak hem seçim hem çıkış: onay adımı
/// yok, geri tuşu işlemez, `advance` da kapıda durur
/// (`social_conflict_pending`). Cevap zorunlu olduğu için sunucu da hiçbir
/// şey harcamıyor (D60) — bu ekranın bütçe yüzünden başarısız olan bir yolu
/// yok, yalnızca ağ hatası olabilir.
///
/// Deltalar açılışta gelmiyor: `GET /conflicts` yalnızca kim, ne ve şu anki
/// puan gönderiyor. Barlar dokunuştan **sonra**, `choose` yanıtının iki
/// taraflı `relationship_changes`'inden oynuyor — ödül tablosunu seçim
/// öncesi tele koymak §5.7 ve §5.4 R4'ün yasakladığı şey.
Future<api.SocialConflictResult?> showSocialConflictScreen(
  BuildContext context, {
  required CareerSession session,
  required api.SocialConflict conflict,
}) {
  return Navigator.of(context).push<api.SocialConflictResult>(
    PageRouteBuilder<api.SocialConflictResult>(
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) =>
          SocialConflictScreen(session: session, conflict: conflict),
      // `showSocialOfferScreen` ile aynı eğri: oyunun "karar ver" anları hep
      // bu şekilde beliriyor.
      transitionsBuilder: (context, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
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

class SocialConflictScreen extends StatefulWidget {
  const SocialConflictScreen({
    super.key,
    required this.session,
    required this.conflict,
  });

  final CareerSession session;
  final api.SocialConflict conflict;

  @override
  State<SocialConflictScreen> createState() => _SocialConflictScreenState();
}

class _SocialConflictScreenState extends State<SocialConflictScreen> {
  String? _chosenRef;
  api.SocialConflictResult? _result;
  bool _busy = false;
  String? _error;
  Timer? _closeTimer;

  /// Karta basmak hem seçim hem çıkış. Ekran hemen kapanmıyor çünkü kapanırsa
  /// barların oynadığı görülmez — sunucu cevabı geldikten sonra 320 ms
  /// animasyon + rakamları okuma payı kadar durup kendi kapanıyor.
  ///
  /// `Future.delayed` değil `Timer`: ekran bu bir saniye içinde başka bir
  /// yoldan kapanabilir ve elde iptal edilebilir bir kulp olmadan
  /// `BuildContext` dispose'dan sonra kullanılmış olurdu.
  Future<void> _choose(String refId) async {
    if (_busy || _result != null) return;
    setState(() {
      _busy = true;
      _error = null;
      _chosenRef = refId;
    });
    try {
      final careerId = await widget.session.resolve();
      final result = await widget.session.client.chooseSocialConflict(
        careerId,
        widget.conflict.conflictId,
        refId,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
      _closeTimer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        Navigator.of(context).pop(result);
      });
    } on CareerApiException catch (e) {
      // D60 gereği bütçe/eşik yüzünden buraya düşülmez; kalan tek sebep ağ.
      // Seçim geri alınır ki oyuncu tekrar deneyebilsin — ekranın cevapsız
      // kapanan bir yolu yok.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _chosenRef = null;
        _error = e.message ?? 'Seçim kaydedilemedi.';
      });
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sides = widget.conflict.sides;

    return PopScope(
      // Geri tuşu kapatmaz; çıkışın tek yolu bir kart seçmek (D53'ün kuralı).
      canPop: false,
      child: Scaffold(
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: _buildStage(sides)),
                          if (_error case final message?)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                message,
                                key: const Key('social_conflict_error'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
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
        ),
      ),
    );
  }

  Widget _buildStage(List<api.SocialConflictSide> sides) {
    if (sides.length < 2) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ölçüler genişlikten türüyor: 420 kapağının altında da dar bir
        // ekranda da çapraz aynı oranda duruyor.
        final extent = (constraints.maxWidth * 0.62).clamp(150.0, 200.0);
        final drop = extent * 0.83;

        return SizedBox(
          height: extent + drop,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: _SideCard(
                  key: const ValueKey('conflictFirst'),
                  side: sides[0],
                  extent: extent,
                  change: _result?.changeFor(sides[0].relationshipId),
                  isChosen: _chosenRef == sides[0].refId,
                  onTap: () => _choose(sides[0].refId),
                ),
              ),
              Positioned(
                right: 0,
                top: drop,
                child: _SideCard(
                  key: const ValueKey('conflictSecond'),
                  side: sides[1],
                  extent: extent,
                  change: _result?.changeFor(sides[1].relationshipId),
                  isChosen: _chosenRef == sides[1].refId,
                  onTap: () => _choose(sides[1].refId),
                ),
              ),
              // Kaldırılan açıklama cümlesinin işini gören tek işaret; iki
              // karenin çaprazda bıraktığı boşluğa oturuyor, o yüzden en
              // üstte çiziliyor.
              const Positioned.fill(child: Align(child: _OrBadge())),
            ],
          ),
        );
      },
    );
  }
}

class _OrBadge extends StatelessWidget {
  const _OrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Text(
        'YA DA',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 9,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Kare, tamamı sanat olan taraf kartı. Metin ayrı bir gövdede değil, portrenin
/// üstündeki perdenin üzerinde duruyor — kare bir kartta metin bloğu için yer
/// ayırmak sanata bırakılan alanı yarıya indirirdi.
class _SideCard extends StatelessWidget {
  const _SideCard({
    super.key,
    required this.side,
    required this.extent,
    required this.isChosen,
    this.change,
    this.onTap,
  });

  final api.SocialConflictSide side;
  final double extent;
  final bool isChosen;

  /// Sunucunun bu ilişki için döndürdüğü `before`/`after`; seçim yapılmadan
  /// önce null ve bar mevcut puanda duruyor.
  final api.RelationshipChange? change;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final presentation = presentationForRelationship(side.relationshipId);
    final tint = presentation.tint;
    final contact = side.relationship;

    final decided = change != null;
    final before = change?.before ?? contact?.score ?? 0;
    final after = change?.after ?? before;
    final delta = after - before;

    return GestureDetector(
      // Kartın içi baştan sona CustomPaint ve DecoratedBox; hiçbiri kendi
      // başına vuruş almıyor, deferToChild ile karenin ortasına yapılan
      // dokunuş boşa düşerdi. Kare bir bütün olarak basılabilir olmalı.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: decided ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final shown = (before + delta * t).round();

          return AnimatedOpacity(
            opacity: decided && !isChosen ? 0.55 : 1,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: extent,
              height: extent,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isChosen ? tint : AppColors.border,
                  width: isChosen ? 1 : 0.5,
                ),
                boxShadow: isChosen
                    ? [
                        BoxShadow(
                          color: tint.withValues(alpha: 0.18),
                          spreadRadius: 3,
                          blurRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DialogueBackdrop(
                        scene: presentation.scene,
                        tint: tint,
                      ),
                    ),
                    Positioned.fill(
                      child: CharacterPortrait(
                        traits: PortraitTraits.forId(
                          side.relationshipId,
                          tint: tint,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // Kare olduğu için perde offer ekranının şeridinden
                          // daha geç başlıyor — portrenin yüzü açıkta kalsın.
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.surfaceDeep.withValues(alpha: 0.93),
                            ],
                            stops: const [0.34, 0.82],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 9,
                      top: 9,
                      child: _TagPill(
                        icon: presentation.icon,
                        label: presentation.leftTag,
                        tint: isChosen || !decided ? tint : AppColors.textSoft,
                      ),
                    ),
                    if (isChosen)
                      Positioned(
                        right: 9,
                        top: 9,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: tint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 13,
                            color: AppColors.surfaceDeep,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            contact?.contactName ?? side.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                          if (contact case final person?)
                            Text(
                              trUpperCase(person.category),
                              style: const TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 9.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          const SizedBox(height: 5),
                          Text(
                            side.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 7,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$shown',
                            style: TextStyle(
                              color: decided
                                  ? AppColors.textPrimary
                                  : AppColors.textSoft,
                              fontSize: 10,
                            ),
                          ),
                          if (decided && delta != 0) ...[
                            const SizedBox(width: 5),
                            Text(
                              '${delta > 0 ? '+' : ''}$delta',
                              style: TextStyle(
                                color: delta > 0
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      // Köşe yarıçapı yok: kartın kendi ClipRRect'i alt köşeleri
                      // zaten kesiyor, bar da kartın tabanı gibi okunuyor.
                      child: _RelationshipBar(
                        tint: tint,
                        // Kazanç dolgunun ucuna ekleniyor, kayıp dolgunun
                        // içinden yeniyor — aynı bar iki yönü de anlatıyor.
                        solidFraction:
                            (delta >= 0 ? before : before + delta * t) / 100,
                        extraFraction: (delta.abs() * t) / 100,
                        isLoss: delta < 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.icon, required this.label, required this.tint});

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceDeep.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: tint),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: tint, fontSize: 9, letterSpacing: 0.3),
            ),
          ],
        ],
      ),
    );
  }
}

/// İki segmentli ilişki barı. Uygulamada ortak bir bar widget'ı yok — her bar
/// kendi ekranında `LinearProgressIndicator` ile kuruluyor — ama burada dolgunun
/// yanında bir de kazanç/kayıp segmenti gerektiği için yerinde çiziliyor.
class _RelationshipBar extends StatelessWidget {
  const _RelationshipBar({
    required this.tint,
    required this.solidFraction,
    required this.extraFraction,
    required this.isLoss,
  });

  final Color tint;

  /// Kalan (ya da kazanç öncesi) dolgu, 0-1.
  final double solidFraction;

  /// Eklenen kazanç ya da yenen kayıp, 0-1.
  final double extraFraction;

  final bool isLoss;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final solid = (width * solidFraction).clamp(0.0, width);
          final extra = (width * extraFraction).clamp(0.0, width - solid);

          return Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: AppColors.surfaceDeep),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: solid,
                child: ColoredBox(color: tint),
              ),
              Positioned(
                left: solid,
                top: 0,
                bottom: 0,
                width: extra,
                child: isLoss
                    ? const CustomPaint(painter: _HatchPainter())
                    : ColoredBox(color: tint.withValues(alpha: 0.45)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Kaybedilen dilim: düz dolgu yerine çapraz tarama, "bu parça elinden gidiyor"
/// okunsun diye — aynı kırmızı düz basılsa kazanılmış bir dilimden ayırt edilmezdi.
class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.danger.withValues(alpha: 0.35),
    );
    final stroke = Paint()
      ..color = AppColors.danger
      ..strokeWidth = 2;
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
}
