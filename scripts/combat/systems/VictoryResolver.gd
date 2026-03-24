extends RefCounted
class_name VictoryResolver

func resolve_if_decided(runtime_state: CombatRuntimeState) -> void:
	if runtime_state.result_state != "PENDING":
		return
	# Foundation scaffold only; final win/loss logic is implemented in later prompts.
