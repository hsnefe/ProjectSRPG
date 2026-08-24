import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/new_career/wizard_kit.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/panel_states.dart';

/// §5.1 C2 + C4: kayıtlı kariyerlerin listesi. Bir kart seçilip alt bardaki
/// "Kariyeri Yükle" ile [CareerSession.adopt] üzerinden oturuma bağlanır,
/// çöp kutusu inline onayla [CareerSession.forget] + C4'ü tetikler.
///
/// Kabuk `new_career_screen.dart`'taki sihirbazla aynı: tek panel, üstte
/// başlık, ortada liste, altta aksiyon barı — iki ekran aynı görsel dili
/// paylaşsın diye.
class LoadCareerScreen extends StatefulWidget {
  const LoadCareerScreen({super.key, this.session});

  static const routeName = '/load-career';

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<LoadCareerScreen> createState() => _LoadCareerScreenState();
}

class _LoadCareerScreenState extends State<LoadCareerScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  late Future<List<api.CareerSummary>> _future = _load();

  String? _selectedId;
  String? _confirmingId;
  String? _busyId;
  bool _entering = false;

  Future<List<api.CareerSummary>> _load() => _session.client.listCareers();

  void _reload() {
    setState(() {
      _future = _load();
      _selectedId = null;
      _confirmingId = null;
    });
  }

  Future<void> _delete(String careerId) async {
    setState(() {
      _busyId = careerId;
      _confirmingId = null;
    });
    try {
      await _session.client.deleteCareer(careerId);
      _session.forget(careerId);
      if (!mounted) return;
      setState(() {
        _busyId = null;
        if (_selectedId == careerId) _selectedId = null;
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(careerErrorText(error)),
          backgroundColor: AppColors.surface2,
        ),
      );
    }
  }

  void _enterCareer() {
    final careerId = _selectedId;
    if (careerId == null) return;
    setState(() => _entering = true);
    _session.adopt(careerId);
    // Paylaşılan oyuncu durumu hâlâ eski kariyeri taşıyor olabilir; kariyer
    // merkezine geçmeden önce yeni künyeyle tazelenir.
    PlayerScope.of(context).load();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const CareerCenterScreen(),
        settings: const RouteSettings(name: CareerCenterScreen.routeName),
      ),
    );
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
                      const _LoadCareerHeader(),
                      Expanded(
                        child: FutureBuilder<List<api.CareerSummary>>(
                          future: _future,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const CenteredSpinner();
                            }
                            if (snapshot.hasError) {
                              return PanelError(
                                message: careerErrorText(snapshot.error!),
                                onRetry: _reload,
                              );
                            }
                            final careers = snapshot.data!;
                            if (careers.isEmpty) {
                              return const _EmptyState();
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                20,
                              ),
                              itemCount: careers.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final summary = careers[index];
                                return _CareerRow(
                                  summary: summary,
                                  selected: summary.careerId == _selectedId,
                                  confirming:
                                      summary.careerId == _confirmingId,
                                  busy: summary.careerId == _busyId,
                                  onTap: () => setState(() {
                                    _selectedId = summary.careerId;
                                    _confirmingId = null;
                                  }),
                                  onDeleteTap: () => setState(
                                    () => _confirmingId = summary.careerId,
                                  ),
                                  onCancelDelete: () =>
                                      setState(() => _confirmingId = null),
                                  onConfirmDelete: () =>
                                      _delete(summary.careerId),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      _LoadActionBar(
                        enabled: _selectedId != null && !_entering,
                        busy: _entering,
                        onPressed: _enterCareer,
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
}

class _LoadCareerHeader extends StatelessWidget {
  const _LoadCareerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.chevron_left,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'KARİYER YÜKLE',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kayıtlı kariyer yok',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Landing ekranındaki New Game ile yeni bir kariyer başlat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerRow extends StatelessWidget {
  const _CareerRow({
    required this.summary,
    required this.selected,
    required this.confirming,
    required this.busy,
    required this.onTap,
    required this.onDeleteTap,
    required this.onCancelDelete,
    required this.onConfirmDelete,
  });

  final api.CareerSummary summary;
  final bool selected;
  final bool confirming;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onCancelDelete;
  final VoidCallback onConfirmDelete;

  @override
  Widget build(BuildContext context) {
    final team = summary.team;
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: SelectCard(
        selected: selected,
        onTap: busy ? () {} : onTap,
        child: Row(
          children: [
            _TeamBadge(team: team),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.playerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    team?.name ?? 'Takımsız',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textMuted,
                ),
              )
            else if (confirming)
              _DeleteConfirm(
                onCancel: onCancelDelete,
                onConfirm: onConfirmDelete,
              )
            else ...[
              if (summary.playerAge != null) ...[
                WizardTag(
                  text: '${summary.playerAge} yaş',
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDeleteTap,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team});

  final api.TeamRef? team;

  @override
  Widget build(BuildContext context) {
    if (team == null) {
      return Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface0,
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Text(
          '?',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            team!.colorPrimary,
            team!.colorPrimary,
            team!.colorSecondary,
            team!.colorSecondary,
          ],
          stops: const [0, 0.5, 0.5, 1],
        ),
      ),
      child: Text(
        team!.shortName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      ),
    );
  }
}

class _DeleteConfirm extends StatelessWidget {
  const _DeleteConfirm({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onCancel,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              'Vazgeç',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onConfirm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Sil',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadActionBar extends StatelessWidget {
  const _LoadActionBar({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              enabled || busy ? '' : 'Bir kariyer seç',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
          GestureDetector(
            onTap: enabled ? onPressed : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Kariyeri Yükle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
