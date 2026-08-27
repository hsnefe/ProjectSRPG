import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// Bir mini oyunu saran ortak kabuk parçaları.
///
/// Antrenman ekranı ve sınav ekranı aynı çerçeveyi kullanıyor — üst başlık
/// çubuğu ve üç denemenin göstergesi — ama sonuç panelleri farklı: biri
/// [TrainingResult] gösteriyor, diğeri sınav notu. Ortak olan kısım burada tek
/// nüsha duruyor, ayrışan kısım kendi ekranında kalıyor.

/// Geri çıkışlı başlık çubuğu.
class GameHeaderBar extends StatelessWidget {
  const GameHeaderBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Deneme göstergesi, faz ipucu ve son uçuşun sonucu.
class AttemptFooter extends StatelessWidget {
  const AttemptFooter({
    super.key,
    required this.log,
    required this.total,
    required this.hint,
    required this.lastLabel,
  });

  final List<bool> log;
  final int total;
  final String hint;
  final String? lastLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AttemptPip(made: i < log.length ? log[i] : null),
                ),
              const Spacer(),
              if (lastLabel != null)
                Text(
                  lastLabel!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class AttemptPip extends StatelessWidget {
  const AttemptPip({super.key, required this.made});

  /// null = henüz atılmadı.
  final bool? made;

  @override
  Widget build(BuildContext context) {
    final made = this.made;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: made == null
            ? Colors.transparent
            : (made ? AppColors.success : AppColors.danger),
        border: Border.all(
          color: made == null ? AppColors.border : Colors.transparent,
          width: 1.5,
        ),
      ),
    );
  }
}
