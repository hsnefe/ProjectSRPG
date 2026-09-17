import 'package:flutter/material.dart';

import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_models.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/character_portrait.dart';
import 'package:project_srpg/widgets/delta_row.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';
import 'package:project_srpg/widgets/relationship_presentation.dart';
import 'package:project_srpg/widgets/typewriter_text.dart';

/// §12.1 M4 — maç öncesi antrenör konuşması.
///
/// [DialogScreen] değil, ama onun görsel diliyle aynı: soyunma odası sahnesi
/// ve antrenörün kimlikten türetilmiş portresi ([PortraitTraits.forId]).
/// Ayrı bir ekran olmasının sebebi seçeneklerin **sunucu tarafında** yaşaması:
/// R3'ün diyalog ağacı FE içeriğidir (D23), M4'ün altı konusu ise bir enum ve
/// sonuçları sunucu hesaplıyor — ağaç kalıbına zorlamak ikisini karıştırırdı.
class CoachTalkScreen extends StatefulWidget {
  const CoachTalkScreen({
    super.key,
    required this.fixtureId,
    required this.coachName,
    this.currentPosition,
    this.currentRole,
    this.currentInstruction,
    this.session,
  });

  final String fixtureId;

  /// Ekranda görünen ad — R1'in `contact_name`'i.
  final String coachName;

  /// Pozisyon/rol talebi seçenekleri bunlara göre kurulur; null ise talep
  /// satırları gizlenir (ne isteneceği bilinmeden buton gösterilemez).
  final String? currentPosition;
  final String? currentRole;

  /// §12.10 · `'attack'|'defend'|'tactical'|'any'` — M1'in `coach_instruction`
  /// alanı, `focus`'un wire null'ı "any" sentinel'ine çevrilmiş hali
  /// (`CoachInstruction.focus ?? 'any'`). Null ise talep satırı gizlenir.
  final String? currentInstruction;

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  @override
  State<CoachTalkScreen> createState() => _CoachTalkScreenState();
}

/// Konu → ekranda görünen replik ve seçenek metni. Sunucu yalnızca `topic`
/// anahtarını tanıyor; metin §5.8 gereği FE'nin.
const _topicLabels = {
  'philosophy_accept': 'Oyun anlayışını kabul et',
  'philosophy_reject': 'Oyun anlayışını reddet',
  'style_accept': 'Oyun tarzını kabul et',
  'style_reject': 'Oyun tarzını reddet',
  'request_position': 'Pozisyon değişikliği iste',
  'request_role': 'Rol değişikliği iste',
  'request_instruction': 'Bugünkü talimatı değiştirmesini iste',
};

/// §12.10 · `worlddata/positions.py`'nin `INSTRUCTIONS`'ıyla aynı dört değer,
/// Türkçe etiketleri de §8.1'in `directive_options.focus`'uyla aynı.
const _instructionLabels = {
  'attack': 'Hücum',
  'defend': 'Savunma',
  'tactical': 'Taktik',
  'any': 'Farketmez',
};

const _openingLine =
    'Bugünkü planı anlattım. Takımın oyun anlayışı belli, senden de o '
    'çerçevede oynamanı bekliyorum. Söyleyecek bir şeyin var mı?';

class _CoachTalkScreenState extends State<CoachTalkScreen> {
  late final CareerSession _session = widget.session ?? CareerSession.instance;
  final _typewriterKey = GlobalKey<TypewriterTextState>();

  bool _sending = false;
  bool _typewriterComplete = false;
  CoachTalkResult? _result;
  String? _error;

  /// Talep konularında hangi hedefin seçildiği. Null ise seçim satırı açık.
  String? _pendingRequestTopic;

