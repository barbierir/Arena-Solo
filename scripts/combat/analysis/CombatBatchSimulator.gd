extends RefCounted
class_name CombatBatchSimulator

const COMBAT_SIMULATION_SCRIPT := preload("res://scripts/combat/CombatSimulation.gd")
const RNG_SERVICE_SCRIPT := preload("res://scripts/utilities/SeededRngService.gd")
const REPORTS_DIR: String = "user://batch_reports"

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
		_accumulate_log_metrics(result, runtime_state.combat_log)
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
	var aggregate: Dictionary = result.get("aggregate_metrics", {})
	var winner_count: int = int(aggregate.get("winner_count", 0))
	if winner_count > 0:
		aggregate.winner_remaining_hp_average = float(aggregate.get("winner_remaining_hp_total", 0)) / float(winner_count)
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
		"aggregate_metrics": {
			"turns_lost_to_stun": {"A": 0, "B": 0},
			"focused": {"gained": {"A": 0, "B": 0}, "consumed": {"A": 0, "B": 0}},
			"off_balance": {"applied": {"A": 0, "B": 0}, "consumed": {"A": 0, "B": 0}},
			"crit_count": {"A": 0, "B": 0},
			"miss_count": {"A": 0, "B": 0},
			"entangled_applications_received": {"A": 0, "B": 0},
			"recover_usage": {"A": 0, "B": 0},
			"winner_remaining_hp_total": 0,
			"winner_count": 0,
			"winner_remaining_hp_average": 0.0,
		},
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
	var aggregate: Dictionary = result.get("aggregate_metrics", {})
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
					_increment_side_count(aggregate.get("miss_count", {}), actor_side_id)
				actor_metrics.damage_dealt_total = int(actor_metrics.damage_dealt_total) + int(event.get("damage", 0))
				if bool(event.get("is_crit", false)):
					_increment_side_count(aggregate.get("crit_count", {}), actor_side_id)
				if skill_id == "RECOVER":
					_increment_side_count(aggregate.get("recover_usage", {}), actor_side_id)
			if not target_metrics.is_empty():
				target_metrics.damage_taken_total = int(target_metrics.damage_taken_total) + int(event.get("damage", 0))
		elif event_type == "STATUS_APPLIED":
			var status_id: String = str(event.get("status_id", "UNKNOWN_STATUS"))
			_increment_count(result.status_application_counts, status_id)
			var target_side_id: String = str(event.get("target_side_id", ""))
			var target_metrics: Dictionary = _fighter_metrics(result, target_side_id)
			if not target_metrics.is_empty():
				_increment_count(target_metrics.status_application_counts, status_id)
			if status_id == "ENTANGLED":
				_increment_side_count(aggregate.get("entangled_applications_received", {}), target_side_id)
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

func _accumulate_log_metrics(result: Dictionary, combat_log: Array[String]) -> void:
	var aggregate: Dictionary = result.get("aggregate_metrics", {})
	for line in combat_log:
		var text: String = str(line)
		var side_id: String = "A" if text.begins_with("A ") else ("B" if text.begins_with("B ") else "")
		if side_id == "":
			continue
		if "is stunned and loses the turn." in text:
			_increment_side_count(aggregate.get("turns_lost_to_stun", {}), side_id)
		if "Recover grants Focused." in text:
			_increment_side_count(aggregate.get("focused", {}).get("gained", {}), side_id)
		if "spends Focused" in text:
			_increment_side_count(aggregate.get("focused", {}).get("consumed", {}), side_id)
		if "becomes Off-Balance" in text:
			_increment_side_count(aggregate.get("off_balance", {}).get("applied", {}), side_id)
		if "Off-Balance reduces damage" in text:
			_increment_side_count(aggregate.get("off_balance", {}).get("consumed", {}), side_id)

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
	var aggregate: Dictionary = result.get("aggregate_metrics", {})
	var attacker_won: bool = runtime_state.winner_combatant_id == "A"
	var defender_won: bool = runtime_state.winner_combatant_id == "B"
	if attacker_won:
		attacker_metrics.wins = int(attacker_metrics.wins) + 1
		defender_metrics.losses = int(defender_metrics.losses) + 1
		attacker_metrics.remaining_hp_in_wins_total = int(attacker_metrics.remaining_hp_in_wins_total) + attacker_state.current_hp
		attacker_metrics.remaining_sta_in_wins_total = int(attacker_metrics.remaining_sta_in_wins_total) + attacker_state.current_sta
		defender_metrics.remaining_hp_in_losses_total = int(defender_metrics.remaining_hp_in_losses_total) + defender_state.current_hp
		defender_metrics.remaining_sta_in_losses_total = int(defender_metrics.remaining_sta_in_losses_total) + defender_state.current_sta
		aggregate.winner_remaining_hp_total = int(aggregate.get("winner_remaining_hp_total", 0)) + attacker_state.current_hp
		aggregate.winner_count = int(aggregate.get("winner_count", 0)) + 1
	elif defender_won:
		defender_metrics.wins = int(defender_metrics.wins) + 1
		attacker_metrics.losses = int(attacker_metrics.losses) + 1
		defender_metrics.remaining_hp_in_wins_total = int(defender_metrics.remaining_hp_in_wins_total) + defender_state.current_hp
		defender_metrics.remaining_sta_in_wins_total = int(defender_metrics.remaining_sta_in_wins_total) + defender_state.current_sta
		attacker_metrics.remaining_hp_in_losses_total = int(attacker_metrics.remaining_hp_in_losses_total) + attacker_state.current_hp
		attacker_metrics.remaining_sta_in_losses_total = int(attacker_metrics.remaining_sta_in_losses_total) + attacker_state.current_sta
		aggregate.winner_remaining_hp_total = int(aggregate.get("winner_remaining_hp_total", 0)) + defender_state.current_hp
		aggregate.winner_count = int(aggregate.get("winner_count", 0)) + 1

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

