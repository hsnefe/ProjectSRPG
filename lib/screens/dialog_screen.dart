import 'package:flutter/material.dart';
import 'package:project_srpg/game/attribute_labels.dart';
import 'package:project_srpg/net/career_api_client.dart';
import 'package:project_srpg/net/career_session.dart';
import 'package:project_srpg/state/player_scope.dart';

import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/character_portrait.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';
import 'package:project_srpg/widgets/typewriter_text.dart';

/// Diyalog ağacındaki tek bir seçenek: gösterilen metin ve gidilecek düğümün id'si.
class DialogueOption {
  const DialogueOption({required this.text, required this.nextId});

  final String text;
  final String nextId;
}

/// Diyalog ağacındaki tek bir replik. `options` boşsa bu düğüm terminaldir
/// (karşı taraf konuşmayı burada bitirir, ardından "İlerle" butonu çıkar).
class DialogueNode {
  const DialogueNode({
    required this.id,
    required this.line,
    this.options = const [],
  });

  final String id;
  final String line;
  final List<DialogueOption> options;
}

/// Çok turlu dallanabilen diyalog akışı: id -> DialogueNode.
class DialogueTree {
  const DialogueTree({required this.startId, required this.nodes});

  final String startId;
  final Map<String, DialogueNode> nodes;

  DialogueNode get start => nodes[startId]!;
}

class DialogScreen extends StatefulWidget {
  const DialogScreen({
    super.key,
    required this.contactName,
    required this.tree,
    required this.tint,
    required this.relationshipId,
    required this.dialogueId,
    this.session,
    this.scene = DialogueScene.trainingGround,
    this.portrait,
    this.backgroundAsset,
    this.characterAsset,
  });

  final String contactName;
  final DialogueTree tree;
  final Color tint;

  /// R3 · hangi ilişki kartına yazılacağı.
  final String relationshipId;

  /// R3 · catalog/dialogue.py'nin `DIALOGUE_RELATIONSHIP` anahtarı — bu
  /// ağacın konuşmanın hangi sonuç tablosuna karşılık geldiği.
  final String dialogueId;

  /// Testlerin sahte bir backend geçirebilmesi için; uygulamada boş bırakılır.
  final CareerSession? session;

  /// Konuşmanın **nerede** geçtiği — arka plan bundan çizilir. Sosyal
  /// olayın kendisi belirler (takim yemeği kafede, röportaj basın odasında);
  /// bilinmiyorsa idman sahası varsayılır.
  final DialogueScene scene;

  /// Karşıdaki kişinin görünüşü. Null ise nötr bir siluet çizilir.
  final PortraitTraits? portrait;

  /// Görsel alanın arka plan katmanı. **Gerçek bir görsel varsa** [scene]'in
  /// çizimini geçersiz kılar; null ise sahne çizilir.
  final String? backgroundAsset;

  /// Görsel alanın karakter katmanı; gerçek portre varsa [portrait]'i
  /// geçersiz kılar.
  final String? characterAsset;

  @override
  State<DialogScreen> createState() => _DialogScreenState();
}

class _DialogScreenState extends State<DialogScreen> {
  final _typewriterKey = GlobalKey<TypewriterTextState>();
  late final CareerSession _session = widget.session ?? CareerSession.instance;

  late DialogueNode _currentNode = widget.tree.start;
  bool _typewriterComplete = false;
  bool _advanceVisible = false;
  List<bool> _choiceVisible = const [];
  int _revealGen = 0;

  /// Seçilen düğümlerin sırası — R3'ün `choice_path`'i (§5.4). v1'in tek
  /// turlu ağaçlarında tek eleman olur ama sıra korunur: çok turlu bir
  /// ağaç eklendiğinde kod değişmeden çalışır.
  final List<String> _choicePath = [];

  /// R3 en fazla bir kez çağrılır — terminal düğüme birden fazla yoldan
  /// (örn. geri/yeniden tetikleme) düşülürse bakiye/skor iki kez yazılmasın.
  bool _reported = false;

  /// N3 `GET /catalog/dialogue` · `leaf_id` -> `requires` (D42). Eşikler
  /// BE'nin, ağacın metni FE'nin (D23) — bu harita ikisini `nextId` üzerinden
  /// birleştirir.
  Map<String, Map<String, int>> _requiresByLeaf = const {};

  @override
  void initState() {
    super.initState();
    _loadRequirements();
  }

