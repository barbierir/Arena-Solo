extends RefCounted
class_name ContentRegistry

var combat_rules: Dictionary = {}
var classes: Dictionary = {}
var builds: Dictionary = {}
var equipment: Dictionary = {}
var skills: Dictionary = {}
var status_effects: Dictionary = {}
var ai_profiles: Dictionary = {}
var encounters: Dictionary = {}
var matchup_modifiers: Dictionary = {}

func as_dictionary() -> Dictionary:
	return {
		"combat_rules": combat_rules,
		"classes": classes,
		"builds": builds,
		"equipment": equipment,
		"skills": skills,
		"status_effects": status_effects,
		"ai_profiles": ai_profiles,
		"encounters": encounters,
		"matchup_modifiers": matchup_modifiers,
	}