func _increment_side_count(target: Dictionary, side_id: String) -> void:
	if side_id != "A" and side_id != "B":
		return
	target[side_id] = int(target.get(side_id, 0)) + 1

func batch_result_to_report_dict(batch_result: Dictionary, build_entries: Dictionary = {}, exported_at_iso_utc: String = "") -> Dictionary:
	var inputs: Dictionary = batch_result.get("inputs", {})
	var attacker_id: String = str(inputs.get("attacker_build_id", ""))
	var defender_id: String = str(inputs.get("defender_build_id", ""))
	return {
		"metadata": {
			"report_version": 1,
			"exported_at_utc": exported_at_iso_utc,
			"attacker_display_name": _build_display_label(build_entries, attacker_id),
			"defender_display_name": _build_display_label(build_entries, defender_id),
		},
		"batch_result": batch_result,
	}

func format_batch_result_text(batch_result: Dictionary, build_entries: Dictionary = {}, exported_at_iso_utc: String = "") -> String:
	var total_runs: int = int(batch_result.get("total_runs", 0))
	var attacker_id: String = str(batch_result.get("inputs", {}).get("attacker_build_id", ""))
	var defender_id: String = str(batch_result.get("inputs", {}).get("defender_build_id", ""))
	var attacker_name: String = _build_display_label(build_entries, attacker_id)
	var defender_name: String = _build_display_label(build_entries, defender_id)
	var attacker_wins: int = int(batch_result.get("wins", {}).get("attacker", 0))
	var defender_wins: int = int(batch_result.get("wins", {}).get("defender", 0))
	var attacker_win_rate: float = float(batch_result.get("win_rates", {}).get("attacker_pct", 0.0))
	var defender_win_rate: float = float(batch_result.get("win_rates", {}).get("defender_pct", 0.0))
	var avg_turns: float = float(batch_result.get("turn_stats", {}).get("average", 0.0))
	var lines: Array[String] = []
	lines.append("GLADIUS Batch Report")
	lines.append("Export UTC: %s" % exported_at_iso_utc)
	lines.append("Inputs:")
	lines.append("- A: %s (%s)" % [attacker_name, attacker_id])
	lines.append("- B: %s (%s)" % [defender_name, defender_id])
	lines.append("- Start Seed: %d" % int(batch_result.get("inputs", {}).get("start_seed", 0)))
	lines.append("- Simulations: %d" % total_runs)
	lines.append("- Max Turns/Fight: %d" % int(batch_result.get("inputs", {}).get("max_turns", 0)))
	lines.append("")
	lines.append("Summary:")
	lines.append("- A wins: %d (%.2f%%)" % [attacker_wins, attacker_win_rate])
	lines.append("- B wins: %d (%.2f%%)" % [defender_wins, defender_win_rate])
	lines.append("- Draws/Unresolved: %d" % int(batch_result.get("wins", {}).get("draws_or_unresolved", 0)))
	lines.append("- Turns avg/min/max: %.2f / %d / %d" % [
		avg_turns,
		int(batch_result.get("turn_stats", {}).get("min", 0)),
		int(batch_result.get("turn_stats", {}).get("max", 0)),
	])
	lines.append("")
	lines.append("Terminal Conditions:")
	lines.append_array(_sorted_count_lines(batch_result.get("terminal_condition_counts", {})))
	lines.append("")
	lines.append("Ability Usage (all fights):")
	lines.append_array(_sorted_count_lines(batch_result.get("action_usage_counts", {})))
	lines.append("")
	lines.append("Status Applications (all fights):")
	lines.append_array(_sorted_count_lines(batch_result.get("status_application_counts", {})))
	lines.append("")
	lines.append("Per-Fighter Diagnostics:")
	lines.append_array(_fighter_diagnostics_lines(batch_result.get("fighters", {}).get("attacker", {}), "A", attacker_name))
	lines.append("")
	lines.append_array(_fighter_diagnostics_lines(batch_result.get("fighters", {}).get("defender", {}), "B", defender_name))
	lines.append("")
	lines.append("Extended Aggregate Metrics:")
	lines.append_array(_extended_aggregate_lines(batch_result.get("aggregate_metrics", {}), total_runs))
	return "\n".join(lines)

