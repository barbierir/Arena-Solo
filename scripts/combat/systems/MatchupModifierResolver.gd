extends RefCounted
class_name MatchupModifierResolver

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
	var raw: Variant = entries.get(matchup_key, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return _sanitize(raw)

func _sanitize(raw: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for key in SUPPORTED_KEYS:
		if not raw.has(key):
			continue
		if key == "global_damage_multiplier":
			sanitized[key] = maxf(0.0, float(raw.get(key, 1.0)))
		else:
			sanitized[key] = int(raw.get(key, 0))
	return sanitized
