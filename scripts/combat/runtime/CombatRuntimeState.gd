extends RefCounted
class_name CombatRuntimeState

var turn_index: int = 0
var attacker_build_id: String = ""
var defender_build_id: String = ""
var combatant_states: Dictionary = {}
var combat_log: Array[String] = []
var result_state: String = "PENDING"

func append_log(entry: String) -> void:
	combat_log.append(entry)
