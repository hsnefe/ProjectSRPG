-- CONTRACT.md §14.4 (D87-D90, D95, INV-67, INV-69): where the player lives.
--
-- `residence` holds what the career holds: the free starting homes it has moved
-- through, leases, a hotel stay, and owned property. `monthly_rent` and
-- `daily_fee` are frozen at move-in (the same reasoning as inventory.upkeep_weekly:
-- a re-priced catalog row never changes a lease already signed).
--
-- The partial unique index IS INV-67 - the database refuses a second active
-- home, so a bug in domain/housing.py cannot produce one.
CREATE TABLE residence (
  career_id     TEXT    NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  residence_id  TEXT    NOT NULL,                 -- catalog/housing.py
  tenure        TEXT    NOT NULL CHECK (tenure IN ('start', 'rented', 'hotel', 'owned')),
  acquired_on   TEXT    NOT NULL,
  price_paid    INTEGER NOT NULL DEFAULT 0,
  monthly_rent  INTEGER NOT NULL DEFAULT 0,
  daily_fee     INTEGER NOT NULL DEFAULT 0,
  expires_on    TEXT,                             -- hotel only
  active        INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0, 1)),
  PRIMARY KEY (career_id, residence_id)
);

CREATE UNIQUE INDEX idx_residence_one_active
  ON residence (career_id)
  WHERE active = 1;

CREATE TABLE residence_upgrade (
  career_id     TEXT    NOT NULL,
  residence_id  TEXT    NOT NULL,
  upgrade_id    TEXT    NOT NULL,                 -- catalog/housing.py
  installed_on  TEXT    NOT NULL,
  price_paid    INTEGER NOT NULL DEFAULT 0,
  monthly_fee   INTEGER NOT NULL DEFAULT 0,       -- the private chef
  PRIMARY KEY (career_id, residence_id, upgrade_id),
  FOREIGN KEY (career_id, residence_id) REFERENCES residence(career_id, residence_id)
    ON DELETE CASCADE
);

-- Every career that already exists wakes up in the academy dorm, the same home a
-- new one opens in. (No ledger row is involved, so this is safe as plain SQL.)
INSERT INTO residence (career_id, residence_id, tenure, acquired_on, active)
SELECT career_id, 'res-dorm', 'start', game_date, 1 FROM career_state;