func save_batch_report(batch_result: Dictionary, build_entries: Dictionary = {}) -> Dictionary:
	var exported_at_iso_utc: String = Time.get_datetime_string_from_system(true, true)
	var report_dir_abs: String = ProjectSettings.globalize_path(REPORTS_DIR)
	var created_ok: bool = DirAccess.make_dir_recursive_absolute(report_dir_abs) == OK
	if not created_ok:
		return {
			"ok": false,
			"error": "Failed to create report directory: %s" % REPORTS_DIR,
			"report_dir": REPORTS_DIR,
		}
	var base_name: String = _unique_report_base_name(batch_result)
	var json_path: String = "%s/%s.json" % [REPORTS_DIR, base_name]
	var txt_path: String = "%s/%s.txt" % [REPORTS_DIR, base_name]
	var report_dict: Dictionary = batch_result_to_report_dict(batch_result, build_entries, exported_at_iso_utc)
	var json_text: String = JSON.stringify(report_dict, "\t", true)
	var text_report: String = format_batch_result_text(batch_result, build_entries, exported_at_iso_utc)
	var json_ok: bool = _write_text_file(json_path, json_text)
	var txt_ok: bool = _write_text_file(txt_path, text_report)
	if not (json_ok and txt_ok):
		return {
			"ok": false,
			"error": "Failed to write one or more report files.",
			"json_path": json_path,
			"txt_path": txt_path,
		}
	return {
		"ok": true,
		"report_dir": REPORTS_DIR,
		"json_path": json_path,
		"txt_path": txt_path,
		"base_name": base_name,
	}

func save_standard_suite_reports(start_seed: int, simulation_count: int, max_turns: int, build_entries: Dictionary = {}) -> Dictionary:
	var suite: Array[Dictionary] = [
		{"label": "RET_vs_RET", "a": "RET_STARTER", "b": "RET_STARTER"},
		{"label": "SEC_vs_SEC", "a": "SEC_STARTER", "b": "SEC_STARTER"},
		{"label": "RET_vs_SEC", "a": "RET_STARTER", "b": "SEC_STARTER"},
		{"label": "SEC_vs_RET", "a": "SEC_STARTER", "b": "RET_STARTER"},
	]
	var saved_reports: Array[Dictionary] = []
	for matchup in suite:
		var result: Dictionary = run_batch(
			str(matchup.get("a", "")),
			str(matchup.get("b", "")),
			start_seed,
			simulation_count,
			max_turns
		)
		var save_outcome: Dictionary = save_batch_report(result, build_entries)
		if not bool(save_outcome.get("ok", false)):
			return {
				"ok": false,
				"error": str(save_outcome.get("error", "Unknown save failure")),
				"saved_reports": saved_reports,
			}
		save_outcome["label"] = str(matchup.get("label", ""))
		saved_reports.append(save_outcome)
		start_seed += simulation_count
	var summary_save: Dictionary = _save_suite_summary(saved_reports, simulation_count, max_turns)
	if not bool(summary_save.get("ok", false)):
		return {
			"ok": false,
			"error": str(summary_save.get("error", "Failed to save suite summary")),
			"saved_reports": saved_reports,
		}
	return {
		"ok": true,
		"saved_reports": saved_reports,
		"summary_path": str(summary_save.get("summary_path", "")),
	}

