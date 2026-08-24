import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Kariyer paneli ekranlarının (sihirbaz, kariyer yükleme) paylaştığı ortak
/// durum gösterimleri — bekleme, hata + "Tekrar dene" ve hata metni eşlemesi.
/// Bunlar önce `new_career_screen.dart` içinde privateydi, ikinci bir ekran
/// aynı ihtiyaçla gelince buraya taşındı.

class CenteredSpinner extends StatelessWidget {
  const CenteredSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class PanelError extends StatelessWidget {
  const PanelError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tekrar dene',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kariyer API hatalarını kullanıcıya gösterilecek Türkçe metne çevirir.
String careerErrorText(Object error) {
  if (error is CareerApiException) {
    switch (error.code) {
      case 'invalid_request':
        return 'Motor bilgileri kabul etmedi: ${error.message ?? 'geçersiz istek'}';
      case 'skill_exam_already_taken':
        return 'Bu sınav zaten girilmiş, bir kez veriliyor.';
      default:
        return error.message ?? 'Beklenmeyen hata (${error.statusCode}).';
    }
  }
  return 'career_engine\'e ulaşılamadı (8001).';
}
