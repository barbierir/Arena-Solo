extends RefCounted
class_name MatchupModifierResolver

# Matchup modifiers are optional per-build-pair combat overrides loaded from
# data/definitions/matchup_modifiers.json via ContentLoader.
# Key format: ATTACKER_BUILD_ID_vs_DEFENDER_BUILD_ID (order-sensitive).
# Current supported fields:
# - attacker_bonus_hp
# - defender_bonus_hp
# - both_bonus_hp
# - global_damage_multiplier
const SUPPORTED_KEYS: Array[String] = [
	"attacker_bonus_hp",
	"defender_bonus_hp",
	"both_bonus_hp",
	"global_damage_multiplier",
]

func resolve(attacker_build_id: String, defender_build_id: String, registry: ContentRegistry) -> Dictionary:
	var entries: Dictionary = registry.matchup_modifiers.get("entries", {})
	if entries.is_empty():
		return {}
	var matchup_key: String = "%s_vs_%s" % [attacker_build_id, defender_build_id]
	var raw_modifiers: Variant = entries.get(matchup_key, {})
	if typeof(raw_modifiers) != TYPE_DICTIONARY:
		push_warning("Ignoring malformed matchup modifier entry for key '%s' (expected Dictionary)." % matchup_key)
		return {}
	return _sanitize(raw_modifiers)

func _sanitize(raw_modifiers: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for key in raw_modifiers.keys():
		if not SUPPORTED_KEYS.has(str(key)):
			push_warning("Ignoring unsupported matchup modifier field '%s'." % str(key))
	for key in SUPPORTED_KEYS:
		if not raw_modifiers.has(key):
			continue
		if key == "global_damage_multiplier":
			sanitized[key] = maxf(0.0, float(raw_modifiers.get(key, 1.0)))
		else:
			sanitized[key] = int(raw_modifiers.get(key, 0))
	return sanitized
