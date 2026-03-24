extends RefCounted
class_name TurnController

const ACTION_RESOLVER_SCRIPT := preload("res://scripts/combat/systems/ActionResolver.gd")

var _action_resolver: ActionResolver

func configure(content_registry: ContentRegistry, rng_service: SeededRngService) -> void:
	_action_resolver = ACTION_RESOLVER_SCRIPT.new()
	_action_resolver.configure(content_registry, rng_service)

func execute_turn(runtime_state: CombatRuntimeState) -> void:
	runtime_state.turn_index += 1
	runtime_state.append_log("Turn %d start" % runtime_state.turn_index)
	_action_resolver.resolve_turn(runtime_state)
