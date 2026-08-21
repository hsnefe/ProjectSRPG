import 'package:flutter/material.dart';

import 'package:project_srpg/game/training_result.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Bir antrenman mini-oyunu bittiğinde alt kontrollerin yerine geçen panel.
/// Üç host ekran da bunu kullanıyor, o yüzden burada.
///
/// Sonucu kendisi pop etmez; [onDone] çağıran ekrana ait — böylece oyun
/// döngüsünün içinden Navigator'a dokunulmuş olmuyor.
class TrainingResultPanel extends StatelessWidget {
  const TrainingResultPanel({
    super.key,
    required this.result,
    required this.onDone,
  });

  final TrainingResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final good = result.succeeded;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            good ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 26,
            color: good ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  good ? 'Antrenman başarılı' : 'Antrenman başarısız',
                  style: TextStyle(
                    color: good ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.detail,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onDone,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
  }
}
