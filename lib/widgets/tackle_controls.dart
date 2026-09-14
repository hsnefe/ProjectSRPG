/// Müdahale oyununun göstergeleri ve tuş takımı.
///
/// Antrenman kartı ile maç içi müdahale aynı oyunu aynı tuşlarla oynatıyor;
/// aralarındaki tek fark oyunun etrafındaki çerçeve. İkinci ekran açılınca
/// kopyalanmasınlar diye buraya taşındılar — `app_colors.dart`'ın koyduğu
/// kural: **en az iki dosyada geçen şey ortak yere gider.**
///
/// Bunlar `game_chrome.dart`'a konmadı: oradaki parçalar hangi oyunu
/// sardıklarını bilmiyor, bunlar ise doğrudan [TackleGame]'e basıyor.
library;

import 'package:flutter/material.dart';

import 'package:project_srpg/game/conditioning_game.dart' show RunSide;
import 'package:project_srpg/game/tackle_game.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Ritim ve süre — ikisi de kare kare değişiyor, o yüzden `setState` yerine
/// oyunun notifier'larını dinler. Yaklaşma kanvasta zaten görünüyor, burada
/// ikinci kez çizilmiyor.
class TackleGauges extends StatelessWidget {
  const TackleGauges({super.key, required this.game});

  final TackleGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: game.rhythmGauge,
            builder: (_, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.surface1,
                valueColor: AlwaysStoppedAnimation<Color>(
                  value >= 0.6 ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          ValueListenableBuilder<double>(
            valueListenable: game.timeLeft,
            builder: (_, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: AppColors.surface1,
                valueColor: AlwaysStoppedAnimation<Color>(
                  value <= TackleGame.warnFraction
                      ? AppColors.dangerBright
                      : AppColors.warning,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üstte tam genişlikte MÜDAHALE, altta SOL/SAĞ.
///
/// Dalışın ayrı bir tuşu olması kasıtlı: koşu ritmi ile dalış anı iki ayrı
/// beceri, tek tuşta toplanınca ritim vuruşunun kendisi istemsiz bir
/// müdahaleye dönüşürdü.
class TackleControls extends StatelessWidget {
  const TackleControls({
    super.key,
    required this.game,
    required this.windowOpen,
  });

  final TackleGame game;

  /// Pencere açık mı — MÜDAHALE tuşu yalnızca o zaman vurgulanır.
  final bool windowOpen;

  @override
  Widget build(BuildContext context) {
    final stumbling = game.stumbleLeft > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: game.finished ? null : game.commit,
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    windowOpen ? AppColors.success : AppColors.textSecondary,
                side: BorderSide(
                  color: windowOpen ? AppColors.success : AppColors.border,
                  width: windowOpen ? 2 : 1,
                ),
                backgroundColor:
                    windowOpen ? AppColors.successBg : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              child: const Text('MÜDAHALE'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SideButton(
                  label: 'SOL',
                  stumbling: stumbling,
                  onTap: game.finished ? null : () => game.step(RunSide.left),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SideButton(
                  label: 'SAĞ',
                  stumbling: stumbling,
                  onTap: game.finished ? null : () => game.step(RunSide.right),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.stumbling,
    required this.onTap,
  });

  final String label;
  final bool stumbling;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: stumbling ? AppColors.danger : AppColors.textPrimary,
          disabledForegroundColor: AppColors.textMuted,
          side: BorderSide(
            color: stumbling ? AppColors.danger : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
