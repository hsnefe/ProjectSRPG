-- CONTRACT.md §14.2 (D80, INV-66): equippable gear.
--
-- `slot` and `grade` are copied from the catalog at purchase time and frozen,
-- the same reasoning as price_paid/upkeep_weekly: a later catalog edit must not
-- move an owned item into another slot under the player's feet. A NULL slot
-- (estate, investment, every row that predates this migration) means "not
-- gear": such a row always counts, exactly as before.
--
-- The partial unique index IS INV-66 - the database refuses a second equipped
-- row in a slot, so a bug in domain/inventory.py cannot produce one.
ALTER TABLE inventory ADD COLUMN slot TEXT;
ALTER TABLE inventory ADD COLUMN grade INTEGER;
ALTER TABLE inventory ADD COLUMN equipped INTEGER NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX idx_inventory_one_equipped_per_slot
  ON inventory (career_id, slot)
  WHERE equipped = 1 AND slot IS NOT NULL;
