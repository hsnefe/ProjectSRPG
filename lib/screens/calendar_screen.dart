import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/pre_match_screen.dart';
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

  /// W5'in maç işaretleri hangi tarafın kullanıcı olduğunu söylemez — yalnız
  /// `home`/`away` verir. P1'den bir kez çekilir; `_opponentOf` bunu
  /// `home.teamId`/`away.teamId` ile karşılaştırıp gerçek rakibi seçer.
  String? _userTeamId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUserTeam();
  }

  Future<void> _loadUserTeam() async {
    try {
      final careerId = await _session.resolve();
      final player = await _session.client.player(careerId);
      if (!mounted) return;
      setState(() => _userTeamId = player.team.teamId);
    } catch (_) {
      // Sessizce vazgeçilir: `_opponentOf` bilinmeyen bir `_userTeamId` ile
      // ev sahibini varsayar (eski davranışın aynısı) — takvimin kendisi
      // P1 olmadan da çalışmaya devam eder.
    }
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
          userTeamId: _userTeamId,
          isToday: _selectedDate != null && _selectedDate == page.today,
          onGoToMatch: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => PreMatchScreen()),
          ),
        ),
      ],
    );
  }

  /// W5 işaretlerini gridin sunum tipine çevirir. Maç günü hücrenin
  /// tamamını rakibin rozetiyle doldurur (§6.3) — kullanıcının kendi takımı
  /// her maçta aynı olurdu ve hiçbir şey ayırt etmezdi.
  Map<String, List<CalendarDayMark>> _dayMarks(api.CalendarPage page) {
    final result = <String, List<CalendarDayMark>>{};
    for (final day in page.days) {
      final marks = <CalendarDayMark>[];
      for (final mark in day.marks) {
        if (mark.isMatch) {
          final opponent = _opponentOf(mark);
          if (opponent != null) {
            marks.add(CalendarDayMark(kind: 'match', refId: mark.refId, opponent: opponent));
          }
          continue;
        }
        marks.add(CalendarDayMark(kind: mark.kind, refId: mark.refId, color: colorForMarkKind(mark.kind)));
      }
      result[day.date] = marks;
    }
    return result;
  }

  /// [_opponentOf] hem gridin hem detay panelinin ortak sorusu — ikisi de
  /// bu fonksiyonu çağırır ki "rakip kim" iki yerde ayrı ayrı (ve
  /// yanlışlıkla farklı) hesaplanmasın.
  api.TeamRef? _opponentOf(api.CalendarMark mark) {
    final home = mark.home;
    final away = mark.away;
    final userTeamId = _userTeamId;
    if (userTeamId != null) {
      if (home?.teamId == userTeamId) return away ?? home;
      if (away?.teamId == userTeamId) return home ?? away;
    }
    // P1 henüz dönmediyse (veya başarısız olduysa) ev sahibini varsay —
    // en azından bir takım gösterilir, `_userTeamId` gelince yeniden çizilir.
    return home ?? away;
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
  const _DayDetail({
    required this.date,
    required this.marks,
    required this.userTeamId,
    required this.isToday,
    required this.onGoToMatch,
  });

  final String? date;
  final List<api.CalendarMark> marks;
  final String? userTeamId;
  final bool isToday;
  final VoidCallback onGoToMatch;

  /// §6.1 D57 · bugünün maçı hâlâ oynanmadıysa — takvimden de "Maça çık"a
  /// giden ikinci bir yol.
  bool get _showGoToMatch =>
      isToday &&
      marks.any((m) => m.isMatch && m.isUserMatch && m.status == 'scheduled');

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
            for (final mark in marks) _MarkRow(mark: mark, userTeamId: userTeamId),
            if (_showGoToMatch) ...[
              const SizedBox(height: 2),
              GestureDetector(
                key: const ValueKey('calGoToMatch'),
                onTap: onGoToMatch,
                child: const Text(
                  'Maça çık →',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
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
  const _MarkRow({required this.mark, required this.userTeamId});

  final api.CalendarMark mark;
  final String? userTeamId;

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
              color: mark.isMatch ? _opponentColor() : colorForMarkKind(mark.kind),
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

  /// Gridin `_opponentOf`'uyla aynı kural: kullanıcının kendi takımı değil,
  /// rakip renklendirilir. Bilinmiyorsa ev sahibi varsayılır (aynı düşüş).
  Color _opponentColor() {
    final home = mark.home;
    final away = mark.away;
    if (userTeamId != null) {
      if (home?.teamId == userTeamId) return away?.colorPrimary ?? AppColors.accent;
      if (away?.teamId == userTeamId) return home?.colorPrimary ?? AppColors.accent;
    }
    return home?.colorPrimary ?? AppColors.accent;
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