  /// Eşikler gelmezse **hiçbir seçenek kilitlenmez**. Bilinçli: gösterim
  /// tarafında açık kalmak, kilidi yanlışlıkla göstermekten iyidir ve
  /// güvenliği zayıflatmaz — R3 aynı kontrolü sunucuda tekrarlar (INV-30),
  /// kullanıcı kilitli bir seçeneği seçerse 409 döner ve `_reportOutcome`
  /// zaten mesajı gösterir.
  Future<void> _loadRequirements() async {
    try {
      final catalog = await _session.client.dialogueCatalog();
      final entry = catalog.byId(widget.dialogueId);
      if (!mounted || entry == null) return;
      setState(() => _requiresByLeaf = entry.requiresByLeaf);
    } catch (_) {
      // Yukarıdaki nota bak — sessizce açık kal. Yalnızca CareerApiException
      // değil: sunucuya hiç ulaşılamadığında (`_get` ağ hatasını sarmalamaz)
      // gelen istisna da buraya düşmeli, yoksa yakalanmayan bir async hata
      // konuşmayı hiç ilgilendirmediği halde ekranı düşürür.
    }
  }

  void _onTypewriterComplete() {
    if (!mounted) return;
    final hasOptions = _currentNode.options.isNotEmpty;
    setState(() {
      _typewriterComplete = true;
      _choiceVisible = List.filled(_currentNode.options.length, false);
      _advanceVisible = !hasOptions;
    });
    if (hasOptions) {
      _revealChoicesStaggered();
    } else {
      _reportOutcome();
    }
  }

