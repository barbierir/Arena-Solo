extends RefCounted
class_name CombatantRuntimeState

var build_id: String
var display_name: String
var current_hp: int
var current_sta: int
var temporary_defense_bonus: int = 0
var cooldowns: Dictionary = {}
var active_statuses: Array[Dictionary] = []

func to_snapshot() -> Dictionary:
	return {
		"build_id": build_id,
		"display_name": display_name,
		"current_hp": current_hp,
		"current_sta": current_sta,
		"temporary_defense_bonus": temporary_defense_bonus,
		"cooldowns": cooldowns.duplicate(true),
		"active_statuses": active_statuses.duplicate(true),
	}
