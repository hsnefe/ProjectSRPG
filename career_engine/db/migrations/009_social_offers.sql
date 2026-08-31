-- Sosyal teklifler (§5.4 R4-R6, §6.3).
--
-- Neden 009 ve neden 007/008 değil: CONTRACT.md §11.3 `007_season_rollover.sql`
-- adını sezon devrine ayırdı, `008_news_state.sql` de haber katmanının
-- dalında duruyor. İkisini de kapmamak için sıradaki boş isim 009. Migration
-- sırası yalnız dosya adına bakar (db/migrate.py), boşluklar sorun değil.
--
-- Neden `expires_on` YOK: teklife cevap zorunludur (D53) — açık bir teklif
-- `POST /advance`'ı durdurur, dolayısıyla teklif geldiği gün cevaplanır.
-- "Süresi doldu" hiçbir zaman ulaşılamayacak bir dal olurdu; ulaşılamayan
-- durum, test edilemeyen durumdur.
--
-- Neden yalnız `template_id` saklanıyor, delta'lar değil: catalog/dialogue.py
-- ile aynı gerekçe — ödül tablosu sunucu tarafında yazarlanmış veridir ve
-- satıra kopyalanması onu ikinci bir doğruluk kaynağı yapardı. Teklif bir gün
-- yaşadığı için içerik düzenlemesinin uçuştaki bir teklifi yeniden
-- fiyatlandırması pratikte imkânsız.
CREATE TABLE social_offer (
  career_id       TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  offer_id        TEXT NOT NULL,          -- 'so_' + 12 hex ('o_' transfer'a ayrılmış, §11.3)
  template_id     TEXT NOT NULL,          -- content/social_offers.py
  relationship_id TEXT NOT NULL,          -- §3.4'ün altı sabit satırından biri
  opened_on       TEXT NOT NULL,          -- 'YYYY-MM-DD'
  status          TEXT NOT NULL,          -- 'open' | 'accepted' | 'declined'
  resolved_on     TEXT,                   -- cevaplanana kadar NULL
  PRIMARY KEY (career_id, offer_id)
);

-- INV-39 (aynı anda en fazla bir açık teklif) her gün sorulur; soğuma ise
-- şablon başına en son ne zaman açıldığına bakar. İki erişim de bu indeksten.
CREATE INDEX idx_social_offer_open ON social_offer (career_id, status);
CREATE INDEX idx_social_offer_template ON social_offer (career_id, template_id, opened_on);
