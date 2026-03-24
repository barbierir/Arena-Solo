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
		actor_id = CombatRuntimeState.ATTACKER_SIDE_ID
	runtime_state.current_actor_id = actor_id
	runtime_state.next_actor_id = runtime_state.other_side_id(actor_id)
	var actor_state: CombatantRuntimeState = runtime_state.combatant_states.get(actor_id)
	runtime_state.append_log("-- Turn %d (%s) --" % [runtime_state.turn_index, actor_id])
	runtime_state.append_event("TURN_STARTED", {
		"actor_side_id": actor_id,
		"actor_build_id": "" if actor_state == null else actor_state.build_id,
	})
	_action_resolver.resolve_turn(runtime_state, actor_id)
