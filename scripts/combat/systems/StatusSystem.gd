extends RefCounted
class_name StatusSystem

func tick_statuses(runtime_state: CombatRuntimeState) -> void:
	runtime_state.append_log("Status tick (stub)")
