-- §5.1 C1 - what "Yeni Kariyer" now collects, plus where the skill exams
-- record themselves.
--
-- The player columns arrive as ALTER TABLE rather than a rewritten 002 so an
-- existing career.db keeps its rows; all five are nullable for the same
-- reason (careers created before this migration have no first_name/role to
-- backfill from). create_career() always writes them, so "NULL role" only
-- ever means "career predates the role system".
--
-- name stays as-is and keeps holding the full display name: every existing
-- query (careers.list_careers, _build_hub, serializers) selects p.name, and
-- splitting it would be a rewrite of all of them for no gain (req 11).

ALTER TABLE player ADD COLUMN first_name TEXT;
ALTER TABLE player ADD COLUMN last_name TEXT;
ALTER TABLE player ADD COLUMN nationality TEXT;     -- worlddata/countries.py country_code
ALTER TABLE player ADD COLUMN role TEXT;            -- worlddata/positions.py role_id
ALTER TABLE player ADD COLUMN target_team_id TEXT;  -- hedeflenen kulüp, oynanan takımdan bağımsız

-- §2 - one row per exam the player has sat, so a career can't re-sit an exam
-- and re-collect its points. PK is (career_id, player_id, exam_id): the guard
-- is the primary key itself, not an application-level check.
--
-- level is stored raw (1-5) rather than the points it awarded: the award is
-- catalog/skill_exams.py's business and re-tuning points_per_level shouldn't
-- make the stored history unreadable.
CREATE TABLE skill_exam_result (
  career_id  TEXT NOT NULL,
  player_id  TEXT NOT NULL,
  exam_id    TEXT NOT NULL,            -- catalog/skill_exams.py EXAM_IDS
  level      INTEGER NOT NULL,         -- MIN_LEVEL..MAX_LEVEL
  applied_at TEXT NOT NULL,
  PRIMARY KEY (career_id, player_id, exam_id),
  FOREIGN KEY (career_id, player_id) REFERENCES player(career_id, player_id) ON DELETE CASCADE
);
