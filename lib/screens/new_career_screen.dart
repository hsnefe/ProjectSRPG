import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project_srpg/net/career_models.dart' as api;
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/screens/career_center_screen.dart';
import 'package:project_srpg/screens/new_career/exam_step.dart';
import 'package:project_srpg/screens/new_career/identity_step.dart';
import 'package:project_srpg/screens/new_career/role_step.dart';
import 'package:project_srpg/screens/new_career/target_step.dart';
import 'package:project_srpg/state/player_scope.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/panel_states.dart';

/// §5.1 C0 → C1 → C5: yeni kariyer sihirbazı.
///
/// Dört adım tek ekranda yaşar (bir `PageView`), çünkü üçü tek bir isteğin
/// (C1) parçası: ad/soyad + milliyet, pozisyon + rol, hedef kulüp. Dördüncü
/// adım kariyer kurulduktan **sonra** çalışır (C5) — rayda o sınır ayrıca
/// işaretlenir, çünkü oradan geriye dönüş yoktur.
///
/// Ekran hiçbir sayıyı kendi bilmez: taban yetenek, rol bonusu ve sınav
/// ölçeği C0'ın `starting_values`/`skill_exams` bloklarından gelir.
class NewCareerScreen extends StatefulWidget {
  const NewCareerScreen({super.key, this.session});

  static const routeName = '/new-career';

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<NewCareerScreen> createState() => _NewCareerScreenState();
}

/// Saha yeteneklerinin FE etiketleri (§1.3: Türkçe etiket FE'de kalır).
const _stepLabels = <String>['Kimlik', 'Pozisyon', 'Hedef', 'Sınav'];

class _NewCareerScreenState extends State<NewCareerScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  late Future<api.CareerOptions> _optionsFuture = _loadOptions();

  final _pageController = PageController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  int _step = 0;
  String? _nationality;
  String? _position;
  String? _roleId;
  String? _targetTeamId;
  final Map<String, int> _examLevels = {};

  /// Adım 1'de boş alan uyarısı ancak kullanıcı "Devam"a bastıktan sonra
  /// çıksın — ekran açılır açılmaz iki kırmızı satırla karşılamak istemiyoruz.
  bool _nameChecked = false;

  /// C1 döndüğünde dolar; doluysa sihirbazdan geri çıkış kapanır.
  String? _careerId;
  List<api.SkillExamOutcome>? _outcomes;
  bool _busy = false;

  Future<api.CareerOptions> _loadOptions() => _session.client.careerOptions();

  @override
  void dispose() {
    _pageController.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  // --- seçimlerden türeyenler ----------------------------------------------

  api.RoleOption? _selectedRole(api.CareerOptions options) {
    for (final position in options.positions) {
      for (final role in position.roles) {
        if (role.roleId == _roleId) return role;
      }
    }
    return null;
  }

  /// Sınav öncesi yetenek değeri: taban + rolün o yeteneğe ayırdığı yuvalar.
  double _baseSkill(api.CareerOptions options, String attributeKey) {
    final role = _selectedRole(options);
    return options.startingValues.skillFor(
      attributeKey,
      role?.attributes ?? const [],
    );
  }

  /// Sınav notunun uygulanmış hali — kazanç sınavın tavanında kesilir.
  double _examPreview(api.CareerOptions options, api.SkillExamOption exam) {
    final base = _baseSkill(options, exam.attributeKey);
    final level = _examLevels[exam.examId];
    if (level == null) return base;
    return math.min(exam.maxValue, base + exam.awardFor(level));
  }

  bool _canContinue(api.CareerOptions options) {
    switch (_step) {
      case 0:
        return _firstName.text.trim().isNotEmpty &&
            _lastName.text.trim().isNotEmpty &&
            _nationality != null;
      case 1:
        return _roleId != null;
      case 2:
        return _targetTeamId != null;
      default:
        if (_outcomes != null) return true;
        return options.skillExams.every(
          (exam) => _examLevels.containsKey(exam.examId),
        );
    }
  }

  // --- eylemler -------------------------------------------------------------

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPrimary(api.CareerOptions options) {
    FocusManager.instance.primaryFocus?.unfocus();
    switch (_step) {
      case 0:
        setState(() => _nameChecked = true);
        if (_canContinue(options)) _goTo(1);
      case 1:
        _goTo(2);
      case 2:
        _createCareer();
      default:
        if (_outcomes == null) {
          _submitExams();
        } else {
          _enterCareer();
        }
    }
  }

  Future<void> _createCareer() async {
    setState(() => _busy = true);
    try {
      final hub = await _session.client.createCareer(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        nationality: _nationality!,
        position: _position!,
        role: _roleId!,
        targetTeamId: _targetTeamId!,
      );
      // Oturum bu kariyere bağlanır; önceki kariyerler kayıt listesinde durur.
      _session.adopt(hub.careerId);
      if (!mounted) return;
      setState(() {
        _careerId = hub.careerId;
        _busy = false;
      });
      _goTo(3);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(error);
    }
  }

  Future<void> _submitExams() async {
    setState(() => _busy = true);
    try {
      final outcomes = await _session.client.submitSkillExams(
        _careerId!,
        _examLevels,
      );
      if (!mounted) return;
      setState(() {
        _outcomes = outcomes;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(error);
    }
  }

  void _enterCareer() {
    // Paylaşılan oyuncu durumu hâlâ açılıştaki yer tutucuları taşıyor;
    // kariyer merkezine geçmeden önce yeni künyeyle tazelenir.
    PlayerScope.of(context).load();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const CareerCenterScreen(),
        settings: const RouteSettings(name: CareerCenterScreen.routeName),
      ),
    );
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(careerErrorText(error)),
        backgroundColor: AppColors.surface2,
      ),
    );
  }

  // --- çatı -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Kariyer kurulduktan sonra geri çıkış yok: kayıt motorda açıldı,
      // sihirbazı terk etmek yarım bir kariyer bırakmaz ama kullanıcıyı
      // sınavları hiç görmeden dışarı atardı.
      canPop: _careerId == null,
      child: Scaffold(
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
                    child: FutureBuilder<api.CareerOptions>(
                      future: _optionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const CenteredSpinner();
                        }
                        if (snapshot.hasError) {
                          return PanelError(
                            message: careerErrorText(snapshot.error!),
                            onRetry: () =>
                                setState(() => _optionsFuture = _loadOptions()),
                          );
                        }
                        return _buildWizard(snapshot.data!);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWizard(api.CareerOptions options) {
    _applyDefaults(options);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Column(
        children: [
          _WizardHeader(
            step: _step,
            careerCreated: _careerId != null,
            onBack: _step == 0 || _careerId != null
                ? null
                : () => _goTo(_step - 1),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                IdentityStep(
                  options: options,
                  firstName: _firstName,
                  lastName: _lastName,
                  nationality: _nationality,
                  showErrors: _nameChecked,
                  onChanged: () => setState(() {}),
                  onNationality: (code) => setState(() => _nationality = code),
                ),
                RoleStep(
                  options: options,
                  position: _position,
                  roleId: _roleId,
                  onPosition: (position) => setState(() {
                    _position = position;
                    _roleId = null;
                  }),
                  onRole: (roleId) => setState(() => _roleId = roleId),
                ),
                TargetStep(
                  options: options,
                  targetTeamId: _targetTeamId,
                  onTarget: (teamId) => setState(() => _targetTeamId = teamId),
                ),
                ExamStep(
                  options: options,
                  levels: _examLevels,
                  outcomes: _outcomes,
                  previewOf: (exam) => _examPreview(options, exam),
                  baseOf: (exam) => _baseSkill(options, exam.attributeKey),
                  onLevel: (examId, level) =>
                      setState(() => _examLevels[examId] = level),
                ),
              ],
            ),
          ),
          _ActionBar(
            label: _primaryLabel(),
            enabled: _canContinue(options) && !_busy,
            busy: _busy,
            hint: _hint(options),
            onPressed: () => _onPrimary(options),
          ),
        ],
      ),
    );
  }

  /// Katalog gelir gelmez ilk geçerli seçimleri kurar: milliyet tek kalemse
  /// kullanıcıya "seç" dedirtmenin anlamı yok, pozisyon da rolü olan ilk
  /// pozisyondan başlar (rolsüz pozisyon C1'de 422 döner).
  void _applyDefaults(api.CareerOptions options) {
    _nationality ??= options.nationalities.isEmpty
        ? null
        : options.nationalities.first.countryCode;
    if (_position == null) {
      for (final position in options.positions) {
        if (position.roles.isNotEmpty) {
          _position = position.position;
          break;
        }
      }
    }
  }

  String _primaryLabel() {
    switch (_step) {
      case 2:
        return 'Kariyeri Başlat';
      case 3:
        return _outcomes == null ? 'Notları Gönder' : 'Kariyere Başla';
      default:
        return 'Devam';
    }
  }

  String? _hint(api.CareerOptions options) {
    if (_busy) return null;
    if (_canContinue(options)) return null;
    switch (_step) {
      case 0:
        return 'Ad ve soyad gerekli';
      case 1:
        return 'Bir rol seç';
      case 2:
        return 'Hedef kulüp seç';
      default:
        return 'Üç sınava da not ver';
    }
  }
}

