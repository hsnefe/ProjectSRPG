import 'package:flutter/material.dart';

import 'package:project_srpg/theme/app_colors.dart';

/// Karanlık tema için hap biçimli seçici — uygulamanın ilk form kontrolü.
///
/// [DropdownButton] yerine [PopupMenuButton] üzerine kuruldu: hem kapalı hâl
/// antrenman ekranındaki segment kontrolüyle (30px yükseklik, tam yuvarlak
/// köşe), hem de açılan menü ekran panelleriyle aynı tonda kalıyor.
/// [DropdownButton] menüsünü Material 3 surface tint'i ile boyar ve 48px
/// satır yüksekliği dayatır; ikisi de bu tasarım diline uymuyor.
class PillDropdown<T> extends StatelessWidget {
  const PillDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.accentColor = AppColors.accent,
    this.pillColor = AppColors.surface1,
    this.menuColor = AppColors.surface2,
    this.borderColor = AppColors.border,
    this.textColor = AppColors.textPrimary,
    this.mutedColor = AppColors.textMuted,
    this.height = 30,
  }) : assert(items.length > 0);

  /// Şu an seçili olan öğe. [items] içinde bulunmalı.
  final T value;

  final List<T> items;

  /// Her seçeneğin görünen metnini üretir; enum'lar için `(e) => e.label`.
  final String Function(T) labelOf;

  final ValueChanged<T> onChanged;

  final Color accentColor;
  final Color pillColor;
  final Color menuColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onChanged,
      color: menuColor,
      elevation: 8,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      padding: EdgeInsets.zero,
      itemBuilder: (context) {
        return [
          for (final item in items)
            PopupMenuItem<T>(
              value: item,
              height: 38,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check,
                    size: 14,
                    color: item == value ? accentColor : Colors.transparent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    labelOf(item),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          item == value ? FontWeight.w500 : FontWeight.w400,
                      color: item == value ? accentColor : textColor,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labelOf(value),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: mutedColor),
          ],
        ),
      ),
    );
  }
}