  /// R3 · `POST /careers/{cid}/relationships/{rid}/interact` — konuşma
  /// terminal düğüme ulaştığında bir kez çağrılır (D23: ağacı FE tutar, BE
  /// yalnızca sonucu değerlendirir).
  Future<void> _reportOutcome() async {
    if (_reported || _choicePath.isEmpty) return;
    _reported = true;
    try {
      final careerId = await _session.resolve();
      final result = await _session.client.interact(
        careerId,
        widget.relationshipId,
        dialogueId: widget.dialogueId,
        choicePath: List.of(_choicePath),
      );
      if (!mounted) return;
      PlayerScope.of(
        context,
      ).applyServerUpdate(attributeChanges: result.attributeChanges);
    } on CareerApiException catch (e) {
      // Tek deneme: kullanıcı yine de "İlerle" ile devam edebilmeli, ikinci
      // bir otomatik tekrar denemesi yok.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Diyalog kaydedilemedi.')),
      );
    }
  }

  Future<void> _revealChoicesStaggered() async {
    final gen = ++_revealGen;
    for (var i = 0; i < _choiceVisible.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || gen != _revealGen) return;
      setState(() => _choiceVisible[i] = true);
    }
  }

  void _selectOption(DialogueOption option) {
    if (_unmetFor(option).isNotEmpty) return;
    _revealGen++;
    _choicePath.add(option.nextId);
    setState(() {
      _currentNode = widget.tree.nodes[option.nextId]!;
      _typewriterComplete = false;
      _advanceVisible = false;
      _choiceVisible = const [];
    });
  }

  /// Bu seçeneğin karşılanmayan eşikleri; boşsa seçenek açıktır. Seviyeler
  /// [PlayerState]'ten, yani BE'nin gönderdiği `level` alanından okunur —
  /// bir aktivite az önce bir kapı açtıysa burası da açılır.
  Map<String, int> _unmetFor(DialogueOption option) {
    final requires = _requiresByLeaf[option.nextId];
    if (requires == null || requires.isEmpty) return const {};
    final player = PlayerScope.of(context);
    return unmetRequirements(requires, player.attributeLevel);
  }

  /// Karşı tarafın diyalog kutusuna dokununca: yazı hâlâ yazılıyorsa anında
  /// tamamlanır, tamamlandıysa ve seçenekler sıralı beliriyorsa hepsi
  /// anında gösterilir. "Animasyonlar skiplensin" isteğinin karşılığı.
  void _onMessageTap() {
    if (!_typewriterComplete) {
      _typewriterKey.currentState?.skip();
      return;
    }
    if (_choiceVisible.contains(false)) {
      _revealGen++;
      setState(() {
        _choiceVisible = List.filled(_choiceVisible.length, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        24;

    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: panelHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        _PhotoSection(
                          contactName: widget.contactName,
                          tint: widget.tint,
                          scene: widget.scene,
                          portrait: widget.portrait,
                          backgroundAsset: widget.backgroundAsset,
                          characterAsset: widget.characterAsset,
                        ),
                        _MessageSection(
                          typewriterKey: _typewriterKey,
                          line: _currentNode.line,
                          onComplete: _onTypewriterComplete,
                          onTap: _onMessageTap,
                        ),
                        Expanded(
                          child: _currentNode.options.isEmpty
                              ? _AdvanceSection(visible: _advanceVisible)
                              : _ChoicesSection(
                                  options: _currentNode.options,
                                  visible: _choiceVisible,
                                  unmetFor: _unmetFor,
                                  onSelect: _selectOption,
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
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.contactName,
    required this.tint,
    required this.scene,
    this.portrait,
    this.backgroundAsset,
    this.characterAsset,
  });

  final String contactName;
  final Color tint;
  final DialogueScene scene;
  final PortraitTraits? portrait;
  final String? backgroundAsset;
  final String? characterAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: _BackgroundLayer(
              asset: backgroundAsset,
              scene: scene,
              tint: tint,
            ),
          ),
          Positioned.fill(
            child: _CharacterLayer(
              asset: characterAsset,
              portrait: portrait,
              tint: tint,
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                contactName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Görsel alanın zemin katmanı; karakter katmanının arkasında kalır.
///
/// Gerçek bir görsel yoksa düz bir degrade yerine **sahne** çizilir — bir
/// konuşmanın nerede geçtiği, ne konuşulduğu kadar bilgi taşıyor.
class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer({
    required this.asset,
    required this.scene,
    required this.tint,
  });

  final String? asset;
  final DialogueScene scene;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final fallback = DialogueBackdrop(scene: scene, tint: tint);

    final path = asset;
    if (path == null) return fallback;
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Görsel alanın karakter katmanı; gerçek portre yoksa kişiden türetilmiş
/// prosüdürel büst çizilir ([PortraitTraits.forId]). Eski placeholder ikonu
/// yalnızca [portrait] da verilmediyse kalır.
class _CharacterLayer extends StatelessWidget {
  const _CharacterLayer({
    required this.asset,
    required this.portrait,
    required this.tint,
  });

  final String? asset;
  final PortraitTraits? portrait;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final traits = portrait;
    final fallback = traits != null
        ? CharacterPortrait(traits: traits)
        : Center(
            child: Icon(
              Icons.person_outline,
              size: 64,
              color: tint.withValues(alpha: 0.8),
            ),
          );

    final path = asset;
    if (path == null) return fallback;
    return Image.asset(
      path,
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _MessageSection extends StatelessWidget {
  const _MessageSection({
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
      key: const Key('dialogue_message_box'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: TypewriterText(
          key: typewriterKey,
          text: line,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.6,
          ),
          onComplete: onComplete,
        ),
      ),
    );
  }
}

class _ChoicesSection extends StatelessWidget {
  const _ChoicesSection({
    required this.options,
    required this.visible,
    required this.unmetFor,
    required this.onSelect,
  });

  final List<DialogueOption> options;
  final List<bool> visible;
  final Map<String, int> Function(DialogueOption) unmetFor;
  final ValueChanged<DialogueOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ChoiceButton(
              option: options[i],
              visible: i < visible.length && visible[i],
              unmet: unmetFor(options[i]),
              onTap: () => onSelect(options[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kilitli seçenek **gizlenmez, griye çekilir** (§5.4): oyuncu neyi
/// söyleyemediğini ve hangi niteliği geliştirirse söyleyebileceğini görür.
/// Gizlemek, konuşmayı kısaltmaktan başka bir şey öğretmezdi.
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.option,
    required this.visible,
    required this.unmet,
    required this.onTap,
  });

  final DialogueOption option;
  final bool visible;

  /// D42 · karşılanmayan eşikler; boşsa seçenek açıktır.
  final Map<String, int> unmet;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = unmet.isNotEmpty;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 0.15),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: visible ? 1 : 0,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: locked ? Key('locked_choice_${option.nextId}') : null,
            onPressed: (visible && !locked) ? onTap : null,
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  locked ? AppColors.textMuted : AppColors.textPrimary,
              disabledForegroundColor: AppColors.textMuted,
              side: BorderSide(
                color: locked
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              alignment: Alignment.centerLeft,
              textStyle: const TextStyle(fontSize: 13, height: 1.4),
            ),
            child: locked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.text),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 12),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              requirementLabel(unmet),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Text(option.text),
          ),
        ),
      ),
    );
  }
}

class _AdvanceSection extends StatelessWidget {
  const _AdvanceSection({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          offset: visible ? Offset.zero : const Offset(0, 0.15),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: visible ? 1 : 0,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    visible ? () => Navigator.of(context).pop(true) : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('İlerle'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