// ---------------------------------------------------------------------------
// Çatı parçaları
// ---------------------------------------------------------------------------

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.careerCreated,
    required this.onBack,
  });

  final int step;
  final bool careerCreated;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: onBack == null
                    ? null
                    : IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.chevron_left,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              const Text(
                'YENİ KARİYER',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StepRail(step: step, careerCreated: careerCreated),
        ],
      ),
    );
  }
}

/// Dört adımın rayı. Üçüncü ile dördüncü arasındaki kesik, kariyerin motorda
/// açıldığı yeri işaretler — o çizginin sağında geri dönüş yok.
class _StepRail extends StatelessWidget {
  const _StepRail({required this.step, required this.careerCreated});

  final int step;
  final bool careerCreated;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _stepLabels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 16),
                color: i == 3 ? AppColors.accent : AppColors.border,
              ),
            ),
          _StepDot(
            index: i,
            current: i == step,
            done: i < step,
            locked: i == 3 && !careerCreated,
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.current,
    required this.done,
    required this.locked,
  });

  final int index;
  final bool current;
  final bool done;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final background = current
        ? AppColors.accent
        : done
        ? AppColors.successBg
        : AppColors.surface1;
    final foreground = current
        ? Colors.white
        : done
        ? AppColors.success
        : AppColors.textMuted;

    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(
                color: current
                    ? AppColors.accent
                    : done
                    ? AppColors.success
                    : AppColors.border,
                width: 0.8,
              ),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _stepLabels[index],
            style: TextStyle(
              color: current ? AppColors.textPrimary : AppColors.textMuted,
              fontSize: 10,
              fontWeight: current ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.hint,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final String? hint;
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
              hint ?? '',
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
                    : Text(
                        label,
                        style: const TextStyle(
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

/// Adımların ortak girişi: küçük üst etiket, başlık ve bir cümlelik açıklama.
