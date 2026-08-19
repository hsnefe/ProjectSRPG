-- CONTRACT.md §3.4 - relationship, relationship_event.
-- D23: traits is a JSON column, not five separate tables — each kind is
-- validated in code (domain layer), not by the schema.
-- D24: score is stored directly; relationship_event is the audit trail,
-- not the source of truth. Both are written only via relationships.apply_delta().

CREATE TABLE relationship (
  career_id       TEXT NOT NULL,
  relationship_id TEXT NOT NULL,           -- 'coach','team','media','partner','family'
  kind            TEXT NOT NULL,           -- traits'i hangi modelin doğrulayacağı
  category        TEXT NOT NULL,           -- FE'nin kart başlığı: 'Antrenör' vb.
  score           INTEGER NOT NULL,        -- 0-100, SAKLANIR (D24)
  person_name     TEXT NOT NULL,
  contact_name    TEXT NOT NULL,
  age             INTEGER,
  occupation      TEXT,
  bio             TEXT,
  last_contact_at TEXT,
  traits          TEXT NOT NULL DEFAULT '{}',
  PRIMARY KEY (career_id, relationship_id)
);

-- Surrogate key, not (career_id, relationship_id, happened_at, reason):
-- two interactions with the same relationship, same day, same dialogue
-- leaf (a player replaying a conversation, or a decay tick landing on a
-- day that already had one) would collide on that composite otherwise —
-- caught by a test hitting the same dialogue outcome twice in one day.
-- money_ledger already used this pattern for the identical reason.
CREATE TABLE relationship_event (
  event_id        INTEGER PRIMARY KEY AUTOINCREMENT,
  career_id       TEXT NOT NULL,
  relationship_id TEXT NOT NULL,
  happened_at     TEXT NOT NULL,
  delta           INTEGER NOT NULL,
  reason          TEXT NOT NULL            -- 'dialogue:coach_01:choice_2', 'decay' ...
);

CREATE INDEX idx_relationship_event_lookup
  ON relationship_event (career_id, relationship_id, happened_at);
