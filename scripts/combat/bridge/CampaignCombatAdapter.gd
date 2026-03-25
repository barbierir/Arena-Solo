extends Node
class_name CampaignCombatAdapter

const CONTENT_LOADER_SCRIPT: GDScript = preload("res://scripts/data/loaders/ContentLoader.gd")
const RNG_SERVICE_SCRIPT: GDScript = preload("res://scripts/utilities/SeededRngService.gd")
const COMBAT_SIMULATION_SCRIPT: GDScript = preload("res://scripts/combat/CombatSimulation.gd")

const REWARD_GOLD_PER_FIGHT: int = 20
const REWARD_FAME_PER_WIN: int = 5

var _content_registry: ContentRegistry

func _ready() -> void:
	_ensure_content_loaded()

func run_payload(payload: Dictionary) -> Dictionary:
	_ensure_content_loaded()
	if payload.is_empty():
		return {"error": "Empty payload"}
	var attacker_id: String = str(payload.get("attacker_build_id", ""))
	var defender_id: String = str(payload.get("defender_build_id", ""))
	if attacker_id == "" or defender_id == "":
		return {"error": "Missing build ids in payload"}

	var seed: int = int(payload.get("seed", 1))
	var rng_service: SeededRngService = RNG_SERVICE_SCRIPT.new(seed)
	var simulation: CombatSimulation = COMBAT_SIMULATION_SCRIPT.new()
	simulation.configure(_content_registry, rng_service)
	simulation.initialize_fight(attacker_id, defender_id)
	simulation.run_to_completion()

	var runtime_state: CombatRuntimeState = simulation.get_runtime_state()
	var fighter_a: Dictionary = payload.get("fighter_a", {})
	var fighter_b: Dictionary = payload.get("fighter_b", {})
	var winner_side_id: String = runtime_state.winner_combatant_id
	var loser_side_id: String = runtime_state.other_side_id(winner_side_id)
	if winner_side_id == "":
		return {
			"error": "Combat ended without winner",
			"turns": runtime_state.turn_index,
			"combat_log": runtime_state.combat_log.duplicate(),
			"combat_events": runtime_state.combat_events.duplicate(true),
		}

	var winner_id: String = str(fighter_a.get("id", "")) if winner_side_id == CombatRuntimeState.ATTACKER_SIDE_ID else str(fighter_b.get("id", ""))
	var loser_id: String = str(fighter_a.get("id", "")) if loser_side_id == CombatRuntimeState.ATTACKER_SIDE_ID else str(fighter_b.get("id", ""))
	var winner_state: CombatantRuntimeState = runtime_state.combatant_states.get(winner_side_id)
	var loser_state: CombatantRuntimeState = runtime_state.combatant_states.get(loser_side_id)
	return {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"turns": runtime_state.turn_index,
		"winner_remaining_hp": 0 if winner_state == null else winner_state.current_hp,
		"loser_dead": true if loser_state == null else not loser_state.is_alive(),
		"combat_log": runtime_state.combat_log.duplicate(),
		"combat_events": runtime_state.combat_events.duplicate(true),
		"reward_summary": {
			"gold": REWARD_GOLD_PER_FIGHT,
			"fame": REWARD_FAME_PER_WIN,
		},
	}

func _ensure_content_loaded() -> void:
	if _content_registry != null:
		return
	var loader: ContentLoader = CONTENT_LOADER_SCRIPT.new()
	_content_registry = loader.load_all_definitions()
