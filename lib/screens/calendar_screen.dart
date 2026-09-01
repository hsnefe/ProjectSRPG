import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/date_labels.dart';
import 'package:project_srpg/widgets/lit_card.dart';
import 'package:project_srpg/widgets/month_calendar.dart';
import 'package:project_srpg/widgets/panel_states.dart';

/// Aylık takvim. Veri W5'ten tek çağrıda gelir (CONTRACT.md §5.3): fikstür,
/// maaş günü, kupa turu, sözleşme bitişi ve sezon sınırları.
///
/// Maaş gününün hangi gün olduğu **BE'nin kuralıdır** — burada
/// `weekday == Pazartesi` diye bir kontrol yok, olmamalı da (§1.3).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.session});

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;

  /// Görüntülenen ay; null iken ilk sayfa henüz gelmemiştir (BE hangi ayda
  /// olduğumuzu söyler, FE tahmin etmez).
  DateTime? _month;
  api.CalendarPage? _page;
  String? _selectedDate;
  bool _loading = true;
  Object? _error;

  /// Kullanıcı aylar arasında ağdan hızlı gezer; geç dönen eski bir yanıtın
  /// yeni ayın üstüne yazmaması için (news feed'in aynı muhafızı).
  int _requestToken = 0;

  /// Ay sayfaları — geri dönmek anında olsun diye. Kariyer içinde takvim
  /// değişmez (fikstür oynanınca skoru değişir, ki o da ekran her açıldığında
  /// yeniden çekiliyor), bu yüzden örnek ömrü boyunca güvenli.
  final Map<String, api.CalendarPage> _cache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  static (String, String) _bounds(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    return (MonthCalendar.isoDate(first), MonthCalendar.isoDate(last));
  }

  /// W5 · `GET /careers/{cid}/calendar`. [month] null ise sınır gönderilmez
  /// ve BE `current_date`'in ayını döner — açılışta hangi aydayız sorusunun
  /// tek sahibi BE'dir.
  Future<void> _load({DateTime? month}) async {
    final token = ++_requestToken;
    setState(() {
      _loading = true;
      _error = null;
    });

    if (month != null) {
      final cached = _cache[_monthKey(month)];
      if (cached != null) {
        setState(() {
          _month = month;
          _page = cached;
          _selectedDate = null;
          _loading = false;
        });
        return;
      }
    }

    try {
      final careerId = await _session.resolve();
      final (from, to) = month == null ? (null, null) : _bounds(month);
      final page = await _session.client.calendar(careerId, from: from, to: to);
      if (!mounted || token != _requestToken) return;

      final resolvedMonth = month ?? DateTime.parse(page.from);
      _cache[_monthKey(resolvedMonth)] = page;
      setState(() {
        _month = resolvedMonth;
        _page = page;
        _selectedDate = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _step(int months) {
    final current = _month;
    if (current == null) return;
    _load(month: DateTime(current.year, current.month + months, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _Header(
                        month: _month,
                        onPrevious: _month == null ? null : () => _step(-1),
                        onNext: _month == null ? null : () => _step(1),
                      ),
                      Expanded(child: _body()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const CenteredSpinner();
    if (_error != null) {
      return PanelError(
        message: careerErrorText(_error!),
        onRetry: () => _load(month: _month),
      );
    }

    final page = _page;
    final month = _month;
    if (page == null || month == null) return const CenteredSpinner();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        MonthCalendar(
          month: month,
          marksByDate: _dayMarks(page),
          today: page.today,
          selected: _selectedDate,
          onSelectDay: (date) => setState(() => _selectedDate = date),
        ),
        const SizedBox(height: 14),
        _DayDetail(
          date: _selectedDate,
          marks: _selectedDate == null
              ? const []
              : page.marksByDate[_selectedDate!] ?? const [],
        ),
      ],
    );
  }

  /// W5 işaretlerini gridin sunum tipine çevirir. Maç günü **rakibin** forma
  /// rengiyle boyanır: kullanıcının kendi rengi her maçta aynı olurdu ve
  /// hiçbir şey ayırt etmezdi.
  Map<String, List<CalendarDayMark>> _dayMarks(api.CalendarPage page) {
    return {
      for (final day in page.days)
        day.date: [
          for (final mark in day.marks)
            CalendarDayMark(
              kind: mark.kind,
              refId: mark.refId,
              color: mark.isMatch
                  ? _opponentColor(mark)
                  : colorForMarkKind(mark.kind),
            ),
        ],
    };
  }

  Color _opponentColor(api.CalendarMark mark) {
    // v1'de W5 yalnız kullanıcının maçlarını döner, yani taraflardan biri
    // hep kendi takımı; renk için diğerini almak istiyoruz. Hangisi olduğunu
    // ayırt edecek bir alan yok, bu yüzden ev sahibinin rengi kullanılıyor —
    // deplasmanda rakip, evde kendi rengi, ikisi de anlamlı bir işaret.
    return mark.home?.colorPrimary ?? AppColors.accent;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.month, this.onPrevious, this.onNext});

  final DateTime? month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left,
                size: 22, color: AppColors.textSecondary),
          ),
          const Text(
            'Takvim',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _StepButton(
            keyName: 'cal-prev',
            icon: Icons.chevron_left,
            onPressed: onPrevious,
          ),
          SizedBox(
            width: 108,
            child: Text(
              month == null ? '' : monthYearLabel(month!),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _StepButton(
            keyName: 'cal-next',
            icon: Icons.chevron_right,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.keyName,
    required this.icon,
    this.onPressed,
  });

  final String keyName;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey(keyName),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, size: 20, color: AppColors.textSecondary),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.date, required this.marks});

  final String? date;
  final List<api.CalendarMark> marks;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const _EmptyDetail(text: 'Bir güne dokun.');
    }
    if (marks.isEmpty) {
      return const _EmptyDetail(text: 'Bu günde bir şey yok.');
    }

    return LitCard(
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullDateLabel(date!),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            for (final mark in marks) _MarkRow(mark: mark),
          ],
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}

