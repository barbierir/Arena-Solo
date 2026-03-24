extends RefCounted
class_name StaminaSystem

func apply_turn_regen(runtime_state: CombatRuntimeState) -> void:
	runtime_state.append_log("Stamina regen tick (stub)")
