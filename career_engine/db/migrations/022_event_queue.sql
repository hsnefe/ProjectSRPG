-- CONTRACT.md §14.5-§14.6 (D91-D94, INV-68, INV-70): triggers, the event queue,
-- and consequences that come due later.
--
-- `event_candidate` is the queue. A trigger (a birthday, a red card, a bad week)
-- never opens an event itself - it writes a candidate, and domain/triggers.py's
-- promote() is the only thing that turns one into an `activity_event` (and so the
-- only thing that has to respect INV-62's "one open at a time"). `dedupe_key` is
-- what makes a trigger safe to fire twice: the same birthday, the same fixture,
-- the same season's roll queues once (INV-70).
--
-- `deferred_consequence` is D94's one mechanism for "it comes out weeks later":
-- a choice writes the effects and, optionally, a follow-up event, and the day
-- loop applies the row exactly once when it falls due (INV-68). Effects and news
-- are JSON because they are an authored map in the template's own effect key
-- space (§5.7), not columns.
CREATE TABLE event_candidate (
  career_id     TEXT    NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  candidate_id  TEXT    NOT NULL,                 -- 'ec_' + 12 hex
  template_id   TEXT    NOT NULL,                 -- content/relationship_events.py
  trigger_kind  TEXT    NOT NULL,                 -- date | daily | post_match | activity | deferred
  priority      INTEGER NOT NULL,
  dedupe_key    TEXT    NOT NULL,
  created_on    TEXT    NOT NULL,
  expires_on    TEXT,                             -- NULL = waits until something opens it
  status        TEXT    NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'opened', 'expired')),
  PRIMARY KEY (career_id, candidate_id),
  UNIQUE (career_id, dedupe_key)
);

CREATE INDEX idx_event_candidate_queue ON event_candidate (career_id, status, priority);

CREATE TABLE deferred_consequence (
  career_id         TEXT    NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  consequence_id    TEXT    NOT NULL,             -- 'dc_' + 12 hex
  due_on            TEXT    NOT NULL,
  effects           TEXT    NOT NULL,             -- JSON, §5.7 effect keys
  source            TEXT    NOT NULL,             -- 'template_id:option_id', for the audit trail
  news              TEXT,                         -- JSON {category, title, body} or NULL
  followup_template TEXT,                         -- a template to queue when it falls due
  status            TEXT    NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'applied')),
  applied_on        TEXT,
  PRIMARY KEY (career_id, consequence_id)
);

CREATE INDEX idx_deferred_due ON deferred_consequence (career_id, status, due_on);
