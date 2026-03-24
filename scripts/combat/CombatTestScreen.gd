extends Node2D
class_name CombatTestScreen

const CONTENT_LOADER_SCRIPT := preload("res://scripts/data/loaders/ContentLoader.gd")
const RNG_SERVICE_SCRIPT := preload("res://scripts/utilities/SeededRngService.gd")
const COMBAT_SIMULATION_SCRIPT := preload("res://scripts/combat/CombatSimulation.gd")
const COMBAT_BATCH_SIMULATOR_SCRIPT := preload("res://scripts/combat/analysis/CombatBatchSimulator.gd")

@onready var viewer: CombatViewer = %CombatViewer

var _content_loader: ContentLoader
var _content_registry: ContentRegistry
var _rng_service: SeededRngService
var _combat_simulation: CombatSimulation
var _batch_simulator: CombatBatchSimulator
var _last_seed: int = 1001
var _last_attacker_build_id: String = "RET_STARTER"
var _last_defender_build_id: String = "SEC_STARTER"
var _last_batch_result: Dictionary = {}

func _ready() -> void:
	_content_loader = CONTENT_LOADER_SCRIPT.new()
	_content_registry = _content_loader.load_all_definitions()
	viewer.set_status_definitions(_content_registry.status_effects.get("entries", {}))
	viewer.set_fighter_options(_content_registry.builds.get("entries", {}), _last_attacker_build_id, _last_defender_build_id)
	viewer.set_seed_value(_last_seed)
	viewer.connect_actions(
		_on_run_pressed,
		_on_step_turn_pressed,
		_on_replay_pressed,
		_on_run_batch_pressed,
		_on_save_batch_report_pressed,
		_on_run_standard_suite_pressed
	)
	_batch_simulator = COMBAT_BATCH_SIMULATOR_SCRIPT.new()
	_batch_simulator.configure(_content_registry)
	_start_fight(_last_seed, _last_attacker_build_id, _last_defender_build_id)
	viewer.render_state(_combat_simulation.get_runtime_state())
	viewer.set_batch_export_status("No reports saved yet.", false)
	viewer.set_last_saved_path("")

func _on_run_pressed() -> void:
	_last_seed = viewer.seed_value()
	_last_attacker_build_id = viewer.selected_attacker_build_id()
	_last_defender_build_id = viewer.selected_defender_build_id()
	_start_fight(_last_seed, _last_attacker_build_id, _last_defender_build_id)
	_combat_simulation.run_to_completion()
	viewer.render_state(_combat_simulation.get_runtime_state())

func _on_step_turn_pressed() -> void:
	if _combat_simulation == null:
		_last_seed = viewer.seed_value()
		_last_attacker_build_id = viewer.selected_attacker_build_id()
		_last_defender_build_id = viewer.selected_defender_build_id()
		_start_fight(_last_seed, _last_attacker_build_id, _last_defender_build_id)
	if _combat_simulation.is_finished():
		viewer.render_state(_combat_simulation.get_runtime_state())
		return
	_combat_simulation.step_turn()
	viewer.render_state(_combat_simulation.get_runtime_state())

func _on_replay_pressed() -> void:
	if _combat_simulation == null:
		_last_seed = viewer.seed_value()
		_last_attacker_build_id = viewer.selected_attacker_build_id()
		_last_defender_build_id = viewer.selected_defender_build_id()
	_start_fight(_last_seed, _last_attacker_build_id, _last_defender_build_id)
	_combat_simulation.run_to_completion()
	viewer.render_state(_combat_simulation.get_runtime_state())

func _on_run_batch_pressed() -> void:
	_last_attacker_build_id = viewer.selected_attacker_build_id()
	_last_defender_build_id = viewer.selected_defender_build_id()
	var start_seed: int = viewer.batch_seed_value()
	var simulation_count: int = viewer.batch_count_value()
	var max_turns: int = viewer.batch_max_turns_value()
	var batch_result: Dictionary = _batch_simulator.run_batch(
		_last_attacker_build_id,
		_last_defender_build_id,
		start_seed,
		simulation_count,
		max_turns
	)
	_last_batch_result = batch_result
	viewer.render_batch_results(batch_result, _content_registry.builds.get("entries", {}))
	viewer.set_batch_export_status("Batch complete. Ready to save.", true)

func _on_save_batch_report_pressed() -> void:
	if _last_batch_result.is_empty():
		viewer.set_batch_export_status("No batch result available. Run Batch first.", false)
		return
	var build_entries: Dictionary = _content_registry.builds.get("entries", {})
	var save_outcome: Dictionary = _batch_simulator.save_batch_report(_last_batch_result, build_entries)
	if not bool(save_outcome.get("ok", false)):
		viewer.set_batch_export_status("Save failed: %s" % str(save_outcome.get("error", "unknown error")), false)
		return
	var json_path: String = str(save_outcome.get("json_path", ""))
	var txt_path: String = str(save_outcome.get("txt_path", ""))
	viewer.set_batch_export_status("Saved JSON+TXT.", true)
	viewer.set_last_saved_path("%s | %s" % [json_path, txt_path])

func _on_run_standard_suite_pressed() -> void:
	var start_seed: int = viewer.batch_seed_value()
	var simulation_count: int = viewer.batch_count_value()
	var max_turns: int = viewer.batch_max_turns_value()
	var build_entries: Dictionary = _content_registry.builds.get("entries", {})
	var suite_outcome: Dictionary = _batch_simulator.save_standard_suite_reports(start_seed, simulation_count, max_turns, build_entries)
	if not bool(suite_outcome.get("ok", false)):
		viewer.set_batch_export_status("Suite export failed: %s" % str(suite_outcome.get("error", "unknown error")), false)
		return
	var summary_path: String = str(suite_outcome.get("summary_path", ""))
	viewer.set_batch_export_status("Standard suite saved (4 matchup reports + summary).", true)
	viewer.set_last_saved_path(summary_path)

func _start_fight(match_seed: int, attacker_build_id: String, defender_build_id: String) -> void:
	_rng_service = RNG_SERVICE_SCRIPT.new(match_seed)
	_combat_simulation = COMBAT_SIMULATION_SCRIPT.new()
	_combat_simulation.configure(_content_registry, _rng_service)
	_combat_simulation.initialize_fight(attacker_build_id, defender_build_id)
