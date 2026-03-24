extends Control
class_name CombatViewer

var status_defs: Dictionary = {}

@onready var attacker_name_label: Label = %AttackerNameLabel
@onready var attacker_hp_label: Label = %AttackerHpLabel
@onready var attacker_sta_label: Label = %AttackerStaLabel
@onready var attacker_status_label: Label = %AttackerStatusLabel

@onready var defender_name_label: Label = %DefenderNameLabel
@onready var defender_hp_label: Label = %DefenderHpLabel
@onready var defender_sta_label: Label = %DefenderStaLabel
@onready var defender_status_label: Label = %DefenderStatusLabel

@onready var turn_label: Label = %TurnLabel
@onready var actor_label: Label = %ActorLabel
@onready var combat_log_box: RichTextLabel = %CombatLogLabel
@onready var result_label: Label = %ResultLabel
@onready var seed_input: LineEdit = %SeedInput
@onready var attacker_selector: OptionButton = %AttackerSelector
@onready var defender_selector: OptionButton = %DefenderSelector
@onready var step_turn_button: Button = %StepTurnButton
@onready var run_fight_button: Button = %RunFightButton
@onready var replay_button: Button = %ReplayButton
@onready var batch_seed_input: LineEdit = %BatchSeedInput
@onready var batch_count_input: LineEdit = %BatchCountInput
@onready var batch_max_turns_input: LineEdit = %BatchMaxTurnsInput
@onready var run_batch_button: Button = %RunBatchButton
@onready var batch_summary_label: Label = %BatchSummaryLabel
@onready var batch_results_label: RichTextLabel = %BatchResultsLabel

func connect_actions(on_run: Callable, on_step_turn: Callable, on_replay: Callable, on_run_batch: Callable) -> void:
	run_fight_button.pressed.connect(on_run)
	step_turn_button.pressed.connect(on_step_turn)
	replay_button.pressed.connect(on_replay)
	run_batch_button.pressed.connect(on_run_batch)

func seed_value() -> int:
	return int(seed_input.text)

func set_seed_value(value: int) -> void:
	seed_input.text = str(value)
	batch_seed_input.text = str(value)

func batch_seed_value() -> int:
	return int(batch_seed_input.text)

func batch_count_value() -> int:
	return maxi(0, int(batch_count_input.text))

func batch_max_turns_value() -> int:
	return maxi(1, int(batch_max_turns_input.text))

func set_status_definitions(definitions: Dictionary) -> void:
	status_defs = definitions

func set_fighter_options(build_entries: Dictionary, default_attacker_id: String, default_defender_id: String) -> void:
	attacker_selector.clear()
	defender_selector.clear()
	var build_ids: Array[String] = []
	for build_id_variant in build_entries.keys():
		build_ids.append(str(build_id_variant))
	build_ids.sort()
	for build_id in build_ids:
		var entry: Dictionary = build_entries.get(build_id, {})
		var label: String = "%s (%s)" % [str(entry.get("display_name", build_id)), build_id]
		attacker_selector.add_item(label)
		attacker_selector.set_item_metadata(attacker_selector.item_count - 1, build_id)
		defender_selector.add_item(label)
		defender_selector.set_item_metadata(defender_selector.item_count - 1, build_id)
	_set_selector_to_build(attacker_selector, default_attacker_id)
	_set_selector_to_build(defender_selector, default_defender_id)

func selected_attacker_build_id() -> String:
	return _selected_build_id(attacker_selector)

func selected_defender_build_id() -> String:
	return _selected_build_id(defender_selector)

func render_state(runtime_state: CombatRuntimeState) -> void:
	if runtime_state == null:
		return
	var attacker: CombatantRuntimeState = runtime_state.attacker_state()
	var defender: CombatantRuntimeState = runtime_state.defender_state()

	attacker_name_label.text = attacker.display_name
	attacker_hp_label.text = "HP: %d/%d" % [attacker.current_hp, attacker.max_hp]
	attacker_sta_label.text = "STA: %d/%d" % [attacker.current_sta, attacker.max_sta]
	attacker_status_label.text = "Statuses: %s" % attacker.status_labels(status_defs)

	defender_name_label.text = defender.display_name
	defender_hp_label.text = "HP: %d/%d" % [defender.current_hp, defender.max_hp]
	defender_sta_label.text = "STA: %d/%d" % [defender.current_sta, defender.max_sta]
	defender_status_label.text = "Statuses: %s" % defender.status_labels(status_defs)

	turn_label.text = "Turn: %d" % runtime_state.turn_index
	actor_label.text = "Current Actor: %s" % runtime_state.current_actor_id
	result_label.text = "Result: %s" % runtime_state.result_state
	combat_log_box.text = "\n".join(runtime_state.combat_log)
	step_turn_button.disabled = runtime_state.result_state != "PENDING"

