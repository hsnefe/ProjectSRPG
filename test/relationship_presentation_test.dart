import 'package:flutter_test/flutter_test.dart';

import 'package:project_srpg/widgets/dialogue_backdrop.dart';
import 'package:project_srpg/widgets/relationship_presentation.dart';

void main() {
  group('sceneFor (§4.1 mekânsal bağımlılık)', () {
    test('eşlenen bir şablon, ilişkinin varsayılanını ezer', () {
      // coach'ın varsayılanı lockerRoom, ama 'fazladan idman' sahada geçer.
      expect(
        sceneFor(relationshipId: 'coach', templateId: 'coach_extra_session'),
        DialogueScene.trainingGround,
      );
      // team'in varsayılanı trainingGround, ama 'takım yemeği' kafede geçer.
      expect(
        sceneFor(relationshipId: 'team', templateId: 'team_dinner'),
        DialogueScene.cafe,
      );
      // partner'ın varsayılanı home, ama 'akşam planı' bir restoranda geçer.
      expect(
        sceneFor(relationshipId: 'partner', templateId: 'partner_evening_out'),
        DialogueScene.restaurant,
      );
    });

    test('eşlenmeyen bir şablon ilişkinin varsayılanına düşer', () {
      expect(
        sceneFor(relationshipId: 'coach', templateId: 'coach_video_review'),
        presentationForRelationship('coach').scene,
      );
      expect(
        sceneFor(relationshipId: 'media', templateId: 'media_interview_request'),
        presentationForRelationship('media').scene,
      );
    });

    test('templateId null ise ilişkinin varsayılanına düşer', () {
      expect(
        sceneFor(relationshipId: 'family'),
        presentationForRelationship('family').scene,
      );
    });

    test('bilinmeyen bir ilişki id\'si varsayılan sunuma düşer', () {
      expect(
        sceneFor(relationshipId: 'does-not-exist'),
        kDefaultRelationshipPresentation.scene,
      );
    });
  });

  group('portraitAsset (§1.2)', () {
    test('altı ilişkinin de kendi portre dosyası var', () {
      for (final id in ['coach', 'team', 'media', 'fans', 'partner', 'family']) {
        expect(
          presentationForRelationship(id).portraitAsset,
          'assets/images/portraits/$id.png',
          reason: id,
        );
      }
    });

    test('bilinmeyen bir ilişkinin hâlâ portresi yok', () {
      expect(kDefaultRelationshipPresentation.portraitAsset, isNull);
    });

    // Kart neredeyse kare (215x300), diyalog şeridi geniş bir bant — aynı
    // görsel ikisine de uymuyor: diyalog için üstte pay bırakılan görsel,
    // kartta kişiyi küçültüp boşluk bırakırdı. Bu yüzden kartın kendi,
    // boşluksuz kırpımı var.
    test('altı ilişkinin de ayrı, boşluksuz bir kart portresi var', () {
      for (final id in ['coach', 'team', 'media', 'fans', 'partner', 'family']) {
        expect(
          presentationForRelationship(id).cardPortraitAsset,
          'assets/images/portraits/cards/$id.png',
          reason: id,
        );
      }
    });
  });
}
