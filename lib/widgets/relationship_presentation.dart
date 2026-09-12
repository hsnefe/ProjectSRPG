import 'package:flutter/material.dart';
import 'package:project_srpg/theme/app_colors.dart';
import 'package:project_srpg/widgets/dialogue_backdrop.dart';

/// §5.8 — ikon, ton, rozet kodu ve üst kategori etiketi BE'den gelmez, FE'nin
/// sunum kararı (R1 yalnızca `relationship_id/kind/category/score/...`
/// verir). Altı ilişki sabit olduğu için (D4, §3.4) elle eşleniyor.
///
/// İlişkiler ekranı da sosyal teklif ekranı da aynı altı satırı okuyor; kayıt
/// bölünmeden burada tek sahipte duruyor — iki ekranın antrenörü aynı mavi,
/// aynı soyunma odası olsun diye.
class RelationshipPresentation {
  const RelationshipPresentation({
    required this.icon,
    required this.tint,
    required this.badgeCode,
    required this.leftTag,
    required this.dialogueId,
    required this.scene,
  });

  final IconData icon;
  final Color tint;
  final String badgeCode;
  final String leftTag;

  /// Bu kişiyle konuşma nerede geçiyor — diyalog ve teklif ekranlarının arka
  /// planı. §5.8: sahne de ikon/renk gibi FE'nin sunum kararı, BE göndermez.
  final DialogueScene scene;

  /// catalog/dialogue.py'nin `DIALOGUE_RELATIONSHIP` anahtarları.
  final String dialogueId;
}

const kPartnerPurple = Color(0xFF9B5CF6);

const _presentationByRelationshipId = {
  'coach': RelationshipPresentation(
    icon: Icons.assignment_outlined, tint: AppColors.accent, badgeCode: 'AN',
    leftTag: 'KLÜP', dialogueId: 'coach_01',
    scene: DialogueScene.lockerRoom,
  ),
  'team': RelationshipPresentation(
    icon: Icons.groups_outlined, tint: AppColors.success, badgeCode: 'TK',
    leftTag: 'KLÜP', dialogueId: 'team_01',
    scene: DialogueScene.trainingGround,
  ),
  'media': RelationshipPresentation(
    icon: Icons.mic_none_outlined, tint: AppColors.danger, badgeCode: 'MD',
    leftTag: 'BASIN', dialogueId: 'media_01',
    scene: DialogueScene.pressRoom,
  ),
  // `dialogueId` bilinçli olarak boş: catalog/dialogue.py'de 'fans' için bir
  // diyalog ağacı yok, `_openDialog` bunu `_dialogueTreeByRelationshipId`'de
  // bulamayınca sessizce no-op olur (bkz. `relationships_screen.dart`).
  'fans': RelationshipPresentation(
    icon: Icons.groups_2_outlined, tint: AppColors.warning, badgeCode: 'TF',
    leftTag: 'TARAFTAR', dialogueId: '',
    scene: DialogueScene.stadium,
  ),
  'partner': RelationshipPresentation(
    icon: Icons.favorite_border, tint: kPartnerPurple, badgeCode: 'PA',
    leftTag: 'ÖZEL', dialogueId: 'partner_01',
    scene: DialogueScene.home,
  ),
  'family': RelationshipPresentation(
    icon: Icons.home_outlined, tint: AppColors.warning, badgeCode: 'AS',
    leftTag: 'ÖZEL', dialogueId: 'family_01',
    scene: DialogueScene.home,
  ),
};

const kDefaultRelationshipPresentation = RelationshipPresentation(
  icon: Icons.person_outline, tint: AppColors.textMuted, badgeCode: '??',
  leftTag: '', dialogueId: '', scene: DialogueScene.trainingGround,
);

RelationshipPresentation presentationForRelationship(String relationshipId) =>
    _presentationByRelationshipId[relationshipId] ??
    kDefaultRelationshipPresentation;
