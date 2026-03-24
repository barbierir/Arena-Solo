extends SceneTree

const CONTENT_LOADER_SCRIPT := preload("res://scripts/data/loaders/ContentLoader.gd")
const RNG_SERVICE_SCRIPT := preload("res://scripts/utilities/SeededRngService.gd")
const COMBAT_SIMULATION_SCRIPT := preload("res://scripts/combat/CombatSimulation.gd")
const COMBAT_BATCH_SIMULATOR_SCRIPT := preload("res://scripts/combat/analysis/CombatBatchSimulator.gd")
const STATUS_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/StatusSystem.gd")
const STAMINA_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/StaminaSystem.gd")

const DEFAULT_TURN_CAP: int = 128

func _initialize() -> void:
	var loader: ContentLoader = CONTENT_LOADER_SCRIPT.new()
	var registry: ContentRegistry = loader.load_all_definitions()
	_test_deterministic_seed_replay(registry)
	_test_combat_reaches_terminal_result(registry)
	_test_step_turn_matches_full_simulation(registry)
	_test_status_duration_behavior(registry)
	_test_stamina_behavior(registry)
	_test_fight_end_condition(registry)
	_test_batch_deterministic_results(registry)
	_test_batch_progressive_seed_behavior(registry)
	_test_batch_aggregate_accounting(registry)
	_test_batch_turn_stats_validity(registry)
	_test_batch_parity_with_manual_loop(registry)
	print("All combat-core tests passed")
	quit(0)

func _test_deterministic_seed_replay(registry: ContentRegistry) -> void:
	var run_a: Dictionary = _run_fight(registry, 1234, false)
	var run_b: Dictionary = _run_fight(registry, 1234, false)

	assert(run_a.result_state == run_b.result_state)
	assert(run_a.winner == run_b.winner)
	assert(run_a.turn_count == run_b.turn_count)
	assert(run_a.attacker_hp == run_b.attacker_hp)
	assert(run_a.attacker_sta == run_b.attacker_sta)
	assert(run_a.defender_hp == run_b.defender_hp)
	assert(run_a.defender_sta == run_b.defender_sta)
	assert(run_a.log == run_b.log)

func _test_combat_reaches_terminal_result(registry: ContentRegistry) -> void:
	var run_data: Dictionary = _run_fight(registry, 2026, false)
	assert(run_data.result_state != "PENDING")
	assert(run_data.result_state != "ABORTED")
	assert(run_data.turn_count > 0)
	assert(run_data.turn_count <= DEFAULT_TURN_CAP)

func _test_step_turn_matches_full_simulation(registry: ContentRegistry) -> void:
	var full_run: Dictionary = _run_fight(registry, 777, false)
	var stepped_run: Dictionary = _run_fight(registry, 777, true)

	assert(full_run.result_state == stepped_run.result_state)
	assert(full_run.winner == stepped_run.winner)
	assert(full_run.turn_count == stepped_run.turn_count)
	assert(full_run.attacker_hp == stepped_run.attacker_hp)
	assert(full_run.attacker_sta == stepped_run.attacker_sta)
	assert(full_run.defender_hp == stepped_run.defender_hp)
	assert(full_run.defender_sta == stepped_run.defender_sta)
	assert(full_run.log == stepped_run.log)

func _test_status_duration_behavior(_registry: ContentRegistry) -> void:
	var status_system: StatusSystem = STATUS_SYSTEM_SCRIPT.new()
	var actor: CombatantRuntimeState = CombatantRuntimeState.new()
	var status_defs: Dictionary = {
		"STUNNED": {
			"id": "STUNNED",
			"display_name": "Stunned",
			"stack_rule": "Replace",
			"skip_turn": true
		}
	}

	status_system.apply_status(actor, "STUNNED", 1, "SHIELD_BASH", status_defs)
	assert(status_system.can_act(actor, status_defs) == false)
	status_system.tick_status_durations(actor)
	assert(actor.has_status("STUNNED") == false)
	assert(status_system.can_act(actor, status_defs))

