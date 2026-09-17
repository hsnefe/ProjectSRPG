-- Aktivite olayları (§13.4, D75, D76).
--
-- Bir yaşam aktivitesi artık bir olay doğurabiliyor: kafede biri seni
-- tanıyor, konserde bir fotoğraf çekiliyor. Olay bir paragraf ve N
-- seçenek; metni content/activity_events.py'de yazarlanmış (D75, R4'ün
-- kalıbı), seçilen dal burada saklanıyor.
--
-- **Neden tablo gerekiyor.** Olay T2'nin yanıtıyla doğuyor ama o yanıtta
-- yaşayamaz: kullanıcı uygulamayı kapatıp açabilir ve seçim sunucuda
-- doğrulanmak zorunda (ödül tablosu BE'de kalır). 009'un `social_offer`
-- tablosuyla aynı gerekçe.
--
-- **Neden `expired` diye bir durum var.** 009'un kendi yorumu "cevap zorunlu
-- olduğu için expiry yok" diyordu. Burada tersi geçerli (D76): açık bir olay
-- `advance`'ı kilitlemiyor, o yüzden cevapsız kalabiliyor ve cevapsız kalan
-- olayın gideceği bir yer lazım. `expired` hiçbir etki yazmaz (INV-63).
--
-- Şablon metni burada yok — 009/011/012/013'ün kalıbı: başlık, gövde ve
-- seçenekler `template_id`'nin arkasında yazarlanmış veridir, buraya
-- kopyalamak ikinci bir doğruluk kaynağı olurdu.
CREATE TABLE activity_event (
  career_id     TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  event_id      TEXT NOT NULL,          -- 'ae_' + 12 hex
  template_id   TEXT NOT NULL,
  catalog_id    TEXT NOT NULL,          -- olayı doğuran aktivite
  opened_on     TEXT NOT NULL,          -- 'YYYY-MM-DD'
  status        TEXT NOT NULL,          -- 'open' | 'resolved' | 'expired'
  chosen_option TEXT,                   -- çözülünce seçilen option_id; açıkken NULL
  resolved_on   TEXT,
  PRIMARY KEY (career_id, event_id)
);

-- INV-62'nin tek sorgusu (açık olay var mı) ve T5'in listesi:
-- WHERE career_id = ? AND status = 'open'.
CREATE INDEX idx_activity_event_open ON activity_event (career_id, status, opened_on);
