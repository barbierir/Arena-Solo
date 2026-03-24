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
	var skill_entries: Dictionary = _content_registry.skills.get("entries", {})

	for match_seed in seed_list:
		var simulation: CombatSimulation = COMBAT_SIMULATION_SCRIPT.new()
		var rng: SeededRngService = RNG_SERVICE_SCRIPT.new(match_seed)
		simulation.configure(_content_registry, rng)
		simulation.initialize_fight(attacker_build_id, defender_build_id)
		var runtime_state: CombatRuntimeState = simulation.run_to_completion(max_turns)
		var attacker_state: CombatantRuntimeState = runtime_state.attacker_state()
		var defender_state: CombatantRuntimeState = runtime_state.defender_state()
		var fight_turns: int = runtime_state.turn_index

		total_turns += fight_turns
		min_turns = mini(min_turns, fight_turns)
		max_turns_seen = maxi(max_turns_seen, fight_turns)
		total_a_remaining_hp += attacker_state.current_hp
		total_b_remaining_hp += defender_state.current_hp
		total_a_remaining_sta += attacker_state.current_sta
		total_b_remaining_sta += defender_state.current_sta

		_accumulate_outcome_counts(result, runtime_state)
		_accumulate_events(result, runtime_state.combat_events, skill_entries)
		_accumulate_match_outcomes(result, attacker_state, defender_state, runtime_state)

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
		"fighters": {
			"attacker": _make_fighter_metrics("A", attacker_build_id),
			"defender": _make_fighter_metrics("B", defender_build_id),
		},
	}

