extends RefCounted
class_name AiActionSelector

func choose_action(_actor_build_id: String, _runtime_state: CombatRuntimeState) -> String:
	return "BASIC_ATTACK"
