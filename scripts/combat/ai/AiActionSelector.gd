extends RefCounted
class_name AiActionSelector

func choose_action(_actor: CombatantRuntimeState, _target: CombatantRuntimeState, _runtime_state: CombatRuntimeState) -> String:
	return "BASIC_ATTACK"
