import 'package:flutter/material.dart';

import 'package:project_srpg/game/shot_objective.dart';
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

/// Oyunun üstünde duran tek/iki satırlık durum tarifi.
///
/// Sınav ekranı bunu sınavın brifingi için kullanıyor, antrenman ekranı da o
/// denemenin hangi durumda geçtiğini yazmak için — ikisi de "oyun başlamadan
/// önce okunacak satır" olduğu için tek nüsha.
class GameBriefBar extends StatelessWidget {
  const GameBriefBar({super.key, required this.text, this.title});

  final String text;

  /// Varsa metnin üstünde duran kısa başlık.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?title == null
              ? null
              : Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          if (title != null) const SizedBox(height: 3),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir denemenin göstergedeki hâli.
///
/// Üç kademe, çünkü şut/pas senaryolarının bir kısmı "başarılı" ile "çok
/// başarılı"yı ayırıyor (`ShotGrade`). İki kademeli oyunlar — esneklik gibi —
/// yalnızca [fail] ve [good] kullanır; [AttemptMark.of] onların `bool`
/// günlüğünü buraya çeviriyor.
enum AttemptMark {
  fail,
  good,
  great;

  static AttemptMark of(bool made) => made ? AttemptMark.good : AttemptMark.fail;

  static AttemptMark ofGrade(ShotGrade grade) => switch (grade) {
        ShotGrade.fail => AttemptMark.fail,
        ShotGrade.good => AttemptMark.good,
        ShotGrade.great => AttemptMark.great,
      };
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

  final List<AttemptMark> log;
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
                  child: AttemptPip(mark: i < log.length ? log[i] : null),
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
  const AttemptPip({super.key, required this.mark});

  /// null = henüz atılmadı.
  final AttemptMark? mark;

  @override
  Widget build(BuildContext context) {
    final mark = this.mark;
    // "Çok başarılı" dolu bir pip değil, halkalı bir pip: başarılıdan ayrılsın
    // ama gösterge tek renkte kalsın, üç ayrı renk sırayı okunmaz yapıyor.
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (mark) {
          null => Colors.transparent,
          AttemptMark.fail => AppColors.danger,
          AttemptMark.good || AttemptMark.great => AppColors.success,
        },
        border: Border.all(
          color: switch (mark) {
            null => AppColors.border,
            AttemptMark.great => AppColors.textPrimary,
            _ => Colors.transparent,
          },
          width: 1.5,
        ),
      ),
      child: mark == AttemptMark.great
          ? Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface2,
                ),
              ),
            )
          : null,
    );
  }
}
