import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// Karakter kartının arkasındaki kişi: modalda gösterilen künye.
class CharacterProfile {
  const CharacterProfile({
    required this.name,
    required this.relationLabel,
    required this.age,
    required this.occupation,
    required this.hobbies,
    required this.bio,
    required this.badgeCode,
    required this.icon,
    required this.tint,
    required this.score,
    required this.lastContact,
  });

  /// Kişinin tam adı: 'Mert Çalışkan'.
  final String name;

  /// Oyuncuya göre konumu: 'Antrenör', 'Partner'.
  final String relationLabel;

  final int age;
  final String occupation;
  final List<String> hobbies;

  /// Bir-iki cümlelik serbest tanıtım metni.
  final String bio;

  final String badgeCode;
  final IconData icon;
  final Color tint;

  /// 0-100 arası ilişki puanı.
  final int score;

  /// Son temas: '12 Ağu · 14:30'.
  final String lastContact;
}

/// Profili, [originRect] dikdörtgeninden ekranın ortasına doğru büyüyerek açar.
/// [originRect] karakter kartının global konumu olduğunda kart öne geliyormuş
/// hissi veriyor; null geçilirse modal olduğu yerde büyür.
Future<void> showCharacterProfile(
  BuildContext context, {
  required CharacterProfile profile,
  Rect? originRect,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: profile.name,
    barrierColor: Colors.black.withValues(alpha: 0.66),
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (_, _, _) => CharacterProfileModal(profile: profile),
    transitionBuilder: (context, animation, _, child) {
      return _GrowFromCardTransition(
        animation: animation,
        originRect: originRect,
        child: child,
      );
    },
  );
}

/// Modalı sabit boyutta tutup `Transform.scale` ile büyütür: animasyon boyunca
/// yeniden yerleşim olmadığı için metinler zıplamaz.
class _GrowFromCardTransition extends StatelessWidget {
  const _GrowFromCardTransition({
    required this.animation,
    required this.originRect,
    required this.child,
  });

  static const _maxWidth = 340.0;
  static const _maxHeight = 480.0;

  final Animation<double> animation;
  final Rect? originRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(_maxWidth, screen.width - 40);
    final height = math.min(_maxHeight, screen.height - 80);
    final target = Rect.fromCenter(
      center: Offset(screen.width / 2, screen.height / 2),
      width: width,
      height: height,
    );
    final origin =
        originRect ??
        Rect.fromCenter(
          center: target.center,
          width: width * 0.85,
          height: height * 0.85,
        );

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // İçerik biraz gecikmeli beliriyor; küçükken metin okunmuyor zaten.
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.2, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0.5, 1, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        final center = Offset.lerp(origin.center, target.center, t)!;
        final scale = lerpDouble(origin.width / width, 1, t)!;

        return Stack(
          children: [
            Positioned(
              left: center.dx - width / 2,
              top: center.dy - height / 2,
              width: width,
              height: height,
              child: Transform.scale(
                scale: scale,
                child: FadeTransition(opacity: fade, child: child),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

/// Kartın büyütülmüş hâli: üstte kişinin künyesi, altta özellik listesi.
class CharacterProfileModal extends StatelessWidget {
  const CharacterProfileModal({super.key, required this.profile});

  static const _base = Color(0xFF141821);
  static const _textSecondary = AppColors.textSoft;

  final CharacterProfile profile;

  @override
  Widget build(BuildContext context) {
    final tint = profile.tint;

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: tint.withValues(alpha: 0.24),
              blurRadius: 36,
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _base,
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHeader(profile: profile),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'İsim', value: profile.name),
                        _InfoRow(label: 'Yaş', value: '${profile.age}'),
                        _InfoRow(label: 'Meslek', value: profile.occupation),
                        _InfoRow(
                          label: 'Son görüşme',
                          value: profile.lastContact,
                        ),
                        const SizedBox(height: 14),
                        const _SectionTitle('HOBİLER'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final hobby in profile.hobbies)
                              _HobbyChip(label: hobby, tint: tint),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _SectionTitle('HAKKINDA'),
                        const SizedBox(height: 6),
                        Text(
                          profile.bio,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
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
                      child: const Text('Kapat'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Karttaki ışık dilini tekrarlayan üst blok.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final CharacterProfile profile;

  @override
  Widget build(BuildContext context) {
    final tint = profile.tint;

    return SizedBox(
      height: 132,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.9),
                radius: 1.2,
                colors: [
                  tint.withValues(alpha: 0.45),
                  tint.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Filigran ikon sağ kenardan taşıyor.
          Positioned(
            right: -18,
            top: 8,
            child: Icon(
              profile.icon,
              size: 108,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.close,
                size: 20,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: tint.withValues(alpha: 0.55)),
                  ),
                  child: Text(
                    profile.badgeCode,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.relationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CharacterProfileModal._textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ScorePill(score: profile.score, tint: tint),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 0.5,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.tint});

  final int score;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.95), tint.withValues(alpha: 0.55)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: tint.withValues(alpha: 0.4), blurRadius: 12),
        ],
      ),
      child: Text(
        (score / 10).toStringAsFixed(1),
        style: const TextStyle(
          color: AppColors.surfaceDeep,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Etiketler hazır büyük harfle geliyor: `toUpperCase` Türkçe'de 'i' harfini
/// 'İ' yerine 'I' yapıyor.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: CharacterProfileModal._textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HobbyChip extends StatelessWidget {
  const _HobbyChip({required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
