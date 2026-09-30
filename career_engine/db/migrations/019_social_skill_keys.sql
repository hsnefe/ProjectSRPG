-- CONTRACT.md §14 (D79): the five kişi attributes are renamed to the five
-- social skills. charisma and intelligence keep their keys. player_attribute is
-- the only table that stores an attribute key (INV-21), and the primary key
-- (career_id, player_id, attribute_key) cannot collide because the new keys
-- did not exist before this migration.
UPDATE player_attribute SET attribute_key = 'empathy'    WHERE attribute_key = 'politeness';
UPDATE player_attribute SET attribute_key = 'courage'    WHERE attribute_key = 'confidence';
UPDATE player_attribute SET attribute_key = 'discipline' WHERE attribute_key = 'resourcefulness';
