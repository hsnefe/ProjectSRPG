import 'package:flutter/material.dart';
import 'package:project_srpg/game/skill_exam_game.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/screens/new_career/wizard_kit.dart';
import 'package:project_srpg/screens/skill_exam_screen.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Adım 4 · Yetenek sınavları ve sonuç kartı.
class ExamStep extends StatelessWidget {
  const ExamStep({
    super.key,
    required this.options,
    required this.levels,
    required this.outcomes,
    required this.previewOf,
    required this.baseOf,
    required this.onLevel,
  });

  final api.CareerOptions options;
  final Map<String, int> levels;
  final List<api.SkillExamOutcome>? outcomes;
  final double Function(api.SkillExamOption) previewOf;
  final double Function(api.SkillExamOption) baseOf;
  final void Function(String examId, int level) onLevel;

  @override
  Widget build(BuildContext context) {
    final results = outcomes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        StepIntro(
          eyebrow: 'ADIM 4 / 4 · KARİYER KURULDU',
          title: results == null ? 'Sınavlar, tek gönderim' : 'Notlar işlendi',
          subtitle: results == null
              ? 'Notun sahada belli oluyor: sınava girip mini oyunu oyna, '
                    'üç denemenin sonucu notun olsun. Notlar rolün verdiği '
                    'bonusun üstüne eklenir, hepsi tek istekte gider ve bir '
                    'kez verilir — geri dönüşü yok.'
              : 'Nitelikler motorda güncellendi; kariyer merkezinde bu '
                    'değerlerle başlıyorsun.',
        ),
        if (results == null)
          for (final exam in options.skillExams) ...[
            _ExamCard(
              exam: exam,
              level: levels[exam.examId],
              before: baseOf(exam),
              after: previewOf(exam),
              onLevel: (level) => onLevel(exam.examId, level),
            ),
            const SizedBox(height: 10),
          ]
        else
          for (final outcome in results) ...[
            _OutcomeRow(outcome: outcome, title: _titleFor(outcome.examId)),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  String _titleFor(String examId) {
    for (final exam in options.skillExams) {
      if (exam.examId == examId) return exam.title;
    }
    return examId;
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.level,
    required this.before,
    required this.after,
    required this.onLevel,
  });

  final api.SkillExamOption exam;
  final int? level;
  final double before;
  final double after;
  final ValueChanged<int> onLevel;

  @override
  Widget build(BuildContext context) {
    final label = attributeLabels[exam.attributeKey] ?? exam.attributeKey;
    final game = SkillExamGame.forExamId(exam.examId);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (exam.description.isNotEmpty)
                      Text(
                        exam.description,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              WizardTag(text: label, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 12),
          // Oyunu olan sınav oynanarak notlanır; olmayan (şimdilik Dribling,
          // kalıcı olarak Müdahale) eski elle not sırasını korur.
          if (game != null)
            _PlayRow(game: game, level: level, onGraded: onLevel)
          else
            Row(
              children: [
                for (var value = exam.minLevel; value <= exam.maxLevel; value++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _LevelButton(
                      value: value,
                      selected: value == level,
                      onTap: () => onLevel(value),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$label ${formatSkill(before)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                formatSkill(after),
                style: TextStyle(
                  color: level == null
                      ? AppColors.textSecondary
                      : AppColors.success,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                level == null
                    ? 'not girilmedi'
                    : '+${formatSkill(after - before)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Oynanarak notlanan sınavın eylem satırı: ya "Sınava Gir", ya alınmış notun
/// rozeti ve tekrar girme hakkı.
///
/// Notu ekran değil sınav belirliyor — buradan geriye yalnızca
/// [SkillExamScreen]'in döndürdüğü not taşınıyor, o da sihirbazın zaten sahip
/// olduğu `onLevel` kanalından geçiyor.
class _PlayRow extends StatelessWidget {
  const _PlayRow({
    required this.game,
    required this.level,
    required this.onGraded,
  });

  final SkillExamGame game;
  final int? level;
  final ValueChanged<int> onGraded;

  Future<void> _play(BuildContext context) async {
    final grade = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => SkillExamScreen(exam: game),
        settings: const RouteSettings(name: SkillExamScreen.routeName),
      ),
    );
    // Sınavı yarıda bırakmak notu silmez; eldeki not neyse o kalır.
    if (grade != null) onGraded(grade);
  }

  @override
  Widget build(BuildContext context) {
    final level = this.level;

    return Row(
      children: [
        if (level != null) ...[
          Container(
            width: 38,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'sınav notun',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () => _play(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: level == null ? AppColors.accent : AppColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: level == null ? AppColors.accent : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sports_soccer,
                  size: 14,
                  color: level == null ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  level == null ? 'Sınava Gir' : 'Tekrar Gir',
                  style: TextStyle(
                    color:
                        level == null ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({required this.outcome, required this.title});

  final api.SkillExamOutcome outcome;
  final String title;

  @override
  Widget build(BuildContext context) {
    final label = attributeLabels[outcome.attributeKey] ?? outcome.attributeKey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$label · not ${outcome.level}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${formatSkill(outcome.before)} → ${formatSkill(outcome.after)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          WizardTag(
            text: '+${formatSkill(outcome.applied)}',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}
