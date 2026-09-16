import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// Kondisyon barı — sayı ve bar birlikte, `condition` değiştiğinde
/// doğrudan zıplamak yerine eski değerden yeniye kayarak geçer.
///
/// Bir aktivite (antrenman, yaşam tarzı, sosyal) `PlayerState.condition`'ı
/// değiştirdiğinde çağıran taraf yalnızca yeni `condition`'ı geçirir; bu
/// widget önceki değeri kendi başına hatırlar (`didUpdateWidget`) ve
/// aradaki farkı hem bar/sayı kaymasıyla hem de kısa süreli bir "+N"/"-N"
/// rozetiyle gösterir. Kullanıcı böylece hem aktivitenin maliyetini hem de
/// kondisyonunun ne kadar değiştiğini görsel olarak okuyabiliyor.
///
/// `TweenAnimationBuilder`'ın kendi "tween değişince mevcut değerden yeniden
/// hedefle" davranışına güvenmek yerine [_displayedFrom] açıkça tutuluyor ve
/// her yeni hedefte `key` değiştirilerek taze bir animasyon başlatılıyor —
/// iki ucu da (`begin`/`end`) belirgin, testte doğrulanabilir.
class AnimatedConditionBar extends StatefulWidget {
  const AnimatedConditionBar({
    super.key,
    required this.condition,
    this.label = 'Kondisyon',
    this.width,
  });

  /// 0-100 arası güncel kondisyon — `PlayerState.condition`.
  final int condition;

  final String label;

  /// Null ise ebeveynin verdiği kısıtlara göre genişler.
  final double? width;

  @override
  State<AnimatedConditionBar> createState() => _AnimatedConditionBarState();
}

class _AnimatedConditionBarState extends State<AnimatedConditionBar> {
  /// Bir SONRAKİ animasyonun başlayacağı değer. İlk build'de hedefle aynı —
  /// ekran ilk açıldığında bar sıfırdan dolmuyor, doğrudan doğru yerde
  /// beliriyor; yalnızca SONRAKİ değişiklikler animasyonlu.
  late int _displayedFrom = widget.condition;

  /// Dolu ise son değişimin farkı kısa süreliğine rozet olarak gösteriliyor.
  int? _deltaToShow;
  Timer? _deltaTimer;

  static const _animationDuration = Duration(milliseconds: 700);
  static const _deltaVisibleDuration = Duration(milliseconds: 1800);

  @override
  void didUpdateWidget(covariant AnimatedConditionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition == widget.condition) return;

    _displayedFrom = oldWidget.condition;
    final delta = widget.condition - oldWidget.condition;

    _deltaTimer?.cancel();
    setState(() => _deltaToShow = delta);
    _deltaTimer = Timer(_deltaVisibleDuration, () {
      if (mounted) setState(() => _deltaToShow = null);
    });
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Hedef her değiştiğinde taze bir animasyon: begin/end açıkça verili,
      // önceki koşunun ortasında kalmış bir değere güvenmiyoruz.
      key: ValueKey(widget.condition),
      tween: Tween<double>(
        begin: _displayedFrom.toDouble(),
        end: widget.condition.toDouble(),
      ),
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final shown = value.round().clamp(0, 100);
        return SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$shown/100',
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (_deltaToShow case final delta?) ...[
                    const SizedBox(width: 6),
                    AnimatedOpacity(
                      key: const Key('condition_delta_badge'),
                      opacity: 1,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        delta > 0 ? '+$delta' : '$delta',
                        style: TextStyle(
                          color: delta > 0 ? AppColors.success : AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: shown / 100,
                  minHeight: 5,
                  backgroundColor: AppColors.surface1,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