func _save_suite_summary(saved_reports: Array[Dictionary], simulation_count: int, max_turns: int) -> Dictionary:
	var summary_lines: Array[String] = []
	var exported_at_iso_utc: String = Time.get_datetime_string_from_system(true, true)
	summary_lines.append("GLADIUS Standard Suite Report")
	summary_lines.append("Export UTC: %s" % exported_at_iso_utc)
	summary_lines.append("Runs per matchup: %d | Max Turns: %d" % [simulation_count, max_turns])
	summary_lines.append("")
	for saved in saved_reports:
		summary_lines.append("- %s" % str(saved.get("label", "")))
		summary_lines.append("  JSON: %s" % str(saved.get("json_path", "")))
		summary_lines.append("  TXT : %s" % str(saved.get("txt_path", "")))
	var base_name: String = "suite_%s_runs%d_max%d" % [_timestamp_for_filename(), simulation_count, max_turns]
	var summary_path: String = "%s/%s.txt" % [REPORTS_DIR, base_name]
	if not _write_text_file(summary_path, "\n".join(summary_lines)):
		return {"ok": false, "error": "Could not write summary file", "summary_path": summary_path}
	return {"ok": true, "summary_path": summary_path}

func _unique_report_base_name(batch_result: Dictionary) -> String:
	var inputs: Dictionary = batch_result.get("inputs", {})
	var attacker_id: String = _sanitize_filename_token(str(inputs.get("attacker_build_id", "ATTACKER")))
	var defender_id: String = _sanitize_filename_token(str(inputs.get("defender_build_id", "DEFENDER")))
	var start_seed: int = int(inputs.get("start_seed", 0))
	var run_count: int = int(batch_result.get("total_runs", 0))
	var base_name: String = "batch_%s_vs_%s_%d_seed%d" % [
		attacker_id,
		defender_id,
		run_count,
		start_seed,
	]
	var candidate: String = base_name
	var suffix: int = 1
	while FileAccess.file_exists("%s/%s.json" % [REPORTS_DIR, candidate]) or FileAccess.file_exists("%s/%s.txt" % [REPORTS_DIR, candidate]):
		candidate = "%s_%02d" % [base_name, suffix]
		suffix += 1
	return candidate

func _timestamp_for_filename() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d%02d%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]

func _sanitize_filename_token(value: String) -> String:
	var token: String = value.strip_edges().to_upper()
	if token == "":
		return "UNKNOWN"
	var sanitized: String = ""
	for i in range(token.length()):
		var ch: String = token.substr(i, 1)
		var is_letter: bool = ch >= "A" and ch <= "Z"
		var is_number: bool = ch >= "0" and ch <= "9"
		if is_letter or is_number:
			sanitized += ch
		else:
			sanitized += "_"
	return sanitized

