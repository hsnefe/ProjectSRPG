-- CONTRACT.md §3.5 - news, activity_log, inventory, money_ledger.
-- D25: money_ledger is the single home for every money movement; wage,
-- bonuses, purchases, upkeep, sales all flow through wallet.apply().

CREATE TABLE news (
  career_id    TEXT NOT NULL,
  news_id      TEXT NOT NULL,
  published_at TEXT NOT NULL,
  category     TEXT NOT NULL,              -- 'Transfer','Maç','Röportaj','Analiz'
  title        TEXT NOT NULL,
  source       TEXT NOT NULL,
  body         TEXT NOT NULL,              -- \n\n ile ayrılmış paragraflar
  fixture_id   TEXT,                       -- maç haberiyse ilişkili fikstür
  PRIMARY KEY (career_id, news_id)
);

CREATE INDEX idx_news_career_date ON news (career_id, published_at);

-- D41: costs/effects are what was actually spent/applied, distinct from the
-- catalog's nominal values (a catalog price can change later; this row
-- can't). No money_delta column — money movement lives only in money_ledger.
-- Surrogate key, same reasoning as relationship_event/fame_event/
-- money_ledger: doing the same catalog_id twice on the same day (nothing
-- stops that — day_budget just tracks remaining pool) would collide on
-- (career_id, happened_at, catalog_id) otherwise.
CREATE TABLE activity_log (
  activity_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  career_id       TEXT NOT NULL,
  happened_at     TEXT NOT NULL,
  kind            TEXT NOT NULL,           -- 'training' | 'lifestyle' | 'relationship' | 'purchase'
  catalog_id      TEXT NOT NULL,
  applied_costs   TEXT NOT NULL,           -- JSON
  applied_effects TEXT NOT NULL,           -- JSON
  payload         TEXT                     -- JSON: minigame skoru gibi girdi verisi
);

CREATE INDEX idx_activity_log_lookup ON activity_log (career_id, happened_at);

-- D27: upkeep_weekly is copied from the catalog at purchase time and frozen,
-- same reasoning as price_paid — a later catalog change can't retroactively
-- alter what an owned item costs to keep.
CREATE TABLE inventory (
  career_id     TEXT NOT NULL,
  item_id       TEXT NOT NULL,
  purchased_at  TEXT NOT NULL,
  price_paid    INTEGER NOT NULL,
  upkeep_weekly INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, item_id)
);

-- D25: the single ledger every money movement passes through. Written only
-- via wallet.apply() (INV-17), which also stamps balance_after (INV-19).
CREATE TABLE money_ledger (
  career_id     TEXT NOT NULL,
  ledger_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  happened_at   TEXT NOT NULL,
  amount        INTEGER NOT NULL,          -- + gelir, − gider
  kind          TEXT NOT NULL,             -- LEDGER_KINDS, api/config.py
  reason        TEXT NOT NULL,
  balance_after INTEGER NOT NULL
);

CREATE INDEX idx_ledger_career_date ON money_ledger (career_id, happened_at);
