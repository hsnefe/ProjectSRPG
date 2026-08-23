import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/screens/new_career/wizard_kit.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Adım 3 · Hedef ("hayalindeki") kulüp.
class TargetStep extends StatelessWidget {
  const TargetStep({
    super.key,
    required this.options,
    required this.targetTeamId,
    required this.onTarget,
  });

  final api.CareerOptions options;
  final String? targetTeamId;
  final ValueChanged<String> onTarget;

  @override
  Widget build(BuildContext context) {
    // Lig adına göre gruplanır; hiçbir lige yazılmamış kulüp (competition
    // null) listenin sonunda kendi başlığını alır.
    final groups = <String, List<api.TargetTeamOption>>{};
    for (final option in options.targetTeams) {
      final key = option.competition?.name ?? 'Diğer';
      groups.putIfAbsent(key, () => []).add(option);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        const StepIntro(
          eyebrow: 'ADIM 3 / 4',
          title: 'Hayalindeki kulüp',
          subtitle:
              'Bu oynayacağın kulüp değil. Başlangıç kulübün en alt '
              'ligden atanır; buradaki seçim kariyerinin hedefi olarak saklanır.',
        ),
        for (final entry in groups.entries) ...[
          GroupHeader(label: entry.key),
          for (final option in entry.value) ...[
            _TeamRow(
              option: option,
              selected: option.team.teamId == targetTeamId,
              onTap: () => onTarget(option.team.teamId),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final api.TargetTeamOption option;
  final bool selected;
  final VoidCallback onTap;

  static const _hintColors = <String, Color>{
    'güçlü': AppColors.danger,
    'orta': AppColors.warning,
    'zayıf': AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final team = option.team;
    return SelectCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  team.colorPrimary,
                  team.colorPrimary,
                  team.colorSecondary,
                  team.colorSecondary,
                ],
                stops: const [0, 0.5, 0.5, 1],
              ),
            ),
            child: Text(
              team.shortName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  option.competition?.name ?? 'Lig kaydı yok',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (option.strengthHint.isNotEmpty)
            WizardTag(
              text: option.strengthHint,
              color: _hintColors[option.strengthHint] ?? AppColors.textMuted,
            ),
        ],
      ),
    );
  }
}
