-- Çakışan sosyal planlar (§12.9, D59).
--
-- Aynı akşama iki davet düşebiliyor ve oyuncu ikisinde birden olamıyor. Bu
-- tablo o ikilemin kendisini saklıyor: hangi iki satır yarışıyor, hangisi
-- seçildi.
--
-- **Neden tek tablo ve bir `source` kolonu.** Çakışma iki kaynaktan doğuyor:
-- aynı güne düşen iki `social_plan` (söz verilmişti, kırılan tarafın cezası
-- ağır) ya da aynı gün açılan iki `social_offer` (kimseye söz verilmedi,
-- kayıp küçük). İkisi de "iki taraf, bir seçim" — ayrı iki tablo aynı üç
-- sorguyu ve aynı ucu iki kez yazdırırdı. Fark yalnızca `left_ref`/`right_ref`
-- hangi tabloyu gösterdiği ve cezanın büyüklüğü; ikisi de `source`'tan okunuyor.
--
-- **Neden refs'lerde FK yok.** `left_ref`/`right_ref` `source`'a göre iki
-- farklı tabloyu gösteriyor; SQLite'ta koşullu FK diye bir şey yok. Aynı
-- gerekçe `social_plan.offer_id` ve `sponsorship_obligation.deal_id` için de
-- yazılmıştı: silinme zaten `career_id` cascade'iyle geliyor.
--
-- Şablon metni burada da yok — 009/011/012'nin kalıbı: getiri ve maliyet
-- content/social_offers.py'de yazarlanmış veridir, taraf satırları zaten
-- `template_id` taşıyor, buraya kopyalamak ikinci bir doğruluk kaynağı olurdu.
CREATE TABLE social_conflict (
  career_id   TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  conflict_id TEXT NOT NULL,          -- 'scf_' + 12 hex
  source      TEXT NOT NULL,          -- 'plan' | 'offer'
  due_on      TEXT NOT NULL,          -- 'YYYY-MM-DD'
  left_ref    TEXT NOT NULL,          -- social_plan.plan_id | social_offer.offer_id
  right_ref   TEXT NOT NULL,          -- aynı tablo, farklı ilişki
  status      TEXT NOT NULL,          -- 'open' | 'resolved'
  chosen_ref  TEXT,                   -- çözülünce seçilen taraf; açıkken NULL
  PRIMARY KEY (career_id, conflict_id)
);

-- `conflict_for_today` ve advance kapısının tek sorgusu:
-- WHERE career_id = ? AND status = 'open'.
CREATE INDEX idx_social_conflict_open ON social_conflict (career_id, status, due_on);
