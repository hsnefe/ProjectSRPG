-- Sosyal planlar (§12.8, D58).
--
-- 009_social_offers.sql'in `social_offer`'ı neden `due_on` taşımadığını
-- anlattığı gerekçenin tam tersi burada geçerli: `plan_days_ahead` alanı
-- olan bir şablon kabul edildiğinde artık aynı gün cevaplanıp bitmiyor,
-- ileriye dönük bir randevu oluyor (011_sponsorship.sql'in
-- `sponsorship_obligation`'ı için yazdığı gerekçenin aynısı). Şablon burada
-- da yalnızca `template_id` olarak duruyor — 009 ve 011'in kalıbı: getiri ve
-- maliyet content/social_offers.py'de yazarlanmış veridir, satıra
-- kopyalanması ikinci bir doğruluk kaynağı yaratırdı.
--
-- `offer_id` bilgi amaçlı: plan hangi kabulden doğduğunu izlemeyi sağlar,
-- ama sorguların hiçbiri ona muhtaç değil (bu yüzden FK yok, tıpkı
-- sponsorship_obligation'ın deal_id'sinde olduğu gibi).
CREATE TABLE social_plan (
  career_id       TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  plan_id         TEXT NOT NULL,          -- 'spl_' + 12 hex
  offer_id        TEXT NOT NULL,          -- doğduğu social_offer.offer_id
  template_id     TEXT NOT NULL,          -- content/social_offers.py
  relationship_id TEXT NOT NULL,          -- §3.4'ün altı sabit satırından biri
  due_on          TEXT NOT NULL,          -- 'YYYY-MM-DD'
  status          TEXT NOT NULL,          -- 'pending' | 'done' | 'missed'
  PRIMARY KEY (career_id, plan_id)
);

CREATE INDEX idx_social_plan_due ON social_plan (career_id, status, due_on);