func _make_fighter_metrics(side_id: String, build_id: String) -> Dictionary:
	return {
		"side_id": side_id,
		"build_id": build_id,
		"damage_dealt_total": 0,
		"damage_taken_total": 0,
		"sta_spent_total": 0,
		"hit_count": 0,
		"miss_count": 0,
		"turns_survived_total": 0,
		"low_sta_turns_total": 0,
		"zero_sta_turns_total": 0,
		"actions_used_total": 0,
		"remaining_hp_in_wins_total": 0,
		"remaining_hp_in_losses_total": 0,
		"remaining_sta_in_wins_total": 0,
		"remaining_sta_in_losses_total": 0,
		"wins": 0,
		"losses": 0,
		"ability_usage_counts": {},
		"status_application_counts": {},
		"status_uptime_turns": {},
		"per_match": {
			"avg_damage_dealt": 0.0,
			"avg_damage_taken": 0.0,
			"avg_sta_spent": 0.0,
			"avg_turns_survived": 0.0,
			"avg_low_sta_turns": 0.0,
			"avg_zero_sta_turns": 0.0,
		},
		"outcome_end_state_averages": {
			"wins": {"remaining_hp": 0.0, "remaining_sta": 0.0},
			"losses": {"remaining_hp": 0.0, "remaining_sta": 0.0},
		},
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

func _accumulate_events(result: Dictionary, combat_events: Array[Dictionary], skill_entries: Dictionary) -> void:
	var attacker_metrics: Dictionary = result.get("fighters", {}).get("attacker", {})
	var defender_metrics: Dictionary = result.get("fighters", {}).get("defender", {})
	for event in combat_events:
		var event_type: String = str(event.get("type", ""))
		if event_type == "ACTION_USED":
			var skill_id: String = str(event.get("skill_id", "UNKNOWN_ACTION"))
			_increment_count(result.action_usage_counts, skill_id)
			var actor_side_id: String = str(event.get("actor_side_id", ""))
			var actor_metrics: Dictionary = _fighter_metrics(result, actor_side_id)
			var target_metrics: Dictionary = _fighter_metrics(result, _other_side_id(actor_side_id))
			if not actor_metrics.is_empty():
				_increment_count(actor_metrics.ability_usage_counts, skill_id)
				actor_metrics.actions_used_total = int(actor_metrics.actions_used_total) + 1
				var skill: Dictionary = skill_entries.get(skill_id, {})
				actor_metrics.sta_spent_total = int(actor_metrics.sta_spent_total) + int(skill.get("sta_cost", 0))
				if bool(event.get("hit", false)):
					actor_metrics.hit_count = int(actor_metrics.hit_count) + 1
				else:
					actor_metrics.miss_count = int(actor_metrics.miss_count) + 1
				actor_metrics.damage_dealt_total = int(actor_metrics.damage_dealt_total) + int(event.get("damage", 0))
			if not target_metrics.is_empty():
				target_metrics.damage_taken_total = int(target_metrics.damage_taken_total) + int(event.get("damage", 0))
		elif event_type == "STATUS_APPLIED":
			var status_id: String = str(event.get("status_id", "UNKNOWN_STATUS"))
			_increment_count(result.status_application_counts, status_id)
			var target_side_id: String = str(event.get("target_side_id", ""))
			var target_metrics: Dictionary = _fighter_metrics(result, target_side_id)
			if not target_metrics.is_empty():
				_increment_count(target_metrics.status_application_counts, status_id)
		elif event_type == "TURN_TELEMETRY" and str(event.get("phase", "")) == "END_OF_TURN":
			var actor_side: String = str(event.get("actor_side_id", ""))
			var target_side: String = str(event.get("target_side_id", ""))
			_accumulate_turn_survival(result, actor_side, int(event.get("actor_sta_after", 0)))
			_accumulate_turn_survival(result, target_side, int(event.get("target_sta_after", 0)))
			_accumulate_status_uptime(result, actor_side, event.get("actor_active_status_ids", []))
			_accumulate_status_uptime(result, target_side, event.get("target_active_status_ids", []))

	result.fighters.attacker = attacker_metrics
	result.fighters.defender = defender_metrics
	_finalize_fighter_averages(result)

func _accumulate_turn_survival(result: Dictionary, side_id: String, sta_after: int) -> void:
	var metrics: Dictionary = _fighter_metrics(result, side_id)
	if metrics.is_empty():
		return
	metrics.turns_survived_total = int(metrics.turns_survived_total) + 1
	if sta_after <= 1:
		metrics.low_sta_turns_total = int(metrics.low_sta_turns_total) + 1
	if sta_after == 0:
		metrics.zero_sta_turns_total = int(metrics.zero_sta_turns_total) + 1

func _accumulate_status_uptime(result: Dictionary, side_id: String, active_status_ids_variant: Variant) -> void:
	var metrics: Dictionary = _fighter_metrics(result, side_id)
	if metrics.is_empty():
		return
	if typeof(active_status_ids_variant) != TYPE_ARRAY:
		return
	var active_status_ids: Array = active_status_ids_variant
	for status_id_variant in active_status_ids:
		var status_id: String = str(status_id_variant)
		if status_id == "":
			continue
		_increment_count(metrics.status_uptime_turns, status_id)

func _accumulate_match_outcomes(result: Dictionary, attacker_state: CombatantRuntimeState, defender_state: CombatantRuntimeState, runtime_state: CombatRuntimeState) -> void:
	var attacker_metrics: Dictionary = _fighter_metrics(result, "A")
	var defender_metrics: Dictionary = _fighter_metrics(result, "B")
	var attacker_won: bool = runtime_state.winner_combatant_id == "A"
	var defender_won: bool = runtime_state.winner_combatant_id == "B"
	if attacker_won:
		attacker_metrics.wins = int(attacker_metrics.wins) + 1
		defender_metrics.losses = int(defender_metrics.losses) + 1
		attacker_metrics.remaining_hp_in_wins_total = int(attacker_metrics.remaining_hp_in_wins_total) + attacker_state.current_hp
		attacker_metrics.remaining_sta_in_wins_total = int(attacker_metrics.remaining_sta_in_wins_total) + attacker_state.current_sta
		defender_metrics.remaining_hp_in_losses_total = int(defender_metrics.remaining_hp_in_losses_total) + defender_state.current_hp
		defender_metrics.remaining_sta_in_losses_total = int(defender_metrics.remaining_sta_in_losses_total) + defender_state.current_sta
	elif defender_won:
		defender_metrics.wins = int(defender_metrics.wins) + 1
		attacker_metrics.losses = int(attacker_metrics.losses) + 1
		defender_metrics.remaining_hp_in_wins_total = int(defender_metrics.remaining_hp_in_wins_total) + defender_state.current_hp
		defender_metrics.remaining_sta_in_wins_total = int(defender_metrics.remaining_sta_in_wins_total) + defender_state.current_sta
		attacker_metrics.remaining_hp_in_losses_total = int(attacker_metrics.remaining_hp_in_losses_total) + attacker_state.current_hp
		attacker_metrics.remaining_sta_in_losses_total = int(attacker_metrics.remaining_sta_in_losses_total) + attacker_state.current_sta

func _finalize_fighter_averages(result: Dictionary) -> void:
	var total_runs: int = maxi(1, int(result.get("total_runs", 0)))
	for side_key in ["attacker", "defender"]:
		var metrics: Dictionary = result.get("fighters", {}).get(side_key, {})
		if metrics.is_empty():
			continue
		metrics.per_match.avg_damage_dealt = float(metrics.damage_dealt_total) / float(total_runs)
		metrics.per_match.avg_damage_taken = float(metrics.damage_taken_total) / float(total_runs)
		metrics.per_match.avg_sta_spent = float(metrics.sta_spent_total) / float(total_runs)
		metrics.per_match.avg_turns_survived = float(metrics.turns_survived_total) / float(total_runs)
		metrics.per_match.avg_low_sta_turns = float(metrics.low_sta_turns_total) / float(total_runs)
		metrics.per_match.avg_zero_sta_turns = float(metrics.zero_sta_turns_total) / float(total_runs)
		var win_count: int = int(metrics.wins)
		var loss_count: int = int(metrics.losses)
		if win_count > 0:
			metrics.outcome_end_state_averages.wins.remaining_hp = float(metrics.remaining_hp_in_wins_total) / float(win_count)
			metrics.outcome_end_state_averages.wins.remaining_sta = float(metrics.remaining_sta_in_wins_total) / float(win_count)
		if loss_count > 0:
			metrics.outcome_end_state_averages.losses.remaining_hp = float(metrics.remaining_hp_in_losses_total) / float(loss_count)
			metrics.outcome_end_state_averages.losses.remaining_sta = float(metrics.remaining_sta_in_losses_total) / float(loss_count)

func _fighter_metrics(result: Dictionary, side_id: String) -> Dictionary:
	if side_id == "A":
		return result.get("fighters", {}).get("attacker", {})
	if side_id == "B":
		return result.get("fighters", {}).get("defender", {})
	return {}

func _other_side_id(side_id: String) -> String:
	if side_id == "A":
		return "B"
	if side_id == "B":
		return "A"
	return ""

func _increment_count(target: Dictionary, key: String) -> void:
	target[key] = int(target.get(key, 0)) + 1
