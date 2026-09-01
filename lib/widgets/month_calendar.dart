/// Bir ayın 7 sütunlu ızgarası. İki yerde kullanılır: takvim ekranının tam
/// boy görünümü ve kariyer merkezinde "İlerle"ye basınca açılan küçük
/// (`compact`) sürüm.
///
/// **Neden `CalendarPage` almıyor.** Overlay'in elinde bir `CalendarPage`
/// yok — yalnızca yürüdüğü günler var. Widget'ı ağa bağlı bir modele
/// bağlamak, onu ikinci kullanım yerinde kullanılamaz hâle getirirdi; bu
/// yüzden girdisi sunum tipleri: tarih → işaret listesi.
///
/// **Saat dilimi uyarısı.** Buradaki her tarih çıplak `YYYY-MM-DD`'dir;
/// `DateTime.parse` onları yerel (UTC olmayan) değerler olarak döner, yani
/// [`date_labels.dart`](date_labels.dart)'ta anlatılan **+3 saat düzeltmesi
/// burada gerekmez ve kopyalanmamalıdır.** O düzeltme yalnız ofset taşıyan
/// `kickoff_at` dizeleri içindir.
import 'package:flutter/material.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/date_labels.dart';

/// Bir gün hücresine düşen tek işaret. `kind` yalnız erişilebilirlik ve test
/// için taşınır; hücrenin çizdiği şey [color].
class CalendarDayMark {
  const CalendarDayMark({required this.kind, required this.color, this.refId});

  final String kind;
  final Color color;
  final String? refId;
}

/// W5 `marks[].kind` → nokta rengi. Bu bir **sunum** kararıdır, model değil:
/// BE `kind` gönderir, rengi ekran seçer (§1.3). Maç günleri bu haritayı
/// kullanmaz — onların rengi rakibin kendi forma rengidir.
const _markColors = <String, Color>{
  'wage': AppColors.warning,
  'cup_round': AppColors.accent,
  'contract_expiry': AppColors.danger,
  'season_start': AppColors.textMuted,
  'season_end': AppColors.textMuted,
  'social_offer': AppColors.success,
};

/// Tanınmayan bir `kind` için sessiz bir gri — §5.0'a göre BE yeni işaret
/// türü ekleyebilir ve bu ekranı bozmamalı.
Color colorForMarkKind(String kind) => _markColors[kind] ?? AppColors.textMuted;

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.marksByDate,
    this.today,
    this.selected,
    this.onSelectDay,
    this.compact = false,
  });

  /// Ayın herhangi bir günü; yalnız yıl/ay okunur.
  final DateTime month;

  /// 'YYYY-MM-DD' → o günün işaretleri.
  final Map<String, List<CalendarDayMark>> marksByDate;

  /// Oyunun bugünü ('YYYY-MM-DD'), vurgulanır.
  final String? today;

  /// Seçili gün ('YYYY-MM-DD').
  final String? selected;

  final ValueChanged<String>? onSelectDay;

  /// Overlay sürümü: küçük hücreler, gün başlığı yok, seçim yok.
  final bool compact;

  static String isoDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    // DateTime.weekday 1..7 Pazartesi'den başlar ve gridin ilk sütunu da
    // Pazartesi, yani boş hücre sayısı doğrudan weekday - 1.
    final leadingBlanks = first.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = leadingBlanks + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) const _WeekdayHeader(),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(child: _cellAt(row * 7 + column, leadingBlanks, daysInMonth)),
            ],
          ),
      ],
    );
  }

  Widget _cellAt(int index, int leadingBlanks, int daysInMonth) {
    final dayNumber = index - leadingBlanks + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return SizedBox(height: compact ? 30 : 44);
    }
    final date = isoDate(DateTime(month.year, month.month, dayNumber));
    return _DayCell(
      dayNumber: dayNumber,
      marks: marksByDate[date] ?? const [],
      isToday: date == today,
      isSelected: date == selected,
      compact: compact,
      onTap: onSelectDay == null ? null : () => onSelectDay!(date),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (final label in turkishWeekdayInitials)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.marks,
    required this.isToday,
    required this.isSelected,
    required this.compact,
    this.onTap,
  });

  final int dayNumber;
  final List<CalendarDayMark> marks;
  final bool isToday;
  final bool isSelected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 44.0;
    final dotSize = compact ? 4.0 : 5.0;

    final cell = Container(
      height: size,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected
            ? AppColors.accentBg
            : isToday
                ? AppColors.surface1
                : null,
        border: isToday
            ? Border.all(color: AppColors.accent, width: 1)
            : isSelected
                ? Border.all(color: AppColors.border, width: 0.5)
                : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$dayNumber',
            style: TextStyle(
              color: marks.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
              fontSize: compact ? 11 : 13,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (marks.isNotEmpty) ...[
            SizedBox(height: compact ? 2 : 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Üçten fazla işaret varsa hücre okunmaz hâle gelir; kalanı
                // gün detayı panelinde zaten görünüyor.
                for (final mark in marks.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      key: ValueKey('calMark:${mark.kind}:$dayNumber'),
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: mark.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return cell;
    return GestureDetector(
      key: ValueKey('calDay:$dayNumber'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: cell,
    );
  }
}
