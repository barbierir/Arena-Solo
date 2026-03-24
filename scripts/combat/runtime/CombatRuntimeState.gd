extends RefCounted
class_name CombatRuntimeState

var turn_index: int = 0
var attacker_build_id: String = ""
var defender_build_id: String = ""
var combatant_states: Dictionary = {}
var combat_log: Array[String] = []
var result_state: String = "PENDING"
var winner_combatant_id: String = ""
var current_actor_id: String = ""
var next_actor_id: String = ""

func append_log(entry: String) -> void:
	combat_log.append(entry)
