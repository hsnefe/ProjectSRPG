import 'package:flutter/material.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Sihirbaz adımlarının paylaştığı küçük parçalar. Dört adım ayrı dosyada
/// yaşıyor (ekran dosyası tek başına 1700 satırı geçiyordu), ortak kabuklar
/// da burada tek nüsha duruyor.

/// Saha yeteneklerinin FE etiketleri (§1.3: Türkçe etiket FE'de kalır).
const attributeLabels = <String, String>{
  'shooting': 'Şut',
  'passing': 'Pas',
  'dribbling': 'Dribling',
  'tackling': 'Müdahale',
};

/// Önizleme çubuklarının sırası — rol bonusu hangi yeteneğe gitmiş olursa
/// olsun dördü de aynı sırada görünsün diye sabit.
const skillOrder = <String>['shooting', 'passing', 'dribbling', 'tackling'];

/// Nitelikler motorda `double`; tam sayı olanlar ondalıksız yazılır
/// (20 → "20", 22.5 → "22.5").
String formatSkill(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

class StepIntro extends StatelessWidget {
  const StepIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Seçilebilir kart — milliyet, rol ve kulüp satırlarının ortak kabuğu.
class SelectCard extends StatelessWidget {
  const SelectCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBg : AppColors.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: child,
      ),
    );
  }
}

class WizardTag extends StatelessWidget {
  const WizardTag({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class GroupHeader extends StatelessWidget {
  const GroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.45),
                width: 0.5,
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}
