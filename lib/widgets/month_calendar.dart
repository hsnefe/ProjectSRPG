/// Bir ayın 7 sütunlu, kare hücreli ızgarası. İki yerde kullanılır: takvim
/// ekranının tam boy görünümü ve kariyer merkezinde "İlerle"ye basınca açılan
/// küçük (`compact`) sürüm.
///
/// Yerleşim FIFA Kariyer Modu'nun takviminden alındı: gün numarası hücrenin
/// sol üstünde, maç günlerinde hücrenin kendisi rakip rozetiyle doldurulur.
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
library;

import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/date_labels.dart';
import 'package:project_srpg/widgets/team_badge.dart';

/// Bir gün hücresine düşen tek işaret.
///
/// `kind == 'match'` ise [opponent] doludur ve hücre rakibin rozetiyle
/// doldurulur — [color] bu durumda okunmaz. Diğer türlerde [opponent] null,
/// [color] hücrenin sağ alt köşesindeki küçük noktanın rengidir.
class CalendarDayMark {
  const CalendarDayMark({required this.kind, this.color, this.refId, this.opponent})
      : assert(
          kind == 'match' ? opponent != null : color != null,
          "match dışı bir işaretin color'u, match'in opponent'ı olmalı",
        );

  final String kind;
  final Color? color;
  final String? refId;

  /// `kind == 'match'` iken hücrenin ortasına çizilecek TAKIM — kullanıcının
  /// kendisi değil, rakip (§6.3: "rakip takımın logosunu hücreye koy").
  final TeamRef? opponent;

  bool get isMatch => kind == 'match';
}

/// W5 `marks[].kind` → nokta rengi. Bu bir **sunum** kararıdır, model değil:
/// BE `kind` gönderir, rengi ekran seçer (§1.3). Maç günleri bu haritayı
/// kullanmaz — onların "rengi" artık rakibin rozetidir.
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
    // Boş hücre de kareyi korur — aksi hâlde son satır kısa kalıp gridin
    // satır yüksekliği bozulurdu.
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
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
    // `firstOrNull` package:collection içinde; tek bir çağrı için bağımlılık
    // eklemek yerine açıkça yazıldı (career_models.dart'ın aynı kararı).
    CalendarDayMark? match;
    for (final mark in marks) {
      if (mark.isMatch) {
        match = mark;
        break;
      }
    }
    final corners = marks.where((m) => !m.isMatch).take(2).toList(growable: false);

    // Gerçek kare: yükseklik `Expanded`'dan gelen genişliğe eşitlenir.
    // Eski sürüm yalnız `height` veriyordu, bu yüzden grid genişliği ne
    // olursa olsun kare garantisi yoktu.
    final cell = AspectRatio(
      key: ValueKey('calCell:$dayNumber'),
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 6 : 9),
          color: isSelected
              ? AppColors.accentBg
              : isToday
                  ? AppColors.surface1
                  : AppColors.surfaceDeep,
          border: isToday
              ? Border.all(color: AppColors.accent, width: 1.4)
              : isSelected
                  ? Border.all(color: AppColors.border, width: 0.5)
                  : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.maxWidth;
            return Stack(
              children: [
                Positioned(
                  left: side * 0.09,
                  top: side * 0.06,
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: match != null || marks.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: compact ? side * 0.30 : side * 0.24,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
                if (match != null)
                  Center(
                    child: TeamBadge(
                      key: ValueKey('calCrest:$dayNumber'),
                      team: match.opponent!,
                      size: side * 0.62,
                    ),
                  ),
                if (corners.isNotEmpty)
                  Positioned(
                    right: side * 0.08,
                    bottom: side * 0.07,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final mark in corners)
                          Padding(
                            padding: EdgeInsets.only(left: side * 0.04),
                            child: Container(
                              key: ValueKey('calMark:${mark.kind}:$dayNumber'),
                              width: side * 0.11,
                              height: side * 0.11,
                              decoration: BoxDecoration(
                                color: mark.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
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
