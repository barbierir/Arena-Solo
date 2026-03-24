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

func _ready() -> void:
	_content_loader = CONTENT_LOADER_SCRIPT.new()
	_content_registry = _content_loader.load_all_definitions()
	viewer.set_status_definitions(_content_registry.status_effects.get("entries", {}))
	viewer.set_seed_value(_last_seed)
	viewer.connect_actions(_on_run_pressed, _on_replay_pressed)
	_run_fight(_last_seed)

func _on_run_pressed() -> void:
	_last_seed = viewer.seed_value()
	_run_fight(_last_seed)

func _on_replay_pressed() -> void:
	_run_fight(_last_seed)

func _run_fight(seed: int) -> void:
	_rng_service = RNG_SERVICE_SCRIPT.new(seed)
	_combat_simulation = COMBAT_SIMULATION_SCRIPT.new()
	_combat_simulation.configure(_content_registry, _rng_service)
	_combat_simulation.bootstrap_default_encounter("RET_STARTER", "SEC_STARTER")
	_combat_simulation.simulate_to_completion()
	viewer.render_state(_combat_simulation.runtime_state)
