import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/game/formations.g.dart';
import 'package:project_srpg/net/match_api_client.dart';
import 'package:project_srpg/net/match_models.dart';
import 'package:project_srpg/screens/match_screen.dart';
import 'package:project_srpg/state/match_controller.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/screens/coach_talk_screen.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/formation_board.dart';
import 'package:project_srpg/widgets/date_labels.dart';

class PreMatchScreen extends StatefulWidget {
  PreMatchScreen({super.key, this.session, MatchApiClient? matchApiClient})
      : _matchApiClient = matchApiClient ?? MatchApiClient();

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;
  final MatchApiClient _matchApiClient;

  @override
  State<PreMatchScreen> createState() => _PreMatchScreenState();
}

class _PreMatchScreenState extends State<PreMatchScreen> {
  MatchApiClient get _apiClient => widget._matchApiClient;
  late final CareerSession _careerSession =
      widget.session ?? CareerSession.instance;

  NextMatchResponse? _next;
  String? _fixtureId;
  int? _preMatchCondition;
  String? _loadError;

  /// M1'in `formation_id`'si ve C3'ten okunan oyuncu bilgisi. Üçü de opsiyonel:
  /// diziliş tahtası bunlar olmadan da varsayılanlarla çizilir (bkz.
  /// [_loadPlayerContext]).
  String? _formationId;

  /// §12.2 M1 · `first_eleven` | `bench`. M1 alanı göndermeyen bir sürüme
  /// karşı ilk 11 varsayılır.
  String _squadStatus = 'first_eleven';
  String? _roleName;
  String? _playerPosition;
  String? _playerRole;

  /// §12.1 M4 · maç başına bir konuşma hakkı var; kullanıldıysa buton kapanır
  /// (sunucu da `409 coach_talk_already_done` ile reddeder, bu yalnızca
  /// kullanıcıya kapalı bir kapıyı tıklatmamak için).
  bool _coachTalked = false;

