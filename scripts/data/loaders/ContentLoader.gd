extends RefCounted
class_name ContentLoader

const FILES: Dictionary = {
	"combat_rules": "res://data/definitions/combat_rules.json",
	"classes": "res://data/definitions/classes.json",
	"builds": "res://data/definitions/builds.json",
	"equipment": "res://data/definitions/equipment.json",
	"skills": "res://data/definitions/skills.json",
	"status_effects": "res://data/definitions/status_effects.json",
	"ai_profiles": "res://data/definitions/ai_profiles.json",
	"encounters": "res://data/definitions/encounters.json",
	"matchup_modifiers": "res://data/definitions/matchup_modifiers.json",
}

func load_all_definitions() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	registry.combat_rules = _load_json(FILES.combat_rules)
	registry.status_effects = _load_json(FILES.status_effects)
	registry.skills = _load_json(FILES.skills)
	registry.equipment = _load_json(FILES.equipment)
	registry.classes = _load_json(FILES.classes)
	registry.builds = _load_json(FILES.builds)
	registry.ai_profiles = _load_json(FILES.ai_profiles)
	registry.encounters = _load_json(FILES.encounters)
	registry.matchup_modifiers = _load_optional_json(FILES.matchup_modifiers)
	return registry

func _load_optional_json(path: String) -> Dictionary:
	# Optional definitions (like matchup modifiers) should fail open:
	# if the file is absent, combat still runs with default behavior.
	if not FileAccess.file_exists(path):
		return {}
	return _load_json(path)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Definition file missing: %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Definition file did not parse as Dictionary: %s" % path)
		return {}
	var parsed_dict: Dictionary = parsed
	return parsed_dict
