-- CONTRACT.md §3.1 - career, career_state, day_budget.

CREATE TABLE career (
  career_id      TEXT PRIMARY KEY,          -- 'car_' + 12 hex
  created_at     TEXT NOT NULL,
  seed           INTEGER NOT NULL,          -- D9: fikstür ve başlangıç formu bundan türer
  schema_version INTEGER NOT NULL
);

CREATE TABLE career_state (
  career_id     TEXT PRIMARY KEY REFERENCES career(career_id) ON DELETE CASCADE,
  current_date  TEXT NOT NULL,             -- D5: dünyanın "bugün"ü
  season_id     TEXT NOT NULL,
  money         INTEGER NOT NULL,          -- ₺, tam sayı
  condition     INTEGER NOT NULL           -- 0-100, D15/D38
);

-- D41: günün bütçesi. Kaynaklar ⟦AÇIK-5⟧'te belirlenecek ('time', 'energy', …)
CREATE TABLE day_budget (
  career_id    TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  resource_key TEXT NOT NULL,
  remaining    REAL NOT NULL,
  PRIMARY KEY (career_id, resource_key)
);