  /// §6.1 — M1 `409 not_match_day`: bugün maç yok. Hata değil, takvimin
  /// normal hâli; ekran maça kaç gün kaldığını gösterir.
  int? _daysUntilMatch;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  /// M1 (career_engine) → E11 (match_engine) köprüsü (D7, D33). Kariyerin
  /// gerçek fikstürü career_engine'den alınır, `engine_payload` olduğu gibi
  /// motora POST'lanır — FE ikisini birbirine bağlayan tek taraf (D3/D33).
  Future<void> _loadNext() async {
    setState(() {
      _loadError = null;
      _daysUntilMatch = null;
      _next = null;
      _formationId = null;
    });
    try {
      final careerId = await _careerSession.resolve();
      final careerMatch = await _fetchNextWithRecovery(careerId);
      final created = await _apiClient.createMatch(careerMatch.enginePayload);
      await _loadPlayerContext(careerId);
      if (!mounted) return;
      setState(() {
        _fixtureId = careerMatch.fixtureId;
        _formationId = careerMatch.formationId;
        _squadStatus = careerMatch.squadStatus;
        _preMatchCondition =
            careerMatch.enginePayload['user_condition'] as int?;
        // E11'in kendi kickoff_at'i motorun dolgu değeri (§8.1a) — gösterimde
        // career_engine'in gerçek fikstür saatini kullanıyoruz.
        _next = NextMatchResponse(
          matchId: created.matchId,
          kickoffAt: DateTime.parse(careerMatch.kickoffAt),
          userSide: created.userSide,
          teams: created.teams,
          teamTactic: created.teamTactic,
          stamina: created.stamina,
          directiveOptions: created.directiveOptions,
          defaults: created.defaults,
        );
      });
    } on CareerApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'not_match_day') {
        // Gün sayısını mesajdan ayıklamak yerine C3'ün kendi `days_until`
        // alanından okuyoruz (§1.3: sayı BE'den, cümle FE'den).
        final days = await _daysUntilNextFixture();
        if (!mounted) return;
        setState(() => _daysUntilMatch = days ?? 0);
        return;
      }
      setState(() => _loadError = e.message ?? 'Maç bilgisi alınamadı.');
    } on MatchApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message ?? 'Maç bilgisi alınamadı.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Maç bilgisi alınamadı.');
    }
  }

  /// Bireysel rol ve mevki C3'te (hub) duruyor — P1 rolü döndürmüyor, o yüzden
  /// maç kurulumundan sonra bir de hub isteniyor. Hata yutuluyor: rolün adı
  /// gösterilemedi diye maça çıkış engellenmez, ekran mevkiyi PlayerState'ten
  /// okuyup dizilişi yine çizer.
  Future<void> _loadPlayerContext(String careerId) async {
    try {
      final hub = await _careerSession.client.hub(careerId);
      if (!mounted) return;
      _roleName = hub.roleName;
      _playerPosition = hub.playerPosition;
      _playerRole = hub.role;
    } catch (_) {
      // Sessizce geç.
    }
  }

  /// §12.1 M4. Konuşma kondisyonu ve günlük bütçeyi oynattığı için
  /// dönüşte oyuncu durumu tazeleniyor; pozisyon/rol talebi kabul edildiyse
  /// diziliş tahtasının etiketi de değişiyor.
  Future<void> _openCoachTalk() async {
    final fixtureId = _fixtureId;
    if (fixtureId == null) return;

    final result = await Navigator.of(context).push<CoachTalkResult>(
      MaterialPageRoute<CoachTalkResult>(
        builder: (_) => CoachTalkScreen(
          fixtureId: fixtureId,
          coachName: 'Antrenör',
          currentPosition: _playerPosition,
          currentRole: _playerRole,
          session: widget.session,
        ),
      ),
    );
    if (!mounted || result == null) return;

    PlayerScope.of(context).applyServerUpdate(careerState: result.careerState);
    setState(() {
      _coachTalked = true;
      if (result.granted == true) {
        _playerPosition = result.position ?? _playerPosition;
        _playerRole = result.role ?? _playerRole;
        // Rol **adını** sunucu bu yanıtta göndermiyor (M4 kimliği yankılıyor,
        // katalog adını değil); etiketi boşaltıyoruz ki eski rolün adı
        // yanlış yerde durmasın — tahta pozisyona düşer.
        _roleName = null;
      }
    });
  }

  Future<int?> _daysUntilNextFixture() async {
    try {
      final careerId = await _careerSession.resolve();
      final hub = await _careerSession.client.hub(careerId);
      return hub.nextFixture?.daysUntil;
    } catch (_) {
      return null;
    }
  }

  /// §6.4 — M1 `409 match_in_progress` dönerse motor oturumu muhtemelen
  /// kaybolmuştur (uygulama maç bitmeden kapanmış olabilir). FE'nin bilmediği
  /// bir sonucu var-mış gibi davranamayacağı için tek güvenli yol M3 ile
  /// fikstürü `scheduled`'a döndürüp yeniden istemek.
  Future<NextCareerMatch> _fetchNextWithRecovery(String careerId) async {
    try {
      return await _careerSession.client.nextMatch(careerId);
    } on CareerApiException catch (e) {
      if (e.code != 'match_in_progress') rethrow;
      // errors.match_in_progress() (career_engine/api/errors.py) yalnızca
      // insan-okur bir cümle döner, ayrı bir `fixture_id` alanı yok — id'yi
      // "fixture '<id>' has an unfinished match" kalıbından çıkarıyoruz.
      final match = RegExp(r"fixture '([^']+)'").firstMatch(e.message ?? '');
      final staleFixtureId = match?.group(1);
      if (staleFixtureId == null) rethrow;
      await _careerSession.client.abandonMatch(careerId, staleFixtureId);
      return _careerSession.client.nextMatch(careerId);
    }
  }

  Future<void> _startMatch() async {
    final next = _next;
    final fixtureId = _fixtureId;
    if (next == null || fixtureId == null || _starting) return;
    setState(() => _starting = true);
    try {
      final start = await _apiClient.startMatch(
        next.matchId,
        userSide: next.userSide,
        effort: next.defaults.effort,
        aggression: next.defaults.aggression,
        focus: next.defaults.focus,
      );
      if (!mounted) return;
      final controller = MatchController(
        matchId: start.matchId,
        streamUrl: start.streamUrl,
        userSide: next.userSide,
        teams: next.teams,
        staminaCatalog: next.stamina,
        directiveOptions: next.directiveOptions,
        // §12.2 — yedek başlayan oyuncu sahaya girene kadar müdahale
        // teklifi almaz ve M2'ye `started: false` raporlanır.
        squadStatus: _squadStatus,
        // D38 — maç oyuncunun kendi kondisyonundan başlar, 100'den değil.
        startCondition: _preMatchCondition,
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MatchScreen(
            controller: controller,
            careerSession: _careerSession,
            fixtureId: fixtureId,
            preMatchCondition: _preMatchCondition ?? next.stamina.current,
          ),
        ),
      );
      // career_engine M1 fikstürü 'in_progress' işaretledi, M2 onu 'played'
      // yapar — geri dönüldüğünde bir sonraki maç için tazesini iste.
      if (mounted) _loadNext();
    } on MatchApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Maç başlatılamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
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
                  child: _buildBody(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final next = _next;
    if (_loadError != null) {
      return _ErrorSection(message: _loadError!, onRetry: _loadNext);
    }
    if (_daysUntilMatch != null) {
      return _NotMatchDaySection(daysUntil: _daysUntilMatch!);
    }
    if (next == null) {
      return const _LoadingSection();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderSection(
          home: next.teams.home.name,
          away: next.teams.away.name,
          kickoffLabel: kickoffDayLabel(next.kickoffAt),
        ),
        _FieldSection(
          formationId: _formationId,
          playerName: PlayerScope.of(context).name,
          playerPosition:
              _playerPosition ?? PlayerScope.of(context).position,
        ),
        _TacticsRow(
          tacticLabel: next.teamTactic.label,
          roleLabel: _roleName ??
              _playerPosition ??
              PlayerScope.of(context).position,
        ),
        _SquadStatusRow(status: _squadStatus),
        const _ConditionBar(),
        _ActionRow(
          starting: _starting,
          onPlay: _startMatch,
          onTalkToCoach: _coachTalked ? null : _openCoachTalk,
        ),
      ],
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.success),
      ),
    );
  }
}

