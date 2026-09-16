-- Taktiksel antrenman yeterliliği (§12.11, D63).
--
-- `player_attribute` ile aynı şekil (career_id, player_id, anahtar, 0-100
-- değer) ama AYRI bir tablo: o tablonun anahtar kümesi INV-21'in kapalı
-- 12'li kümesi, level()/requires ikilisine bağlı (D30). Taktik yeterliliğinin
-- ne bir seviye ölçeği ne de (şimdilik, ⟦AÇIK⟧) bir requires tüketicisi var —
-- oraya eklemek ya INV-21'i 15'e genişletip üç ölü hücre bırakırdı ya da aynı
-- satırlardan ikinci bir invariant çıkarmayı gerektirirdi.
--
-- `player_attribute`'un aksine satırlar kariyer kuruluşunda tohumlanmıyor:
-- `domain/tactics.py::apply_delta` bir upsert, ilk antrenman satırı kendi
-- yaratıyor; P1 hiç yazılmamış bir anahtarı zaten 0.0 olarak okuyor.
CREATE TABLE player_tactics (
  career_id  TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  player_id  TEXT NOT NULL,
  tactic_key TEXT NOT NULL,          -- config.TACTIC_KEYS'ten biri
  value      REAL NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, player_id, tactic_key)
);
