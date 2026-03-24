extends RefCounted
class_name CombatSimulation

const COMBAT_RUNTIME_STATE_SCRIPT := preload("res://scripts/combat/runtime/CombatRuntimeState.gd")
const COMBATANT_RUNTIME_STATE_SCRIPT := preload("res://scripts/combat/runtime/CombatantRuntimeState.gd")
const TURN_CONTROLLER_SCRIPT := preload("res://scripts/combat/TurnController.gd")

var content_registry: ContentRegistry
var rng_service: SeededRngService
var runtime_state: CombatRuntimeState
var turn_controller: TurnController

func configure(registry: ContentRegistry, rng: SeededRngService) -> void:
	content_registry = registry
	rng_service = rng
	turn_controller = TURN_CONTROLLER_SCRIPT.new()
	turn_controller.configure(registry, rng)

func bootstrap_default_encounter(attacker_build_id: String, defender_build_id: String) -> void:
	runtime_state = COMBAT_RUNTIME_STATE_SCRIPT.new()
	runtime_state.attacker_build_id = attacker_build_id
	runtime_state.defender_build_id = defender_build_id
	runtime_state.combatant_states[attacker_build_id] = _make_combatant_state(attacker_build_id)
	runtime_state.combatant_states[defender_build_id] = _make_combatant_state(defender_build_id)
	runtime_state.append_log("Encounter initialized: %s vs %s" % [attacker_build_id, defender_build_id])

func simulate_single_turn() -> void:
	if runtime_state == null:
		return
	turn_controller.execute_turn(runtime_state)

func _make_combatant_state(build_id: String) -> CombatantRuntimeState:
	var state := COMBATANT_RUNTIME_STATE_SCRIPT.new()
	var build: Dictionary = content_registry.builds.get("entries", {}).get(build_id, {})
	var class_id: String = build.get("class_id", "")
	var class_def: Dictionary = content_registry.classes.get("entries", {}).get(class_id, {})
	state.build_id = build_id
	state.display_name = build.get("display_name", build_id)
	state.current_hp = int(class_def.get("base_hp", 20))
	state.current_sta = int(class_def.get("base_sta", 8))
	return state
