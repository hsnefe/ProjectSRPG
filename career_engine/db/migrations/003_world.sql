-- CONTRACT.md §3.3 - team, competition (+ entry, rule), season,
-- competition_round, fixture, fixture_team_stat, and the standing VIEW.

CREATE TABLE team (
  career_id       TEXT NOT NULL,
  team_id         TEXT NOT NULL,
  name            TEXT NOT NULL,           -- ≤24 karakter (motorun sınırı)
  short_name      TEXT NOT NULL,
  country         TEXT NOT NULL,           -- paralel ligler için (D18)
  attack          REAL NOT NULL,           -- 0-100, motorun Team alanları
  midfield        REAL NOT NULL,
  defense         REAL NOT NULL,
  goalkeeper      REAL NOT NULL,
  mentality       TEXT NOT NULL,
  color_primary   TEXT NOT NULL,           -- '#1E6FD9' — kimlik rengi (D17)
  color_secondary TEXT NOT NULL,
  PRIMARY KEY (career_id, team_id)
);

-- D18: piramit + paralel + lig/kupa/uluslararası tek soyutlamada.
CREATE TABLE competition (
  career_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  kind           TEXT NOT NULL,            -- 'league' | 'cup' | 'continental'
  name           TEXT NOT NULL,
  country        TEXT,                     -- 'continental'de NULL
  tier           INTEGER,                  -- lig dışında NULL
  format         TEXT NOT NULL,            -- 'double_round_robin' | 'single_elimination'
                                            -- | 'group_then_knockout'
  team_count     INTEGER NOT NULL,
  PRIMARY KEY (career_id, competition_id)
);

-- Hangi takım hangi sezonda hangi müsabakada — düşme-çıkmanın yaşadığı yer.
CREATE TABLE competition_entry (
  career_id      TEXT NOT NULL,
  season_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  team_id        TEXT NOT NULL,
  PRIMARY KEY (career_id, season_id, competition_id, team_id)
);

-- Yalnızca kind='league' için dolu.
CREATE TABLE competition_rule (
  career_id                   TEXT NOT NULL,
  competition_id              TEXT NOT NULL,
  promote_count               INTEGER NOT NULL DEFAULT 0,
  relegate_count              INTEGER NOT NULL DEFAULT 0,
  promotes_to_competition_id  TEXT,        -- NULL = en üst kademe
  relegates_to_competition_id TEXT,        -- NULL = en alt kademe
  PRIMARY KEY (career_id, competition_id)
);

CREATE TABLE season (
  career_id  TEXT NOT NULL,
  season_id  TEXT NOT NULL,
  starts_on  TEXT NOT NULL,
  ends_on    TEXT NOT NULL,
  PRIMARY KEY (career_id, season_id)
);

-- Tur TAKVİMİ baştan bellidir; kupada EŞLEŞME sonradan çekilir (drawn 0→1).
CREATE TABLE competition_round (
  career_id      TEXT NOT NULL,
  season_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  round_no       INTEGER NOT NULL,
  stage          TEXT NOT NULL,            -- 'regular'|'group'|'r16'|'qf'|'sf'|'final'
  scheduled_on   TEXT NOT NULL,
  drawn          INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, season_id, competition_id, round_no)
);

CREATE TABLE fixture (
  career_id      TEXT NOT NULL,
  fixture_id     TEXT NOT NULL,
  season_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  round_no       INTEGER NOT NULL,
  leg            INTEGER,                  -- çift maçlı eleme (1|2); tek maçlıkta NULL
  kickoff_at     TEXT NOT NULL,
  home_team_id   TEXT NOT NULL,
  away_team_id   TEXT NOT NULL,
  status         TEXT NOT NULL,            -- 'scheduled' | 'in_progress' | 'played'
  home_score     INTEGER,
  away_score     INTEGER,
  match_id       TEXT,                     -- motorun ürettiği id, iz sürme için
  PRIMARY KEY (career_id, fixture_id)
);

CREATE INDEX idx_fixture_lookup
  ON fixture (career_id, competition_id, round_no, status);

-- Motorun _blank_stats() 13 anahtarıyla birebir aynı.
CREATE TABLE fixture_team_stat (
  career_id   TEXT NOT NULL,
  fixture_id  TEXT NOT NULL,
  side        TEXT NOT NULL,               -- 'home' | 'away'
  goals INTEGER, shots INTEGER, shots_on_target INTEGER, corners INTEGER,
  dangerous_attacks INTEGER, total_attacks INTEGER, yellow_cards INTEGER,
  red_cards INTEGER, penalties INTEGER, penalty_goals INTEGER, fouls INTEGER,
  substitutions INTEGER, possession_ticks INTEGER,
  PRIMARY KEY (career_id, fixture_id, side)
);

-- Puan durumu: tek doğruluk kaynağı fixture (INV-2). rank ve is_user_team
-- burada değil, API katmanında türetilir (§5.3 W2) — sıralama tabloya bağlı,
-- tek satırdan hesaplanamaz.
CREATE VIEW standing AS
WITH sides AS (
  SELECT career_id, season_id, competition_id, home_team_id AS team_id,
         home_score AS gf, away_score AS ga,
         CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS won,
         CASE WHEN home_score = away_score THEN 1 ELSE 0 END AS drawn,
         CASE WHEN home_score < away_score THEN 1 ELSE 0 END AS lost
  FROM fixture WHERE status = 'played'
  UNION ALL
  SELECT career_id, season_id, competition_id, away_team_id AS team_id,
         away_score AS gf, home_score AS ga,
         CASE WHEN away_score > home_score THEN 1 ELSE 0 END AS won,
         CASE WHEN away_score = home_score THEN 1 ELSE 0 END AS drawn,
         CASE WHEN away_score < home_score THEN 1 ELSE 0 END AS lost
  FROM fixture WHERE status = 'played'
)
SELECT career_id, season_id, competition_id, team_id,
       COUNT(*) AS played,
       SUM(won) AS won, SUM(drawn) AS drawn, SUM(lost) AS lost,
       SUM(gf) AS goals_for, SUM(ga) AS goals_against,
       SUM(won) * 3 + SUM(drawn) AS points
FROM sides
GROUP BY career_id, season_id, competition_id, team_id;