func render_batch_results(batch_result: Dictionary, build_entries: Dictionary) -> void:
	var total_runs: int = int(batch_result.get("total_runs", 0))
	var attacker_id: String = str(batch_result.get("inputs", {}).get("attacker_build_id", ""))
	var defender_id: String = str(batch_result.get("inputs", {}).get("defender_build_id", ""))
	var attacker_name: String = _build_display_label(build_entries, attacker_id)
	var defender_name: String = _build_display_label(build_entries, defender_id)
	var attacker_wins: int = int(batch_result.get("wins", {}).get("attacker", 0))
	var defender_wins: int = int(batch_result.get("wins", {}).get("defender", 0))
	var attacker_win_rate: float = float(batch_result.get("win_rates", {}).get("attacker_pct", 0.0))
	var avg_turns: float = float(batch_result.get("turn_stats", {}).get("average", 0.0))
	batch_summary_label.text = "%s won %d/%d (%.1f%%), %s won %d/%d (%.1f%%), avg %.2f turns." % [
		attacker_name,
		attacker_wins,
		total_runs,
		attacker_win_rate,
		defender_name,
		defender_wins,
		total_runs,
		float(batch_result.get("win_rates", {}).get("defender_pct", 0.0)),
		avg_turns,
	]

	var lines: Array[String] = []
	lines.append("Inputs:")
	lines.append("- A: %s (%s)" % [attacker_name, attacker_id])
	lines.append("- B: %s (%s)" % [defender_name, defender_id])
	lines.append("- Start Seed: %d" % int(batch_result.get("inputs", {}).get("start_seed", 0)))
	lines.append("- Simulations: %d" % total_runs)
	lines.append("- Max Turns/Fight: %d" % int(batch_result.get("inputs", {}).get("max_turns", 0)))
	lines.append("")
	lines.append("Outcomes:")
	lines.append("- A wins: %d (%.2f%%)" % [attacker_wins, attacker_win_rate])
	lines.append("- B wins: %d (%.2f%%)" % [defender_wins, float(batch_result.get("win_rates", {}).get("defender_pct", 0.0))])
	lines.append("- Draws/Unresolved: %d" % int(batch_result.get("wins", {}).get("draws_or_unresolved", 0)))
	lines.append("")
	lines.append("Turn Stats:")
	lines.append("- Average turns: %.2f" % avg_turns)
	lines.append("- Min turns: %d" % int(batch_result.get("turn_stats", {}).get("min", 0)))
	lines.append("- Max turns: %d" % int(batch_result.get("turn_stats", {}).get("max", 0)))
	lines.append("")
	lines.append("End State Averages:")
	lines.append("- A HP: %.2f | A STA: %.2f" % [
		float(batch_result.get("end_state_averages", {}).get("attacker", {}).get("remaining_hp", 0.0)),
		float(batch_result.get("end_state_averages", {}).get("attacker", {}).get("remaining_sta", 0.0)),
	])
	lines.append("- B HP: %.2f | B STA: %.2f" % [
		float(batch_result.get("end_state_averages", {}).get("defender", {}).get("remaining_hp", 0.0)),
		float(batch_result.get("end_state_averages", {}).get("defender", {}).get("remaining_sta", 0.0)),
	])
	lines.append("")
	lines.append("Terminal Conditions:")
	lines.append_array(_sorted_count_lines(batch_result.get("terminal_condition_counts", {})))
	lines.append("")
	lines.append("Ability Usage:")
	lines.append_array(_sorted_count_lines(batch_result.get("action_usage_counts", {})))
	lines.append("")
	lines.append("Status Applications:")
	lines.append_array(_sorted_count_lines(batch_result.get("status_application_counts", {})))
	lines.append("")
	lines.append("Per-Fighter Diagnostics:")
	lines.append_array(_fighter_diagnostics_lines(batch_result.get("fighters", {}).get("attacker", {}), "A", attacker_name))
	lines.append("")
	lines.append_array(_fighter_diagnostics_lines(batch_result.get("fighters", {}).get("defender", {}), "B", defender_name))
	batch_results_label.text = "\n".join(lines)

