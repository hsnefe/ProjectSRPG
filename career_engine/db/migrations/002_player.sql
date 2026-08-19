-- CONTRACT.md §3.2 - player, player_attribute, player_fame, fame_event,
-- player_value_history, player_season_stat, player_contract.

CREATE TABLE player (
  career_id   TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  player_id   TEXT NOT NULL,
  name        TEXT NOT NULL,
  position    TEXT NOT NULL,
  birth_date  TEXT NOT NULL,               -- yaş türetilir, sabit tutulmaz
  team_id     TEXT NOT NULL,
  is_user     INTEGER NOT NULL DEFAULT 0,  -- v1'de tam olarak 1 satır 1
  PRIMARY KEY (career_id, player_id)
);

-- D30: sabit 11 anahtar (ATTRIBUTE_KEYS, api/config.py). family veritabanında
-- saklanmaz (INV-21) — kod kataloğundan okunur.
CREATE TABLE player_attribute (
  career_id     TEXT NOT NULL,
  player_id     TEXT NOT NULL,
  attribute_key TEXT NOT NULL,
  value         REAL NOT NULL,             -- 0-100
  PRIMARY KEY (career_id, player_id, attribute_key),
  FOREIGN KEY (career_id, player_id) REFERENCES player(career_id, player_id) ON DELETE CASCADE
);

-- D35: şöhret. Anlamı ⟦AÇIK-9⟧'da; depolama bugünden hazır. CONTRACT.md'nin
-- kendi §3.2 SQL'inde bu tablo için FK yok (player_attribute'un aksine) —
-- fame.apply() bir player satırından bağımsız çalışabilsin diye böyle kaldı.
CREATE TABLE player_fame (
  career_id TEXT NOT NULL,
  player_id TEXT NOT NULL,
  scope     TEXT NOT NULL,                -- v1'de yalnızca 'overall'
  value     REAL NOT NULL,
  PRIMARY KEY (career_id, player_id, scope)
);

CREATE TABLE fame_event (
  career_id   TEXT NOT NULL,
  player_id   TEXT NOT NULL,
  scope       TEXT NOT NULL,
  happened_at TEXT NOT NULL,
  delta       REAL NOT NULL,
  reason      TEXT NOT NULL,
  PRIMARY KEY (career_id, player_id, scope, happened_at, reason)
);

-- ⟦AÇIK-8⟧: güncel piyasa değeri türetilecek (compute_market_value()); bu
-- tablo yalnızca geçmiş eğrinin anlık görüntülerini tutar.
CREATE TABLE player_value_history (
  career_id   TEXT NOT NULL,
  player_id   TEXT NOT NULL,
  measured_on TEXT NOT NULL,
  value       INTEGER NOT NULL,            -- ₺
  PRIMARY KEY (career_id, player_id, measured_on)
);

-- D13: dayanağı olmayan kolon (assists, passes_*) daima 0 kalır (INV-11).
CREATE TABLE player_season_stat (
  career_id         TEXT NOT NULL,
  player_id         TEXT NOT NULL,
  season_id         TEXT NOT NULL,
  competition_id    TEXT NOT NULL,
  appearances       INTEGER NOT NULL DEFAULT 0,
  starts            INTEGER NOT NULL DEFAULT 0,
  goals             INTEGER NOT NULL DEFAULT 0,
  assists           INTEGER NOT NULL DEFAULT 0,
  minutes           INTEGER NOT NULL DEFAULT 0,
  passes_completed  INTEGER NOT NULL DEFAULT 0,
  passes_attempted  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, player_id, season_id, competition_id)
);

CREATE TABLE player_contract (
  career_id        TEXT NOT NULL,
  player_id        TEXT NOT NULL,
  team_id          TEXT NOT NULL,
  signed_at        TEXT NOT NULL,
  expires_at       TEXT NOT NULL,
  weekly_wage      INTEGER NOT NULL,       -- ⟦B-1⟧ v1 ölçeği tier 2'ye ayarlanacak
  appearance_bonus INTEGER NOT NULL,
  goal_bonus       INTEGER NOT NULL,
  release_clause   INTEGER NOT NULL,
  PRIMARY KEY (career_id, player_id, signed_at)
);
