extends RefCounted
class_name VictoryResolver

func resolve_if_decided(runtime_state: CombatRuntimeState) -> void:
	if runtime_state.result_state != "PENDING":
		return
	var attacker: CombatantRuntimeState = runtime_state.attacker_state()
	var defender: CombatantRuntimeState = runtime_state.defender_state()
	if attacker != null and defender != null and not attacker.is_alive() and not defender.is_alive():
		runtime_state.result_state = "DRAW"
		runtime_state.winner_combatant_id = ""
		runtime_state.append_log("Combat ended: double knockout.")
		runtime_state.append_event("COMBAT_ENDED", {
			"terminal_condition": "DOUBLE_KO",
			"winner_build_id": "",
			"winner_combatant_id": "",
		})
		return
	if attacker != null and not attacker.is_alive():
		runtime_state.result_state = "DEFEAT"
		runtime_state.winner_combatant_id = defender.combatant_id
		runtime_state.append_log("Combat ended: %s wins." % defender.display_name)
		runtime_state.append_event("COMBAT_ENDED", {
			"terminal_condition": "HP_ZERO",
			"winner_build_id": defender.build_id,
			"winner_combatant_id": defender.combatant_id,
		})
	elif defender != null and not defender.is_alive():
		runtime_state.result_state = "VICTORY"
		runtime_state.winner_combatant_id = attacker.combatant_id
		runtime_state.append_log("Combat ended: %s wins." % attacker.display_name)
		runtime_state.append_event("COMBAT_ENDED", {
			"terminal_condition": "HP_ZERO",
			"winner_build_id": attacker.build_id,
			"winner_combatant_id": attacker.combatant_id,
		})
