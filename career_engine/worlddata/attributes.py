"""§5.2 P1 - starting player_attribute values for a brand-new career.
Ported verbatim from FE's own two radar screens' mock data: the saha six
are training_radar_screen.dart's _values, the kişi five are
relationships_radar_screen.dart's _values. Order matches api/config.py's
ATTRIBUTE_KEYS."""

STARTING_ATTRIBUTES = {
    "condition": 64.0, "strength": 38.0, "flexibility": 92.0,
    "shooting": 50.0, "passing": 80.0, "dribbling": 25.0,
    "charisma": 74.0, "politeness": 58.0, "confidence": 51.0,
    "intelligence": 63.0, "resourcefulness": 29.0,
}
