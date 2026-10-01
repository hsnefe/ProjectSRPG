import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// Antrenman ve sınav mini oyunlarının ortak tam ekran yerleşimi.
///
/// Eskiden her ekran oyunu 420 px'lik bir kartın içine, başlık/kontrol
/// şeritleri arasına sıkıştırıyordu; sahne küçücük kalıyordu. Şimdi [GameWidget]
/// bütün ekranı kaplıyor, başlık ve kontroller onun **üstüne** yarı saydam
/// şeritler olarak biniyor. Şeritlerin içeriği [maxContentWidth] ile sınırlı:
/// geniş (web) pencerede butonlar ekran boyu uzamasın, ama oyun uzasın.
///
/// `intervention_*` (maç içi müdahale) ekranları da bunu kullanıyor; üst ya da
/// alt şerit boş bırakılabilir ve o durumda hiç çizilmez.
class FullscreenGame<T extends FlameGame> extends StatelessWidget {
  const FullscreenGame({
    super.key,
    required this.game,
    required this.top,
    this.bottom,
    this.maxContentWidth = 560,
  });

  final T game;

  /// Üst şeridin satırları (başlık, brifing, göstergeler).
  final List<Widget> top;

  /// Alt şeritte duran tek parça: kontroller, sonuç paneli, vb.
  final Widget? bottom;

  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget<T>(game: game)),
          if (top.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _Strip(
                maxWidth: maxContentWidth,
                top: true,
                child: Column(mainAxisSize: MainAxisSize.min, children: top),
              ),
            ),
          if (bottom case final bottom?)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _Strip(
                maxWidth: maxContentWidth,
                top: false,
                child: bottom,
              ),
            ),
        ],
      ),
    );
  }
}

/// Oyunun üstüne binen yarı saydam şerit. Sahne altından hâlâ seçiliyor ama
/// yazılar okunuyor; SafeArea yalnızca şeridin kendi kenarında uygulanıyor ki
/// oyun çentiğin arkasına kadar uzansın.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.child,
    required this.maxWidth,
    required this.top,
  });

  final Widget child;
  final double maxWidth;
  final bool top;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface2.withValues(alpha: 0.82),
      child: SafeArea(
        top: top,
        bottom: !top,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}
