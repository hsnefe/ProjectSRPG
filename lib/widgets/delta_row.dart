import 'package:flutter/material.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// 'Güven   48 → 53   +5' — bir değerin iki yakasını ve farkını gösteren satır.
///
/// Antrenör konuşması ve sosyal teklif ekranı aynı sonuç panelini kuruyor;
/// satır ikisinde de aynı görünsün diye tek yerde duruyor. İşareti ve rengi
/// farktan türetir, BE'nin gönderdiği `delta` alanına bakmaz — `before/after`
/// her yanıtta var, `delta` her blokta yok (ör. `attribute_changes`).
class DeltaRow extends StatelessWidget {
  const DeltaRow({
    super.key,
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final double before;
  final double after;

  @override
  Widget build(BuildContext context) {
    final delta = after - before;
    final color = delta > 0
        ? AppColors.success
        : (delta < 0 ? AppColors.danger : AppColors.textSecondary);
    final sign = delta > 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${before.round()} → ${after.round()}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 1)}',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