func _test_stamina_behavior(registry: ContentRegistry) -> void:
	var stamina_system: StaminaSystem = STAMINA_SYSTEM_SCRIPT.new()
	var status_defs: Dictionary = registry.status_effects.get("entries", {})
	var controls: Dictionary = registry.combat_rules.get("entries", {}).get("COMBAT_CONTROLS", {})
	var actor: CombatantRuntimeState = CombatantRuntimeState.new()
	actor.max_sta = 10
	actor.current_sta = 2

	stamina_system.spend(actor, 2)
	assert(actor.current_sta == 0)
	var regen: int = stamina_system.apply_turn_regen(actor, controls, status_defs)
	assert(regen >= 1)
	assert(actor.current_sta >= 1)

func _test_fight_end_condition(registry: ContentRegistry) -> void:
	var run_data: Dictionary = _run_fight(registry, 1001, false)
	var attacker_hp: int = int(run_data.attacker_hp)
	var defender_hp: int = int(run_data.defender_hp)
	assert(attacker_hp == 0 or defender_hp == 0)
	assert(str(run_data.winner) != "")
	assert(str(run_data.result_state) == "VICTORY" or str(run_data.result_state) == "DEFEAT")

func _test_batch_deterministic_results(registry: ContentRegistry) -> void:
	var simulator: CombatBatchSimulator = _make_batch_simulator(registry)
	var run_a: Dictionary = simulator.run_batch("RET_STARTER", "SEC_STARTER", 5000, 40, DEFAULT_TURN_CAP)
	var run_b: Dictionary = simulator.run_batch("RET_STARTER", "SEC_STARTER", 5000, 40, DEFAULT_TURN_CAP)
	assert(run_a.wins == run_b.wins)
	assert(run_a.win_rates == run_b.win_rates)
	assert(run_a.turn_stats == run_b.turn_stats)
	assert(run_a.action_usage_counts == run_b.action_usage_counts)
	assert(run_a.status_application_counts == run_b.status_application_counts)
	assert(run_a.terminal_condition_counts == run_b.terminal_condition_counts)

func _test_batch_progressive_seed_behavior(registry: ContentRegistry) -> void:
	var simulator: CombatBatchSimulator = _make_batch_simulator(registry)
	var result: Dictionary = simulator.run_batch("RET_STARTER", "SEC_STARTER", 42, 6, DEFAULT_TURN_CAP)
	assert(result.seeds_used == [42, 43, 44, 45, 46, 47])

func _test_batch_aggregate_accounting(registry: ContentRegistry) -> void:
	var simulator: CombatBatchSimulator = _make_batch_simulator(registry)
	var result: Dictionary = simulator.run_batch("RET_STARTER", "SEC_STARTER", 900, 25, DEFAULT_TURN_CAP)
	var total_runs: int = int(result.total_runs)
	var attacker_wins: int = int(result.wins.attacker)
	var defender_wins: int = int(result.wins.defender)
	var unresolved: int = int(result.wins.draws_or_unresolved)
	assert(attacker_wins + defender_wins + unresolved == total_runs)

func _test_batch_turn_stats_validity(registry: ContentRegistry) -> void:
	var simulator: CombatBatchSimulator = _make_batch_simulator(registry)
	var result: Dictionary = simulator.run_batch("RET_STARTER", "SEC_STARTER", 321, 35, DEFAULT_TURN_CAP)
	var min_turns: int = int(result.turn_stats.min)
	var max_turns: int = int(result.turn_stats.max)
	var average_turns: float = float(result.turn_stats.average)
	assert(min_turns <= max_turns)
	assert(float(min_turns) <= average_turns)
	assert(average_turns <= float(max_turns))

