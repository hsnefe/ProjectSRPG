-- İlişki kapsamı ve partner ömrü (§13.1/§13.2, D68, D71).
--
-- **Neden kimlik değil kolon (D68).** Kulüp bilgisini `relationship_id`'ye
-- gömmek (`coach@t_ykz`) FE'de beş ayrı sabit tabloyu birden düşürürdü:
-- character_portrait.dart yüzü id'yi hash'leyerek türetiyor,
-- relationship_presentation.dart rozet/sahne/diyalog kimliğini id'den
-- okuyor, relationships_screen.dart ağaçları id'ye göre anahtarlıyor,
-- request_screen.dart maç sonrası çubuk sırasını id listesiyle yazıyor,
-- social_offer_screen.dart kapanış cümlesini id'den seçiyor. Kimlik FE'de
-- bir SUNUM anahtarı; kapsam ise bir veri sorusu ve veri sorusu kolona yazılır.
--
-- `team_id`'de FK yok: 013'ün `left_ref`/`right_ref`'i ve 012'nin
-- `social_plan.offer_id`'si ile aynı gerekçe değil — burada gerçek sebep
-- `scope='career'` satırlarda kolonun NULL olması ve silinmenin zaten
-- `career_id` cascade'iyle gelmesi.
ALTER TABLE relationship ADD COLUMN scope   TEXT NOT NULL DEFAULT 'career';  -- 'career' | 'club'
ALTER TABLE relationship ADD COLUMN team_id TEXT;                            -- scope='club' iken dolu

-- §13.2/D71 - partner dışındaki her ilişki 'active' doğar ve öyle kalır
-- (INV-59). Varsayılanın 'active' olması mevcut kariyerleri olduğu gibi
-- bırakıyor; partner satırı aşağıda ayrıca düzeltiliyor.
ALTER TABLE relationship ADD COLUMN state TEXT NOT NULL DEFAULT 'active';    -- 'absent'|'courting'|'active'

-- Mevcut kariyerlerin geri doldurulması. Yeni kariyerler bu değerleri
-- onboarding'den alıyor (domain/onboarding.py::_seed_relationships), ama
-- 016'ya kadar oynanmış bir career.db bu üç satırı kendisi bilmiyor.
UPDATE relationship
   SET scope = 'club',
       team_id = (SELECT p.team_id FROM player p
                   WHERE p.career_id = relationship.career_id AND p.is_user = 1)
 WHERE relationship_id IN ('coach', 'team', 'fans');

-- §13.2 - hiç tanışılmamış bir partner. Skoru 0 olan partner satırı
-- "ilişki henüz kurulmadı" demektir; bugüne kadar oynanmış ve skoru
-- yükselmiş bir partner ilişkisi ise kurulmuş sayılır ve 'active' kalır.
-- Bu, geriye dönük en az sürprizli okuma: kimsenin elindeki ilişki bir
-- migration yüzünden kaybolmuyor.
UPDATE relationship SET state = 'absent' WHERE relationship_id = 'partner' AND score = 0;

-- R1 açık ilişkileri kapsam sormadan listeliyor; transfer sıfırlaması ise
-- yalnızca kulüp kapsamlılara bakıyor. İkisi de bu indeksten geçiyor.
CREATE INDEX idx_relationship_scope ON relationship (career_id, scope);
