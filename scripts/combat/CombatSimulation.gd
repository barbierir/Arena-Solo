extends RefCounted
class_name CombatSimulation

const COMBAT_RUNTIME_STATE_SCRIPT := preload("res://scripts/combat/runtime/CombatRuntimeState.gd")
const COMBATANT_RUNTIME_STATE_SCRIPT := preload("res://scripts/combat/runtime/CombatantRuntimeState.gd")
const TURN_CONTROLLER_SCRIPT := preload("res://scripts/combat/TurnController.gd")
const BUILD_STATS_RESOLVER_SCRIPT := preload("res://scripts/combat/systems/BuildStatsResolver.gd")

var content_registry: ContentRegistry
var rng_service: SeededRngService
var runtime_state: CombatRuntimeState
var turn_controller: TurnController
var build_stats_resolver: BuildStatsResolver

func configure(registry: ContentRegistry, rng: SeededRngService) -> void:
	content_registry = registry
	rng_service = rng
	turn_controller = TURN_CONTROLLER_SCRIPT.new()
	turn_controller.configure(registry, rng)
	build_stats_resolver = BUILD_STATS_RESOLVER_SCRIPT.new()
	build_stats_resolver.configure(registry)

func bootstrap_default_encounter(attacker_build_id: String, defender_build_id: String) -> void:
	initialize_fight(attacker_build_id, defender_build_id)

func initialize_fight(attacker_build_id: String, defender_build_id: String) -> void:
	runtime_state = COMBAT_RUNTIME_STATE_SCRIPT.new()
	runtime_state.attacker_build_id = attacker_build_id
	runtime_state.defender_build_id = defender_build_id
	runtime_state.combatant_states[CombatRuntimeState.ATTACKER_SIDE_ID] = _make_combatant_state(attacker_build_id, CombatRuntimeState.ATTACKER_SIDE_ID)
	runtime_state.combatant_states[CombatRuntimeState.DEFENDER_SIDE_ID] = _make_combatant_state(defender_build_id, CombatRuntimeState.DEFENDER_SIDE_ID)
	runtime_state.next_actor_id = _resolve_first_actor()
	runtime_state.append_log("Encounter initialized: %s vs %s (seed=%d)" % [attacker_build_id, defender_build_id, rng_service.get_seed()])

func simulate_single_turn() -> void:
	if runtime_state == null or is_finished():
		return
	turn_controller.execute_turn(runtime_state)

func simulate_to_completion(max_turns: int = 64) -> CombatRuntimeState:
	for _i in range(max_turns):
		if is_finished():
			break
		simulate_single_turn()
	if runtime_state != null and runtime_state.result_state == "PENDING":
		runtime_state.result_state = "ABORTED"
		runtime_state.append_log("Combat aborted after max turns (%d)." % max_turns)
		runtime_state.append_event("COMBAT_ENDED", {
			"terminal_condition": "MAX_TURNS_ABORT",
			"winner_build_id": "",
			"winner_combatant_id": "",
		})
	return runtime_state

func run_to_completion(max_turns: int = 64) -> CombatRuntimeState:
	return simulate_to_completion(max_turns)

func step_turn() -> void:
	simulate_single_turn()

func is_finished() -> bool:
	return runtime_state != null and runtime_state.result_state != "PENDING"

func get_runtime_state() -> CombatRuntimeState:
	return runtime_state

func get_log() -> Array[String]:
	if runtime_state == null:
		return []
	return runtime_state.combat_log

func _make_combatant_state(build_id: String, combatant_id: String) -> CombatantRuntimeState:
	var state: CombatantRuntimeState = COMBATANT_RUNTIME_STATE_SCRIPT.new()
	var build: Dictionary = content_registry.builds.get("entries", {}).get(build_id, {})
	var stats: Dictionary = build_stats_resolver.resolve_build_stats(build_id)
	state.combatant_id = combatant_id
	state.build_id = build_id
	state.class_id = str(build.get("class_id", ""))
	state.display_name = str(build.get("display_name", build_id))
	state.max_hp = int(stats.max_hp)
	state.max_sta = int(stats.max_sta)
	state.current_hp = state.max_hp
	state.current_sta = state.max_sta
	state.base_atk = int(stats.atk)
	state.base_def = int(stats.def)
	state.base_spd = int(stats.spd)
	state.base_skl = int(stats.skl)
	state.total_hit_mod_pct = float(stats.total_hit_mod_pct)
	state.total_crit_mod_pct = float(stats.total_crit_mod_pct)
	return state

func _resolve_first_actor() -> String:
	var attacker: CombatantRuntimeState = runtime_state.attacker_state()
	var defender: CombatantRuntimeState = runtime_state.defender_state()
	if attacker.base_spd > defender.base_spd:
		return CombatRuntimeState.ATTACKER_SIDE_ID
	if defender.base_spd > attacker.base_spd:
		return CombatRuntimeState.DEFENDER_SIDE_ID
	return CombatRuntimeState.ATTACKER_SIDE_ID if rng_service.randf() <= 0.5 else CombatRuntimeState.DEFENDER_SIDE_ID
