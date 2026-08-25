import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';

/// §5.1 C2 · `GET /careers` — kayıtlı kariyerler, yeniden eskiye.
///
/// Açılıştaki "Load Career" buraya gelir: sihirbaz yeni bir kayıt açarken bu
/// ekran var olanlardan birini seçtirir. Seçim [CareerSession.adopt] ile
/// oturuma bağlanır — [CareerSession.resolve]'un "listenin ilki" yedeğine
/// bırakılmaz, kullanıcı hangisine dokunduysa o açılır.
class CareerListScreen extends StatefulWidget {
  const CareerListScreen({super.key, this.session});

  static const routeName = '/careers';

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır
  /// ve paylaşılan [CareerSession.instance] kullanılır.
  final CareerSession? session;

  @override
  State<CareerListScreen> createState() => _CareerListScreenState();
}

class _CareerListScreenState extends State<CareerListScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  late Future<List<api.CareerSummary>> _careers = _load();

  Future<List<api.CareerSummary>> _load() => _session.client.listCareers();

  void _retry() => setState(() => _careers = _load());

  void _open(api.CareerSummary career) {
    _session.adopt(career.careerId);
    // Paylaşılan oyuncu durumu açılıştaki (veya önceki kariyerin) künyesini
    // taşıyor; kariyer merkezine geçmeden önce seçilen kayıtla tazelenir.
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
                      const _HeaderSection(),
                      Expanded(
                        child: FutureBuilder<List<api.CareerSummary>>(
                          future: _careers,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const _LoadingState();
                            }
                            if (snapshot.hasError) {
                              return _ErrorState(
                                error: snapshot.error!,
                                onRetry: _retry,
                              );
                            }
                            final careers = snapshot.data!;
                            if (careers.isEmpty) return const _EmptyState();
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: careers.length,
                              itemBuilder: (context, index) {
                                final career = careers[index];
                                return _CareerTile(
                                  career: career,
                                  onTap: () => _open(career),
                                );
                              },
                            );
                          },
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
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.chevron_left,
              size: 24,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'KARİYERLER',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir kayıt satırı: kulüp renginde künye rozeti, oyuncu adı, kulüp + lig,
/// sağda sezon ve kayıttaki gün.
class _CareerTile extends StatelessWidget {
  const _CareerTile({required this.career, required this.onTap});

  final api.CareerSummary career;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final team = career.team;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            _TeamBadge(team: team),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    career.playerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  career.seasonId,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(career.currentDate),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  /// Kulüp ve lig C2'de opsiyonel (kariyer daha kulübe bağlanmamış olabilir);
  /// eksik olanı satırdan düşürürüz, "—" yazmayız.
  String get _subtitle {
    final parts = [
      if (career.team != null) career.team!.name,
      if (career.competition != null) career.competition!.name,
    ];
    return parts.isEmpty ? 'Kulüp atanmadı' : parts.join(' · ');
  }

  /// `2026-08-19` → `19.08.2026`. Ayrıştırılamayan bir değer geldiğinde ham
  /// hâliyle gösterilir — tarih bir kayıt satırında en fazla süs, ekranı
  /// düşürmesine değmez.
  static String _formatDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year}';
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team});

  final api.TeamRef? team;

  @override
  Widget build(BuildContext context) {
    final tint = team?.colorPrimary ?? AppColors.textMuted;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tint.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Text(
        team?.shortName ?? '—',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Kayıtlı kariyer yok.\nAçılıştan "New Game" ile bir tane başlat.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kariyerler alınamadı.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }

  String get _detail {
    final e = error;
    if (e is CareerApiException) {
      return e.message ?? 'Sunucu ${e.statusCode} döndü.';
    }
    return 'career_engine çalışıyor mu? (127.0.0.1:8001)';
  }
}