func _write_text_file(path: String, contents: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	return true

func _build_display_label(build_entries: Dictionary, build_id: String) -> String:
	var entry: Dictionary = build_entries.get(build_id, {})
	return str(entry.get("display_name", build_id))

func _sorted_count_lines(counts_variant: Variant) -> Array[String]:
	if typeof(counts_variant) != TYPE_DICTIONARY:
		return ["- (none)"]
	var counts: Dictionary = counts_variant
	if counts.is_empty():
		return ["- (none)"]
	var keys: Array[String] = []
	for key_variant in counts.keys():
		keys.append(str(key_variant))
	keys.sort()
	var lines: Array[String] = []
	for key in keys:
		lines.append("- %s: %d" % [key, int(counts.get(key, 0))])
	return lines

func _extended_aggregate_lines(aggregate_metrics: Dictionary, total_runs: int) -> Array[String]:
	if aggregate_metrics.is_empty():
		return ["- (none)"]
	var runs: int = maxi(1, total_runs)
	var lines: Array[String] = []
	var stun: Dictionary = aggregate_metrics.get("turns_lost_to_stun", {})
	var focused: Dictionary = aggregate_metrics.get("focused", {})
	var off_balance: Dictionary = aggregate_metrics.get("off_balance", {})
	var crit: Dictionary = aggregate_metrics.get("crit_count", {})
	var miss: Dictionary = aggregate_metrics.get("miss_count", {})
	var entangled: Dictionary = aggregate_metrics.get("entangled_applications_received", {})
	var recover: Dictionary = aggregate_metrics.get("recover_usage", {})
	lines.append("- Turns lost to stun (A/B): %d / %d" % [int(stun.get("A", 0)), int(stun.get("B", 0))])
	lines.append("- Focused gained (A/B): %d / %d" % [
		int(focused.get("gained", {}).get("A", 0)),
		int(focused.get("gained", {}).get("B", 0)),
	])
	lines.append("- Focused consumed (A/B): %d / %d" % [
		int(focused.get("consumed", {}).get("A", 0)),
		int(focused.get("consumed", {}).get("B", 0)),
	])
	lines.append("- Off-Balance applied (A/B): %d / %d" % [
		int(off_balance.get("applied", {}).get("A", 0)),
		int(off_balance.get("applied", {}).get("B", 0)),
	])
	lines.append("- Off-Balance consumed (A/B): %d / %d" % [
		int(off_balance.get("consumed", {}).get("A", 0)),
		int(off_balance.get("consumed", {}).get("B", 0)),
	])
	lines.append("- Crit count (A/B): %d / %d" % [int(crit.get("A", 0)), int(crit.get("B", 0))])
	lines.append("- Miss count (A/B): %d / %d" % [int(miss.get("A", 0)), int(miss.get("B", 0))])
	lines.append("- Entangled applications received (A/B): %d / %d" % [int(entangled.get("A", 0)), int(entangled.get("B", 0))])
	lines.append("- Recover usage (A/B): %d / %d" % [int(recover.get("A", 0)), int(recover.get("B", 0))])
	lines.append("- Avg winner remaining HP: %.2f" % float(aggregate_metrics.get("winner_remaining_hp_average", 0.0)))
	lines.append("- Avg turns lost to stun per match: %.4f" % (float(int(stun.get("A", 0)) + int(stun.get("B", 0))) / float(runs)))
	return lines

func _fighter_diagnostics_lines(metrics: Dictionary, side_id: String, display_name: String) -> Array[String]:
	if metrics.is_empty():
		return ["%s (%s): no data." % [side_id, display_name]]
	var per_match: Dictionary = metrics.get("per_match", {})
	var lines: Array[String] = []
	lines.append("%s (%s):" % [side_id, display_name])
	lines.append("- Build ID: %s" % str(metrics.get("build_id", "")))
	lines.append("- W/L: %d / %d" % [int(metrics.get("wins", 0)), int(metrics.get("losses", 0))])
	lines.append("- Avg damage dealt/taken: %.2f / %.2f" % [
		float(per_match.get("avg_damage_dealt", 0.0)),
		float(per_match.get("avg_damage_taken", 0.0)),
	])
	lines.append("- Avg stamina spent: %.2f" % float(per_match.get("avg_sta_spent", 0.0)))
	lines.append("- Hit/Miss: %d / %d" % [int(metrics.get("hit_count", 0)), int(metrics.get("miss_count", 0))])
	lines.append("- Avg turns survived: %.2f" % float(per_match.get("avg_turns_survived", 0.0)))
	lines.append("- Avg low/zero STA turns: %.2f / %.2f" % [
		float(per_match.get("avg_low_sta_turns", 0.0)),
		float(per_match.get("avg_zero_sta_turns", 0.0)),
	])
	var outcome: Dictionary = metrics.get("outcome_end_state_averages", {})
	var win_end: Dictionary = outcome.get("wins", {})
	var loss_end: Dictionary = outcome.get("losses", {})
	lines.append("- End state in wins (HP/STA): %.2f / %.2f" % [
		float(win_end.get("remaining_hp", 0.0)),
		float(win_end.get("remaining_sta", 0.0)),
	])
	lines.append("- End state in losses (HP/STA): %.2f / %.2f" % [
		float(loss_end.get("remaining_hp", 0.0)),
		float(loss_end.get("remaining_sta", 0.0)),
	])
	lines.append("- Ability usage:")
	lines.append_array(_sorted_count_lines(metrics.get("ability_usage_counts", {})))
	lines.append("- Status applications:")
	lines.append_array(_sorted_count_lines(metrics.get("status_application_counts", {})))
	lines.append("- Status uptime turns:")
	lines.append_array(_sorted_count_lines(metrics.get("status_uptime_turns", {})))
	return lines
