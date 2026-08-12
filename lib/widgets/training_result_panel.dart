import 'package:flutter/material.dart';

import 'package:project_srpg/game/training_result.dart';

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

  static const _border = Color(0xFF333845);
  static const _textPrimary = Color(0xFFE8EAED);
  static const _textMuted = Color(0xFF6B7280);
  static const _success = Color(0xFF3DDC97);
  static const _danger = Color(0xFFE85D5D);

  final TrainingResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final good = result.succeeded;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            good ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 26,
            color: good ? _success : _danger,
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
                    color: good ? _success : _danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.detail,
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onDone,
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              side: const BorderSide(color: _border),
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