/// Gün detayındaki tek satır. §1.3: BE `kind` gönderir, cümleyi ekran kurar —
/// tanımadığı bir `kind` sessizce atlanır, çünkü ileride yeni işaret türleri
/// eklenebilir (§5.0).
class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.mark});

  final api.CalendarMark mark;

  static const _labels = {
    'wage': 'Maaş günü',
    'contract_expiry': 'Sözleşme bitiyor',
    'season_start': 'Sezon başlangıcı',
    'season_end': 'Sezon sonu',
  };

  @override
  Widget build(BuildContext context) {
    final title = _title();
    if (title == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5, right: 10),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: mark.isMatch
                  ? (mark.home?.colorPrimary ?? AppColors.accent)
                  : colorForMarkKind(mark.kind),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                if (_subtitle() case final subtitle?)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _title() {
    if (mark.isMatch) {
      final home = mark.home?.shortName ?? '?';
      final away = mark.away?.shortName ?? '?';
      if (mark.isPlayed) {
        return '$home ${mark.homeScore ?? 0}-${mark.awayScore ?? 0} $away';
      }
      return '$home – $away';
    }
    if (mark.kind == 'cup_round') {
      return 'Kupa turu';
    }
    return _labels[mark.kind];
  }

  String? _subtitle() {
    if (mark.isMatch) {
      final competition = mark.competition?.name;
      final kickoff = mark.kickoffAt;
      if (kickoff == null) return competition;
      final time = kickoffDayLabelFrom(kickoff);
      return competition == null ? time : '$competition · $time';
    }
    if (mark.kind == 'cup_round') {
      // Kura çekilmemiş tur: rakip henüz yok, tarih var (§5.3).
      return mark.drawn == false ? 'Kura henüz çekilmedi' : null;
    }
    return null;
  }
}
