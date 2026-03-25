extends RefCounted
class_name CombatRuntimeState

var turn_index: int = 0
var attacker_build_id: String = ""
var defender_build_id: String = ""
var combatant_states: Dictionary = {}
var matchup_modifiers: Dictionary = {}
var combat_log: Array[String] = []
var combat_events: Array[Dictionary] = []
var result_state: String = "PENDING"
var winner_combatant_id: String = ""
var current_actor_id: String = ""
var next_actor_id: String = ""

const ATTACKER_SIDE_ID: String = "A"
const DEFENDER_SIDE_ID: String = "B"

func append_log(entry: String) -> void:
	combat_log.append(entry)

func append_event(event_type: String, payload: Dictionary = {}) -> void:
	var event: Dictionary = {
		"type": event_type,
		"turn_index": turn_index,
	}
	for key_variant in payload.keys():
		event[str(key_variant)] = payload[key_variant]
	combat_events.append(event)

func attacker_state() -> CombatantRuntimeState:
	return combatant_states.get(ATTACKER_SIDE_ID)

func defender_state() -> CombatantRuntimeState:
	return combatant_states.get(DEFENDER_SIDE_ID)

func other_side_id(side_id: String) -> String:
	return DEFENDER_SIDE_ID if side_id == ATTACKER_SIDE_ID else ATTACKER_SIDE_ID
