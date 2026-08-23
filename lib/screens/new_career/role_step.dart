import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/screens/new_career/wizard_kit.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Adım 2 · Pozisyon ve rol seçimi.
class RoleStep extends StatelessWidget {
  const RoleStep({
    super.key,
    required this.options,
    required this.position,
    required this.roleId,
    required this.onPosition,
    required this.onRole,
  });

  final api.CareerOptions options;
  final String? position;
  final String? roleId;
  final ValueChanged<String> onPosition;
  final ValueChanged<String> onRole;

  @override
  Widget build(BuildContext context) {
    final selected = options.positions.where((p) => p.position == position);
    final roles = selected.isEmpty ? <api.RoleOption>[] : selected.first.roles;

    // Roller katalogdaki sırayla gruplanır (DC → DL/DR → DM …), yani ekran
    // sahayı arkadan öne dizmek için ikinci bir liste tutmaz.
    final groups = <String, List<api.RoleOption>>{};
    for (final role in roles) {
      groups.putIfAbsent(role.group, () => []).add(role);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        const StepIntro(
          eyebrow: 'ADIM 2 / 4',
          title: 'Sahada nerede oynuyorsun?',
          subtitle:
              'Her rol iki yetenek yuvası harcar. İkisini de aynı '
              'yeteneğe veren rol orada iki kat başlar.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options.positions)
              _PositionPill(
                label: option.position,
                selected: option.position == position,
                onTap: () => onPosition(option.position),
              ),
          ],
        ),
        const SizedBox(height: 18),
        for (final entry in groups.entries) ...[
          GroupHeader(label: entry.key),
          for (final role in entry.value) ...[
            _RoleCard(
              role: role,
              selected: role.roleId == roleId,
              startingValues: options.startingValues,
              onTap: () => onRole(role.roleId),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _PositionPill extends StatelessWidget {
  const _PositionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.startingValues,
    required this.onTap,
  });

  final api.RoleOption role;
  final bool selected;
  final api.StartingValues startingValues;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Aynı anahtar iki kez geçebilir; rozet o zaman tek satırda çift bonusu
    // gösterir (Regista → "Pas +4").
    final slots = <String, int>{};
    for (final key in role.attributes) {
      slots[key] = (slots[key] ?? 0) + 1;
    }

    return SelectCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final slot in slots.entries)
                WizardTag(
                  text:
                      '${attributeLabels[slot.key] ?? slot.key} '
                      '+${formatSkill(slot.value * startingValues.roleBonusPerSlot)}',
                  color: AppColors.success,
                ),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 12),
            for (final key in skillOrder)
              _SkillBar(
                label: attributeLabels[key] ?? key,
                value: startingValues.skillFor(key, role.attributes),
                highlighted: slots.containsKey(key),
              ),
          ],
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final String label;
  final double value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0, 1),
                minHeight: 5,
                backgroundColor: AppColors.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  highlighted ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              formatSkill(value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