func _test_batch_parity_with_manual_loop(registry: ContentRegistry) -> void:
	var start_seed: int = 2800
	var runs: int = 20
	var batch_simulator: CombatBatchSimulator = _make_batch_simulator(registry)
	var batch_result: Dictionary = batch_simulator.run_batch("RET_STARTER", "SEC_STARTER", start_seed, runs, DEFAULT_TURN_CAP)

	var manual: Dictionary = {
		"attacker_wins": 0,
		"defender_wins": 0,
		"unresolved": 0,
		"total_turns": 0,
		"action_usage_counts": {},
	}
	for offset in range(runs):
		var seed: int = start_seed + offset
		var run_data: Dictionary = _run_fight_with_events(registry, seed, DEFAULT_TURN_CAP)
		manual.total_turns = int(manual.total_turns) + int(run_data.turn_count)
		if str(run_data.result_state) == "VICTORY":
			manual.attacker_wins = int(manual.attacker_wins) + 1
		elif str(run_data.result_state) == "DEFEAT":
			manual.defender_wins = int(manual.defender_wins) + 1
		else:
			manual.unresolved = int(manual.unresolved) + 1
		var action_counts: Dictionary = manual.action_usage_counts
		for event in run_data.events:
			if str(event.get("type", "")) != "ACTION_USED":
				continue
			var skill_id: String = str(event.get("skill_id", "UNKNOWN_ACTION"))
			action_counts[skill_id] = int(action_counts.get(skill_id, 0)) + 1
		manual.action_usage_counts = action_counts

	assert(int(batch_result.wins.attacker) == int(manual.attacker_wins))
	assert(int(batch_result.wins.defender) == int(manual.defender_wins))
	assert(int(batch_result.wins.draws_or_unresolved) == int(manual.unresolved))
	assert(is_equal_approx(float(batch_result.turn_stats.average), float(manual.total_turns) / float(runs)))
	assert(batch_result.action_usage_counts == manual.action_usage_counts)

func _run_fight(registry: ContentRegistry, seed: int, use_steps: bool) -> Dictionary:
	var simulation: CombatSimulation = COMBAT_SIMULATION_SCRIPT.new()
	var rng: SeededRngService = RNG_SERVICE_SCRIPT.new(seed)
	simulation.configure(registry, rng)
	simulation.initialize_fight("RET_STARTER", "SEC_STARTER")
	if use_steps:
		for _step_idx in range(DEFAULT_TURN_CAP):
			if simulation.is_finished():
				break
			simulation.step_turn()
	else:
		simulation.run_to_completion(DEFAULT_TURN_CAP)

	var runtime_state: CombatRuntimeState = simulation.get_runtime_state()
	var attacker: CombatantRuntimeState = runtime_state.combatant_states.get(runtime_state.attacker_build_id)
	var defender: CombatantRuntimeState = runtime_state.combatant_states.get(runtime_state.defender_build_id)
	assert(runtime_state.result_state != "PENDING")
	return {
		"result_state": runtime_state.result_state,
		"winner": runtime_state.winner_combatant_id,
		"turn_count": runtime_state.turn_index,
		"attacker_hp": attacker.current_hp,
		"attacker_sta": attacker.current_sta,
		"defender_hp": defender.current_hp,
		"defender_sta": defender.current_sta,
		"log": _normalize_log(runtime_state.combat_log),
	}

func _run_fight_with_events(registry: ContentRegistry, seed: int, max_turns: int) -> Dictionary:
	var simulation: CombatSimulation = COMBAT_SIMULATION_SCRIPT.new()
	var rng: SeededRngService = RNG_SERVICE_SCRIPT.new(seed)
	simulation.configure(registry, rng)
	simulation.initialize_fight("RET_STARTER", "SEC_STARTER")
	simulation.run_to_completion(max_turns)
	var runtime_state: CombatRuntimeState = simulation.get_runtime_state()
	return {
		"result_state": runtime_state.result_state,
		"turn_count": runtime_state.turn_index,
		"events": runtime_state.combat_events,
	}

func _make_batch_simulator(registry: ContentRegistry) -> CombatBatchSimulator:
	var simulator: CombatBatchSimulator = COMBAT_BATCH_SIMULATOR_SCRIPT.new()
	simulator.configure(registry)
	return simulator

func _normalize_log(entries: Array[String]) -> Array[String]:
	var normalized: Array[String] = []
	for entry in entries:
		normalized.append(entry.strip_edges())
	return normalized