  Future<void> _send(String topic, {String? value}) async {
    if (_sending || _result != null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final careerId = await _session.resolve();
      final result = await _session.client.coachTalk(
        careerId,
        widget.fixtureId,
        topic: topic,
        value: value,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _sending = false;
      });
    } on CareerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Konuşma kaydedilemedi.';
        _sending = false;
        _pendingRequestTopic = null;
      });
    }
  }

  /// Konuşma bittiğinde sonucu geri taşır: maç öncesi ekranı kondisyon ve
  /// güven değişimini bununla tazeliyor.
  void _close() => Navigator.of(context).pop(_result);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_sending) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface1,
        body: SafeArea(
          child: Column(
            children: [
              _Header(name: widget.coachName, onClose: _sending ? null : _close),
              SizedBox(
                height: 240,
                width: double.infinity,
                child: Stack(
                  children: [
                    // §4.1 · Sabit bir DialogueScene.lockerRoom yerine tek
                    // kaynaktan (coach-talk'ın kendi şablon kavramı yok, bu
                    // yüzden templateId'siz) — bugün aynı değeri veriyor ama
                    // artık relationship_presentation.dart'ın tek noktasından.
                    Positioned.fill(
                      child: DialogueBackdrop(
                        scene: presentationForRelationship('coach').scene,
                        tint: AppColors.accent,
                      ),
                    ),
                    Positioned.fill(
                      child: CharacterPortrait(
                        traits: PortraitTraits.forId(
                          'coach',
                          tint: AppColors.accent,
                        ),
                        imageAsset: presentationForRelationship('coach').portraitAsset,
                      ),
                    ),
                  ],
                ),
              ),
              _MessageBox(
                typewriterKey: _typewriterKey,
                line: _lineFor(),
                onComplete: () {
                  if (mounted) setState(() => _typewriterComplete = true);
                },
                onTap: () {
                  if (!_typewriterComplete) _typewriterKey.currentState?.skip();
                },
              ),
              if (_error case final message?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    message,
                    key: const Key('coach_talk_error'),
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              Expanded(child: SingleChildScrollView(child: _buildChoices())),
            ],
          ),
        ),
      ),
    );
  }

  String _lineFor() {
    final result = _result;
    if (result == null) return _openingLine;
    return switch (result.topic) {
      'philosophy_accept' =>
        'İyi. Sahada da böyle görürsem sözümün arkasında dururum.',
      'philosophy_reject' =>
        'Anlıyorum ama planı ben kuruyorum. Bu konuşma seni geri çeker.',
      'style_accept' => 'Tamam, anlaştık. Alışılmış işini yap yeter.',
      'style_reject' => 'Kendi bildiğini okumak istiyorsan bedeli var.',
      _ => result.granted == true
          ? 'Peki. Bu sefer senin dediğin gibi deneyelim.'
          : 'Hayır. Bugün değil — takımın şekli buna uygun değil.',
    };
  }

  Widget _buildChoices() {
    if (_result != null) return _ResultPanel(result: _result!, onDone: _close);
    if (!_typewriterComplete) return const SizedBox(height: 24);

    final requestTopic = _pendingRequestTopic;
    if (requestTopic != null) {
      return _TargetPicker(
        topic: requestTopic,
        currentPosition: widget.currentPosition,
        currentRole: widget.currentRole,
        currentInstruction: widget.currentInstruction,
        onPick: (value) => _send(requestTopic, value: value),
        onCancel: () => setState(() => _pendingRequestTopic = null),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          for (final topic in _topicLabels.keys)
            if (_isAvailable(topic))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChoiceButton(
                  key: Key('coach_topic_$topic'),
                  label: _topicLabels[topic]!,
                  onPressed: _sending
                      ? null
                      : () {
                          if (topic.startsWith('request_')) {
                            setState(() => _pendingRequestTopic = topic);
                          } else {
                            _send(topic);
                          }
                        },
                ),
              ),
        ],
      ),
    );
  }

  /// Talep konuları yalnızca neyin isteneceği bilindiğinde görünür — mevcut
  /// pozisyon/rol gelmemişse hedef listesi kurulamaz.
  bool _isAvailable(String topic) {
    if (topic == 'request_position') return widget.currentPosition != null;
    if (topic == 'request_role') return widget.currentPosition != null;
    if (topic == 'request_instruction') return widget.currentInstruction != null;
    return true;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onClose});

  final String name;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          ),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(
            'MAÇ ÖNCESİ',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.typewriterKey,
    required this.line,
    required this.onComplete,
    required this.onTap,
  });

  final GlobalKey<TypewriterTextState> typewriterKey;
  final String line;
  final VoidCallback onComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const Key('coach_talk_message_box'),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: TypewriterText(
          key: typewriterKey,
          text: line,
          onComplete: onComplete,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.centerLeft,
          textStyle: const TextStyle(fontSize: 13),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Talep konusunda hedefi seçtirir. Rol listesi mevcut pozisyona bağlı —
/// sunucu başka pozisyonun rolünü zaten 422 ile reddediyor, burada seçenek
/// olarak hiç gösterilmiyor.
class _TargetPicker extends StatelessWidget {
  const _TargetPicker({
    required this.topic,
    required this.currentPosition,
    required this.currentRole,
    required this.currentInstruction,
    required this.onPick,
    required this.onCancel,
  });

  final String topic;
  final String? currentPosition;
  final String? currentRole;
  final String? currentInstruction;
  final ValueChanged<String> onPick;
  final VoidCallback onCancel;

  static const _positions = ['Defans', 'Orta saha', 'Forvet'];

  @override
  Widget build(BuildContext context) {
    final options = switch (topic) {
      'request_position' =>
        _positions.where((p) => p != currentPosition).toList(),
      'request_instruction' =>
        _instructionLabels.keys.where((v) => v != currentInstruction).toList(),
      _ => rolesForPosition(currentPosition).where((r) => r != currentRole).toList(),
    };
    // Rol/pozisyon butonları kendi ham değerini (role_id / pozisyon adı)
    // etiket olarak kullanıyor; talimatın dört değeri için Türkçe karşılığı
    // var, o kullanılıyor (§8.1'in `directive_options.focus` etiketleri).
    String labelFor(String value) =>
        topic == 'request_instruction' ? _instructionLabels[value]! : value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChoiceButton(
                key: Key('coach_target_$option'),
                label: labelFor(option),
                onPressed: () => onPick(option),
              ),
            ),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// `worlddata/positions.py`'nin rol kataloğunun FE kopyası. Yalnızca **hangi
/// rolün hangi pozisyona ait olduğu** taşınıyor; nitelik eşlemesi ve sonuçlar
/// sunucuda kalıyor. Bilinmeyen bir pozisyon boş liste döndürür, o da talep
/// satırını gizler.
List<String> rolesForPosition(String? position) => switch (position) {
      'Defans' => const [
          'stoper',
          'ileri_cikan_stoper',
          'libero',
          'bek',
          'kanat_bek',
          'oyun_kuran_kanat_bek',
          'yaratici_kanat_bek',
        ],
      'Orta saha' => const [
          'defansif_orta_saha',
          'yari_bek',
          'regista',
          'merkez_orta_saha',
          'oyun_kurucu',
          'box_to_box',
          'mezzala',
          'ofansif_orta_saha',
          'gelismis_oyun_kurucu',
          'shadow_striker',
          'kanat',
          'ic_kanat',
        ],
      'Forvet' => const [
          'forvet',
          'hedef_adam',
          'firsatci_forvet',
          'pres_yapan_forvet',
          'derine_gelen_forvet',
        ],
      _ => const [],
    };

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result, required this.onDone});

  final CoachTalkResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final trust = result.trust;
    final score = result.relationshipChanges.isEmpty
        ? null
        : result.relationshipChanges.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trust != null)
            DeltaRow(
              key: const Key('coach_trust_delta'),
              label: 'Güven',
              before: trust.before,
              after: trust.after,
            ),
          if (score != null)
            DeltaRow(
              key: const Key('coach_score_delta'),
              label: 'İlişki',
              before: score.before.toDouble(),
              after: score.after.toDouble(),
            ),
          if (result.granted == true && result.role != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Yeni görev: ${result.position} · ${result.role}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                ),
              ),
            ),
          // §12.10 · `request_instruction` kabul edildiğinde ya da rolü
          // değiştiren bir talep talimatı yeniden türettiğinde dolar.
          if (result.granted == true && result.instructionLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Yeni talimat: ${result.instructionLabel}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('coach_talk_done'),
            onPressed: onDone,
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
