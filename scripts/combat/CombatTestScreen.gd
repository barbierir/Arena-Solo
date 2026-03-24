extends Node2D
class_name CombatTestScreen

const CONTENT_LOADER_SCRIPT := preload("res://scripts/data/loaders/ContentLoader.gd")
const RNG_SERVICE_SCRIPT := preload("res://scripts/utilities/SeededRngService.gd")
const COMBAT_SIMULATION_SCRIPT := preload("res://scripts/combat/CombatSimulation.gd")

@onready var viewer: CombatViewer = %CombatViewer

var _content_loader: ContentLoader
var _content_registry: ContentRegistry
var _rng_service: SeededRngService
var _combat_simulation: CombatSimulation
var _last_seed: int = 1001
var _last_attacker_build_id: String = "RET_STARTER"
var _last_defender_build_id: String = "SEC_STARTER"

func _ready() -> void:
	_content_loader = CONTENT_LOADER_SCRIPT.new()
	_content_registry = _content_loader.load_all_definitions()
	viewer.set_status_definitions(_content_registry.status_effects.get("entries", {}))
	viewer.set_fighter_options(_content_registry.builds.get("entries", {}), _last_attacker_build_id, _last_defender_build_id)
	viewer.set_seed_value(_last_seed)
	viewer.connect_actions(_on_run_pressed, _on_step_turn_pressed, _on_replay_pressed)
	_start_fight(_last_seed, _last_attacker_build_id, _last_defender_build_id)
	viewer.render_state(_combat_simulation.get_runtime_state())

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

func _start_fight(match_seed: int, attacker_build_id: String, defender_build_id: String) -> void:
	_rng_service = RNG_SERVICE_SCRIPT.new(match_seed)
	_combat_simulation = COMBAT_SIMULATION_SCRIPT.new()
	_combat_simulation.configure(_content_registry, _rng_service)
	_combat_simulation.initialize_fight(attacker_build_id, defender_build_id)
