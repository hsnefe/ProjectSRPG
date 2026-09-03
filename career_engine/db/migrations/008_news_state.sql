-- Haber katmanının durum tabloları (§3.5 eki).
--
-- Neden 008 ve neden 007 değil: CONTRACT.md §11.3 `007_season_rollover.sql`
-- adını sezon devrine ayırdı. O dosya henüz yazılmadı ama adı sözleşmede
-- geçiyor; haber katmanının onu kapması, ileride sezon devri yazıldığında
-- ya sözleşmeyi ya da dosya adını yalancı çıkarırdı. Migration sırası
-- yalnızca dosya adına bakar (db/migrate.py), 008 boşluğu sorun değil.
--
-- İki tablo da DENETİM İZİDİR; doğruluk kaynağı `news` tablosudur. Bir
-- satırın burada olup `news`'te olmaması (ya da tersi) bir hatadır, ama
-- okuma tarafı (N1/N2) hiçbir zaman buraya bakmaz — yalnızca üretim tarafı
-- (domain/news.py) bakar.

-- Soğuma kaynağı: bir arketip en son ne zaman yayımlandı? `news` tablosu bu
-- soruyu cevaplayamaz çünkü orada story_id kolonu yok ve olmamalı — `news`
-- FE'ye servis edilen içeriktir, arketip kimliği ise spoiler'dır (aynı
-- gerekçeyle content/ paketi catalog/ değil).
CREATE TABLE news_story_log (
  career_id    TEXT NOT NULL,
  story_id     TEXT NOT NULL,
  published_at TEXT NOT NULL,
  news_id      TEXT NOT NULL,
  PRIMARY KEY (career_id, story_id, published_at)
);

CREATE INDEX idx_news_story_log ON news_story_log (career_id, story_id);

-- Söylenti yayları: çok günlü hikâyeler durumunu burada tutar. `heat` bir
-- gün içinde bir kez güncellenir (day_tick) ve aşama ondan TÜRETİLİR —
-- stage kolonu türetilmiş değerin donmuş hâlidir, tek yazarı
-- domain/news.touch_arc(). D45'in "türetilmiş değer saklanmaz" kuralının
-- bilinçli istisnası: aşamanın geçmişi haberin kendisinde yaşıyor
-- ("teklif yapıldı" haberi çıktıysa geri alınamaz), bu yüzden aşama
-- yalnızca bugünün heat'inden değil, dünkü aşamadan da etkilenir.
CREATE TABLE news_arc (
  career_id  TEXT NOT NULL,
  arc_id     TEXT NOT NULL,            -- 'transfer:t_gal'
  stage      INTEGER NOT NULL DEFAULT 0,
  heat       REAL NOT NULL DEFAULT 0,  -- 0-100, söylentinin sıcaklığı
  opened_on  TEXT NOT NULL,
  updated_on TEXT NOT NULL,
  payload    TEXT,                     -- JSON
  PRIMARY KEY (career_id, arc_id)
);
