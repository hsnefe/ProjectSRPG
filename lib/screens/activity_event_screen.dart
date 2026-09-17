import 'package:flutter/material.dart';
import 'package:project_srpg/game/attribute_labels.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/net/money.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/delta_row.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';
import 'package:project_srpg/widgets/typewriter_text.dart';

/// Aktivite olayı ekranı — T2'nin `event` bloğunu gösterir, T6'yı çağırır
/// (§13.4).
///
/// `social_offer_screen`'ın ikizi ve bilerek öyle: aynı sahne + daktilo +
/// `DeltaRow` dili, çünkü ikisi de "biri seninle konuşuyor, karar ver" anı.
/// **Üç fark var:**
///
/// 1. **Çıkılabilir (D76).** Sosyal teklifin aksine cevap zorunlu değil: açık
///    bir olay `advance`'ı kilitlemiyor, kaçırılan olay ertesi gün `expired`
///    oluyor ve hiçbir şey yazmıyor (INV-63). Geri tuşu bu yüzden çalışıyor.
/// 2. **İki değil N seçenek.** Kilitli olan (D42) gri görünür ve eşiği
///    yazar — `dialog_screen`'in `locked_choice_*` kalıbı.
/// 3. **Karşıda kimse yok.** Olayın bir `relationship_id`'si yok, bu yüzden
///    portre de yok; yalnızca aktivitenin geçtiği sahne çiziliyor.
Future<api.ActivityEventResult?> showActivityEventScreen(
  BuildContext context, {
  required CareerSession session,
  required api.ActivityEvent event,
}) {
  return Navigator.of(context).push<api.ActivityEventResult>(
    PageRouteBuilder<api.ActivityEventResult>(
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) =>
          ActivityEventScreen(session: session, event: event),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class ActivityEventScreen extends StatefulWidget {
  const ActivityEventScreen({
    super.key,
    required this.session,
    required this.event,
  });

  final CareerSession session;
  final api.ActivityEvent event;

  @override
  State<ActivityEventScreen> createState() => _ActivityEventScreenState();
}

class _ActivityEventScreenState extends State<ActivityEventScreen> {
  final _typewriterKey = GlobalKey<TypewriterTextState>();

  bool _busy = false;
  String? _error;
  api.ActivityEventResult? _result;
  bool _typewriterComplete = false;

  Future<void> _choose(api.ActivityEventOption option) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final careerId = await widget.session.resolve();
      final result = await widget.session.client.chooseActivityEvent(
        careerId,
        widget.event.eventId,
        option.optionId,
      );
      if (!mounted) return;
      // §13.3/D74 · nitelik değişimleri yerel kopyaya işlenir ki bir kilidin
      // açılması P1 tazelenmeden görünsün — `dialog_screen`'in yaptığı gibi.
      PlayerScope.of(context).applyServerUpdate(
        careerState: result.careerState,
        attributeChanges: result.attributeChanges,
      );
      setState(() {
        _busy = false;
        _result = result;
        _typewriterComplete = false;
      });
    } on CareerApiException catch (e) {
      // Seçim reddedildi (gereksinim/bütçe/bakiye). Olay AÇIK kalır ve
      // kullanıcı başka bir dal seçebilir (§13.4) — sunucu da öyle bıraktı.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message ?? 'Seçim uygulanamadı.';
      });
    }
  }

  void _onMessageTap() {
    if (!_typewriterComplete) _typewriterKey.currentState?.skip();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final result = _result;
    final player = PlayerScope.of(context);

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
                      _SceneStrip(catalogId: event.catalogId),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _onMessageTap,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: result == null
                                ? _buildEventBody(event, player)
                                : _buildResultBody(result),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: result == null
                            ? Column(
                                children: [
                                  for (final option in event.options)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
                                      child: _OptionButton(
                                        option: option,
                                        locked: _lockedBy(option, player),
                                        onPressed: _busy
                                            ? null
                                            : () => _choose(option),
                                      ),
                                    ),
                                ],
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  key: const ValueKey('activityEventDone'),
                                  onPressed: () =>
                                      Navigator.of(context).pop(result),
                                  child: const Text('Devam'),
                                ),
                              ),
                      ),
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

  /// D42 · karşılanmayan eşikler. Sunucu da aynı kontrolü yapıyor (INV-61);
  /// burada yapılan yalnızca kilidin **görünmesi**, engellenmesi değil —
  /// seviye [PlayerState] üzerinden BE'den geldiği gibi okunur, türetilmez.
  Map<String, int> _lockedBy(api.ActivityEventOption option, dynamic player) {
    return unmetRequirements(option.requires, player.attributeLevel);
  }

  Widget _buildEventBody(api.ActivityEvent event, dynamic player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        TypewriterText(
          key: _typewriterKey,
          text: event.body,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.55,
          ),
          onComplete: () {
            if (!mounted) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _typewriterComplete) return;
              setState(() => _typewriterComplete = true);
            });
          },
        ),
        if (_error case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            key: const Key('activity_event_error'),
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildResultBody(api.ActivityEventResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §13.2 · bir seçenek biriyle tanıştırdıysa ekranın söylemesi gereken
        // ilk şey bu: yeni bir kart belirdi ya da bir tanesi düştü.
        for (final change in result.relationshipStateChanges)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Chip(
              key: ValueKey('eventState_${change.relationshipId}'),
              icon: change.isEnded
                  ? Icons.heart_broken_outlined
                  : Icons.favorite_outline,
              tint: change.isEnded ? AppColors.danger : AppColors.success,
              label: change.isEnded
                  ? 'Bu ilişki sona erdi'
                  : change.isEstablished
                      ? 'Artık bir ilişkiniz var'
                      : 'Tanıştınız — rehberine eklendi',
            ),
          ),
        for (final change in result.relationshipChanges)
          DeltaRow(
            key: ValueKey('eventRelDelta_${change.relationshipId}'),
            label: change.relationshipId,
            before: change.before.toDouble(),
            after: change.after.toDouble(),
          ),
        for (final change in result.attributeChanges) ...[
          DeltaRow(
            key: ValueKey('eventAttrDelta_${change.key}'),
            label: attributeLabel(change.key),
            before: change.before,
            after: change.after,
          ),
          if (change.levelAfter != change.levelBefore)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Text(
                '${attributeLabel(change.key)} seviye ${change.levelAfter}',
                style: const TextStyle(color: AppColors.success, fontSize: 11),
              ),
            ),
        ],
        for (final entry in result.ledgerEntries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.reason,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  formatMoney(entry.amount),
                  style: TextStyle(
                    color: entry.amount >= 0
                        ? AppColors.success
                        : AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Olayın geçtiği yer. §5.8: BE sahne göndermiyor — `dialogue_backdrop`'ın
/// ilişkiden sahne seçmesiyle aynı kalıpta, burada aktiviteden seçiliyor.
DialogueScene sceneForActivity(String catalogId) {
  if (catalogId.startsWith('ev-')) return DialogueScene.home;
  if (catalogId.startsWith('fiz-')) return DialogueScene.trainingGround;
  return switch (catalogId) {
    'sos-taraftar' => DialogueScene.stadium,
    'sos-aile' => DialogueScene.home,
    _ => DialogueScene.cafe,
  };
}

class _SceneStrip extends StatelessWidget {
  const _SceneStrip({required this.catalogId});

  final String catalogId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: DialogueBackdrop(
              scene: sceneForActivity(catalogId),
              tint: AppColors.accent,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.surface2.withValues(alpha: 0),
                    AppColors.surface2.withValues(alpha: 0.92),
                  ],
                  stops: const [0, 0.52, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.locked,
    required this.onPressed,
  });

  final api.ActivityEventOption option;

  /// Karşılanmayan eşikler; boşsa seçenek açık.
  final Map<String, int> locked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Kilitli seçenek GİZLENMEZ, gri görünür — `dialog_screen`'in kararı:
    // görmediğin bir kapıyı açmak istemezsin.
    final isLocked = locked.isNotEmpty;
    final tint = isLocked ? AppColors.textMuted : AppColors.accent;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: ValueKey(
          isLocked
              ? 'locked_option_${option.optionId}'
              : 'option_${option.optionId}',
        ),
        onPressed: isLocked ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          side: BorderSide(color: tint.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(option.label, style: const TextStyle(fontSize: 13)),
            ),
            if (option.costs.isNotEmpty || isLocked) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._costChips(option.costs),
                  if (isLocked)
                    _Chip(
                      icon: Icons.lock_outline,
                      tint: AppColors.danger,
                      label: requirementLabel(locked),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// '45 dk' · '5 enerji'. `social_offer_screen`'ınkiyle aynı dil; ikisi de
/// BE'nin sayısını alıp birimi kendi yazıyor (§1.3).
List<Widget> _costChips(Map<String, double> costs) {
  final chips = <Widget>[];
  for (final entry in costs.entries) {
    switch (entry.key) {
      case 'time':
        final hours = entry.value / 60;
        chips.add(
          _Chip(
            icon: Icons.schedule,
            tint: AppColors.warning,
            label: hours >= 1
                ? '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} sa'
                : '${entry.value.round()} dk',
          ),
        );
      case 'energy':
        chips.add(
          _Chip(
            icon: Icons.bolt,
            tint: AppColors.success,
            label: '${entry.value.round()} enerji',
          ),
        );
      default:
        chips.add(
          _Chip(
            icon: Icons.remove_circle_outline,
            tint: AppColors.textMuted,
            label: '${entry.value.round()} ${entry.key}',
          ),
        );
    }
  }
  return chips;
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.icon,
    required this.tint,
    required this.label,
  });

  final IconData icon;
  final Color tint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: tint, fontSize: 11)),
        ],
      ),
    );
  }
}
