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
    this.portraitAsset,
    this.cardPortraitAsset,
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

  /// §1.2 · `assets/images/portraits/<relationship_id>.png` — geniş diyalog
  /// şeridi için, üstte boşluk paylı (yüz kutunun ortasına düşsün diye).
  /// Null ise `CharacterPortrait`/`DialogScreen` prosedürel büste düşer
  /// ([PortraitTraits.forId]).
  final String? portraitAsset;

  /// §1.2 · `assets/images/portraits/cards/<relationship_id>.png` —
  /// İlişkiler kartı için, boşluksuz orijinal kırpım. Kart neredeyse kare
  /// (215x300), orijinal kare kırpımı zaten kenara taşmadan oturuyor;
  /// diyalog için eklenen üst boşluk burada kişiyi küçültüp ortaya boşluk
  /// bırakırdı — o yüzden kartın kendi, boşluksuz versiyonu var.
  final String? cardPortraitAsset;
}

const kPartnerPurple = Color(0xFF9B5CF6);

const _presentationByRelationshipId = {
  // §1.2 · portraitAsset'ler yeri.ai'de üretilen 3x3 pixel-art gridinden
  // dokuzda altısı — gri zemin şeffaflaştırılıp tek tek kesildi. Kimin kime
  // gittiği içerikteki isimlere göre: "coach" Antrenör Mert (coach_talk_screen),
  // "media" Ayça Kılıç (media_interview_request şablonu), "partner" Elif
  // (partner_evening_out), "team" Kaptan Burak (team_dinner) — geri kalan üç
  // portre (r1c1, r1c3, r2c3) şimdilik kullanılmıyor, ileride NPC çeşitliliği
  // için ayrılabilir.
  'coach': RelationshipPresentation(
    icon: Icons.assignment_outlined, tint: AppColors.accent, badgeCode: 'AN',
    leftTag: 'KLÜP', dialogueId: 'coach_01',
    scene: DialogueScene.lockerRoom,
    portraitAsset: 'assets/images/portraits/coach.png',
    cardPortraitAsset: 'assets/images/portraits/cards/coach.png',
  ),
  'team': RelationshipPresentation(
    icon: Icons.groups_outlined, tint: AppColors.success, badgeCode: 'TK',
    leftTag: 'KLÜP', dialogueId: 'team_01',
    scene: DialogueScene.trainingGround,
    portraitAsset: 'assets/images/portraits/team.png',
    cardPortraitAsset: 'assets/images/portraits/cards/team.png',
  ),
  'media': RelationshipPresentation(
    icon: Icons.mic_none_outlined, tint: AppColors.danger, badgeCode: 'MD',
    leftTag: 'BASIN', dialogueId: 'media_01',
    scene: DialogueScene.pressRoom,
    portraitAsset: 'assets/images/portraits/media.png',
    cardPortraitAsset: 'assets/images/portraits/cards/media.png',
  ),
  // `dialogueId` bilinçli olarak boş: catalog/dialogue.py'de 'fans' için bir
  // diyalog ağacı yok, `_openDialog` bunu `_dialogueTreeByRelationshipId`'de
  // bulamayınca sessizce no-op olur (bkz. `relationships_screen.dart`).
  'fans': RelationshipPresentation(
    icon: Icons.groups_2_outlined, tint: AppColors.warning, badgeCode: 'TF',
    leftTag: 'TARAFTAR', dialogueId: '',
    scene: DialogueScene.stadium,
    portraitAsset: 'assets/images/portraits/fans.png',
    cardPortraitAsset: 'assets/images/portraits/cards/fans.png',
  ),
  'partner': RelationshipPresentation(
    icon: Icons.favorite_border, tint: kPartnerPurple, badgeCode: 'PA',
    leftTag: 'ÖZEL', dialogueId: 'partner_01',
    scene: DialogueScene.home,
    portraitAsset: 'assets/images/portraits/partner.png',
    cardPortraitAsset: 'assets/images/portraits/cards/partner.png',
  ),
  'family': RelationshipPresentation(
    icon: Icons.home_outlined, tint: AppColors.warning, badgeCode: 'AS',
    leftTag: 'ÖZEL', dialogueId: 'family_01',
    scene: DialogueScene.home,
    portraitAsset: 'assets/images/portraits/family.png',
    cardPortraitAsset: 'assets/images/portraits/cards/family.png',
  ),
};

const kDefaultRelationshipPresentation = RelationshipPresentation(
  icon: Icons.person_outline, tint: AppColors.textMuted, badgeCode: '??',
  leftTag: '', dialogueId: '', scene: DialogueScene.trainingGround,
);

RelationshipPresentation presentationForRelationship(String relationshipId) =>
    _presentationByRelationshipId[relationshipId] ??
    kDefaultRelationshipPresentation;

/// §4.1 · Mekânsal bağımlılık — bir sosyal teklif şablonu, ilişkinin
/// varsayılan sahnesinden FARKLI bir yerde geçiyorsa burada eziliyor.
/// Yalnızca gerçek anlamda farklı ve daha uygun olan üç şablon eşlendi
/// ("fazladan idman" soyunma odasında değil sahada geçer, "takım yemeği" ve
/// "akşam planı" antrenman sahasında/evde değil bir kafede) — geri kalanı
/// zaten ilişkisinin varsayılanına uyuyor. `cafe` sahnesi bugüne kadar
/// hiçbir ilişkiye bağlı değildi; ilk gerçek kullanımı burada.
const _sceneByTemplateId = {
  'coach_extra_session': DialogueScene.trainingGround,
  'team_dinner': DialogueScene.cafe,
  'partner_evening_out': DialogueScene.cafe,
};

/// Bir konuşmanın arka planı: önce şablonun kendine özgü bir sahnesi var mı
/// bakılır, yoksa ilişkinin varsayılanına düşülür — dosyanın kendi eski
/// notunun ("sahne ilişki türünden ya da sosyal olayın şablonundan seçilir")
/// artık gerçekten uyguladığı hâli.
DialogueScene sceneFor({required String relationshipId, String? templateId}) {
  final override = templateId == null ? null : _sceneByTemplateId[templateId];
  return override ?? presentationForRelationship(relationshipId).scene;
}