/// §6.1 — bugün maç günü değil. Maç yalnızca kendi gününde oynanır; araya
/// giren günler kariyer merkezindeki "İlerle" ile geçilir.
class _NotMatchDaySection extends StatelessWidget {
  const _NotMatchDaySection({required this.daysUntil});

  final int daysUntil;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_outlined,
                size: 28,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                daysUntil <= 0
                    ? 'Bugün maçın yok.'
                    : 'Maça $daysUntil gün var.',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kalan günleri kariyer merkezinden ilerlet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Kariyer merkezine dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 28,
                color: AppColors.danger,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.home,
    required this.away,
    required this.kickoffLabel,
  });

  final String home;
  final String away;
  final String kickoffLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
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
              'Maça Çıkış',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$home - $away',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kickoffLabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Varsayılan diziliş: M1 bir `formation_id` vermezse ya da verdiği id bu
/// istemcinin gömülü kataloğunda yoksa çizilen şekil. career_engine'in
/// `worlddata/formations.py` DEFAULT_FORMATION'ı ile aynı olmalı.
const _kDefaultFormationId = '4-4-2-duz';

class _FieldSection extends StatelessWidget {
  const _FieldSection({
    required this.formationId,
    required this.playerName,
    required this.playerPosition,
  });

  final String? formationId;
  final String playerName;
  final String playerPosition;

  @override
  Widget build(BuildContext context) {
    // Bilinmeyen id boş kutuya düşmez: dizilişi göstermemektense yaklaşık
    // göstermek yeğ, ekranın geri kalanı (kondisyon, taktik, maça çıkış) her
    // hâlükârda çalışmalı.
    final formation = kFormationsById[formationId] ??
        kFormationsById[_kDefaultFormationId]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Center(
        // Yükseklik sınırı: birebir ölçekli dikey bir saha kartın
        // genişliğinin bir buçuk katı yer ister ve ekranın kalanını taşırır.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: AspectRatio(
            aspectRatio: 0.95,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: FormationBoard(
                formation: formation,
                playerName: playerName,
                playerPosition: playerPosition,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TacticsRow extends StatelessWidget {
  const _TacticsRow({required this.tacticLabel, required this.roleLabel});

  final String tacticLabel;

  /// Antrenörün verdiği rolün adı (C3 `player.role_name`). Rol seçilmeden
  /// açılmış eski kariyerlerde null gelir; çağıran taraf mevkiye düşer.
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _InfoTile(label: 'Takım taktiği', value: tacticLabel),
          ),
          const SizedBox(width: 12),
          // Bireysel rol: kariyer açılışında seçilen rol (C3 `role_name`),
          // rolsüz kariyerlerde oyuncunun mevkisi.
          Expanded(
            child: _InfoTile(label: 'Bireysel rol', value: roleLabel),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionBar extends StatelessWidget {
  const _ConditionBar();

  @override
  Widget build(BuildContext context) {
    final condition = PlayerScope.of(context).condition;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kondisyon',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              Text(
                '$condition/100',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: condition / 100,
              minHeight: 6,
              backgroundColor: AppColors.surface1,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// §12.2 · bugün ilk 11'de mi yedekte mi. `out` buraya hiç düşmez:
/// kadro dışı kaldığında M1 fikstürü hiç vermiyor, ekran "maç günü değil"
/// gövdesine düşüyor.
class _SquadStatusRow extends StatelessWidget {
  const _SquadStatusRow({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final bench = status == 'bench';
    final color = bench ? AppColors.warning : AppColors.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Container(
            key: Key('squad_status_$status'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
            ),
            child: Text(
              bench ? 'YEDEK' : 'İLK 11',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bench
                  ? 'Antrenör kulübeye dönerse oyuna girersin.'
                  : 'Başlangıç on birindesin.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.starting,
    required this.onPlay,
    required this.onTalkToCoach,
  });

  final bool starting;
  final VoidCallback onPlay;

  /// Null ise bu maçta antrenörle zaten konuşulmuş demektir (§12.1).
  final VoidCallback? onTalkToCoach;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onTalkToCoach,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 13),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: Text(
                onTalkToCoach == null ? 'Konuşuldu' : 'Antrenörle konuş',
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            height: 64,
            child: OutlinedButton(
              onPressed: starting ? null : onPlay,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: EdgeInsets.zero,
              ),
              child: starting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
