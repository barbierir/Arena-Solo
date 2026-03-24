extends RefCounted
class_name TurnController

const ACTION_RESOLVER_SCRIPT := preload("res://scripts/combat/systems/ActionResolver.gd")

var _action_resolver: ActionResolver

func configure(content_registry: ContentRegistry, rng_service: SeededRngService) -> void:
	_action_resolver = ACTION_RESOLVER_SCRIPT.new()
	_action_resolver.configure(content_registry, rng_service)

func execute_turn(runtime_state: CombatRuntimeState) -> void:
	if runtime_state.result_state != "PENDING":
		return
	runtime_state.turn_index += 1
	var actor_id: String = runtime_state.next_actor_id
	if actor_id == "":
		actor_id = runtime_state.attacker_build_id
	runtime_state.current_actor_id = actor_id
	runtime_state.next_actor_id = runtime_state.defender_build_id if actor_id == runtime_state.attacker_build_id else runtime_state.attacker_build_id
	runtime_state.append_log("-- Turn %d (%s) --" % [runtime_state.turn_index, actor_id])
	runtime_state.append_event("TURN_STARTED", {
		"actor_build_id": actor_id,
	})
	_action_resolver.resolve_turn(runtime_state, actor_id)