func _selected_build_id(selector: OptionButton) -> String:
	var selected_index: int = selector.selected
	if selected_index < 0:
		return ""
	return str(selector.get_item_metadata(selected_index))

func _set_selector_to_build(selector: OptionButton, build_id: String) -> void:
	for idx in range(selector.item_count):
		var option_build_id: String = str(selector.get_item_metadata(idx))
		if option_build_id == build_id:
			selector.select(idx)
			return

func _build_display_label(build_entries: Dictionary, build_id: String) -> String:
	var build_entry: Dictionary = build_entries.get(build_id, {})
	return str(build_entry.get("display_name", build_id))

func _sorted_count_lines(counts: Dictionary) -> Array[String]:
	if counts.is_empty():
		return ["- None"]
	var entries: Array[Dictionary] = []
	for key_variant in counts.keys():
		var key: String = str(key_variant)
		entries.append({
			"key": key,
			"count": int(counts.get(key, 0)),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.count) == int(b.count):
			return str(a.key) < str(b.key)
		return int(a.count) > int(b.count)
	)
	var lines: Array[String] = []
	for entry in entries:
		lines.append("- %s: %d" % [str(entry.key), int(entry.count)])
	return lines

func _fighter_diagnostics_lines(metrics: Dictionary, side_id: String, display_name: String) -> Array[String]:
	if metrics.is_empty():
		return ["- %s (%s): no fighter telemetry." % [side_id, display_name]]
	var lines: Array[String] = []
	lines.append("- %s (%s):" % [side_id, display_name])
	lines.append("  - Avg damage dealt/match: %.2f" % float(metrics.get("per_match", {}).get("avg_damage_dealt", 0.0)))
	lines.append("  - Avg damage taken/match: %.2f" % float(metrics.get("per_match", {}).get("avg_damage_taken", 0.0)))
	lines.append("  - Avg STA spent/match: %.2f" % float(metrics.get("per_match", {}).get("avg_sta_spent", 0.0)))
	lines.append("  - Hits/Misses: %d / %d" % [int(metrics.get("hit_count", 0)), int(metrics.get("miss_count", 0))])
	lines.append("  - Avg turns survived: %.2f" % float(metrics.get("per_match", {}).get("avg_turns_survived", 0.0)))
	lines.append("  - Avg low-STA turns (<=1): %.2f" % float(metrics.get("per_match", {}).get("avg_low_sta_turns", 0.0)))
	lines.append("  - Avg zero-STA turns: %.2f" % float(metrics.get("per_match", {}).get("avg_zero_sta_turns", 0.0)))
	lines.append("  - End-state (wins): HP %.2f | STA %.2f" % [
		float(metrics.get("outcome_end_state_averages", {}).get("wins", {}).get("remaining_hp", 0.0)),
		float(metrics.get("outcome_end_state_averages", {}).get("wins", {}).get("remaining_sta", 0.0)),
	])
	lines.append("  - End-state (losses): HP %.2f | STA %.2f" % [
		float(metrics.get("outcome_end_state_averages", {}).get("losses", {}).get("remaining_hp", 0.0)),
		float(metrics.get("outcome_end_state_averages", {}).get("losses", {}).get("remaining_sta", 0.0)),
	])
	lines.append("  - Ability usage:")
	lines.append_array(_indent_lines(_sorted_count_lines(metrics.get("ability_usage_counts", {})), 4))
	lines.append("  - Status applications received:")
	lines.append_array(_indent_lines(_sorted_count_lines(metrics.get("status_application_counts", {})), 4))
	lines.append("  - Status uptime turns:")
	lines.append_array(_indent_lines(_sorted_count_lines(metrics.get("status_uptime_turns", {})), 4))
	return lines

func _indent_lines(lines: Array[String], spaces: int) -> Array[String]:
	var prefixed: Array[String] = []
	var prefix: String = " ".repeat(spaces)
	for line in lines:
		prefixed.append("%s%s" % [prefix, line])
	return prefixed
