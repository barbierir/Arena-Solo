extends RefCounted
class_name CombatBatchSimulator

const COMBAT_SIMULATION_SCRIPT := preload("res://scripts/combat/CombatSimulation.gd")
const RNG_SERVICE_SCRIPT := preload("res://scripts/utilities/SeededRngService.gd")

var _content_registry: ContentRegistry

func configure(registry: ContentRegistry) -> void:
	_content_registry = registry

func progressive_seeds(start_seed: int, simulation_count: int) -> Array[int]:
	var seeds: Array[int] = []
	for offset in range(simulation_count):
		seeds.append(start_seed + offset)
	return seeds

func run_batch(attacker_build_id: String, defender_build_id: String, start_seed: int, simulation_count: int, max_turns: int = 128) -> Dictionary:
	assert(_content_registry != null)
	var run_count: int = maxi(0, simulation_count)
	var seed_list: Array[int] = progressive_seeds(start_seed, run_count)
	var result: Dictionary = _make_initial_result(attacker_build_id, defender_build_id, start_seed, run_count, max_turns, seed_list)
	if run_count == 0:
		return result

	var total_turns: int = 0
	var min_turns: int = 2147483647
	var max_turns_seen: int = 0
	var total_a_remaining_hp: int = 0
	var total_b_remaining_hp: int = 0
	var total_a_remaining_sta: int = 0
	var total_b_remaining_sta: int = 0

	for match_seed in seed_list:
		var simulation: CombatSimulation = COMBAT_SIMULATION_SCRIPT.new()
		var rng: SeededRngService = RNG_SERVICE_SCRIPT.new(match_seed)
		simulation.configure(_content_registry, rng)
		simulation.initialize_fight(attacker_build_id, defender_build_id)
		var runtime_state: CombatRuntimeState = simulation.run_to_completion(max_turns)
		var attacker_state: CombatantRuntimeState = runtime_state.combatant_states.get(attacker_build_id)
		var defender_state: CombatantRuntimeState = runtime_state.combatant_states.get(defender_build_id)
		var fight_turns: int = runtime_state.turn_index

		total_turns += fight_turns
		min_turns = mini(min_turns, fight_turns)
		max_turns_seen = maxi(max_turns_seen, fight_turns)
		total_a_remaining_hp += attacker_state.current_hp
		total_b_remaining_hp += defender_state.current_hp
		total_a_remaining_sta += attacker_state.current_sta
		total_b_remaining_sta += defender_state.current_sta

		_accumulate_outcome_counts(result, runtime_state)
		_accumulate_events(result, runtime_state.combat_events)

	result.turn_stats.min = min_turns
	result.turn_stats.max = max_turns_seen
	result.turn_stats.average = float(total_turns) / float(run_count)
	result.end_state_averages.attacker.remaining_hp = float(total_a_remaining_hp) / float(run_count)
	result.end_state_averages.attacker.remaining_sta = float(total_a_remaining_sta) / float(run_count)
	result.end_state_averages.defender.remaining_hp = float(total_b_remaining_hp) / float(run_count)
	result.end_state_averages.defender.remaining_sta = float(total_b_remaining_sta) / float(run_count)
	var attacker_wins: int = int(result.wins.attacker)
	var defender_wins: int = int(result.wins.defender)
	result.win_rates.attacker_pct = (float(attacker_wins) * 100.0) / float(run_count)
	result.win_rates.defender_pct = (float(defender_wins) * 100.0) / float(run_count)
	return result

func _make_initial_result(attacker_build_id: String, defender_build_id: String, start_seed: int, simulation_count: int, max_turns: int, seeds_used: Array[int]) -> Dictionary:
	return {
		"inputs": {
			"attacker_build_id": attacker_build_id,
			"defender_build_id": defender_build_id,
			"start_seed": start_seed,
			"simulation_count": simulation_count,
			"max_turns": max_turns,
		},
		"seeds_used": seeds_used,
		"total_runs": simulation_count,
		"wins": {
			"attacker": 0,
			"defender": 0,
			"draws_or_unresolved": 0,
		},
		"win_rates": {
			"attacker_pct": 0.0,
			"defender_pct": 0.0,
		},
		"turn_stats": {
			"average": 0.0,
			"min": 0,
			"max": 0,
		},
		"terminal_condition_counts": {},
		"end_state_averages": {
			"attacker": {
				"remaining_hp": 0.0,
				"remaining_sta": 0.0,
			},
			"defender": {
				"remaining_hp": 0.0,
				"remaining_sta": 0.0,
			},
		},
		"action_usage_counts": {},
		"status_application_counts": {},
	}

func _accumulate_outcome_counts(result: Dictionary, runtime_state: CombatRuntimeState) -> void:
	var attacker_won: bool = runtime_state.result_state == "VICTORY"
	var defender_won: bool = runtime_state.result_state == "DEFEAT"
	if attacker_won:
		result.wins.attacker = int(result.wins.attacker) + 1
	elif defender_won:
		result.wins.defender = int(result.wins.defender) + 1
	else:
		result.wins.draws_or_unresolved = int(result.wins.draws_or_unresolved) + 1

	if runtime_state.result_state == "ABORTED":
		_increment_count(result.terminal_condition_counts, "MAX_TURNS_ABORT")
		return

	if attacker_won or defender_won:
		_increment_count(result.terminal_condition_counts, "HP_ZERO")
		return

	_increment_count(result.terminal_condition_counts, "UNRESOLVED")

func _accumulate_events(result: Dictionary, combat_events: Array[Dictionary]) -> void:
	for event in combat_events:
		var event_type: String = str(event.get("type", ""))
		if event_type == "ACTION_USED":
			var skill_id: String = str(event.get("skill_id", "UNKNOWN_ACTION"))
			_increment_count(result.action_usage_counts, skill_id)
		elif event_type == "STATUS_APPLIED":
			var status_id: String = str(event.get("status_id", "UNKNOWN_STATUS"))
			_increment_count(result.status_application_counts, status_id)

func _increment_count(target: Dictionary, key: String) -> void:
	target[key] = int(target.get(key, 0)) + 1
