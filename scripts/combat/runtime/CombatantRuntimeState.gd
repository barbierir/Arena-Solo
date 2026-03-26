extends RefCounted
class_name CombatantRuntimeState

var combatant_id: String = ""
var build_id: String = ""
var class_id: String = ""
var display_name: String = ""

var max_hp: int = 0
var max_sta: int = 0
var current_hp: int = 0
var current_sta: int = 0

var base_atk: int = 0
var base_def: int = 0
var base_spd: int = 0
var base_skl: int = 0
var total_hit_mod_pct: float = 0.0
var total_crit_mod_pct: float = 0.0

var temporary_defense_bonus: int = 0
var cooldowns: Dictionary = {}
var active_statuses: Array[Dictionary] = []
var focused_hit_bonus_pct: float = 0.0
var off_balance_damage_penalty: int = 0
var consecutive_stun_attempts_received: int = 0
var was_stunned_last_turn: bool = false

func is_alive() -> bool:
	return current_hp > 0

func has_status(status_id: String) -> bool:
	for entry in active_statuses:
		if entry.get("status_id", "") == status_id:
			return true
	return false

func status_mod(stat_key: String, status_defs: Dictionary) -> int:
	var value: int = 0
	for entry in active_statuses:
		var definition: Dictionary = status_defs.get(entry.get("status_id", ""), {})
		value += int(definition.get(stat_key, 0))
	return value

func effective_atk(status_defs: Dictionary) -> int:
	return base_atk + status_mod("atk_mod", status_defs)

func effective_def(status_defs: Dictionary) -> int:
	return base_def + temporary_defense_bonus + status_mod("def_mod", status_defs)

func effective_spd(status_defs: Dictionary) -> int:
	return base_spd + status_mod("spd_mod", status_defs)

func effective_skl() -> int:
	return base_skl

func status_labels(status_defs: Dictionary) -> String:
	if active_statuses.is_empty():
		return "None"
	var labels: Array[String] = []
	for entry in active_statuses:
		var def: Dictionary = status_defs.get(entry.get("status_id", ""), {})
		labels.append("%s(%d)" % [def.get("display_name", entry.get("status_id", "?")), int(entry.get("remaining_turns", 0))])
	return ", ".join(labels)
