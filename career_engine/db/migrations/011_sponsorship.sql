-- §12.7 Sponsorluk anlaşmaları.
--
-- Sözleşmede (§11 dahil) hiç geçmiyor: 3000 satırlık belgede "sponsor"
-- kelimesi yalnızca §10'un şöhret tartışmasında, şöhretin *olası bir
-- tüketicisi* olarak anılıyor. Bu tablolar §12.7 ile geliyor.
--
-- Yapı sosyal tekliflerin (009) kanıtlanmış deseni: satırda yalnızca
-- `template_id` durur, getiriler ve yükümlülük ritmi content/sponsorships.py'de
-- yazarlanmış veridir. Kopyalamak onu ikinci bir doğruluk kaynağı yapardı.
--
-- `weekly_income` bunun istisnası ve bilerek saklanıyor: bir anlaşma
-- imzalandığı andaki rakamla yürür. Şablonu sonradan düzenlemek uçuştaki bir
-- anlaşmanın maaşını değiştirmemeli — inventory'nin `price_paid`'i donduruyor
-- olmasıyla aynı gerekçe (005).
CREATE TABLE sponsorship_deal (
  career_id     TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  deal_id       TEXT NOT NULL,          -- 'sp_' + 12 hex
  template_id   TEXT NOT NULL,          -- content/sponsorships.py
  status        TEXT NOT NULL,          -- 'offered' | 'active' | 'declined' | 'ended' | 'broken'
  offered_on    TEXT NOT NULL,
  signed_on     TEXT,                   -- imzalanana kadar NULL
  expires_on    TEXT,                   -- imzalanana kadar NULL
  weekly_income INTEGER NOT NULL,       -- ₭, imza anında dondurulur
  PRIMARY KEY (career_id, deal_id)
);

-- Zorunlu etkinlikler. Açık (pending) bir yükümlülük `POST /advance`'ı
-- kapıda reddeder — sosyal tekliflerin D53 kilidiyle aynı okuma: bir şeye
-- söz verdiysen o gün onu yaşarsın, ertelemek bir seçenek değil.
--
-- Neden `due_on` var ama sosyal teklifte yoktu: sponsorluk etkinliği imza
-- anında takvime yazılıyor, o yüzden "hangi gün" bilinen bir veri. Sosyal
-- teklif geldiği gün cevaplanıyordu (D54), bu ileriye dönük bir randevu.
CREATE TABLE sponsorship_obligation (
  career_id     TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  obligation_id TEXT NOT NULL,          -- 'so' değil: 'ob_' + 12 hex
  deal_id       TEXT NOT NULL,
  due_on        TEXT NOT NULL,
  status        TEXT NOT NULL,          -- 'pending' | 'done' | 'missed'
  PRIMARY KEY (career_id, obligation_id)
);

CREATE INDEX idx_sponsorship_deal_status ON sponsorship_deal (career_id, status);
CREATE INDEX idx_sponsorship_obligation_due
  ON sponsorship_obligation (career_id, status, due_on);
