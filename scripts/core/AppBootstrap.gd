extends Node
class_name AppBootstrap

const CONTENT_LOADER_SCRIPT := preload("res://scripts/data/loaders/ContentLoader.gd")
const RNG_SERVICE_SCRIPT := preload("res://scripts/utilities/SeededRngService.gd")
const COMBAT_SIMULATION_SCRIPT := preload("res://scripts/combat/CombatSimulation.gd")

var content_loader: ContentLoader
var content_registry: ContentRegistry
var rng_service: SeededRngService
var combat_simulation: CombatSimulation

@export var startup_seed: int = 1001

func _ready() -> void:
	content_loader = CONTENT_LOADER_SCRIPT.new()
	content_registry = content_loader.load_all_definitions()
	rng_service = RNG_SERVICE_SCRIPT.new(startup_seed)
	combat_simulation = COMBAT_SIMULATION_SCRIPT.new()

	combat_simulation.configure(content_registry, rng_service)
	combat_simulation.bootstrap_default_encounter("RET_STARTER", "SEC_STARTER")
