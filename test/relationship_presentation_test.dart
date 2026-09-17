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
      // partner'ın varsayılanı home, ama 'akşam planı' kafede geçer.
      expect(
        sceneFor(relationshipId: 'partner', templateId: 'partner_evening_out'),
        DialogueScene.cafe,
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
    test('henüz hiçbir ilişkinin gerçek portresi yok', () {
      // Görsel geldikçe ilgili satır burada güncellenir — bu test o günün
      // farkını gösterecek, sessizce yanlış kalmayacak.
      for (final id in ['coach', 'team', 'media', 'fans', 'partner', 'family']) {
        expect(presentationForRelationship(id).portraitAsset, isNull,
            reason: id);
      }
    });
  });
}
