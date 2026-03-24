extends RefCounted
class_name VictoryResolver

func resolve_if_decided(runtime_state: CombatRuntimeState) -> void:
	if runtime_state.result_state != "PENDING":
		return
	var attacker: CombatantRuntimeState = runtime_state.combatant_states.get(runtime_state.attacker_build_id)
	var defender: CombatantRuntimeState = runtime_state.combatant_states.get(runtime_state.defender_build_id)
	if attacker != null and not attacker.is_alive():
		runtime_state.result_state = "DEFEAT"
		runtime_state.winner_combatant_id = defender.combatant_id
		runtime_state.append_log("Combat ended: %s wins." % defender.display_name)
	elif defender != null and not defender.is_alive():
		runtime_state.result_state = "VICTORY"
		runtime_state.winner_combatant_id = attacker.combatant_id
		runtime_state.append_log("Combat ended: %s wins." % attacker.display_name)
