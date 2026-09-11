-- §11.3 Sezon devri şeması.
--
-- Devre arası sezonun kendi verisidir, kod sabiti değil: season tablosu zaten
-- starts_on/ends_on'u türetmek yerine SAKLIYOR, tatil sınırı da aynı cinsten.
-- Eski kariyerlerin satırları NULL kalır ve "devre arası yok" diye okunur.
ALTER TABLE season ADD COLUMN winter_break_from TEXT;
ALTER TABLE season ADD COLUMN winter_break_to   TEXT;

-- Ligin kıta turnuvası kontenjanını belirleyen puan. kind='league' dışında NULL.
ALTER TABLE competition ADD COLUMN international_score INTEGER;   -- ⟦AÇIK-12⟧

-- Sezon sonu defteri. Nihai sıralama fixture'dan yeniden TÜRETİLEBİLİR (INV-2),
-- ama sonuçlar türetilemez: kontenjan sayısı ve terfi/düşme kuralı zamanla
-- değişebilir, geçmiş sezonun kararı ise değişmemelidir.
--
-- Dört bayrak, tek 'outcome' enum'u değil: 1. sıradaki takım aynı anda HEM
-- şampiyon HEM kıta katılımcısıdır; tek kolon ikisini taşıyamaz.
CREATE TABLE season_result (
  career_id      TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  season_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  team_id        TEXT NOT NULL,
  final_rank     INTEGER NOT NULL,
  is_champion    INTEGER NOT NULL DEFAULT 0,
  continental    INTEGER NOT NULL DEFAULT 0,
  promoted       INTEGER NOT NULL DEFAULT 0,
  relegated      INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, season_id, competition_id, team_id)
);

-- Kullanıcıya açılan sözleşme teklifleri (§11.7). Kadro yoktur (D4 korunur) —
-- bu tablonun tek öznesi kullanıcının kendisidir.
--
-- `counter_used`: §12'nin eki. §11.7 yalnızca kabul/ret tanımlıyordu; mevcut
-- kulübün yenileme görüşmesi (P4) bir kez "daha iyisini iste" hakkı taşıyor ve
-- o hakkın harcanıp harcanmadığı tekliften başka tutulacak yer yok.
CREATE TABLE transfer_offer (
  career_id        TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  offer_id         TEXT NOT NULL,            -- 'o_' + 12 hex
  opened_on        TEXT NOT NULL,
  window           TEXT NOT NULL,            -- 'winter' | 'summer'
  team_id          TEXT NOT NULL,
  weekly_wage      INTEGER NOT NULL,
  appearance_bonus INTEGER NOT NULL,
  goal_bonus       INTEGER NOT NULL,
  release_clause   INTEGER NOT NULL,
  length_seasons   INTEGER NOT NULL,
  expires_at       TEXT NOT NULL,            -- kabul edilirse sözleşmenin bitişi
  status           TEXT NOT NULL,            -- 'open' | 'accepted' | 'expired'
  is_renewal       INTEGER NOT NULL DEFAULT 0,
  counter_used     INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, offer_id)
);

CREATE INDEX idx_transfer_offer_open ON transfer_offer (career_id, status);
